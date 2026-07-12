@testset "lemma3_test" begin
    include(joinpath(@__DIR__, "..", "lemma3.jl"))

    # Lemma 3 (tex:244): for gcd(m,i)=1 and S ∉ {0,1}, P(N) has exactly the four
    # roots {0, 1, S, S+1}. Exhaustive over every S and every N in GF(2^m).
    for m in (5, 7), i in 1:(m - 1)
        gcd(i, m) == 1 || continue
        @test lemma3_holds(m, i)
    end

    # Non-vacuity: the root set is exactly four elements, not "at least four" —
    # a P that vanished identically would trivially contain {0,1,S,S+1}.
    for S in 2:31
        r = lemma3_roots(5, 1, S)
        @test length(r) == 4
        @test Set(r) == Set([0, 1, S, S ⊻ 1])
    end
    # The four roots really are four distinct field elements (S ∉ {0,1} ⇒ S+1 ∉ {0,1}).
    @test length(Set(lemma3_roots(5, 2, 7))) == 4

    # And P is a genuine linearised polynomial with non-zero coefficients: it does
    # NOT vanish on the whole field (2^5 = 32 elements, only 4 are roots).
    @test length(lemma3_roots(5, 1, 3)) < 32

    # Hypothesis guard: gcd(m,i) = 1 is required
    @test_throws ErrorException lemma3_holds(6, 2)
end
