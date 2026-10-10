@testset "table1_invariants_test" begin
    include(joinpath(@__DIR__, "..", "table1_invariants.jl"))

    csv = joinpath(@__DIR__, "..", "inputs", "table1.csv")

    # parse_table1: correct number of rows and field types
    table = parse_table1(csv)
    @test length(table) == 61
    @test table[1].id == "6.1"
    @test table[1].dim == 6
    @test table[1].gamma_rank == 1102
    @test table[1].delta_rank == 94

    # table1_polynomial_to_sbox: known monomials should parse correctly
    row61 = table[1]   # x^{3} dim=6
    f = table1_polynomial_to_sbox(row61)
    @test f !== nothing
    @test differential_uniformity(f) == 2
    @test algebraic_degree(f) == 2

    # Rows with Tr_{n}(...) must return nothing (unparseable)
    tr_row = findfirst(r -> occursin("Tr", r.polynomial), table)
    @test table1_polynomial_to_sbox(table[tr_row]) === nothing

    # check_ranks: all dim <= 6 rows pass (3 rows, no Tr)
    r = check_ranks(devnull; max_dim = 6)
    @test r.all_ok
    @test r.checked == 3

    # check_walsh: all parseable rows pass
    r_w = check_walsh(devnull)
    @test r_w.all_ok
end
