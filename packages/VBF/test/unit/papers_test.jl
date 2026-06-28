@testitem "papers" begin
using Test
using Base.CoreLogging: with_logger, NullLogger

if get(ENV, "RUN_PAPER_TESTS", "false") != "true"
    @test_skip "paper integration tests skipped (set RUN_PAPER_TESTS=true to enable)"
    return
end

const PAPERS_DIR = normpath(joinpath(@__DIR__, "../../../../papers"))

function _paper_runtests(dir::String)
    for sub in ("test", "tests")
        f = joinpath(dir, sub, "runtests.jl")
        isfile(f) && return f
    end
    return nothing
end

# Unwrap nested LoadErrors down to the underlying cause.
function _root_cause(e)
    while e isa LoadError
        e = e.error
    end
    return e
end

# A paper is *unavailable* (skip, not fail) when it cannot even load in the
# test environment — e.g. it `using`s a package that is not among the test
# dependencies (such as Nemo). Genuine test failures still surface.
_is_unavailable(e) = e isa ArgumentError && occursin("not found in current path", e.msg)

# Each paper's `runtests.jl` is executed in its own throwaway module so that
# paper-local names (helpers, `paper_report`, claim builders) never collide
# across papers, and in-process so the suite does not spawn ~40 fresh Julia
# subprocesses — the previous `make`-based runner exhausted memory and the OS
# OOM-killed paper builds under the parallel test workers.
for folder in sort(readdir(PAPERS_DIR))
    dir = joinpath(PAPERS_DIR, folder)
    isdir(dir) || continue
    startswith(folder, ".") && continue

    @testset "$folder" begin
        rt = _paper_runtests(dir)
        if rt === nothing
            @test_skip "$folder has no test runner"
        else
            mod = Module(Symbol("Paper_", replace(folder, r"[^A-Za-z0-9]" => "_")))
            Core.eval(mod, :(include(p) = Base.include(@__MODULE__, p)))
            try
                # Run with the paper folder as the working directory (matching the
                # old `make -C <dir>` behaviour) and silence the doc-redefinition
                # warnings emitted when claim files re-include `helpers.jl`.
                cd(dir) do
                    with_logger(NullLogger()) do
                        Base.include(mod, rt)
                    end
                end
            catch e
                cause = _root_cause(e)
                if _is_unavailable(cause)
                    @test_skip "$folder unavailable in test env: $(cause.msg)"
                else
                    rethrow(e)
                end
            end
        end
    end
end
end
