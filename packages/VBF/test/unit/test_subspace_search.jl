using VBF
using Test

@testset "extract_linear_subspaces: trivial cases" begin
    # dim = 0 → exactly one subspace ({0}), represented by an empty basis.
    @test extract_linear_subspaces(UInt32[1, 2], 0; max_bits = 2) == [UInt32[]]
    # Empty z and dim > 0 → no subspaces.
    @test isempty(extract_linear_subspaces(UInt32[], 1))
    # Negative dim → error.
    @test_throws ArgumentError extract_linear_subspaces(UInt32[1], -1)
end

@testset "extract_linear_subspaces: F₂² closed-form counts" begin
    # All nonzero elements of F₂² = {1, 2, 3}. 1-dim subspaces: 3 (one per
    # nonzero); 2-dim subspaces: 1 (the whole space).
    z = UInt32[1, 2, 3]
    @test length(extract_linear_subspaces(z, 1; max_bits = 2)) == 3
    @test length(extract_linear_subspaces(z, 2; max_bits = 2)) == 1
    # The unique 2-dim basis in GJB form is [2, 1] (high-bit first, then low).
    @test extract_linear_subspaces(z, 2; max_bits = 2) == [UInt32[2, 1]]
end

@testset "extract_linear_subspaces: F₂³ closed-form counts" begin
    # z = all nonzero of F₂³ = {1..7}. Number of k-dim subspaces of F₂³:
    # 1-dim: 7 (one per nonzero); 2-dim: 7; 3-dim: 1 (Gaussian binomial coeffs).
    z = UInt32[1, 2, 3, 4, 5, 6, 7]
    @test length(extract_linear_subspaces(z, 1; max_bits = 3)) == 7
    @test length(extract_linear_subspaces(z, 2; max_bits = 3)) == 7
    @test length(extract_linear_subspaces(z, 3; max_bits = 3)) == 1
end

@testset "extract_linear_subspaces: GJB invariants on every basis" begin
    # Basis must have strictly decreasing leading bits and pairwise-cleared
    # leading-bit columns.
    z = UInt32[1, 2, 3, 4, 5, 6, 7]
    for basis in extract_linear_subspaces(z, 3; max_bits = 3)
        msbs = [VBF._leading_bit_pos(b) for b in basis]
        @test issorted(msbs; rev = true)
        @test allunique(msbs)
        # Pairwise GJB: bit p_j of basis[i] is 0 for i ≠ j.
        for i in eachindex(basis), j in eachindex(basis)
            i == j && continue
            p_j = msbs[j]
            @test (basis[i] >> p_j) & UInt32(1) == 0
        end
    end
end

@testset "extract_linear_subspaces: every subspace ⊆ z ∪ {0}" begin
    F = load_literature_sbox("PRESENT")
    Z = walsh_zeroes(F)
    bases = extract_linear_subspaces(Z, 4; max_bits = 8)
    @test !isempty(bases)
    for basis in bases
        span = span_from_basis(basis)
        @test length(span) == 16   # 2^4
        for v in span
            v == 0 && continue
            @test v in Z
        end
    end
end

@testset "extract_linear_subspaces: each subspace counted once" begin
    # span_from_basis(basis) should give the same set across all returned
    # bases — but each set should be unique.
    F = load_literature_sbox("PRESENT")
    Z = walsh_zeroes(F)
    bases = extract_linear_subspaces(Z, 4; max_bits = 8)
    spans = [Set(span_from_basis(b)) for b in bases]
    @test length(unique(spans)) == length(spans)
end

@testset "extract_linear_subspaces: CCZ-invariance under inv(F) at n=4" begin
    # The number of n-dim subspaces of Z(F) is a CCZ-invariant. inv(F) is
    # CCZ-equivalent to F. So the counts must match.
    for name in ("PRESENT", "GIFT", "SKINNY_4", "Midori_Sb0")
        F = load_literature_sbox(name)
        N = inputbits(F)
        is_permutation(F) || continue
        F_inv = inv(F)
        Z_F = walsh_zeroes(F)
        Z_Finv = walsh_zeroes(F_inv)
        n_F = length(extract_linear_subspaces(Z_F, N; max_bits = 2N))
        n_Finv = length(extract_linear_subspaces(Z_Finv, N; max_bits = 2N))
        @test n_F == n_Finv
    end
end

@testset "span_from_basis: simple cases" begin
    @test span_from_basis(UInt32[]) == UInt32[0]
    @test sort(span_from_basis(UInt32[2, 1])) == UInt32[0, 1, 2, 3]
    @test sort(span_from_basis(UInt32[4, 2, 1])) == UInt32[0, 1, 2, 3, 4, 5, 6, 7]
end
