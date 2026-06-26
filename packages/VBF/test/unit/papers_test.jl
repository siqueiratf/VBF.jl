@testitem "papers" begin
using Test

const PAPERS_DIR = normpath(joinpath(@__DIR__, "../../../../papers"))

function _has_test_target(dir::String)::Bool
    mf = joinpath(dir, "Makefile")
    isfile(mf) || return false
    any(startswith(ln, "test:") for ln in eachline(mf))
end

for folder in sort(readdir(PAPERS_DIR))
    dir = joinpath(PAPERS_DIR, folder)
    isdir(dir) || continue
    startswith(folder, ".") && continue

    @testset "$folder" begin
        if _has_test_target(dir)
            @test success(run(ignorestatus(`make -C $dir test`)))
        else
            @test_skip "$folder"
        end
    end
end

end
