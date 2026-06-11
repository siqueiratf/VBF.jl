include(joinpath(@__DIR__, "helpers.jl"))

# Long-running, resumable QAM search support for Yu-Wang-Li (2014).
# Paper section: IV, "New Quadratic APN Functions" and appendices.
#
# VBF API used: rank_f2, is_qam, qam_to_sbox, apn_ea_mugshot,
#               are_ea_equivalent, encode_quadratic, decode_quadratic_lut,
#               conway_polynomial, quadratic_exponents.

using Dates

const DEFAULT_RESULT_FILE = "qam_full_search.toml"
const DEFAULT_GPU_BATCH_SIZE = 1_048_576
const DEFAULT_GPU_PIPELINE_DEPTH = 3
const DEFAULT_GPU_RESULT_CAPACITY = 1_048_576

abstract type AbstractQAMSearchBackend end

struct CPUQAMBackend <: AbstractQAMSearchBackend end

function _make_cuda_qam_backend end

function _env_bool(name::AbstractString, default::Bool = false)
    value = get(ENV, name, nothing)
    value === nothing && return default
    s = lowercase(strip(value))
    s in ("1", "true", "yes", "on") && return true
    s in ("0", "false", "no", "off", "") && return false
    throw(ArgumentError("environment variable $name must be a boolean, got '$value'"))
end

function _env_optional_int(name::AbstractString, default)
    value = get(ENV, name, nothing)
    value === nothing && return default
    s = lowercase(strip(value))
    s in ("", "nothing", "none") && return nothing
    parse(Int, s)
end

function _format_elapsed(seconds::Real)
    s = Float64(seconds)
    s < 60 && return "$(round(s; digits = 3))s"
    minutes, rems = divrem(s, 60)
    minutes < 60 && return "$(Int(minutes))m $(round(rems; digits = 3))s"
    hours, remm = divrem(Int(minutes), 60)
    "$(hours)h $(remm)m $(round(rems; digits = 3))s"
end

_default_gpu_device() = _env_optional_int("QAM_GPU_DEVICE", 5)
_default_gpu_batch_size() = Int(_env_optional_int("QAM_GPU_BATCH_SIZE", DEFAULT_GPU_BATCH_SIZE))
_default_gpu_pipeline_depth() =
    Int(_env_optional_int("QAM_GPU_PIPELINE_DEPTH", DEFAULT_GPU_PIPELINE_DEPTH))
_default_gpu_suffix_entries() = _env_optional_int("QAM_GPU_SUFFIX_ENTRIES", nothing)
_default_gpu_result_capacity() =
    Int(_env_optional_int("QAM_GPU_RESULT_CAPACITY", DEFAULT_GPU_RESULT_CAPACITY))

function _ensure_cuda_search_loaded!()
    isdefined(@__MODULE__, :CUDAQAMBackend) && return nothing
    include(joinpath(@__DIR__, "exhaustive_search_cuda.jl"))
    nothing
end

function _make_search_backend(
    n::Int;
    use_gpu::Bool,
    gpu_device::Union{Nothing,Integer},
    gpu_batch_size::Integer,
    gpu_pipeline_depth::Integer,
    gpu_suffix_entries::Union{Nothing,Integer},
    gpu_result_capacity::Integer,
)
    if use_gpu
        _ensure_cuda_search_loaded!()
        return Base.invokelatest(
            _make_cuda_qam_backend,
            n;
            device = gpu_device === nothing ? nothing : Int(gpu_device),
            batch_size = Int(gpu_batch_size),
            pipeline_depth = Int(gpu_pipeline_depth),
            suffix_entries = gpu_suffix_entries === nothing ? nothing : Int(gpu_suffix_entries),
            result_capacity = Int(gpu_result_capacity),
        )
    end
    CPUQAMBackend()
end

_search_chunk_with_backend!(backend::CPUQAMBackend, args...; kwargs...) =
    _search_chunk!(backend, args...; kwargs...)

_search_chunk_with_backend!(backend::AbstractQAMSearchBackend, args...; kwargs...) =
    Base.invokelatest(_search_chunk!, backend, args...; kwargs...)

_resolve_modulus(n::Int, modulus::Union{Nothing,Integer}) =
    modulus === nothing ? conway_polynomial(n) : Int(modulus)

function bytes_to_hex(bytes::AbstractVector{UInt8})::String
    join(string(Int(b), base = 16, pad = 2) for b in bytes)
end

function hex_to_bytes(hex::AbstractString)::Vector{UInt8}
    s = strip(hex)
    iseven(length(s)) || throw(ArgumentError("hex_to_bytes: odd-length hex string"))
    [parse(UInt8, s[i:(i + 1)], base = 16) for i = 1:2:length(s)]
end

function spectrum_key(s::Spectrum)::String
    join(("$(p.first):$(p.second)" for p in sorted_pairs(s)), ",")
end

"""
    stable_mugshot_key(F) -> String

Stable text key for TOML persistence. This is an invariant key, not a proof of
EA-equivalence by itself; use `dedup = :ea` for strict pairwise checks among
representatives with the same key.
"""
function stable_mugshot_key(F::SBox)::String
    m = apn_ea_mugshot(F)
    parts = ["kind=$(m.kind)"]
    for name in keys(m.fields)
        v = getfield(m.fields, name)
        if v isa Spectrum
            push!(parts, "$(name)=" * spectrum_key(v))
        elseif v isa AbstractVector
            push!(parts, "$(name)=" * join(v, ","))
        else
            push!(parts, "$(name)=$(v)")
        end
    end
    join(parts, "|")
end

function _poly_degree(p::Integer)::Int
    x = Int(p)
    x == 0 && return -1
    8 * sizeof(Int) - leading_zeros(x) - 1
end

function _gf2_poly_mod(a::Integer, modulus::Integer)::Int
    r = Int(a)
    m = Int(modulus)
    md = _poly_degree(m)
    md >= 0 || throw(ArgumentError("zero polynomial modulus"))
    while _poly_degree(r) >= md
        r ⊻= m << (_poly_degree(r) - md)
    end
    r
end

function _gf2_poly_mul_mod(a::Integer, b::Integer, modulus::Integer)::Int
    aa = Int(a)
    bb = Int(b)
    m = Int(modulus)
    acc = 0
    while bb != 0
        (bb & 1) == 1 && (acc ⊻= aa)
        bb >>= 1
        aa <<= 1
        _poly_degree(aa) >= _poly_degree(m) && (aa = _gf2_poly_mod(aa, m))
    end
    _gf2_poly_mod(acc, m)
end

function _gf2_poly_gcd(a::Integer, b::Integer)::Int
    x = Int(a)
    y = Int(b)
    while y != 0
        x, y = y, _gf2_poly_mod(x, y)
    end
    x
end

function _prime_factors(n::Integer)::Vector{Int}
    x = Int(n)
    out = Int[]
    p = 2
    while p * p <= x
        if x % p == 0
            push!(out, p)
            while x % p == 0
                x ÷= p
            end
        end
        p += p == 2 ? 1 : 2
    end
    x > 1 && push!(out, x)
    out
end

function is_irreducible_modulus(n::Int, modulus::Integer)::Bool
    f = Int(modulus)
    _poly_degree(f) == n || return false
    x = 0b10
    y = x
    for _ = 1:n
        y = _gf2_poly_mul_mod(y, y, f)
    end
    y == x || return false
    for p in _prime_factors(n)
        y = x
        for _ = 1:(n ÷ p)
            y = _gf2_poly_mul_mod(y, y, f)
        end
        _gf2_poly_gcd(y ⊻ x, f) == 1 || return false
    end
    true
end

function multiplicative_order(
    a::Integer,
    n::Int;
    modulus::Int = conway_polynomial(n),
)::Int
    aa = Int(a)
    aa != 0 || return 0
    qminus1 = (1 << n) - 1
    gf_pow(aa, qminus1, n; modulus) == 1 || return 0
    order = qminus1
    for p in _prime_factors(qminus1)
        while order % p == 0 && gf_pow(aa, order ÷ p, n; modulus) == 1
            order ÷= p
        end
    end
    order
end

function validate_field_model(;
    n::Int = 7,
    modulus::Union{Nothing,Integer} = nothing,
    generator::Integer = 2,
)
    mod = _resolve_modulus(n, modulus)
    gen = Int(generator)
    irreducible = is_irreducible_modulus(n, mod)
    order = irreducible ? multiplicative_order(gen, n; modulus = mod) : 0
    (;
        n,
        modulus = mod,
        modulus_binary = string(mod, base = 2),
        modulus_degree = _poly_degree(mod),
        modulus_irreducible = irreducible,
        generator = gen,
        generator_order = order,
        generator_primitive = order == (1 << n) - 1,
        multiplicative_group_order = (1 << n) - 1,
    )
end

function assert_valid_field_model(n::Int, modulus::Int, generator::Int)
    r = validate_field_model(; n, modulus, generator)
    r.modulus_irreducible ||
        throw(ArgumentError("modulus $(modulus) is not irreducible of degree $n"))
    r.generator_primitive ||
        throw(ArgumentError("generator $(generator) is not primitive in GF(2^$n)"))
    r
end

function _discrete_log_table(n::Int, modulus::Int, generator::Int = 2)
    logs = Dict{Int,Int}()
    x = 1
    for e = 0:((1 << n) - 2)
        haskey(logs, x) && break
        logs[x] = e
        x = gf_mul(x, generator, n; modulus)
    end
    logs
end

function gf_trace(x::Integer, n::Int; modulus::Int = conway_polynomial(n))::Int
    y = Int(x)
    acc = 0
    for _ = 1:n
        acc ⊻= y
        y = gf_mul(y, y, n; modulus)
    end
    acc & 1
end

function _solve_f2_matrix(A::Matrix{UInt8}, b::Vector{UInt8})::Vector{UInt8}
    m, n = size(A)
    length(b) == m || throw(ArgumentError("right-hand side length mismatch"))
    aug = hcat(copy(A), reshape(copy(b), :, 1))
    row = 1
    pivots = Int[]
    for col = 1:n
        pivot_row = 0
        for r = row:m
            if aug[r, col] == 1
                pivot_row = r
                break
            end
        end
        pivot_row == 0 && continue
        if pivot_row != row
            tmp = copy(aug[row, :])
            aug[row, :] = aug[pivot_row, :]
            aug[pivot_row, :] = tmp
        end
        for r = 1:m
            r == row && continue
            if aug[r, col] == 1
                aug[r, :] .⊻= aug[row, :]
            end
        end
        push!(pivots, col)
        row += 1
        row > m && break
    end
    any(all(aug[r, c] == 0 for c = 1:n) && aug[r, n + 1] == 1 for r = 1:m) &&
        throw(ArgumentError("linear system is inconsistent"))
    x = zeros(UInt8, n)
    for (r, col) in enumerate(pivots)
        x[col] = aug[r, n + 1]
    end
    x
end

function polynomial_basis(n::Int)::Vector{Int}
    [1 << (u - 1) for u = 1:n]
end

function dual_basis(n::Int; modulus::Int = conway_polynomial(n))::Vector{Int}
    alpha = polynomial_basis(n)
    T = zeros(UInt8, n, n)
    for u = 1:n, b = 1:n
        T[u, b] = UInt8(gf_trace(gf_mul(alpha[u], alpha[b], n; modulus), n; modulus))
    end
    theta = Int[]
    for j = 1:n
        rhs = zeros(UInt8, n)
        rhs[j] = 1
        coords = _solve_f2_matrix(T, rhs)
        val = 0
        for b = 1:n
            coords[b] == 1 && (val ⊻= alpha[b])
        end
        push!(theta, val)
    end
    theta
end

function _frobenius_power(x::Integer, power_index::Int, n::Int, modulus::Int)
    y = Int(x)
    for _ = 1:power_index
        y = gf_mul(y, y, n; modulus)
    end
    y
end

function dual_basis_matrix(n::Int; modulus::Int = conway_polynomial(n))::Matrix{Int}
    theta = dual_basis(n; modulus)
    [_frobenius_power(theta[u], i - 1, n, modulus) for i = 1:n, u = 1:n]
end

function paper_restricted_terms_from_qam(
    H::AbstractMatrix{<:Integer};
    modulus::Int = conway_polynomial(size(H, 1)),
    generator::Int = 2,
)
    n = size(H, 1)
    size(H, 2) == n || throw(ArgumentError("paper_restricted_terms_from_qam: H must be square"))
    logs = _discrete_log_table(n, modulus, generator)
    Mtheta = dual_basis_matrix(n; modulus)
    terms = Vector{Dict{String,Any}}()
    for i = 2:n, t = 1:(i - 1)
        c = 0
        for u = 1:n, v = 1:n
            h = Int(H[u, v])
            h == 0 && continue
            prod = gf_mul(Mtheta[i, u], Mtheta[t, v], n; modulus)
            c ⊻= gf_mul(prod, h, n; modulus)
        end
        c == 0 && continue
        power = get(logs, c, -1)
        exponent = (1 << (i - 1)) + (1 << (t - 1))
        push!(
            terms,
            Dict{String,Any}(
                "i" => i,
                "t" => t,
                "coefficient" => c,
                "coefficient_power_of_generator" => power,
                "coefficient_power_of_x" => power,
                "exponent" => exponent,
            ),
        )
    end
    sort!(terms; by = t -> Int(t["exponent"]), rev = true)
    terms
end

function _quadratic_terms_from_bytes(
    bytes::AbstractVector{UInt8},
    n::Int,
    modulus::Int,
    generator::Int = 2,
)
    exps = quadratic_exponents(n)
    nb = cld(n, 8)
    length(bytes) == length(exps) * nb ||
        throw(ArgumentError("invalid quadratic coefficient byte length"))
    logs = _discrete_log_table(n, modulus, generator)
    terms = Vector{Dict{String,Any}}()
    for (i, e) in enumerate(exps)
        c = 0
        for b = 0:(nb - 1)
            c |= Int(bytes[(i - 1) * nb + b + 1]) << (8b)
        end
        c == 0 && continue
        power = get(logs, c, -1)
        push!(
            terms,
            Dict{String,Any}(
                "coefficient" => c,
                "coefficient_power_of_generator" => power,
                "coefficient_power_of_x" => power,
                "exponent" => e,
                "binary_weight" => count_ones(e),
            ),
        )
    end
    terms
end

function _term_label(term::AbstractDict)
    c = Int(term["coefficient"])
    e = Int(term["exponent"])
    p = Int(get(term, "coefficient_power_of_x", -1))
    coeff = if c == 1
        ""
    elseif p >= 0
        "a^$(p)*"
    else
        "$(c)*"
    end
    e == 0 ? (isempty(coeff) ? "1" : first(split(coeff, "*"))) : coeff * "X^$(e)"
end

function polynomial_string(terms::AbstractVector)::String
    isempty(terms) && return "0"
    join((_term_label(t) for t in terms), " + ")
end

function _literature_term_label(
    term::AbstractDict;
    generator_symbol::AbstractString = "g",
    variable_symbol::AbstractString = "x",
)
    c = Int(term["coefficient"])
    e = Int(term["exponent"])
    p = Int(get(term, "coefficient_power_of_generator", get(term, "coefficient_power_of_x", -1)))
    coeff = if c == 1
        ""
    elseif p == 1
        String(generator_symbol)
    elseif p >= 0
        "$(generator_symbol)^$(p)"
    else
        "$(c)"
    end
    var = e == 0 ? "" : e == 1 ? String(variable_symbol) : "$(variable_symbol)^$(e)"
    isempty(coeff) && isempty(var) && return "1"
    coeff * var
end

function paper_polynomial_string(
    terms::AbstractVector;
    generator_symbol::AbstractString = "g",
    variable_symbol::AbstractString = "x",
)::String
    isempty(terms) && return "0"
    ordered = sort(collect(terms); by = t -> Int(t["exponent"]), rev = true)
    join(
        (
            _literature_term_label(
                t;
                generator_symbol,
                variable_symbol,
            ) for t in ordered
        ),
        " + ",
    )
end

_matrix_rows(M::AbstractMatrix{<:Integer}) =
    [Int[M[i, j] for j = 1:size(M, 2)] for i = 1:size(M, 1)]

_upper_triangle(M::AbstractMatrix{<:Integer}) =
    [Int(M[i, j]) for j = 2:size(M, 2) for i = 1:(j - 1)]

"""
    class_record(F, M; class_index, chunk, modulus, powtab) -> Dict

Persist one representative in literature-friendly forms: LUT, QAM matrix,
upper-triangular QAM entries, packed quadratic coefficients, and the restricted
quadratic univariate polynomial terms.
"""
function class_record(
    F::SBox,
    M::AbstractMatrix{<:Integer};
    class_index::Int,
    chunk::Int,
    modulus::Int = conway_polynomial(inputbits(F)),
    generator::Int = 2,
    generator_symbol::AbstractString = "g",
    variable_symbol::AbstractString = "x",
    powtab = nothing,
)
    n = inputbits(F)
    bytes = encode_quadratic(F; modulus, powtab)
    terms = _quadratic_terms_from_bytes(bytes, n, modulus, generator)
    paper_terms = paper_restricted_terms_from_qam(M; modulus, generator)
    Dict{String,Any}(
        "index" => class_index,
        "n" => n,
        "field_modulus" => modulus,
        "field_generator" => generator,
        "source_chunk_h12" => chunk,
        "mugshot_key" => stable_mugshot_key(F),
        "lut" => Int.(F.lut),
        "qam_matrix" => _matrix_rows(M),
        "qam_upper_triangle" => _upper_triangle(M),
        "quadratic_coefficients_format" => "quadratic-coeffs-v1",
        "quadratic_coefficients_hex" => bytes_to_hex(bytes),
        "univariate_terms" => terms,
        "univariate_polynomial" => polynomial_string(terms),
        "paper_restricted_terms" => paper_terms,
        "paper_restricted_polynomial_format" => "literature-gx-v1",
        "paper_restricted_polynomial" => paper_polynomial_string(
            paper_terms;
            generator_symbol,
            variable_symbol,
        ),
    )
end

function sbox_from_record(rec::AbstractDict, n::Int; modulus::Int = conway_polynomial(n))
    if haskey(rec, "lut")
        return SBox{n}(Int.(rec["lut"]))
    elseif haskey(rec, "qam_matrix")
        rows = rec["qam_matrix"]
        M = reduce(vcat, (reshape(Int.(r), 1, :) for r in rows))
        return qam_to_sbox(M)
    elseif haskey(rec, "quadratic_coefficients_hex")
        bytes = hex_to_bytes(String(rec["quadratic_coefficients_hex"]))
        return SBox{n}(decode_quadratic_lut(bytes, n, modulus))
    elseif haskey(rec, "univariate_terms")
        terms = [(Int(t["coefficient"]), Int(t["exponent"])) for t in rec["univariate_terms"]]
        return SBox{n}(terms_to_lut(terms, n, modulus))
    end
    throw(ArgumentError("record does not contain a supported function representation"))
end

function _load_search_state(path::AbstractString, n::Int, modulus::Int)
    isfile(path) || return (classes = Dict{String,Any}[], completed = Int[], chunks = Dict{String,Any}[])
    data = TOML.parsefile(path)
    classes = [Dict{String,Any}(c) for c in get(data, "classes", Any[])]
    chunks = [Dict{String,Any}(c) for c in get(data, "chunks", Any[])]
    completed = Int.(get(data, "completed_chunks", Int[]))
    for rec in classes
        Int(rec["n"]) == n ||
            throw(ArgumentError("result file n=$(rec["n"]) does not match requested n=$n"))
        sbox_from_record(rec, n; modulus)
    end
    (classes = classes, completed = completed, chunks = chunks)
end

function _write_search_state(
    path::AbstractString;
    n::Int,
    modulus::Int,
    expected_classes::Union{Nothing,Int},
    generator::Int,
    field_validation,
    generator_symbol::AbstractString,
    variable_symbol::AbstractString,
    dedup::Symbol,
    threaded::Bool,
    classes,
    completed_chunks,
    chunks,
    exhaustive::Bool,
)
    data = Dict{String,Any}(
        "metadata" => Dict{String,Any}(
            "paper" => "Yu-Wang-Li 2014",
            "search" => "full symmetric QAM, chunked by H[1,2]",
            "n" => n,
            "modulus" => modulus,
            "generator" => generator,
            "generator_symbol" => String(generator_symbol),
            "variable_symbol" => String(variable_symbol),
            "field_validation" => field_validation,
            "expected_classes" => expected_classes === nothing ? "unknown" : expected_classes,
            "dedup" => String(dedup),
            "threaded" => threaded,
            "julia_threads" => Threads.nthreads(),
            "updated_at" => Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS"),
            "exhaustive" => exhaustive,
        ),
        "completed_chunks" => sort!(collect(completed_chunks)),
        "chunks" => chunks,
        "classes" => classes,
    )
    dir = dirname(path)
    mkpath(dir)
    tmp = tempname(dir)
    try
        open(tmp, "w") do io
            TOML.print(io, toml_safe(data); sorted = true)
        end
        mv(tmp, path; force = true)
    finally
        isfile(tmp) && rm(tmp; force = true)
    end
    path
end

mutable struct AsyncCheckpointWriter
    queue::Channel{Any}
    task::Task
    error::Base.RefValue{Any}
    closed::Base.RefValue{Bool}
end

function _write_search_state_snapshot(snapshot)
    _write_search_state(
        snapshot.path;
        n = snapshot.n,
        modulus = snapshot.modulus,
        expected_classes = snapshot.expected_classes,
        generator = snapshot.generator,
        field_validation = snapshot.field_validation,
        generator_symbol = snapshot.generator_symbol,
        variable_symbol = snapshot.variable_symbol,
        dedup = snapshot.dedup,
        threaded = snapshot.threaded,
        classes = snapshot.classes,
        completed_chunks = snapshot.completed_chunks,
        chunks = snapshot.chunks,
        exhaustive = snapshot.exhaustive,
    )
end

function _start_async_checkpoint_writer()
    queue = Channel{Any}(2)
    err = Ref{Any}(nothing)
    closed = Ref(false)
    task = Threads.@spawn begin
        try
            while true
                snapshot = take!(queue)
                snapshot === nothing && break
                _write_search_state_snapshot(snapshot)
            end
        catch e
            err[] = e
        end
    end
    AsyncCheckpointWriter(queue, task, err, closed)
end

function _checkpoint_snapshot(
    path::AbstractString;
    n::Int,
    modulus::Int,
    expected_classes::Union{Nothing,Int},
    generator::Int,
    field_validation,
    generator_symbol::AbstractString,
    variable_symbol::AbstractString,
    dedup::Symbol,
    threaded::Bool,
    classes,
    completed_chunks,
    chunks,
    exhaustive::Bool,
)
    (;
        path = String(path),
        n,
        modulus,
        expected_classes,
        generator,
        field_validation,
        generator_symbol = String(generator_symbol),
        variable_symbol = String(variable_symbol),
        dedup,
        threaded,
        classes = deepcopy(classes),
        completed_chunks = Set(Int.(collect(completed_chunks))),
        chunks = deepcopy(chunks),
        exhaustive,
    )
end

function _check_async_checkpoint_error!(writer::AsyncCheckpointWriter)
    writer.error[] === nothing || throw(writer.error[])
end

function _schedule_async_checkpoint!(writer::AsyncCheckpointWriter, snapshot)
    _check_async_checkpoint_error!(writer)
    writer.closed[] && return nothing
    while isready(writer.queue)
        take!(writer.queue)
    end
    put!(writer.queue, snapshot)
    nothing
end

function _finish_async_checkpoint_writer!(writer::AsyncCheckpointWriter, final_snapshot)
    _check_async_checkpoint_error!(writer)
    writer.closed[] && return nothing
    writer.closed[] = true
    while isready(writer.queue)
        take!(writer.queue)
    end
    put!(writer.queue, final_snapshot)
    put!(writer.queue, nothing)
    wait(writer.task)
    _check_async_checkpoint_error!(writer)
    nothing
end

function _stop_async_checkpoint_writer!(writer::AsyncCheckpointWriter)
    writer.closed[] && return nothing
    writer.closed[] = true
    while isready(writer.queue)
        take!(writer.queue)
    end
    put!(writer.queue, nothing)
    wait(writer.task)
    nothing
end

function _proper_leading_submatrix(M, c::Int, n::Int, vecbuf::Vector{UInt})
    @inbounds for mask = 1:((1 << c) - 1)
        for i = 1:c
            v = UInt(0)
            s = mask
            while s != 0
                r = trailing_zeros(s) + 1
                v ⊻= UInt(M[r][i])
                s &= s - 1
            end
            vecbuf[i] = v
        end
        rank_f2(view(vecbuf, 1:c); nbits = n) < c - 1 && return false
    end
    true
end

"""
    _span_at_least!(basis, vecbuf, c, need) -> Bool

GF(2) span-dimension test by streaming Gaussian elimination: returns whether
`dim span{vecbuf[1..c]} >= need`, exiting as soon as more than `c - need`
elements have reduced to zero against the partial basis. `basis` is a scratch
vector of length >= the bit-width of the entries, indexed by leading-bit
position.
"""
function _span_at_least!(basis::Vector{UInt}, vecbuf::Vector{UInt}, c::Int, need::Int)
    need <= 0 && return true
    fill!(basis, UInt(0))
    allowed = c - need
    allowed < 0 && return false
    fails = 0
    @inbounds for i = 1:c
        v = vecbuf[i]
        while v != UInt(0)
            t = 8 * sizeof(UInt) - leading_zeros(v)
            b = basis[t]
            if b == UInt(0)
                basis[t] = v
                break
            end
            v ⊻= b
        end
        if v == UInt(0)
            fails += 1
            fails > allowed && return false
        end
    end
    true
end

"""
    _proper_subsets_containing(M, pivot, c, n, vecbuf, basis) -> Bool

Checks the QAM properness condition `dim span >= c - 1` over the leading `c`
entries for every row subset of `{1..pivot}` that contains row `pivot`
(Yu-Wang-Li 2014, Theorem 2 applied incrementally). Calling this after entry
`(pivot, c)` is filled covers each subset exactly once per column: subsets are
tested at the moment their highest row's column-`c` entry becomes known, and
the `pivot == c` call covers the subsets containing the diagonal row.
"""
function _proper_subsets_containing(
    M,
    pivot::Int,
    c::Int,
    n::Int,
    vecbuf::Vector{UInt},
    basis::Vector{UInt},
)
    pivotbit = 1 << (pivot - 1)
    @inbounds for sub = 0:((1 << (pivot - 1)) - 1)
        mask = sub | pivotbit
        for i = 1:c
            v = UInt(0)
            s = mask
            while s != 0
                r = trailing_zeros(s) + 1
                v ⊻= UInt(M[r][i])
                s &= s - 1
            end
            vecbuf[i] = v
        end
        _span_at_least!(basis, vecbuf, c, c - 1) || return false
    end
    true
end

function _cpu_chunk_worker!(
    register_candidate!::Function,
    n::Int,
    h12::Int,
    next_root::Threads.Atomic{Int},
    evaluated::Threads.Atomic{Int},
    max_evaluations_per_chunk::Integer,
    should_stop::Function,
)
    q = 1 << n
    M = [zeros(Int, n) for _ = 1:n]
    M[1][2] = h12
    M[2][1] = h12
    vecbuf = zeros(UInt, n)
    basis = zeros(UInt, n)

    function materialize_matrix()
        Mat = Matrix{Int}(undef, n, n)
        @inbounds for i = 1:n, j = 1:n
            Mat[i, j] = M[i][j]
        end
        Mat
    end

    local fill_col
    fill_entry = function (c::Int, r::Int)
        should_stop() && return
        evaluated[] >= max_evaluations_per_chunk && return
        if r == c
            _proper_subsets_containing(M, c, c, n, vecbuf, basis) && fill_col(c + 1)
            return
        end
        @inbounds for v = 0:(q - 1)
            M[r][c] = v
            M[c][r] = v
            _proper_subsets_containing(M, r, c, n, vecbuf, basis) &&
                fill_entry(c, r + 1)
            should_stop() && return
            evaluated[] >= max_evaluations_per_chunk && return
        end
    end

    fill_col = function (c::Int)
        should_stop() && return
        evaluated[] >= max_evaluations_per_chunk && return
        if c > n
            Threads.atomic_add!(evaluated, 1)
            Mat = materialize_matrix()
            is_qam(Mat) && register_candidate!(qam_to_sbox(Mat), Mat, h12)
            return
        end
        fill_entry(c, 1)
    end

    while true
        root = Threads.atomic_add!(next_root, 1)
        root >= q * q && break
        should_stop() && break
        evaluated[] >= max_evaluations_per_chunk && break
        v1 = root >> n
        v2 = root & (q - 1)
        M[1][3] = v1
        M[3][1] = v1
        _proper_subsets_containing(M, 1, 3, n, vecbuf, basis) || continue
        M[2][3] = v2
        M[3][2] = v2
        _proper_subsets_containing(M, 2, 3, n, vecbuf, basis) || continue
        fill_entry(3, 3)
    end
    nothing
end

function _search_chunk!(
    ::CPUQAMBackend,
    register_candidate!::Function,
    n::Int,
    h12::Int;
    max_evaluations_per_chunk::Integer = typemax(Int),
    should_stop::Function = () -> false,
    progress_callback::Function = _ -> nothing,
    dfs_threads::Int = 1,
)
    evaluated = Threads.Atomic{Int}(0)
    vecbuf = zeros(UInt, n)
    M0 = [zeros(Int, n) for _ = 1:n]
    M0[1][2] = h12
    M0[2][1] = h12
    if !_proper_leading_submatrix(M0, 2, n, vecbuf)
        return (chunk = h12, evaluated = 0, complete = true)
    end
    if n < 3
        Threads.atomic_add!(evaluated, 1)
        Mat = Matrix{Int}(undef, n, n)
        @inbounds for i = 1:n, j = 1:n
            Mat[i, j] = M0[i][j]
        end
        is_qam(Mat) && register_candidate!(qam_to_sbox(Mat), Mat, h12)
        return (chunk = h12, evaluated = evaluated[], complete = true)
    end
    next_root = Threads.Atomic{Int}(0)
    nworkers = clamp(dfs_threads, 1, (1 << n)^2)
    if nworkers == 1
        _cpu_chunk_worker!(
            register_candidate!,
            n,
            h12,
            next_root,
            evaluated,
            max_evaluations_per_chunk,
            should_stop,
        )
    else
        tasks = [
            Threads.@spawn _cpu_chunk_worker!(
                register_candidate!,
                n,
                h12,
                next_root,
                evaluated,
                max_evaluations_per_chunk,
                should_stop,
            ) for _ = 1:nworkers
        ]
        foreach(wait, tasks)
    end
    (
        chunk = h12,
        evaluated = evaluated[],
        complete = evaluated[] < max_evaluations_per_chunk,
    )
end

_search_chunk!(
    register_candidate!::Function,
    n::Int,
    h12::Int;
    kwargs...,
) = _search_chunk!(CPUQAMBackend(), register_candidate!, n, h12; kwargs...)

function _existing_sboxes(classes, n::Int, modulus::Int)
    [sbox_from_record(c, n; modulus) for c in classes]
end

function _rebuild_seen(classes, reps)
    seen = Dict{String,Vector{Int}}()
    for (i, rec) in enumerate(classes)
        key = haskey(rec, "mugshot_key") ? String(rec["mugshot_key"]) : stable_mugshot_key(reps[i])
        push!(get!(seen, key, Int[]), i)
    end
    seen
end

"""
    exhaustive_qam_search(; n = 7, expected_classes = 490, ...)

Long-running full symmetric QAM search. The search is chunked by `H[1,2]`, so
completed chunks are resumable from the TOML file under `results/`.
"""
function exhaustive_qam_search(;
    n::Int = 7,
    expected_classes::Union{Nothing,Int} = 490,
    modulus::Union{Nothing,Integer} = nothing,
    generator::Integer = 2,
    generator_symbol::AbstractString = "g",
    variable_symbol::AbstractString = "x",
    validate_field::Bool = true,
    result_file::AbstractString = paper_results_path("qam_full_n$(n).toml"),
    resume::Bool = true,
    threaded::Bool = Threads.nthreads() > 1,
    dfs_threads::Integer = threaded ? Threads.nthreads() : 1,
    dedup::Symbol = :ea,
    limit_classes::Integer = typemax(Int),
    max_chunks::Integer = typemax(Int),
    max_evaluations_per_chunk::Integer = typemax(Int),
    checkpoint_every_chunks::Integer = 1,
    use_gpu::Bool = _env_bool("QAM_GPU", false),
    gpu_device::Union{Nothing,Integer} = _default_gpu_device(),
    gpu_batch_size::Integer = _default_gpu_batch_size(),
    gpu_pipeline_depth::Integer = _default_gpu_pipeline_depth(),
    gpu_suffix_entries::Union{Nothing,Integer} = _default_gpu_suffix_entries(),
    gpu_result_capacity::Integer = _default_gpu_result_capacity(),
    io::IO = stdout,
)
    dedup in (:mugshot, :ea) ||
        throw(ArgumentError("dedup must be :mugshot or :ea"))
    dfs_threads >= 1 || throw(ArgumentError("dfs_threads must be positive, got $dfs_threads"))
    search_backend = _make_search_backend(
        n;
        use_gpu,
        gpu_device,
        gpu_batch_size,
        gpu_pipeline_depth,
        gpu_suffix_entries,
        gpu_result_capacity,
    )
    effective_dfs_threads = min(Int(dfs_threads), Threads.nthreads())
    effective_threaded =
        threaded && search_backend isa CPUQAMBackend && effective_dfs_threads == 1
    modulus = _resolve_modulus(n, modulus)
    generator = Int(generator)
    field_validation = validate_field ?
        assert_valid_field_model(n, modulus, generator) :
        validate_field_model(; n, modulus, generator)
    state = resume ?
        _load_search_state(result_file, n, modulus) :
        (classes = Dict{String,Any}[], completed = Int[], chunks = Dict{String,Any}[])

    classes = state.classes
    completed_chunks = Set(state.completed)
    chunk_records = state.chunks
    initial_chunk_records = length(chunk_records)
    reps = _existing_sboxes(classes, n, modulus)
    seen = _rebuild_seen(classes, reps)
    lock_obj = ReentrantLock()
    chunks_done_since_checkpoint = Ref(0)
    gpu_progress_next_ns = Ref(UInt64(0))
    gpu_progress_interval_ns = UInt64(10_000_000_000)
    checkpoint_writer = _start_async_checkpoint_writer()
    run_started_ns = time_ns()
    class_discovery_times = NamedTuple{(:index, :chunk, :elapsed_seconds),Tuple{Int,Int,Float64}}[]
    powtab = monomial_power_table(n, modulus)
    all_chunks = collect(1:((1 << n) - 1))
    todo = [c for c in all_chunks if !(c in completed_chunks)]
    length(todo) > max_chunks && resize!(todo, Int(max_chunks))

    function should_stop()
        limit_classes == typemax(Int) && return false
        lock(lock_obj)
        try
            return length(classes) >= limit_classes
        finally
            unlock(lock_obj)
        end
    end

    function checkpoint_locked()
        exhaustive = length(completed_chunks) == length(all_chunks)
        _checkpoint_snapshot(
            result_file;
            n,
            modulus,
            expected_classes,
            generator,
            field_validation,
            generator_symbol,
            variable_symbol,
            dedup,
            threaded = effective_threaded || effective_dfs_threads > 1,
            classes,
            completed_chunks,
            chunks = chunk_records,
            exhaustive,
        )
    end

    function schedule_checkpoint_locked()
        _schedule_async_checkpoint!(checkpoint_writer, checkpoint_locked())
    end

    function register_candidate!(F::SBox, M::AbstractMatrix{<:Integer}, chunk::Int)
        key = stable_mugshot_key(F)
        lock(lock_obj)
        try
            idxs = get(seen, key, Int[])
            is_new = if dedup === :mugshot
                isempty(idxs)
            else
                !any(i -> are_ea_equivalent(F, reps[i]), idxs)
            end
            is_new || return false
            elapsed_seconds = (time_ns() - run_started_ns) / 1.0e9
            push!(reps, F)
            rec = class_record(
                F,
                M;
                class_index = length(classes) + 1,
                chunk,
                modulus,
                generator,
                generator_symbol,
                variable_symbol,
                powtab,
            )
            push!(classes, rec)
            push!(get!(seen, key, Int[]), length(classes))
            push!(
                class_discovery_times,
                (index = length(classes), chunk = Int(chunk), elapsed_seconds = elapsed_seconds),
            )
            schedule_checkpoint_locked()
            return true
        finally
            unlock(lock_obj)
        end
    end

    function report_gpu_progress!(stats)
        search_backend isa CPUQAMBackend && return nothing
        now_ns = UInt64(time_ns())
        phase = String(stats.phase)
        if phase != "start" && now_ns < gpu_progress_next_ns[]
            return nothing
        end
        gpu_progress_next_ns[] = now_ns + gpu_progress_interval_ns
        print_kv(
            "GPU chunk progress",
            "h12=$(Int(stats.chunk)), phase=$(phase), " *
            "prefixes=$(Int(stats.prefixes)), queued=$(Int(stats.queued_prefixes)), " *
            "evaluated=$(Int(stats.evaluated)), gpu_batches=$(Int(stats.gpu_batches)), " *
            "dfs_nodes=$(Int(stats.dfs_nodes)), rank_checks=$(Int(stats.rank_checks))",
            io,
        )
        flush(io)
        nothing
    end

    function finish_chunk!(stats)
        lock(lock_obj)
        try
            Bool(stats.complete) && push!(completed_chunks, Int(stats.chunk))
            chunk_record = Dict{String,Any}(
                "h12" => Int(stats.chunk),
                "evaluated" => Int(stats.evaluated),
                "complete" => Bool(stats.complete),
                "completed_at" => Dates.format(now(), dateformat"yyyy-mm-ddTHH:MM:SS"),
            )
            for field in (:prefixes, :gpu_batches, :dfs_nodes, :rank_checks, :suffix_entries)
                if field in propertynames(stats)
                    chunk_record[String(field)] = Int(getproperty(stats, field))
                end
            end
            push!(
                chunk_records,
                chunk_record,
            )
            chunks_done_since_checkpoint[] += 1
            processed_this_run = length(chunk_records) - initial_chunk_records
            gpu_tail = if :prefixes in propertynames(stats)
                ", prefixes=$(Int(stats.prefixes)), gpu_batches=$(Int(stats.gpu_batches)), " *
                "dfs_nodes=$(Int(stats.dfs_nodes)), rank_checks=$(Int(stats.rank_checks))"
            else
                ""
            end
            print_kv(
                "chunk progress",
                "$(length(completed_chunks))/$(length(all_chunks)) completed; " *
                "$(processed_this_run)/$(length(todo)) processed this run; " *
                "last h12=$(Int(stats.chunk)), complete=$(Bool(stats.complete)), " *
                "evaluated=$(Int(stats.evaluated))$(gpu_tail)",
                io,
            )
            flush(io)
            if chunks_done_since_checkpoint[] >= checkpoint_every_chunks || Bool(stats.complete) == false
                schedule_checkpoint_locked()
                chunks_done_since_checkpoint[] = 0
            end
        finally
            unlock(lock_obj)
        end
    end

    print_section("Long-running full QAM search", io)
    print_kv("result file", result_file, io)
    print_kv("n", n, io)
    print_kv("modulus", "$(modulus) (0b$(string(modulus, base = 2)))", io)
    print_kv("generator", generator, io)
    print_check("modulus irreducible", field_validation.modulus_irreducible, io)
    print_check("generator primitive", field_validation.generator_primitive, io)
    print_kv("expected classes", expected_classes === nothing ? "unknown" : expected_classes, io)
    print_kv("dedup", dedup, io)
    if search_backend isa CPUQAMBackend
        print_kv("backend", "CPU", io)
    else
        print_kv("backend", "CUDA", io)
        backend_props = propertynames(search_backend)
        :active_device in backend_props && print_kv("CUDA device", search_backend.active_device, io)
        :batch_size in backend_props && print_kv("CUDA batch size", search_backend.batch_size, io)
        :pipeline_depth in backend_props &&
            print_kv("CUDA pipeline depth", search_backend.pipeline_depth, io)
        :suffix_entries in backend_props &&
            print_kv("CUDA suffix entries", search_backend.suffix_entries, io)
        :prefix_batch_capacity in backend_props &&
            print_kv("CUDA prefix batch capacity", search_backend.prefix_batch_capacity, io)
    end
    print_kv("Julia threads", Threads.nthreads(), io)
    print_kv("DFS workers per chunk", effective_dfs_threads, io)
    print_kv("chunks pending this run", length(todo), io)
    print_kv("classes already loaded", length(classes), io)

    try
        if effective_threaded && Threads.nthreads() > 1
            Threads.@threads :dynamic for idx in eachindex(todo)
                should_stop() && continue
                stats = _search_chunk_with_backend!(
                    search_backend,
                    register_candidate!,
                    n,
                    todo[idx];
                    max_evaluations_per_chunk,
                    should_stop,
                    progress_callback = report_gpu_progress!,
                    dfs_threads = effective_dfs_threads,
                )
                finish_chunk!(stats)
            end
        else
            for h12 in todo
                should_stop() && break
                stats = _search_chunk_with_backend!(
                    search_backend,
                    register_candidate!,
                    n,
                    h12;
                    max_evaluations_per_chunk,
                    should_stop,
                    progress_callback = report_gpu_progress!,
                    dfs_threads = effective_dfs_threads,
                )
                finish_chunk!(stats)
            end
        end

        final_snapshot = begin
            lock(lock_obj)
            try
                checkpoint_locked()
            finally
                unlock(lock_obj)
            end
        end
        _finish_async_checkpoint_writer!(checkpoint_writer, final_snapshot)
    catch
        _stop_async_checkpoint_writer!(checkpoint_writer)
        rethrow()
    end

    lock(lock_obj)
    try
        _check_async_checkpoint_error!(checkpoint_writer)
    finally
        unlock(lock_obj)
    end

    exhaustive = length(completed_chunks) == length(all_chunks)
    expected_ok = expected_classes === nothing ? nothing : length(classes) == expected_classes
    result = (;
        n,
        result_file,
        classes = length(classes),
        expected_classes,
        expected_ok,
        chunks_completed = length(completed_chunks),
        total_chunks = length(all_chunks),
        exhaustive,
        dedup,
    )
    print_kv("classes stored", result.classes, io)
    print_kv("chunks completed", "$(result.chunks_completed)/$(result.total_chunks)", io)
    print_kv("exhaustive", result.exhaustive, io)
    if isempty(class_discovery_times)
        print_kv("class discovery times", "no new classes found in this run", io)
    else
        print_section("Class discovery times", io)
        for rec in class_discovery_times
            print_kv(
                "class $(rec.index)",
                "$(_format_elapsed(rec.elapsed_seconds)) total elapsed; chunk h12=$(rec.chunk)",
                io,
            )
        end
    end
    expected_classes === nothing || print_check("class count matches expected", result.expected_ok, io)
    result
end

function load_search_sboxes(path::AbstractString)
    data = TOML.parsefile(path)
    meta = data["metadata"]
    n = Int(meta["n"])
    modulus = Int(meta["modulus"])
    [sbox_from_record(rec, n; modulus) for rec in get(data, "classes", Any[])]
end

"""
    compare_result_sets(found_path, reference_path; equivalence = :ea)

Compare persisted search output with an imported published-reference TOML file.
The reference file may use the same `classes` schema or any class records with
LUT, QAM matrix, packed quadratic coefficients, or univariate terms.
"""
function compare_result_sets(
    found_path::AbstractString,
    reference_path::AbstractString;
    equivalence::Symbol = :ea,
)
    equivalence in (:lut, :mugshot, :ea) ||
        throw(ArgumentError("equivalence must be :lut, :mugshot, or :ea"))
    found = load_search_sboxes(found_path)
    ref = load_search_sboxes(reference_path)
    used = falses(length(found))

    function equiv(a, b)
        if equivalence === :lut
            return a == b
        elseif equivalence === :mugshot
            return stable_mugshot_key(a) == stable_mugshot_key(b)
        else
            return are_ea_equivalent(a, b)
        end
    end

    missing = Int[]
    for (ri, r) in enumerate(ref)
        hit = findfirst(i -> !used[i] && equiv(found[i], r), eachindex(found))
        if hit === nothing
            push!(missing, ri)
        else
            used[hit] = true
        end
    end
    extra = findall(!, used)
    (;
        found_count = length(found),
        reference_count = length(ref),
        matched_count = length(ref) - length(missing),
        missing_reference_indices = missing,
        extra_found_indices = extra,
        exact_same_set = isempty(missing) && isempty(extra),
        equivalence,
    )
end

function exhaustive_search_report(io::IO = stdout; kwargs...)
    exhaustive_qam_search(; io, kwargs...)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    exhaustive_search_report()
end
