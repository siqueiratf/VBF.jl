@testset "lemma2_1_test" begin
    include(joinpath(@__DIR__, "..", "lemma2_1.jl"))

    m = 5
    n = 2m
    modulus = primitive_polynomial(n)
    b = 2
    c = gf_pow(b, 3, n; modulus)  # c = b³
    s = 3

    # Trivial solutions x=0 and x=u always satisfy B_s(x,u)=0
    for u in [1, 3, 7, 31]
        P, Q = bilinear_components(0, u, m, s, b, c; modulus)
        @test P == 0
        @test Q == 0
        P, Q = bilinear_components(u, u, m, s, b, c; modulus)
        @test P == 0
        @test Q == 0
    end

    # Symmetry: B_s(x,u) = B_s(u,x) → P and Q are symmetric in x,u
    for (x, u) in [(3, 7), (15, 31), (5, 9)]
        Pxu, Qxu = bilinear_components(x, u, m, s, b, c; modulus)
        Pux, Qux = bilinear_components(u, x, m, s, b, c; modulus)
        @test Pxu == Pux
        @test Qxu == Qux
    end

    # Both P and Q must lie in F_{2^m}: verify y^{2^m} = y (subfield condition)
    for (x, u) in [(3, 7), (5, 11)]
        P, Q = bilinear_components(x, u, m, s, b, c; modulus)
        @test gf_pow(P, 1 << m, n; modulus) == P  # P ∈ F_{2^m}
        @test gf_pow(Q, 1 << m, n; modulus) == Q  # Q ∈ F_{2^m}
    end

    # Degenerate case c=0: B_s(x,u)=0 reduces to Q=0 always, so APN fails
    is_apn_c0, _ = lemma2_1_is_apn(m, s, b, 0; modulus, limit = 10)
    @test !is_apn_c0

    # F15 at n=10 (m=5) passes lemma2_1 with a bounded check
    is_apn, _ = lemma2_1_is_apn(m, s, b, c; modulus, limit = 50)
    @test is_apn

    # lemma2_1_report: agreement between lemma and differential_uniformity
    r = lemma2_1_report(devnull; m, a = 2, b, limit = 50)
    @test r.du == 2
    @test r.du_apn
    @test r.agree
end
