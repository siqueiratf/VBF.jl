@testset "section6_test" begin
    include(joinpath(@__DIR__, "..", "section6.jl"))

    # Theorem 7 for n=5: x^{-1} = x^30 has exactly 2 Walsh-zero 5-dim subspaces
    r5 = theorem7_verify(5; io = devnull)
    @test r5.is_perm
    @test r5.is_involution
    @test r5.n_subsp == 2

    # Theorem 7 for n=6: x^{-1} = x^62 has exactly 2 Walsh-zero 6-dim subspaces
    r6 = theorem7_verify(6; io = devnull)
    @test r6.is_perm
    @test r6.is_involution
    @test r6.n_subsp == 2

    # Theorem 8 for n=5: x^15 (non-Gold APN) has ≤2 Walsh-zero 5-dim subspaces
    r8 = theorem8_verify_n5(; io = devnull)
    @test r8.n_subsp <= 2
    # 15^{-1} mod 31 = 29 is in the same cyclotomic coset as 15 → linearly equiv
    @test r8.in_same_coset
end
