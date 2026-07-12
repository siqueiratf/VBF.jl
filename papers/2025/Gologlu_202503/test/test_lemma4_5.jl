@testset "lemma4_5_test" begin
    include(joinpath(@__DIR__, "..", "lemma4_5.jl"))

    io = IOBuffer()
    r = lemma4_5_report(io; m_values = (3, 4))
    @test r.automorphism_ok
    @test r.order_ok
    @test r.checked > 0
    @test r.all_ok

    fld = BiField(5)
    F = family_f1(fld, 1)

    # positive: every a ∈ M^× gives a graph automorphism, so |Z^{(q,r)}| = 2^m − 1
    @test all(a -> z_qr_is_automorphism(F, a), 1:31)
    @test z_qr_order(F) == 31

    # negative 1: the wrong exponent in the group element breaks it for almost all a
    wrong = count(a -> z_qr_is_automorphism(F, a; ll = lexp(F) + 1), 1:31)
    @test wrong < 31
    @test r.wrong_exponent_survivors < 31

    # negative 2: F + (x², 0) is not bihomogeneous and loses the automorphism
    P = PerturbedPair(F)
    surv = count(a -> perturbed_z_is_automorphism(P, a), 1:31)
    @test surv < 31
    @test perturbed_z_is_automorphism(P, 1)      # a = 1 is the identity: still true
end
