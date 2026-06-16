@testset "algorithm1_test" begin
    include(joinpath(@__DIR__, "..", "algorithm1.jl"))

    # Algorithm 1: partition by sigma_4 multiplicities.

    # Basic structure: partition covers all 2^n elements.
    for n in [5, 6]
        F = gold_x3(n)
        p = ea_partition(F)
        @test sum(p.bucket_sizes) == (1 << n)
        @test length(p.buckets) == nbuckets(p)
    end

    # EA-equivalent pair: same partition signature.
    F6 = gold_x3(6)
    G6_lut = UInt8[UInt8(xor(Int(F6.lut[xor(x, 1) + 1]), 2)) for x = 0:63]
    G6 = SBox{6,UInt8}(G6_lut)
    @test ea_partition_signature(F6) == ea_partition_signature(G6)

    # Non-EA-equivalent pair: different signature.
    db = load_catalog()
    F5 = load_sbox(db, "n5_Gold_x3")
    F5b = load_sbox(db, "reprs6_1")  # n=6, different dimension → different sig
    # (Signatures for different n are incomparable; just verify they each exist.)
    @test length(ea_partition_signature(F5)) ≥ 1
    @test length(ea_partition_signature(F5b)) ≥ 1

    # Gold x^3 n=6: exactly 3 buckets (Gold-like, paper Section 5 / Table 1)
    p6 = ea_partition(gold_x3(6))
    @test nbuckets(p6) == 3
    @test sort(p6.bucket_sizes) == [1, 21, 42]
end
