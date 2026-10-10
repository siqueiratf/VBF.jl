using Test
using VBF

# The paper's datasets (`inputs/apn_*bit.txt`, `inputs/table1.csv`) are large and
# git-ignored; a fresh checkout will not have them. The dataset-dependent test
# files are skipped when the inputs are absent.
inputs_present = isfile(joinpath(@__DIR__, "..", "inputs", "apn_8bit.txt"))

include("test_dataset_validation.jl")   # self-guards on missing inputs
if inputs_present
    include("test_table1_invariants.jl")
    include("test_proposition1.jl")
    include("test_catalog_validation.jl")
else
    @testset "dataset-dependent tests (inputs absent)" begin
        @test_skip "packages/VBFRepro/papers/Beierle_202201/inputs/* not present"
    end
end
include("test_algorithm1.jl")
include("test_lemma4.jl")
include("test_lemma5.jl")
