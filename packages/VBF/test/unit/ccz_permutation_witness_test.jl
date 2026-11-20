@testitem "ccz_permutation_witness" begin

using VBF
using Test

# Kim's quadratic APN function is CCZ-equivalent to Dillon's APN permutation.
@testset "Kim n=6: witness, permutation, CCZ back to Kim" begin
    F = kim_apn()
    r = ccz_permutation_search(F; count = true)
    @test r.status === :witness
    @test r.max_nonbent_subspace_dim == 3
    @test r.complementary_pairs == 256
    V, W = ccz_permutation_witness(F)
    Z = Set(walsh_zeroes(F))
    @test all(v -> v == 0 || v in Z, span_from_basis(V))
    @test all(v -> v == 0 || v in Z, span_from_basis(W))
    @test rank_f2(UInt32[V; W]; nbits = 12) == 12
    G = ccz_permutation_from_witness(F, V, W)
    @test is_permutation(G)
    @test differential_uniformity(G) == 2
    @test are_ccz_equivalent(G, F; on_inconclusive = :throw)
    @test are_ccz_equivalent(G, dillon_apn_permutation(); on_inconclusive = :throw)
end

@testset "permutations and odd dimension" begin
    @test ccz_permutation_search(dillon_apn_permutation()).status === :witness
    r = ccz_permutation_search(gold_apn(5, 1))   # x³ is a permutation for n = 5
    @test r.status === :witness
    G = ccz_permutation_from_witness(gold_apn(5, 1), r.witness...)
    @test is_permutation(G) && differential_uniformity(G) == 2
end

@testset "negatives agree with the unpruned pair enumeration" begin
    for F in (gold_apn(4, 1), gold_apn(6, 1))
        r = ccz_permutation_search(F; count = true)
        @test r.status === :none
        @test ccz_permutation_witness(F) === nothing
        @test !is_ccz_equivalent_to_permutation(F)
    end
    # Gold n=8: no 4-dim subspace of non-bent components (stage 1 certificate).
    r = ccz_permutation_search(gold_apn(8, 1))
    @test r.status === :none && r.certificate === :nonbent_dimension
    @test r.nonbent_count == 85 && r.max_nonbent_subspace_dim == 2
end

@testset "stage-1 counts match subspace_count_signature" begin
    F = kim_apn()
    mask = UInt32(63)
    nb = sort(unique(Int[z & mask for z in walsh_zeroes(F)]))
    sig = subspace_count_signature(nb, 6)
    r = ccz_permutation_search(F)
    @test sig[1:end-1] == r.subspace_counts && sig[end] == 0
end

@testset "budget and argument checks" begin
    r = ccz_permutation_search(kim_apn(); max_nodes = 1)
    @test r.status === :inconclusive && r.witness === nothing
    V, W = ccz_permutation_witness(kim_apn())
    @test_throws ArgumentError ccz_permutation_from_witness(kim_apn(), V, V)
end

end
