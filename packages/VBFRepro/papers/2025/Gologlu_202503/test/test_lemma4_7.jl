@testset "lemma4_7_test" begin
    include(joinpath(@__DIR__, "..", "lemma4_7.jl"))

    io = IOBuffer()
    r = lemma4_7_report(io; m_values = (3, 4), exhaustive_m2 = true)
    @test r.dim_ok
    @test r.sylow_ok
    @test r.containment_ok
    @test r.normalizer_containment
    @test !r.transvection_centralises      # the negative control genuinely fails
    @test r.all_ok

    # Lemma 4.7(b): dim_F2 C_GL(M) = 4m = dim_F2 of the 2x2 matrices over M
    for m in (3, 4, 5)
        fld = BiField(m)
        g = primitive_element(fld)
        @test centralizer_dimension(fld, g) == 4m
        gp = sylow_p_generator(fld)
        @test gp !== nothing
        @test centralizer_dimension(fld, gp) == 4m       # C(M_P) = C(M)
    end

    # Exhaustive at m = 2: |C| = |GL(2,F4)| = 180, |N| = |GammaL(2,F4)| = 360.
    # These are computed by enumerating all 20160 elements of GL(4,2), NOT read
    # from a table.
    ex = r.exhaustive_m2
    @test ex.gl_order == 20160
    @test ex.centralizer == 180
    @test ex.normalizer == 360
    @test ex.normalizer == 2 * ex.centralizer          # index = |Gal(F4/F2)| = 2

    # m = 6 has no primitive prime divisor (Zsygmondy) — the reason every
    # equivalence theorem in the paper excludes it.
    @test primitive_prime_divisor(6) === nothing
    @test primitive_prime_divisor(5) == 31
    @test sylow_p_generator(BiField(6)) === nothing
end
