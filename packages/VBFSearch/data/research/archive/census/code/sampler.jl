# Implements the threaded Knuth sampler with an exact last extension step
# Study: census of quadratic APN functions on F_2^8 (census/quadratic_apn8)
# Source: Beierle et al. (2025, v2), Theorem 4.1 and Lemma 4.5
#
# Math:
#   Knuth's estimator on the extension tree: a probe from the root to depth n-1 multiplies
#   the numbers d_k of valid values of every step; the last step (n-1 -> n variables) is
#   counted exactly, e = e(G) (fastlast.jl, FL3).  The weight W = prod(d_k) * e satisfies
#   E[W] = T(n,m), and T(n,m) / (|GL(n,2)| |GL(m,2)|) = sum_{classes} 1/|Stab| (the mass).
#   A sampled leaf (one completion chosen uniformly among the canonical ones) is an APN
#   function drawn with probability proportional to 1/W; the analysis reweights by W.
#
# Pseudocode:
#   for th in 1:S (RNG streams, default S = threads), rng = Xoshiro(seed * 100003 + th):
#     for i in th:S:N (sample index):
#       (logw, C) = probe to n-1 variables;  logw = -Inf -> line "i  -Inf  0  ".
#       (e, sols) = FL3.count_completions(C, n-1, m; want_solution = true)
#       e == 0 -> line "i  logw  0  ".
#       else L = sols[rand(rng, 1:length(sols))]; C[k,n] = L[k];
#            line "i  logw  e  coeffs" (coeffs = encode_coeffs(C, n)).
#   Write the N lines in index order.
#
# Reproducibility: sample i uses the RNG stream th = ((i-1) mod S) + 1, so a chunk is a
#   function of (N, seed, S, n, m) only.  The same seed and the SAME stream count S
#   reproduce a chunk byte for byte; a different S gives a different (equally valid)
#   chunk.  The streams run on any number of threads: S = threads by default, and
#   streams = 12 with threads = 2 regenerates a 12-thread chunk.  The legacy chunks
#   c101..c140 and s1.tsv use S = 12; s77.tsv uses S = 4.
# VBF API used: none (helpers.jl loads VBF for SBox; the sampler does not call it).

isdefined(@__MODULE__, :QK) || include(joinpath(@__DIR__, "qknuth.jl"))
isdefined(@__MODULE__, :FL3) || include(joinpath(@__DIR__, "fastlast.jl"))
isdefined(@__MODULE__, :encode_coeffs) || include(joinpath(@__DIR__, "helpers.jl"))

using Random
using Printf
using Base.Threads

"""
    probe_to_penultimate(rng, n, m) -> (logw, C)

Knuth probe down to `n-1` variables. `logw = sum log d_k`, or `-Inf` on a dead end.
"""
function probe_to_penultimate(rng, n::Int, m::Int)
    C = zeros(UInt16, n, n)
    forb = falses(1 << m)
    free = Vector{UInt16}(undef, 1 << m)
    logw = 0.0
    for nv in 1:n - 2
        I = QK.images(C, nv, m)
        L = zeros(UInt16, 1 << nv)
        for k in 1:nv
            QK.free_values!(forb, L, I, k, m)
            d = 0
            @inbounds for b in 0:(1 << m) - 1
                forb[b + 1] || (d += 1; free[d] = b)
            end
            d == 0 && return (-Inf, C)
            logw += log(d)
            b = free[rand(rng, 1:d)]
            C[k, nv + 1] = b
            C[nv + 1, k] = b
            hk = 1 << (k - 1)
            @inbounds for a in 0:hk - 1
                L[(a | hk) + 1] = L[a + 1] ⊻ b
            end
        end
    end
    (logw, C)
end

"""
    sample_line(rng, i, n, m) -> String

One sample: the TSV line `i<TAB>logw<TAB>e<TAB>coeffs` (coeffs only when `e > 0`).
"""
function sample_line(rng, i::Int, n::Int, m::Int)
    logw, C = probe_to_penultimate(rng, n, m)
    isfinite(logw) || return "$(i)\t-Inf\t0\t"
    e, sols = FL3.count_completions(C, n - 1, m; want_solution = true)
    e == 0 && return @sprintf("%d\t%.10f\t0\t", i, logw)
    L = sols[rand(rng, 1:length(sols))]
    for k in 1:n - 1
        C[k, n] = L[k]
        C[n, k] = L[k]
    end
    @sprintf("%d\t%.10f\t%d\t%s", i, logw, e, encode_coeffs(C, n))
end

"""
    sample_stream!(res, seed, th, nthr, n, m)

Fill `res[i]` for `i in th:nthr:length(res)` from the RNG stream
`Xoshiro(seed * 100003 + th)`. This is the work of thread `th` of `nthr`.
"""
function sample_stream!(res::Vector{String}, seed::Int, th::Int, nthr::Int, n::Int, m::Int)
    rng = Xoshiro(seed * 100003 + th)
    for i in th:nthr:length(res)
        res[i] = sample_line(rng, i, n, m)
    end
    res
end

"""
    sample_chunk(nsamples, seed; n = 8, m = 8, streams = nthreads()) -> Vector{String}

`nsamples` sample lines from `streams` RNG streams. The streams run in parallel on the
Julia threads; the result depends on `streams`, not on the number of threads.
"""
function sample_chunk(nsamples::Int, seed::Int; n::Int = 8, m::Int = 8,
                      streams::Int = nthreads())
    streams >= 1 || throw(ArgumentError("streams must be >= 1"))
    res = Vector{String}(undef, nsamples)
    @threads :dynamic for th in 1:streams
        sample_stream!(res, seed, th, streams, n, m)
    end
    res
end

"Write sample lines to `path` through a temporary file (no partial chunk on interrupt)."
function write_chunk(path::AbstractString, lines::AbstractVector{<:AbstractString})
    mkpath(dirname(path))
    tmp = path * ".tmp"
    open(tmp, "w") do io
        for r in lines
            println(io, r)
        end
    end
    mv(tmp, path; force = true)
    path
end

function _check_threads(threads::Integer)
    threads == nthreads() && return nothing
    error("threads=$threads but Julia runs $(nthreads()) threads; start julia with -t $threads " *
          "(the RNG scheme depends on streams, not on threads)")
end

"""
    run_sampling(; outdir, first_seed, nchunks, samples, threads, streams = threads, n = 8, m = 8)

Write chunks `outdir/c<seed>.tsv` for `seed in first_seed:first_seed+nchunks-1`, each
with `samples` lines from `streams` RNG streams. An existing chunk is kept (the run
resumes). `threads` must equal `Threads.nthreads()`.
"""
function run_sampling(; outdir::AbstractString, first_seed::Int, nchunks::Int, samples::Int,
                      threads::Int, streams::Int = threads, n::Int = 8, m::Int = 8,
                      io::IO = stdout)
    _check_threads(threads)
    nchunks >= 0 || throw(ArgumentError("nchunks must be >= 0"))
    samples > 0 || throw(ArgumentError("samples must be > 0"))
    for s in first_seed:first_seed + nchunks - 1
        path = joinpath(outdir, "c$(s).tsv")
        if isfile(path)
            println(io, "skip  ", path, " (exists)")
            continue
        end
        t = @elapsed lines = sample_chunk(samples, s; n, m, streams)
        write_chunk(path, lines)
        nh = count(l -> split(l, '\t')[3] != "0", lines)
        @printf(io, "wrote %s  (n,m)=(%d,%d) samples=%d hits=%d threads=%d streams=%d [%.1fs]\n",
                path, n, m, samples, nh, threads, streams, t)
        flush(io)
    end
    nothing
end

"""
    reproduce_check(; ref, seed, samples, threads, streams = threads, n = 8, m = 8, outdir) -> Bool

Regenerate one chunk and compare it byte for byte with the reference file `ref`.
"""
function reproduce_check(; ref::AbstractString, seed::Int, samples::Int, threads::Int,
                         streams::Int = threads, n::Int = 8, m::Int = 8,
                         outdir::AbstractString, io::IO = stdout)
    _check_threads(threads)
    isfile(ref) || error("reference file not found: $ref")
    path = joinpath(outdir, "c$(seed).tsv")
    t = @elapsed write_chunk(path, sample_chunk(samples, seed; n, m, streams))
    same = read(path) == read(ref)
    @printf(io, "regenerated %s  (seed=%d samples=%d threads=%d streams=%d (n,m)=(%d,%d)) [%.1fs]\n",
            path, seed, samples, threads, streams, n, m, t)
    println(io, "reference   ", ref)
    println(io, same ? "byte-identical: YES" : "byte-identical: NO")
    same
end
