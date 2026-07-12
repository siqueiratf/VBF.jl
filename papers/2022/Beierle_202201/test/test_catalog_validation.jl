@testset "catalog_validation_test" begin
    include(joinpath(@__DIR__, "..", "catalog_validation.jl"))

    # catalog_cross_check: run with a tiny sample; should not error.
    # If the corpus is present, n8_length_ok and n8_sample_ok are tested.
    # If absent, n8_found == false is accepted (graceful handling).
    r = catalog_cross_check(devnull; sample_size = 5)
    if r.n8_found
        @test r.n8_length_ok
        @test r.n8_sample_ok
    else
        @test r.n8_found == false
    end
end
