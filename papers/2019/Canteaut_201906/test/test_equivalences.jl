@testset "equivalences_test" begin
    include(joinpath(@__DIR__, "..", "equivalences.jl"))

    r3 = equivalences_build(3, 1)
    @test r3.frob_ok
    @test r3.bprime_ok
    @test r3.mirror_ok
    @test r3.n_frob == 49      # 7 α × 7 β
    @test r3.n_bprime == 42    # 6 α (α≠1) × 7 β

    r5 = equivalences_build(5, 1)
    @test r5.frob_ok
    @test r5.bprime_ok
    @test r5.mirror_ok
    @test r5.n_frob == 961     # 31 α × 31 β
    @test r5.n_bprime == 930   # 30 α × 31 β

    # i=2 spot check (gcd(2,5)=1)
    r5b = equivalences_build(5, 2)
    @test r5b.frob_ok
    @test r5b.bprime_ok
    @test r5b.mirror_ok
end
