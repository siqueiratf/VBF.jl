@testset "section4_test" begin
    include(joinpath(@__DIR__, "..", "section4.jl"))

    # Cyclic T for n=3: no unknowns, is APN
    M3, known3 = kalgin_T(3)
    @test all(known3)
    @test is_qam(M3)

    # Verify T[i,j] = 2^{i+j-3} formula for n=3
    @test M3[1, 2] == 1   # e_1 = 2^0
    @test M3[1, 3] == 2   # e_2 = 2^1
    @test M3[2, 3] == 4   # e_3 = 2^2
    @test M3[2, 1] == M3[1, 2]  # symmetric

    # Cyclic T for n=4: exactly 1 unknown position
    M4, known4 = kalgin_T(4)
    upos4 = unknown_positions(known4)
    @test length(upos4) == 1
    @test upos4[1] == (3, 4)  # only (3,4) has i+j=7 > n+2=6

    # Cyclic T for n=5: exactly 2 unknowns
    M5, known5 = kalgin_T(5)
    upos5 = unknown_positions(known5)
    @test length(upos5) == 2

    # Modified T for n=5 (remove e_5 subdiag at i+j=7): adds (2,5),(3,4) → 4 total
    M5m, known5m = kalgin_T(5; remove_e_n = true)
    upos5m = unknown_positions(known5m)
    @test length(upos5m) == 4

    # Modified T for n=7: 9 unknowns (3 standard + 3 from subdiag + 3 from higher)
    # Standard unknowns (i+j > 9): (3,7),(4,6),(4,7),(5,6),(5,7),(6,7) = 6
    # Removed subdiag (i+j = 9 = n+2): (2,7),(3,6),(4,5) = 3 → total 9
    M7m, known7m = kalgin_T(7; remove_e_n = true)
    upos7m = unknown_positions(known7m)
    @test length(upos7m) == 9

    # Cyclic search n=4: finds at least 1 APN function
    fns4 = cyclic_apn_search(4; limit = 5)
    @test length(fns4) >= 1
    for f in fns4
        @test differential_uniformity(f) == 2
    end

    # New n=7 function from paper
    F7 = new_apn_function_n7()
    @test F7 isa SBox{7}
    @test differential_uniformity(F7) == 2
    @test algebraic_degree(F7) == 2

    # F7 is CCZ-distinct from Gold n=7
    g7 = gold_apn(7)
    @test apn_ea_mugshot(F7) != apn_ea_mugshot(g7)

    # Round-trip: QAM of new function is a QAM
    @test is_qam(quadratic_apn_matrix(F7))
end
