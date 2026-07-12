@testset "table1_test" begin
    include(joinpath(@__DIR__, "..", "table1.jl"))

    r = table1_check()
    @test r.all_apn
    @test r.all_distinct
    @test r.n_entries == 4  # 3 Gold + 1 new

    # n=8 reference function check (Section VII-A)
    include(joinpath(@__DIR__, "..", "section7.jl"))
    rn8 = section7_check_n8_reference()
    @test rn8.is_apn
end
