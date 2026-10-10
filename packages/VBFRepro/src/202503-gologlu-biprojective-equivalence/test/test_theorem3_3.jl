@testset "theorem3_3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3_3.jl"))

    io = IOBuffer()
    r = theorem3_3_report(io; m = 6, ddt_sample = 2)

    @test r.n == 12
    @test r.admissible == 504              # 2 k-values x 42 non-cubes x 7 a, minus 84
    @test isempty(r.not_apn)               # every admissible F4 instance is APN
    @test r.ddt_ok                         # confirmed on the full 2^12 DDT
    @test r.quadratic
    @test r.all_ok

    fld = BiField(6)
    # positive: an admissible instance is APN with differential uniformity 2
    F = family_f4(fld, 1, 2, 1)
    @test f4_valid(fld, 1, 2, 1)
    @test biprojective_is_apn(F)
    S = bipair_sbox(F)
    @test differential_uniformity(S) == 2
    @test algebraic_degree(S) == 2
    @test !is_permutation(S)               # F4 is 3-to-1, hence never a permutation

    # negative control 1: B must be a non-cube
    v = f4_condition_violations(fld, 1)
    Bc, ac = first(v.cube_B)
    @test gf_is_dth_power(Bc, 3, 6; modulus = fld.modulus)
    @test !f4_valid(fld, 1, Bc, ac)
    @test !biprojective_is_apn(family_f4(fld, 1, Bc, ac))
    @test differential_uniformity(bipair_sbox(family_f4(fld, 1, Bc, ac))) > 2

    # negative control 2: B^{q+r} ≠ a^{q+1} is required
    @test !isempty(v.norm_eq)
    Bn, an = first(v.norm_eq)
    @test !gf_is_dth_power(Bn, 3, 6; modulus = fld.modulus)   # B IS a non-cube here…
    @test !f4_valid(fld, 1, Bn, an)                           # …but the norm condition fails
    @test !biprojective_is_apn(family_f4(fld, 1, Bn, an))
    @test differential_uniformity(bipair_sbox(family_f4(fld, 1, Bn, an))) > 2

    # m = 2 admits no F4 at all (there B^{q+r} = a^{q+1} = 1 always)
    @test isempty(f4_parameters(BiField(2)))
    # m must be ≡ 2 (mod 4)
    @test isempty(f4_parameters(BiField(4)))
end
