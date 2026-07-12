@testset "proposition4_test" begin
    include(joinpath(@__DIR__, "..", "proposition4.jl"))

    db = load_catalog()

    # Proposition 4: Walsh formula == direct k-tuple enumeration.
    # ea_multiplicities requires even k ≥ 4; verify for k=4.
    for n in [5, 6]
        F = gold_x3(n)
        direct = ea_multiplicities(F, 4)
        walsh = sigma_multiplicities_vec(F; k = 4)
        @test direct == walsh
    end

    # Also holds for a non-Gold function (reprs6_1 at n=6)
    F6 = load_sbox(db, "reprs6_1")
    @test ea_multiplicities(F6, 4) == sigma_multiplicities_vec(F6; k = 4)

    # Sum of M_k^F(0,s) over all s = #{k-tuples summing to 0} = (2^n)^{k-1}
    F5 = gold_x3(5)
    vec5 = sigma_multiplicities_vec(F5; k = 4)
    @test sum(vec5) == (1 << 5)^3   # = 32^3 = 32768
end
