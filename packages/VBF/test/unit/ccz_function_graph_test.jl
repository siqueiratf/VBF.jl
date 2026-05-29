@testitem "ccz_function_graph" begin
using VBFCatalog
using VBF
using Test
using Random

@testset "FunctionGraph: construction + basic API" begin
    F = load_literature_sbox("PRESENT")
    g = FunctionGraph(F)
    @test inputbits(g) == 4
    @test length(g) == 16
    @test eltype(g.packed) == UInt32
    @test issorted(g.packed)
end

@testset "FunctionGraph: invalid N rejected" begin
    @test_throws ArgumentError FunctionGraph{0}(UInt32[0, 1])
    @test_throws ArgumentError FunctionGraph{17}(UInt32[0])   # 2N=34 > 32
    @test_throws ArgumentError FunctionGraph{4}(UInt32[0, 1])  # wrong length
end

@testset "FunctionGraph: graph entries pack (x << N) | F(x)" begin
    F = load_literature_sbox("PRESENT")
    g = FunctionGraph(F)
    for entry in g.packed
        x = entry >> 4
        y = entry & 0x0F
        @test F.lut[x + 1] == UInt8(y)
    end
end

@testset "ccz_equivalent_function: identity L recovers F" begin
    for name in ("PRESENT", "GIFT", "SKINNY_4")
        F = load_literature_sbox(name)
        N = inputbits(F)
        L_id = identity_linear_map(2N)
        A_id = F2AffineMap(L_id, UInt8(0))
        @test ccz_equivalent_function(F, A_id) == F
    end
end

@testset "ccz_equivalent_function: swap map recovers inv(F)" begin
    # The CCZ map (x, y) → (y, x) applied to graph(F) = {(x, F(x))}
    # gives {(F(x), x)} = graph(F⁻¹).
    F = load_literature_sbox("PRESENT")
    @test is_permutation(F)
    N, T = 4, UInt8
    swap_cols = T[T(1) << ((i + N) % (2N)) for i in 0:(2N - 1)]
    L_swap = F2LinearMap{2N, T}(swap_cols)
    A_swap = F2AffineMap(L_swap, T(0))
    F_eq = ccz_equivalent_function(F, A_swap)
    @test F_eq !== nothing
    @test F_eq == inv(F)
end

@testset "ccz_equivalent_function: non-admissible L returns nothing" begin
    F = load_literature_sbox("PRESENT")
    T = UInt8
    # Collapse the input bits: e_i → 0 for i < N; e_i → e_{i-N} for i ≥ N.
    bad_cols = T[
        i < 4 ? T(0) : T(1) << (i - 4)
        for i in 0:7
    ]
    L_bad = F2LinearMap{8, T}(bad_cols)
    A_bad = F2AffineMap(L_bad, T(0))
    @test ccz_equivalent_function(F, A_bad) === nothing
end

@testset "ccz_equivalent_function: wrong input length throws" begin
    F = load_literature_sbox("PRESENT")
    L_4 = identity_linear_map(4)   # input length 4, not 2N=8
    A_4 = F2AffineMap(L_4, UInt8(0))
    @test_throws ArgumentError ccz_equivalent_function(F, A_4)
end

@testset "ccz_equivalent_function: result preserves DDT (CCZ-invariant)" begin
    # CCZ-equivalence preserves the multiset of DDT entries.
    rng = MersenneTwister(0xBFA91)
    F = load_literature_sbox("PRESENT")
    N, T = 4, UInt8
    mask = T(0x0F)
    ref_ddt_sorted = sort(vec(ddt(F)))
    for _ in 1:5
        # Random invertible L on F₂^{2N}
        cols = T[]
        bs = T[]
        nbits_total = 2N
        while length(cols) < nbits_total
            v = rand(rng, T) & T((T(1) << nbits_total) - T(1))
            v == 0 && continue
            is_in_span(v, bs; nbits = nbits_total) && continue
            push!(cols, v); push!(bs, v)
            bs = linear_basis(bs; nbits = nbits_total)
        end
        L = F2LinearMap{2N, T}(cols)
        A = F2AffineMap(L, T(0))
        F_eq = ccz_equivalent_function(F, A)
        F_eq === nothing && continue  # not admissible
        # DDT entry multisets must match.
        @test sort(vec(ddt(F_eq))) == ref_ddt_sorted
    end
end

end
