@testitem "ccz_graph_primitives" begin
using VBFCatalog
using VBF
using Test
using Random

@testset "ccz_block_decomposition: identity and swap" begin
    # Identity on F₂^{2n}: A = B = id, C = D = 0.
    Lid = identity_linear_map(8)
    bd = ccz_block_decomposition(Lid)
    @test bd.A == identity_linear_map(4)
    @test bd.B == identity_linear_map(4)
    @test bd.C == zero_linear_map(4)
    @test bd.D == zero_linear_map(4)
    @test_throws ArgumentError ccz_block_decomposition(identity_linear_map(5))  # odd M
end

@testset "ea_mapping: trivial components give identity" begin
    em = ea_mapping(identity_linear_map(4), identity_linear_map(4), zero_linear_map(4))
    @test em == identity_linear_map(8)
end

@testset "ea_mapping ↔ block decomposition round-trip" begin
    # ea_mapping(A=id, B, C=0) places B in the high blocks; decomposing
    # should recover B. Use a concrete invertible B.
    B = F2LinearMap{4, UInt8}(UInt8[0x2, 0x4, 0x8, 0x1])  # cyclic shift
    em = ea_mapping(identity_linear_map(4), B, zero_linear_map(4))
    bd = ccz_block_decomposition(em)
    # The block carrying B is the high half of the first n columns (= C-slot
    # in the [A D; C B] layout maps B(eᵢ) into low bits of first n cols → A).
    @test bd.A == B
end

@testset "graph_image_by: identity recovers the graph; swap gives inv(F)" begin
    F = load_literature_sbox("PRESENT")
    g = FunctionGraph(F)
    @test graph_image_by(g, identity_linear_map(8)).packed == g.packed
    # Swap map (x,y)->(y,x): image graph = graph(inv(F)).
    N, T = 4, UInt8
    swap_cols = T[T(1) << ((i + N) % (2N)) for i in 0:(2N - 1)]
    L_swap = F2LinearMap{2N, T}(swap_cols)
    g_inv = graph_image_by(g, L_swap)
    @test FunctionGraph(inv(F)).packed == g_inv.packed
end

@testset "graph_xor_equivalence: self gives {0}; translate detected" begin
    F = load_literature_sbox("PRESENT")
    g = FunctionGraph(F)
    offs = graph_xor_equivalence(g, g)
    @test UInt32(0) in offs
    # Translate the whole graph by a fixed offset; it must be detected.
    o = UInt32(0b10110010)
    g2 = FunctionGraph{4}(UInt32[p ⊻ o for p in g.packed])
    @test o in graph_xor_equivalence(g, g2)
end

@testset "code matrices: shapes + CCZ-row" begin
    F = load_literature_sbox("PRESENT")
    cm = ccz_matrix(F)
    @test size(cm) == (2 * 4 + 1, 16)
    @test all(cm[1, :])                  # leading constant row is all ones
    em = ea_matrix(F)
    @test size(em) == (2 * 4 + 1, 16 + 15)
    # The first 16 columns of ea_matrix coincide with ccz_matrix.
    @test em[:, 1:16] == cm
end

@testset "ccz_matrix: rank is a CCZ-invariant (F vs inv(F))" begin
    # The CCZ-code's parameters (in particular its dimension = rank of
    # the generator matrix) are CCZ-invariant. inv(F) is CCZ-equivalent.
    for name in ("PRESENT", "GIFT", "SKINNY_4")
        F = load_literature_sbox(name)
        is_permutation(F) || continue
        rk(M) = rank_f2(UInt64[sum(UInt64(M[r, c]) << (r - 1) for r in 1:size(M, 1))
                               for c in 1:size(M, 2)]; nbits = size(M, 1))
        @test rk(ccz_matrix(F)) == rk(ccz_matrix(inv(F)))
    end
end

end
