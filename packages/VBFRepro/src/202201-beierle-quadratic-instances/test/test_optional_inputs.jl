include(joinpath(@__DIR__, "..", "dataset_validation.jl"))
include(joinpath(@__DIR__, "..", "proposition1.jl"))
@testset "unavailable and empty evidence cannot pass" begin
    empty_dir = mktempdir()
    for f in (dataset_counts, verify_apn, verify_quadratic)
        io = IOBuffer()
        r = f(io; input_dir = empty_dir, save_results = false)
        @test !r.all_ok
        @test r.status == :inconclusive
        @test all(row.status == :unavailable for row in r.results)
        @test !occursin("PASS", String(take!(io)))
    end
    r = ccz_distinctness(IOBuffer(); input_dir = empty_dir)
    @test r.status == :unavailable
    @test r.sample_size == 0
    write(joinpath(empty_dir, "apn_8bit.txt"), "")
    @test !verify_apn(IOBuffer(); input_dir = empty_dir).results[1].ok
    @test !verify_quadratic(IOBuffer(); input_dir = empty_dir).results[1].ok
end
