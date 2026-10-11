using VBF
# Implements small-n validation of the estimators against exact masses
# Study: census of quadratic APN functions on F_2^8 (packages/VBFCatalog/data/research/archive/census)
#
# Math:
#   For n = 6, 7 the mass M(n) = T(n,n)/|GL(n,2)|^2 = sum 1/|Stab| is known exactly from the
#   catalog (exact_masses.jl):  M(6) = 7 + 2/5 + 1/7 + 1/14 + 1/63 + 1/378 = 7.632804,
#   M(7) = 473 + 12/7 + 3/889 = 474.7177.  An unbiased estimator must give z = (M_hat - M)/SE
#   of order 1.
#   (6,6): plain Knuth (VBF.QuadraticAPNTree.probe to n variables, no exact last step).
#   (7,7): the production pipeline (sampler.jl: Knuth to n-1 variables + FL3 exact last step).
#
# Pseudocode:
#   1. (6,6): lw_t = probe(Xoshiro(seed), 6, 6) for t = 1..samples66; report mass, SE, z.
#   2. (7,7): either read existing sample files (data77) or run sample_chunk(samples77, seed;
#      n = 7, m = 7) on the current threads and write results/validate/; report mass, SE, z.
# VBF API used: none

isdefined(@__MODULE__, :run_sampling) || include(joinpath(@__DIR__, "sampler.jl"))

"""
    validate_plain(n, m; samples, seed, io) -> NamedTuple

Plain Knuth estimate of the (n,m) mass with `samples` single-threaded probes.
"""
function validate_plain(n::Int, m::Int; samples::Int, seed::Int, io::IO = stdout)
    rng = Xoshiro(seed)
    t = @elapsed lw = [VBF.QuadraticAPNTree.probe(rng, n, m)[1] for _ in 1:samples]
    r = mass_estimate(lw, n, m)
    _print_validation(io, "plain Knuth", n, m, r, t)
end

"""
    validate_pipeline(n, m; samples, seed, data = "", io) -> NamedTuple

Estimate of the (n,m) mass with the production pipeline. With `data` non-empty, read
those sample files; else sample `samples` lines on the current threads.
"""
function validate_pipeline(n::Int, m::Int; samples::Int, seed::Int, data::AbstractString = "",
                           io::IO = stdout)
    if isempty(data)
        path = joinpath(results_dir("validate"), "s$(n)$(m)_seed$(seed)_N$(samples)_t$(nthreads()).tsv")
        t = @elapsed write_chunk(path, sample_chunk(samples, seed; n, m))
        files = [path]
    else
        t = 0.0
        files = expand_paths(data)
    end
    lw, _ = read_samples(files)
    r = mass_estimate(lw, n, m)
    println(io, "  data: ", join(files, ", "))
    _print_validation(io, "Knuth + exact last step", n, m, r, t)
end

function _print_validation(io, label, n, m, r, t)
    ex = Float64(EXACT_MASS[(n, m)])
    z = (r.mass - ex) / r.se
    @printf(io, "  (%d,%d) %-24s samples=%d hits=%d  mass=%.6g ± %.3g (%.2f%%)  exact=%.6f  z=%+.2f  [%.1fs]\n",
            n, m, label, r.samples, r.hits, r.mass, r.se, 100r.se / r.mass, ex, z, t)
    (method = label, samples = r.samples, hits = r.hits, mass = r.mass, se = r.se,
     exact = ex, exact_rational = EXACT_MASS[(n, m)], z = z, pass = abs(z) < 4, seconds = t)
end

"Run both validations and return their results."
function validate_report(; samples66::Int, samples77::Int, seed::Int, data77::AbstractString = "",
                         io::IO = stdout)
    print_section("Validation against exact masses", io)
    v66 = validate_plain(6, 6; samples = samples66, seed, io)
    v77 = validate_pipeline(7, 7; samples = samples77, seed, data = data77, io)
    ok = v66.pass && v77.pass
    println(io, ok ? "  validation: PASS (|z| < 4)" : "  validation: FAIL (|z| >= 4)")
    Dict("n6m6" => v66, "n7m7" => v77, "pass" => ok)
end
