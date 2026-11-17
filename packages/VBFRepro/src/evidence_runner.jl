# Run the test suite of one paper and record the result of each top-level test file.
# VBFRepro starts this script in a subprocess with the root project, like `make test`.
#
#   julia --project=ROOT evidence_runner.jl RUNTESTS OUT_TOML
#
# runtests.jl is evaluated in a fresh module whose `include` is replaced: each include made
# directly by runtests.jl gets its own record (test counts, time, error). Test sets defined
# in runtests.jl itself are recorded under "runtests.jl". Unlike `make test`, an error in one
# file does not stop the other files; the error is recorded and the outcome is "error".
using Test, TOML

const RUNTESTS = abspath(ARGS[1])
const OUT = ARGS[2]
const TESTDIR = dirname(RUNTESTS)
const PAPERDIR = dirname(TESTDIR)
const TOP = Test.DefaultTestSet("paper")
const DEPTH = Ref(0)
const FILES = Dict{String,Any}[]

"Pass, fail, error and broken counts of a list of results, nested test sets included."
function counts(results)
    c = Dict("pass" => 0, "fail" => 0, "error" => 0, "broken" => 0, "testsets" => 0)
    for r in results
        if r isa Test.AbstractTestSet
            c["testsets"] += 1
            t = Test.get_test_counts(r)
            c["pass"] += t.passes + t.cumulative_passes
            c["fail"] += t.fails + t.cumulative_fails
            c["error"] += t.errors + t.cumulative_errors
            c["broken"] += t.broken + t.cumulative_broken
        elseif r isa Test.Pass; c["pass"] += 1
        elseif r isa Test.Fail; c["fail"] += 1
        elseif r isa Test.Error; c["error"] += 1
        elseif r isa Test.Broken; c["broken"] += 1
        end
    end
    c
end

outcome(c, err) = err !== nothing || c["error"] > 0 ? "error" : c["fail"] > 0 ? "failed" : "passed"

const M = Module(:PaperTests)
function hooked_include(p::AbstractString)
    DEPTH[] += 1
    if DEPTH[] > 1
        try
            return Base.include(M, p)
        finally
            DEPTH[] -= 1
        end
    end
    file = relpath(normpath(isabspath(p) ? p : joinpath(TESTDIR, p)), PAPERDIR)
    n0 = length(TOP.results); t0 = time(); err = nothing
    try
        Base.include(M, p)
    catch e
        err = sprint(showerror, e)
    finally
        DEPTH[] -= 1
    end
    c = counts(TOP.results[n0+1:end])
    push!(FILES, merge(c, Dict("file" => file, "elapsed_seconds" => round(time() - t0; digits = 3),
        "outcome" => outcome(c, err), "error_message" => something(err, ""))))
    nothing
end
Core.eval(M, :(include(p::AbstractString) = $hooked_include(p)))
Core.eval(M, :(using Test))

t0 = time(); toperr = nothing
function run_all()
    try
        Base.include(M, RUNTESTS)
    catch e
        global toperr = sprint(showerror, e)
    end
end
# Make TOP the current test set: a scoped value in newer Test versions, a stack in older ones.
if isdefined(Test, Symbol("@with_testset"))
    @eval Test.@with_testset $TOP run_all()
else
    Test.push_testset(TOP); run_all(); Test.pop_testset()
end
# Results that no include produced (test sets of runtests.jl itself) are the difference.
c_all = counts(TOP.results)
c_files = Dict(k => sum(f[k] for f in FILES; init = 0) for k in ("pass", "fail", "error", "broken", "testsets"))
rest = Dict(k => c_all[k] - c_files[k] for k in keys(c_files))
if any(v -> v > 0, values(rest)) || toperr !== nothing
    push!(FILES, merge(rest, Dict("file" => relpath(RUNTESTS, PAPERDIR), "elapsed_seconds" => 0.0,
        "outcome" => outcome(rest, toperr), "error_message" => something(toperr, ""))))
end
total = merge(c_all, Dict("elapsed_seconds" => round(time() - t0; digits = 3),
    "outcome" => any(f -> f["outcome"] == "error", FILES) ? "error" :
                 any(f -> f["outcome"] == "failed", FILES) ? "failed" : "passed"))
open(io -> TOML.print(io, Dict("total" => total, "files" => FILES); sorted = true), OUT, "w")
exit(total["outcome"] == "passed" ? 0 : 1)
