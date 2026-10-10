using VBF
# Implements the threaded Knuth sampler with an exact last extension step
# Study: census of quadratic APN functions on F_2^8 (data/apn/archive/census)
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
#       (e, sols) = VBF.QuadraticAPNTree.count_completions(C, n-1, m; want_solution = true)
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

isdefined(@__MODULE__, :encode_coeffs) || include(joinpath(@__DIR__, "helpers.jl"))

using Random
using Printf
using Base.Threads
using VBFSearch: DiscoveryStore, DiscoveryEvidence

using VBF.QuadraticAPNTree: probe_to_penultimate

"""
    sample_line(rng, i, n, m) -> String

One sample: the TSV line `i<TAB>logw<TAB>e<TAB>coeffs` (coeffs only when `e > 0`).
"""
function sample_line(rng, i::Int, n::Int, m::Int)
    logw, C = probe_to_penultimate(rng, n, m)
    isfinite(logw) || return "$(i)\t-Inf\t0\t"
    e, sols = VBF.QuadraticAPNTree.count_completions(C, n - 1, m; want_solution = true)
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
                      threads::Int, streams::Int=threads, n::Int=8, m::Int=8, io::IO=stdout)
    _check_threads(threads)
    nchunks>=0 && samples>0 && streams>0 || throw(ArgumentError("invalid sampling limits"))
    mkpath(outdir)
    identity=Dict("n"=>n,"m"=>m,"samples"=>samples,"streams"=>streams,
        "julia_version"=>string(VERSION),"vbf_sha256"=>DiscoveryEvidence.solver_fingerprint(),
        "sampler_sha256"=>DiscoveryEvidence.filehash(@__FILE__),
        "helpers_sha256"=>DiscoveryEvidence.filehash(joinpath(@__DIR__,"helpers.jl")))
    ledgerpath=joinpath(outdir,"sampling.toml")
    # Share the existing exclusive writer lease convention; the chunk manifest is small.
    lease=open(joinpath(outdir,"writer.lock"),"a+")
    ccall(:flock,Cint,(Cint,Cint),fd(lease),6)==0 || (close(lease);error("another sampler owns this output"))
    try
        !isfile(ledgerpath) && any(f->endswith(f,".tsv"),readdir(outdir)) && error("existing samples have no configuration manifest; use a fresh directory")
        ledger=isfile(ledgerpath) ? TOML.parsefile(ledgerpath) : Dict("identity"=>identity,"chunks"=>Dict{String,Any}())
        ledger["identity"]==identity || error("sampling configuration or implementation changed; use a fresh directory")
        DiscoveryStore.atomic_toml(ledgerpath,ledger)
        for seed in first_seed:first_seed+nchunks-1
            name="c$(seed).tsv";path=joinpath(outdir,name)
            if haskey(ledger["chunks"],name)
                isfile(path) && DiscoveryEvidence.filehash(path)==ledger["chunks"][name] || error("completed chunk changed: $path")
                println(io,"skip ",path," (configuration and digest match)");continue
            end
            # A crash between the chunk rename and manifest update repeats only that chunk.
            t=@elapsed lines=sample_chunk(samples,seed;n,m,streams)
            write_chunk(path,lines)
            ledger["chunks"][name]=DiscoveryEvidence.filehash(path)
            DiscoveryStore.atomic_toml(ledgerpath,ledger)
            @printf(io,"wrote %s (n,m)=(%d,%d) samples=%d streams=%d [%.1fs]\n",path,n,m,samples,streams,t)
            flush(io)
        end
    finally
        close(lease)
    end
    nothing
end
