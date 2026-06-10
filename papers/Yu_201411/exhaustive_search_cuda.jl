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
    d_count::Any
    d_out_mats::Any
    h_prefix::Vector{UInt32}
    h_count::Vector{UInt32}
    h_out_mats::Vector{UInt32}
    prefix_len::Int
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
    suffix_entries::Int32,
    suffix_index::UInt64,
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
    if ord <= suffix_entries
        shift = UInt64((ord - Int32(1)) * n)
        return UInt32((suffix_index >> shift) & mask)
    end
    prefix[Int(ord - suffix_entries)]
end

@inline function _cuda_mark_span!(w0::UInt64, w1::UInt64, w2::UInt64, w3::UInt64, value::UInt32)
    word = value >> UInt32(6)
    bit = value & UInt32(0x3f)
    mask = UInt64(1) << bit
    if word == UInt32(0)
        return (w0 | mask, w1, w2, w3)
    elseif word == UInt32(1)
        return (w0, w1 | mask, w2, w3)
    elseif word == UInt32(2)
        return (w0, w1, w2 | mask, w3)
    else
        return (w0, w1, w2, w3 | mask)
    end
end

@inline function _cuda_leading_row_subset_has_rank(
    prefix,
    n::Int32,
    h12::UInt32,
    suffix_entries::Int32,
    suffix_index::UInt64,
    c::Int32,
    row_subset::UInt32,
)
    limit = UInt32(1) << UInt32(c)
    required = Int(UInt32(1) << UInt32(c - Int32(1)))
    w0 = UInt64(0)
    w1 = UInt64(0)
    w2 = UInt64(0)
    w3 = UInt64(0)
    span_subset = UInt32(0)
    while span_subset < limit
        acc = UInt32(0)
        s = span_subset
        while s != UInt32(0)
            i = Int32(trailing_zeros(s) + 1)
            rows = row_subset
            while rows != UInt32(0)
                r = Int32(trailing_zeros(rows) + 1)
                acc ⊻= _cuda_candidate_entry(prefix, n, h12, suffix_entries, suffix_index, r, i)
                rows &= rows - UInt32(1)
            end
            s &= s - UInt32(1)
        end
        w0, w1, w2, w3 = _cuda_mark_span!(w0, w1, w2, w3, acc)
        span_subset += UInt32(1)
    end
    count_ones(w0) + count_ones(w1) + count_ones(w2) + count_ones(w3) >= required
end

@inline function _cuda_candidate_passes(
    prefix,
    n::Int32,
    h12::UInt32,
    suffix_entries::Int32,
    suffix_index::UInt64,
)
    c = Int32(2)
    while c <= n
        row_subset = UInt32(1)
        limit = UInt32(1) << UInt32(c)
        while row_subset < limit
            _cuda_leading_row_subset_has_rank(
                prefix,
                n,
                h12,
                suffix_entries,
                suffix_index,
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
    suffix_entries::Int32,
    suffix_index::UInt64,
)
    base = Int(out_slot) * Int(n) * Int(n)
    for j = Int32(1):n
        for i = Int32(1):n
            out_mats[base + Int((j - Int32(1)) * n + i)] =
                _cuda_candidate_entry(prefix, n, h12, suffix_entries, suffix_index, i, j)
        end
    end
    nothing
end

function _cuda_expand_qam_kernel(
    prefix,
    out_count,
    out_mats,
    n::Int32,
    h12::UInt32,
    suffix_entries::Int32,
    batch_start::UInt64,
    batch_len::UInt64,
    result_capacity::UInt32,
)
    idx = (UInt64(CUDA.blockIdx().x) - UInt64(1)) * UInt64(CUDA.blockDim().x) +
          UInt64(CUDA.threadIdx().x)
    idx > batch_len && return nothing

    suffix_index = batch_start + idx - UInt64(1)
    if _cuda_candidate_passes(prefix, n, h12, suffix_entries, suffix_index)
        out_slot = CUDA.@atomic out_count[1] += UInt32(1)
        if out_slot < result_capacity
            _cuda_write_matrix!(out_mats, out_slot, prefix, n, h12, suffix_entries, suffix_index)
        end
    end
    return nothing
end

function _make_cuda_pipeline_slot(n::Int, result_capacity::Int, max_prefix_entries::Int)
    prefix_len = max(max_prefix_entries, 1)
    d_prefix = CUDA.CuArray{UInt32}(undef, prefix_len)
    d_count = CUDA.CuArray{UInt32}(undef, 1)
    d_out_mats = CUDA.CuArray{UInt32}(undef, n * n * result_capacity)
    h_prefix = Vector{UInt32}(undef, prefix_len)
    h_count = zeros(UInt32, 1)
    h_out_mats = Vector{UInt32}(undef, n * n * result_capacity)
    CUDA.pin(h_prefix)
    CUDA.pin(h_count)
    CUDA.pin(h_out_mats)
    CUDAPipelineSlot(
        CUDA.CuStream(flags = CUDA.STREAM_NON_BLOCKING),
        CUDA.CuEvent(CUDA.EVENT_DISABLE_TIMING),
        d_prefix,
        d_count,
        d_out_mats,
        h_prefix,
        h_count,
        h_out_mats,
        0,
        UInt64(0),
        0,
        0,
        false,
    )
end

function _default_cuda_suffix_entries(n::Int, var_count::Int)
    min(var_count, 63 ÷ n)
end

function _make_cuda_qam_backend(
    n::Int;
    device::Union{Nothing,Int},
    batch_size::Int,
    pipeline_depth::Int,
    suffix_entries::Union{Nothing,Int} = nothing,
    result_capacity::Union{Nothing,Int} = nothing,
)
    n <= CUDA_MAX_N || throw(ArgumentError("GPU backend currently supports n <= $CUDA_MAX_N, got n=$n"))
    batch_size >= 1 || throw(ArgumentError("gpu_batch_size must be positive, got $batch_size"))
    pipeline_depth >= 2 ||
        throw(ArgumentError("gpu_pipeline_depth must be at least 2, got $pipeline_depth"))
    var_count = (n * (n - 1)) ÷ 2 - 1
    suffix = suffix_entries === nothing ? _default_cuda_suffix_entries(n, var_count) : suffix_entries
    1 <= suffix <= min(var_count, 63 ÷ n) ||
        throw(ArgumentError("gpu_suffix_entries must be in 1:$(min(var_count, 63 ÷ n)), got $suffix"))
    capacity = result_capacity === nothing ? batch_size : result_capacity
    capacity >= 1 || throw(ArgumentError("gpu_result_capacity must be positive, got $capacity"))
    capacity <= typemax(UInt32) ||
        throw(ArgumentError("gpu_result_capacity must fit UInt32, got $capacity"))
    CUDA.functional() ||
        throw(ArgumentError("GPU backend requested, but CUDA.functional() is false"))
    device === nothing || CUDA.device!(device)
    CUDA.allowscalar(false)
    max_prefix_entries = max(var_count - suffix, 0)
    slots = [_make_cuda_pipeline_slot(n, capacity, max_prefix_entries) for _ = 1:pipeline_depth]
    CUDAQAMBackend(device, string(CUDA.device()), batch_size, pipeline_depth, suffix, capacity, slots)
end

function _cuda_submit_slot!(slot::CUDAPipelineSlot, n::Int, suffix_entries::Int, result_capacity::Int)
    slot.h_count[1] = UInt32(0)
    prefix_len = max(slot.prefix_len, 1)
    batch_len = UInt64(slot.batch_len)
    threads = 256
    blocks = cld(slot.batch_len, threads)
    d_prefix = slot.d_prefix
    d_count = slot.d_count
    d_out_mats = slot.d_out_mats
    h_prefix = slot.h_prefix
    h_count = slot.h_count
    event = slot.event
    stream = slot.stream
    CUDA.stream!(stream) do
        GC.@preserve d_prefix d_count d_out_mats h_prefix h_count begin
            unsafe_copyto!(pointer(d_prefix), pointer(h_prefix), prefix_len; async = true)
            unsafe_copyto!(pointer(d_count), pointer(h_count), 1; async = true)
            CUDA.@cuda threads=threads blocks=blocks stream=stream _cuda_expand_qam_kernel(
                d_prefix,
                d_count,
                d_out_mats,
                Int32(n),
                UInt32(slot.h12),
                Int32(suffix_entries),
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
    slot.prefix_len = 0
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

function _advance_prefix!(prefix_values::Vector{UInt32}, prefix_entries::Int, q::UInt32)
    prefix_entries == 0 && return false
    @inbounds for i = 1:prefix_entries
        next = prefix_values[i] + UInt32(1)
        if next < q
            prefix_values[i] = next
            return true
        end
        prefix_values[i] = UInt32(0)
    end
    false
end

function _search_chunk!(
    backend::CUDAQAMBackend,
    register_candidate!::Function,
    n::Int,
    h12::Int;
    max_evaluations_per_chunk::Integer = typemax(Int),
    should_stop::Function = () -> false,
)
    var_count = (n * (n - 1)) ÷ 2 - 1
    suffix_entries = backend.suffix_entries
    prefix_entries = var_count - suffix_entries
    prefix_values = zeros(UInt32, max(prefix_entries, 1))
    q = UInt32(1) << UInt32(n)
    suffix_total = UInt64(1) << UInt64(n * suffix_entries)
    suffix_offset = UInt64(0)
    evaluated = Ref(0)
    prefix_active = true
    stop_requested = Ref(false)

    function remaining_budget()
        max_evaluations_per_chunk == typemax(Int) && return backend.batch_size
        remaining = Int(max(0, max_evaluations_per_chunk - evaluated[]))
        min(backend.batch_size, remaining)
    end

    try
        while prefix_active && !stop_requested[] && !should_stop()
            budget = remaining_budget()
            budget <= 0 && break
            remaining_suffix = suffix_total - suffix_offset
            batch_len = min(budget, Int(min(UInt64(typemax(Int)), remaining_suffix)))
            batch_len <= 0 && break

            slot = _cuda_acquire_slot!(backend, register_candidate!, n, should_stop)
            slot === nothing && (stop_requested[] = true; break)
            slot.prefix_len = prefix_entries
            if prefix_entries == 0
                slot.h_prefix[1] = UInt32(0)
            else
                @inbounds for i = 1:prefix_entries
                    slot.h_prefix[i] = prefix_values[i]
                end
            end
            slot.batch_start = suffix_offset
            slot.batch_len = batch_len
            slot.h12 = h12
            _cuda_submit_slot!(slot, n, suffix_entries, backend.result_capacity)

            evaluated[] += batch_len
            suffix_offset += UInt64(batch_len)
            if suffix_offset == suffix_total
                suffix_offset = UInt64(0)
                prefix_active = _advance_prefix!(prefix_values, prefix_entries, q)
            end
            max_evaluations_per_chunk != typemax(Int) &&
                evaluated[] >= max_evaluations_per_chunk && break
        end

        _cuda_drain_all!(backend, register_candidate!, n, should_stop) && (stop_requested[] = true)
    catch
        _cuda_drain_all!(backend, register_candidate!, n, should_stop; process = false)
        rethrow()
    end

    complete =
        prefix_active == false &&
        suffix_offset == UInt64(0) &&
        evaluated[] < max_evaluations_per_chunk &&
        !stop_requested[]
    (chunk = h12, evaluated = evaluated[], complete)
end
