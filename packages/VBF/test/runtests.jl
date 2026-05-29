using VBF
using Test

include("helpers.jl")    # shared random_function_sbox / random_permutation_sbox

const UNIT_DIR = joinpath(@__DIR__, "unit")
const PROPERTY_DIR = joinpath(@__DIR__, "property")

# Each tier's tests live in its own @testset for legible failure reports.
@testset "VBF.jl" begin
    @testset "unit" begin
        if isdir(UNIT_DIR)
            for f in sort(readdir(UNIT_DIR))
                startswith(f, "test_") && endswith(f, ".jl") || continue
                @testset "$f" begin
                    include(joinpath(UNIT_DIR, f))
                end
            end
        end
    end
    @testset "property" begin
        if isdir(PROPERTY_DIR)
            for f in sort(readdir(PROPERTY_DIR))
                startswith(f, "test_prop_") && endswith(f, ".jl") || continue
                @testset "$f" begin
                    include(joinpath(PROPERTY_DIR, f))
                end
            end
        end
    end
end
