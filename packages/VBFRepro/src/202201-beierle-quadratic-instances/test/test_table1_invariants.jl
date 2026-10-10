include(joinpath(@__DIR__, "..", "table1_invariants.jl"))
@testset "Table 1 unsupported reconstruction is explicit" begin
    io = IOBuffer()
    result = table1_status(io)
    @test result.status == :unsupported
    @test !result.all_ok
    text = String(take!(io))
    @test occursin("UNSUPPORTED", text)
    @test !occursin("PASS", text)
end
