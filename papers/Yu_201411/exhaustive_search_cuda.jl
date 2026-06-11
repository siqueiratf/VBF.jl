try
    @eval import CUDA
catch err
    throw(
        ArgumentError(
            "GPU backend requested, but CUDA.jl could not be loaded. " *
            "Add CUDA to the active Julia project and rerun with GPU=true. " *
            "Original error: $(err)",
        ),
    )
end

const CUDA_MAX_N = 8
const CUDA_MAX_Q = 1 << CUDA_MAX_N
const CUDA_MAX_MATRIX_WORDS = CUDA_MAX_N * CUDA_MAX_N
const CUDA_MAX_VARIABLES = (CUDA_MAX_N * (CUDA_MAX_N - 1)) ÷ 2 - 1

mutable struct CUDAPipelineSlot
    stream::Any
    event::Any
    d_prefix::Any
    d_prefix_rank::Any
    d_prefix_span::Any
    d_count::Any
    d_out_mats::Any
    h_prefix::Vector{UInt32}
    h_prefix_rank::Vector{UInt32}
    h_prefix_span::Vector{UInt64}
    h_count::Vector{UInt32}
    h_out_mats::Vector{UInt32}
    prefix_entries::Int
    prefix_count::Int
    batch_start::UInt64
    batch_len::Int
    h12::Int
    in_flight::Bool
end

mutable struct CUDAQAMBackend <: AbstractQAMSearchBackend
    requested_device::Union{Nothing,Int}
    active_device::String
    batch_size::Int
    pipeline_depth::Int
    suffix_entries::Int
    result_capacity::Int
    prefix_batch_capacity::Int
    slots::Vector{CUDAPipelineSlot}
end

@inline function _cuda_variable_count(n::Int32)
    (n * (n - Int32(1))) ÷ Int32(2) - Int32(1)
end

@inline function _cuda_variable_ordinal(i0::Int32, j0::Int32)
    i = i0
    j = j0
    if i > j
        i, j = j, i
    end
    ((j - Int32(2)) * (j - Int32(1))) ÷ Int32(2) - Int32(1) + i
end

@inline function _cuda_candidate_entry(
    prefix,
    n::Int32,
    h12::UInt32,
    prefix_entries::Int32,
    suffix_entries::Int32,
    suffix_index::UInt64,
    prefix_index::Int32,
    i::Int32,
    j::Int32,
)
    i == j && return UInt32(0)
    if i > j
        i, j = j, i
    end
    i == Int32(1) && j == Int32(2) && return h12

    ord = _cuda_variable_ordinal(i, j)
    mask = (UInt64(1) << UInt64(n)) - UInt64(1)
    if ord <= prefix_entries
        base = Int(prefix_index - Int32(1)) * Int(prefix_entries)
        return prefix[base + Int(ord)]
    end
    suffix_ord = ord - prefix_entries
    shift = UInt64((suffix_ord - Int32(1)) * n)
    return UInt32((suffix_index >> shift) & mask)
end

@inline function _cuda_basis_get(basis::UInt64, bit::Int32)
    shift = UInt64((bit - Int32(1)) * Int32(8))
    UInt32((basis >> shift) & UInt64(0xff))
end

@inline function _cuda_basis_set(basis::UInt64, bit::Int32, value::UInt32)
    shift = UInt64((bit - Int32(1)) * Int32(8))
    mask = UInt64(0xff) << shift
    (basis & ~mask) | ((UInt64(value) & UInt64(0xff)) << shift)
end

@inline function _cuda_insert_basis(basis::UInt64, rank::Int32, value::UInt32)
    v = value
    while v != UInt32(0)
        bit = Int32(32 - leading_zeros(v))
        b = _cuda_basis_get(basis, bit)
        if b == UInt32(0)
            basis = _cuda_basis_set(basis, bit, v)
            rank += Int32(1)
            break
        end
        v ⊻= b
    end
    return (basis, rank)
end

@inline function _cuda_span_cache_contains(prefix_span, meta_index::Int, value::UInt32)
    word = Int(value >> UInt32(6))
    bit = value & UInt32(0x3f)
    mask = UInt64(1) << bit
    (prefix_span[(meta_index - 1) * 4 + word + 1] & mask) != UInt64(0)
end

@inline function _cuda_suffix_xor_for_row_subset(
    prefix,
    n::Int32,
    h12::UInt32,
    prefix_entries::Int32,
    suffix_entries::Int32,
    suffix_index::UInt64,
    prefix_index::Int32,
    row_subset::UInt32,
)
    acc = UInt32(0)
    rows = row_subset
    while rows != UInt32(0)
        r = Int32(trailing_zeros(rows) + 1)
        acc ⊻= _cuda_candidate_entry(
            prefix,
            n,
            h12,
            prefix_entries,
            suffix_entries,
            suffix_index,
            prefix_index,
            r,
            n,
        )
        rows &= rows - UInt32(1)
    end
    acc
end

@inline function _cuda_leading_row_subset_has_rank(
    prefix,
    n::Int32,
    h12::UInt32,
    prefix_entries::Int32,
    suffix_entries::Int32,
    suffix_index::UInt64,
    prefix_index::Int32,
    c::Int32,
    row_subset::UInt32,
)
    need = c - Int32(1)
    basis = UInt64(0)
    rank = Int32(0)
    i = Int32(1)
    while i <= c
        acc = UInt32(0)
        rows = row_subset
        while rows != UInt32(0)
            r = Int32(trailing_zeros(rows) + 1)
            acc ⊻= _cuda_candidate_entry(
                prefix,
                n,
                h12,
                prefix_entries,
                suffix_entries,
                suffix_index,
                prefix_index,
                r,
                i,
            )
            rows &= rows - UInt32(1)
        end
        basis, rank = _cuda_insert_basis(basis, rank, acc)
        rank >= need && return true
        rank + (c - i) < need && return false
        i += Int32(1)
    end
    rank >= need
end

@inline function _cuda_candidate_passes_final_column(
    prefix,
    prefix_rank,
    prefix_span,
    n::Int32,
    h12::UInt32,
    prefix_entries::Int32,
    suffix_entries::Int32,
    suffix_index::UInt64,
    prefix_index::Int32,
)
    subset_count = (UInt32(1) << UInt32(n - Int32(1))) - UInt32(1)
    prefix_meta_base = Int(prefix_index - Int32(1)) * Int(subset_count)
    almost = n - Int32(2)

    row_subset = UInt32(1)
    while row_subset <= subset_count
        meta_index = prefix_meta_base + Int(row_subset)
        rank = Int32(prefix_rank[meta_index])
        rank < almost && return false
        if rank == almost
            suffix_value = _cuda_suffix_xor_for_row_subset(
                prefix,
                n,
                h12,
                prefix_entries,
                suffix_entries,
                suffix_index,
                prefix_index,
                row_subset,
            )
            _cuda_span_cache_contains(prefix_span, meta_index, suffix_value) && return false
        end
        row_subset += UInt32(1)
    end

    final_row_bit = UInt32(1) << UInt32(n - Int32(1))
    tail_subset = UInt32(0)
    while tail_subset <= subset_count
        _cuda_leading_row_subset_has_rank(
            prefix,
            n,
            h12,
            prefix_entries,
            suffix_entries,
            suffix_index,
            prefix_index,
            n,
            final_row_bit | tail_subset,
        ) || return false
        tail_subset += UInt32(1)
    end
    true
end

@inline function _cuda_candidate_passes(
    prefix,
    prefix_rank,
    prefix_span,
    n::Int32,
    h12::UInt32,
    prefix_entries::Int32,
    suffix_entries::Int32,
    suffix_index::UInt64,
    prefix_index::Int32,
    first_check_col::Int32,
)
    c = first_check_col
    while c <= n
        if c == n
            return _cuda_candidate_passes_final_column(
                prefix,
                prefix_rank,
                prefix_span,
                n,
                h12,
                prefix_entries,
                suffix_entries,
                suffix_index,
                prefix_index,
            )
        end
        row_subset = UInt32(1)
        limit = UInt32(1) << UInt32(c)
        while row_subset < limit
            _cuda_leading_row_subset_has_rank(
                prefix,
                n,
                h12,
                prefix_entries,
                suffix_entries,
                suffix_index,
                prefix_index,
                c,
                row_subset,
            ) || return false
            row_subset += UInt32(1)
        end
        c += Int32(1)
    end
    true
end

@inline function _cuda_write_matrix!(
    out_mats,
    out_slot::UInt32,
    prefix,
    n::Int32,
    h12::UInt32,
    prefix_entries::Int32,
    suffix_entries::Int32,
    suffix_index::UInt64,
    prefix_index::Int32,
)
    base = Int(out_slot) * Int(n) * Int(n)
    for j = Int32(1):n
        for i = Int32(1):n
            out_mats[base + Int((j - Int32(1)) * n + i)] =
                _cuda_candidate_entry(
                    prefix,
                    n,
                    h12,
                    prefix_entries,
                    suffix_entries,
                    suffix_index,
                    prefix_index,
                    i,
                    j,
                )
        end
    end
    nothing
end

function _cuda_expand_qam_kernel(
    prefix,
    prefix_rank,
    prefix_span,
    out_count,
    out_mats,
    n::Int32,
    h12::UInt32,
    prefix_entries::Int32,
    prefix_count::Int32,
    suffix_entries::Int32,
    suffix_total::UInt64,
    batch_start::UInt64,
    batch_len::UInt64,
    result_capacity::UInt32,
)
    idx = (UInt64(CUDA.blockIdx().x) - UInt64(1)) * UInt64(CUDA.blockDim().x) +
          UInt64(CUDA.threadIdx().x)
    idx > batch_len && return nothing

    flat_index = batch_start + idx - UInt64(1)
    prefix_index = Int32(flat_index ÷ suffix_total) + Int32(1)
    prefix_index > prefix_count && return nothing
    suffix_index = flat_index % suffix_total
    if _cuda_candidate_passes(
        prefix,
        prefix_rank,
        prefix_span,
        n,
        h12,
        prefix_entries,
        suffix_entries,
        suffix_index,
        prefix_index,
        n,
    )
        out_slot = CUDA.@atomic out_count[1] += UInt32(1)
        if out_slot < result_capacity
            _cuda_write_matrix!(
                out_mats,
                out_slot,
                prefix,
                n,
                h12,
                prefix_entries,
                suffix_entries,
                suffix_index,
                prefix_index,
            )
        end
    end
    return nothing
end

function _make_cuda_pipeline_slot(
    n::Int,
    result_capacity::Int,
    max_prefix_entries::Int,
    prefix_batch_capacity::Int,
)
    prefix_len = max(max_prefix_entries * prefix_batch_capacity, 1)
    prefix_subset_count = max((1 << (n - 1)) - 1, 1)
    prefix_rank_len = max(prefix_subset_count * prefix_batch_capacity, 1)
    prefix_span_len = max(4 * prefix_rank_len, 1)
    d_prefix = CUDA.CuArray{UInt32}(undef, prefix_len)
    d_prefix_rank = CUDA.CuArray{UInt32}(undef, prefix_rank_len)
    d_prefix_span = CUDA.CuArray{UInt64}(undef, prefix_span_len)
    d_count = CUDA.CuArray{UInt32}(undef, 1)
    d_out_mats = CUDA.CuArray{UInt32}(undef, n * n * result_capacity)
    h_prefix = Vector{UInt32}(undef, prefix_len)
    h_prefix_rank = Vector{UInt32}(undef, prefix_rank_len)
    h_prefix_span = Vector{UInt64}(undef, prefix_span_len)
    h_count = zeros(UInt32, 1)
    h_out_mats = Vector{UInt32}(undef, n * n * result_capacity)
    CUDA.pin(h_prefix)
    CUDA.pin(h_prefix_rank)
    CUDA.pin(h_prefix_span)
    CUDA.pin(h_count)
    CUDA.pin(h_out_mats)
    CUDAPipelineSlot(
        CUDA.CuStream(flags = CUDA.STREAM_NON_BLOCKING),
        CUDA.CuEvent(CUDA.EVENT_DISABLE_TIMING),
        d_prefix,
        d_prefix_rank,
        d_prefix_span,
        d_count,
        d_out_mats,
        h_prefix,
        h_prefix_rank,
        h_prefix_span,
        h_count,
        h_out_mats,
        0,
        0,
        UInt64(0),
        0,
        0,
        false,
    )
end

function _default_cuda_suffix_entries(n::Int, var_count::Int)
    n - 1
end

function _cuda_prefix_batch_capacity(batch_size::Int, n::Int, suffix_entries::Int)
    suffix_total = UInt64(1) << UInt64(n * suffix_entries)
    suffix_total >= UInt64(batch_size) && return 1
    min(batch_size, cld(batch_size, Int(suffix_total)))
end

function _make_cuda_qam_backend(
    n::Int;
    device::Union{Nothing,Int},
    batch_size::Int,
    pipeline_depth::Int,
    suffix_entries::Union{Nothing,Int} = nothing,
    result_capacity::Union{Nothing,Int} = nothing,
)
    n >= 3 || throw(ArgumentError("GPU backend currently supports n >= 3, got n=$n"))
    n <= CUDA_MAX_N || throw(ArgumentError("GPU backend currently supports n <= $CUDA_MAX_N, got n=$n"))
    batch_size >= 1 || throw(ArgumentError("gpu_batch_size must be positive, got $batch_size"))
    pipeline_depth >= 2 ||
        throw(ArgumentError("gpu_pipeline_depth must be at least 2, got $pipeline_depth"))
    var_count = (n * (n - 1)) ÷ 2 - 1
    suffix = suffix_entries === nothing ? _default_cuda_suffix_entries(n, var_count) : suffix_entries
    suffix == n - 1 ||
        throw(
            ArgumentError(
                "hybrid GPU backend requires gpu_suffix_entries = n - 1 ($(n - 1)) " *
                "so CUDA enumerates only the final column; got $suffix",
            ),
        )
    n * suffix <= 63 ||
        throw(ArgumentError("final-column CUDA suffix must fit UInt64, got n*suffix=$(n * suffix)"))
    capacity = result_capacity === nothing ? batch_size : result_capacity
    capacity >= 1 || throw(ArgumentError("gpu_result_capacity must be positive, got $capacity"))
    capacity <= typemax(UInt32) ||
        throw(ArgumentError("gpu_result_capacity must fit UInt32, got $capacity"))
    CUDA.functional() ||
        throw(ArgumentError("GPU backend requested, but CUDA.functional() is false"))
    device === nothing || CUDA.device!(device)
    CUDA.allowscalar(false)
    max_prefix_entries = max(var_count - suffix, 0)
    prefix_batch_capacity = _cuda_prefix_batch_capacity(batch_size, n, suffix)
    slots = [
        _make_cuda_pipeline_slot(n, capacity, max_prefix_entries, prefix_batch_capacity) for
        _ = 1:pipeline_depth
    ]
    CUDAQAMBackend(
        device,
        string(CUDA.device()),
        batch_size,
        pipeline_depth,
        suffix,
        capacity,
        prefix_batch_capacity,
        slots,
    )
end

function _cuda_submit_slot!(
    slot::CUDAPipelineSlot,
    n::Int,
    suffix_entries::Int,
    suffix_total::UInt64,
    result_capacity::Int,
)
    slot.h_count[1] = UInt32(0)
    prefix_len = max(slot.prefix_entries * slot.prefix_count, 1)
    prefix_subset_count = max((1 << (n - 1)) - 1, 1)
    prefix_rank_len = max(prefix_subset_count * slot.prefix_count, 1)
    prefix_span_len = max(4 * prefix_rank_len, 1)
    batch_len = UInt64(slot.batch_len)
    threads = 256
    blocks = cld(slot.batch_len, threads)
    d_prefix = slot.d_prefix
    d_prefix_rank = slot.d_prefix_rank
    d_prefix_span = slot.d_prefix_span
    d_count = slot.d_count
    d_out_mats = slot.d_out_mats
    h_prefix = slot.h_prefix
    h_prefix_rank = slot.h_prefix_rank
    h_prefix_span = slot.h_prefix_span
    h_count = slot.h_count
    event = slot.event
    stream = slot.stream
    CUDA.stream!(stream) do
        GC.@preserve d_prefix d_prefix_rank d_prefix_span d_count d_out_mats h_prefix h_prefix_rank h_prefix_span h_count begin
            unsafe_copyto!(pointer(d_prefix), pointer(h_prefix), prefix_len; async = true)
            unsafe_copyto!(
                pointer(d_prefix_rank),
                pointer(h_prefix_rank),
                prefix_rank_len;
                async = true,
            )
            unsafe_copyto!(
                pointer(d_prefix_span),
                pointer(h_prefix_span),
                prefix_span_len;
                async = true,
            )
            unsafe_copyto!(pointer(d_count), pointer(h_count), 1; async = true)
            CUDA.@cuda threads=threads blocks=blocks stream=stream _cuda_expand_qam_kernel(
                d_prefix,
                d_prefix_rank,
                d_prefix_span,
                d_count,
                d_out_mats,
                Int32(n),
                UInt32(slot.h12),
                Int32(slot.prefix_entries),
                Int32(slot.prefix_count),
                Int32(suffix_entries),
                suffix_total,
                slot.batch_start,
                batch_len,
                UInt32(result_capacity),
            )
            unsafe_copyto!(pointer(h_count), pointer(d_count), 1; async = true)
            CUDA.record(event, stream)
        end
    end
    slot.in_flight = true
    nothing
end

function _matrix_from_output_buffer(buf::Vector{UInt32}, n::Int, slot::Int)
    Mat = Matrix{Int}(undef, n, n)
    base = (slot - 1) * n * n
    @inbounds for j = 1:n, i = 1:n
        Mat[i, j] = Int(buf[base + (j - 1) * n + i])
    end
    Mat
end

function _copy_slot_outputs!(slot::CUDAPipelineSlot, n::Int, hit_count::Int)
    hit_count == 0 && return
    elems = n * n * hit_count
    d_out_mats = slot.d_out_mats
    h_out_mats = slot.h_out_mats
    stream = slot.stream
    CUDA.stream!(stream) do
        GC.@preserve d_out_mats h_out_mats begin
            unsafe_copyto!(pointer(h_out_mats), pointer(d_out_mats), elems; async = true)
            CUDA.synchronize(stream)
        end
    end
    nothing
end

function _cuda_drain_slot!(
    slot::CUDAPipelineSlot,
    register_candidate!::Function,
    n::Int,
    should_stop::Function;
    wait::Bool,
    process::Bool = true,
)
    slot.in_flight || return false
    if wait
        CUDA.synchronize(slot.event)
    elseif !CUDA.isdone(slot.event)
        return false
    end

    raw_hits = Int(slot.h_count[1])
    stop_requested = false
    if process
        raw_hits > length(slot.h_out_mats) ÷ (n * n) &&
            throw(ArgumentError("GPU result buffer overflow: $raw_hits hits exceed capacity"))
        _copy_slot_outputs!(slot, n, raw_hits)
        @inbounds for idx = 1:raw_hits
            Mat = _matrix_from_output_buffer(slot.h_out_mats, n, idx)
            register_candidate!(qam_to_sbox(Mat), Mat, slot.h12)
            if should_stop()
                stop_requested = true
                break
            end
        end
    end
    slot.prefix_entries = 0
    slot.prefix_count = 0
    slot.batch_start = UInt64(0)
    slot.batch_len = 0
    slot.h12 = 0
    slot.in_flight = false
    stop_requested
end

function _cuda_drain_ready!(
    backend::CUDAQAMBackend,
    register_candidate!::Function,
    n::Int,
    should_stop::Function,
)
    stop_requested = false
    for slot in backend.slots
        _cuda_drain_slot!(
            slot,
            register_candidate!,
            n,
            should_stop;
            wait = false,
        ) && (stop_requested = true)
    end
    stop_requested
end

function _cuda_drain_all!(
    backend::CUDAQAMBackend,
    register_candidate!::Function,
    n::Int,
    should_stop::Function;
    process::Bool = true,
)
    stop_requested = false
    for slot in backend.slots
        _cuda_drain_slot!(
            slot,
            register_candidate!,
            n,
            should_stop;
            wait = true,
            process,
        ) && (stop_requested = true)
    end
    stop_requested
end

function _cuda_acquire_slot!(
    backend::CUDAQAMBackend,
    register_candidate!::Function,
    n::Int,
    should_stop::Function,
)
    while true
        for slot in backend.slots
            !slot.in_flight && return slot
        end
        _cuda_drain_ready!(backend, register_candidate!, n, should_stop) && return nothing
        for slot in backend.slots
            !slot.in_flight && return slot
        end
        for slot in backend.slots
            if slot.in_flight
                _cuda_drain_slot!(
                    slot,
                    register_candidate!,
                    n,
                    should_stop;
                    wait = true,
                ) && return nothing
                return slot
            end
        end
    end
end

_cuda_prefix_subset_count(n::Int) = (1 << (n - 1)) - 1

function _cuda_host_rank_f2!(basis::Vector{UInt}, vecbuf::Vector{UInt}, c::Int)
    fill!(basis, UInt(0))
    rank = 0
    @inbounds for i = 1:c
        v = vecbuf[i]
        while v != UInt(0)
            t = 8 * sizeof(UInt) - leading_zeros(v)
            b = basis[t]
            if b == UInt(0)
                basis[t] = v
                rank += 1
                break
            end
            v ⊻= b
        end
    end
    rank
end

@inline function _cuda_host_mark_span!(
    prefix_span_buffer::Vector{UInt64},
    span_base::Int,
    value::UInt,
)
    word = Int(value >> 6)
    bit = value & UInt(0x3f)
    prefix_span_buffer[span_base + word + 1] |= UInt64(1) << bit
    nothing
end

function _cuda_fill_prefix_span_cache!(
    M,
    n::Int,
    prefix_index::Int,
    prefix_rank_buffer::Vector{UInt32},
    prefix_span_buffer::Vector{UInt64},
    vecbuf::Vector{UInt},
    basis::Vector{UInt},
)
    subset_count = _cuda_prefix_subset_count(n)
    rank_base = (prefix_index - 1) * subset_count
    need_without_suffix = n - 2
    span_limit = 1 << (n - 1)
    @inbounds for row_subset = 1:subset_count
        for col = 1:(n - 1)
            v = UInt(0)
            rows = row_subset
            while rows != 0
                r = trailing_zeros(rows) + 1
                v ⊻= UInt(M[r][col])
                rows &= rows - 1
            end
            vecbuf[col] = v
        end
        rank = _cuda_host_rank_f2!(basis, vecbuf, n - 1)
        prefix_rank_buffer[rank_base + row_subset] = UInt32(rank)
        span_base = (rank_base + row_subset - 1) * 4
        prefix_span_buffer[span_base + 1] = UInt64(0)
        prefix_span_buffer[span_base + 2] = UInt64(0)
        prefix_span_buffer[span_base + 3] = UInt64(0)
        prefix_span_buffer[span_base + 4] = UInt64(0)
        rank == need_without_suffix || continue
        for span_subset = 0:(span_limit - 1)
            acc = UInt(0)
            s = span_subset
            while s != 0
                col = trailing_zeros(s) + 1
                acc ⊻= vecbuf[col]
                s &= s - 1
            end
            _cuda_host_mark_span!(prefix_span_buffer, span_base, acc)
        end
    end
    nothing
end

function _cuda_variable_positions(n::Int)
    positions = Tuple{Int,Int}[]
    sizehint!(positions, (n * (n - 1)) ÷ 2 - 1)
    for j = 3:n, i = 1:(j - 1)
        push!(positions, (i, j))
    end
    positions
end

function _search_chunk!(
    backend::CUDAQAMBackend,
    register_candidate!::Function,
    n::Int,
    h12::Int;
    max_evaluations_per_chunk::Integer = typemax(Int),
    should_stop::Function = () -> false,
    progress_callback::Function = _ -> nothing,
    dfs_threads::Int = 1,
)
    var_count = (n * (n - 1)) ÷ 2 - 1
    suffix_entries = backend.suffix_entries
    prefix_entries = var_count - suffix_entries
    suffix_entries == n - 1 ||
        throw(ArgumentError("hybrid CUDA search expects final-column suffix_entries = $(n - 1)"))
    positions = _cuda_variable_positions(n)
    prefix_subset_count = _cuda_prefix_subset_count(n)
    prefix_buffer = Vector{UInt32}(undef, max(prefix_entries * backend.prefix_batch_capacity, 1))
    prefix_rank_buffer =
        Vector{UInt32}(undef, max(prefix_subset_count * backend.prefix_batch_capacity, 1))
    prefix_span_buffer =
        Vector{UInt64}(undef, max(4 * prefix_subset_count * backend.prefix_batch_capacity, 1))
    M = [zeros(Int, n) for _ = 1:n]
    M[1][2] = h12
    M[2][1] = h12
    vecbuf = zeros(UInt, n)
    basis = zeros(UInt, n)
    q = 1 << n
    suffix_total = UInt64(1) << UInt64(n * suffix_entries)
    evaluated = Ref(0)
    prefixes = Ref(0)
    pending_prefixes = Ref(0)
    gpu_batches = Ref(0)
    dfs_nodes = Ref(0)
    rank_checks = Ref(0)
    stop_requested = Ref(false)
    budget_exhausted = Ref(false)

    function remaining_budget()
        max_evaluations_per_chunk == typemax(Int) && return backend.batch_size
        remaining = Int(max(0, max_evaluations_per_chunk - evaluated[]))
        min(backend.batch_size, remaining)
    end

    function report_progress(phase::AbstractString)
        progress_callback((
            chunk = h12,
            phase = String(phase),
            evaluated = evaluated[],
            prefixes = prefixes[],
            queued_prefixes = pending_prefixes[],
            gpu_batches = gpu_batches[],
            dfs_nodes = dfs_nodes[],
            rank_checks = rank_checks[],
            complete = false,
        ))
        nothing
    end

    function copy_prefix_batch_to_slot!(slot::CUDAPipelineSlot, prefix_count::Int)
        if prefix_entries == 0
            slot.h_prefix[1] = UInt32(0)
        else
            total = prefix_entries * prefix_count
            @inbounds for i = 1:total
                slot.h_prefix[i] = prefix_buffer[i]
            end
        end
        cache_total = prefix_subset_count * prefix_count
        @inbounds for i = 1:cache_total
            slot.h_prefix_rank[i] = prefix_rank_buffer[i]
        end
        span_total = 4 * cache_total
        @inbounds for i = 1:span_total
            slot.h_prefix_span[i] = prefix_span_buffer[i]
        end
        nothing
    end

    function submit_pending_prefixes!()
        prefix_count = pending_prefixes[]
        prefix_count == 0 && return true
        flat_total = suffix_total * UInt64(prefix_count)
        offset = UInt64(0)
        while offset < flat_total && !stop_requested[] && !should_stop()
            budget = remaining_budget()
            if budget <= 0
                budget_exhausted[] = true
                return false
            end
            remaining_flat = flat_total - offset
            batch_len = min(backend.batch_size, budget, Int(min(UInt64(typemax(Int)), remaining_flat)))
            batch_len <= 0 && break

            all(slot -> slot.in_flight, backend.slots) && report_progress("wait")
            slot = _cuda_acquire_slot!(backend, register_candidate!, n, should_stop)
            slot === nothing && (stop_requested[] = true; return false)
            slot.prefix_entries = prefix_entries
            slot.prefix_count = prefix_count
            copy_prefix_batch_to_slot!(slot, prefix_count)
            slot.batch_start = offset
            slot.batch_len = batch_len
            slot.h12 = h12
            _cuda_submit_slot!(slot, n, suffix_entries, suffix_total, backend.result_capacity)

            evaluated[] += batch_len
            gpu_batches[] += 1
            offset += UInt64(batch_len)
            report_progress("gpu")
            max_evaluations_per_chunk != typemax(Int) &&
                evaluated[] >= max_evaluations_per_chunk &&
                offset < flat_total &&
                (budget_exhausted[] = true; return false)
        end
        stop_requested[] && return false
        should_stop() && return false
        pending_prefixes[] = 0
        true
    end

    function enqueue_prefix!()
        stop_requested[] && return false
        should_stop() && return false
        if pending_prefixes[] >= backend.prefix_batch_capacity
            submit_pending_prefixes!() || return false
        end
        prefix_index = pending_prefixes[] + 1
        if prefix_entries > 0
            base = (prefix_index - 1) * prefix_entries
            @inbounds for ord = 1:prefix_entries
                i, j = positions[ord]
                prefix_buffer[base + ord] = UInt32(M[i][j])
            end
        end
        _cuda_fill_prefix_span_cache!(
            M,
            n,
            prefix_index,
            prefix_rank_buffer,
            prefix_span_buffer,
            vecbuf,
            basis,
        )
        pending_prefixes[] = prefix_index
        prefixes[] += 1
        report_progress("dfs")
        if pending_prefixes[] >= backend.prefix_batch_capacity ||
           UInt64(pending_prefixes[]) * suffix_total >= UInt64(backend.batch_size)
            submit_pending_prefixes!() || return false
        end
        true
    end

    local fill_col
    fill_entry = function (c::Int, r::Int)
        (stop_requested[] || budget_exhausted[] || should_stop()) && return
        dfs_nodes[] += 1
        (dfs_nodes[] & 0xfffff) == 0 && report_progress("dfs")
        if r == c
            rank_checks[] += 1
            _proper_subsets_containing(M, c, c, n, vecbuf, basis) && fill_col(c + 1)
            return
        end
        @inbounds for v = 0:(q - 1)
            M[r][c] = v
            M[c][r] = v
            rank_checks[] += 1
            _proper_subsets_containing(M, r, c, n, vecbuf, basis) &&
                fill_entry(c, r + 1)
            (stop_requested[] || budget_exhausted[] || should_stop()) && return
        end
    end

    fill_col = function (c::Int)
        (stop_requested[] || budget_exhausted[] || should_stop()) && return
        if c > n - 1
            enqueue_prefix!() || (stop_requested[] = true)
            return
        end
        fill_entry(c, 1)
    end

    try
        report_progress("start")
        if _proper_leading_submatrix(M, 2, n, vecbuf)
            fill_col(3)
        end
        if !stop_requested[] && !budget_exhausted[] && !should_stop()
            submit_pending_prefixes!() || (stop_requested[] = true)
        end

        _cuda_drain_all!(backend, register_candidate!, n, should_stop) && (stop_requested[] = true)
    catch
        _cuda_drain_all!(backend, register_candidate!, n, should_stop; process = false)
        rethrow()
    end

    complete =
        pending_prefixes[] == 0 &&
        !budget_exhausted[] &&
        evaluated[] < max_evaluations_per_chunk &&
        !stop_requested[] &&
        !should_stop()
    (;
        chunk = h12,
        evaluated = evaluated[],
        complete,
        prefixes = prefixes[],
        gpu_batches = gpu_batches[],
        dfs_nodes = dfs_nodes[],
        rank_checks = rank_checks[],
        suffix_entries,
    )
end
