@testitem "linear_backtracking" setup=[SBoxFixtures] begin

using VBF
using Test
using Random

# Direct unit tests against VBF.are_linearly_equivalent_perm; the public `are_linear_equivalent` strategy-dispatch lives in api.jl and gets tested separately.

@testset "reflexivity: F ~ F for every fixed permutation" begin
    # Small n so the search is fast even for the fixed 4-bit examples.
    for name in fixture_names()
        s = fixture_sbox(name)
        is_permutation(s) || continue
        inputbits(s) ≤ 4 || continue
        @test VBF.are_linearly_equivalent_perm(s, s)
    end
end

@testset "L conjugation: F ~ L ∘ F ∘ L⁻¹ for invertible L" begin
    rng = MersenneTwister(0xBFA51)
    @testset "n=$N" for N in (3, 4)
        T = UInt8
        mask = T((T(1) << N) - T(1))
        for _ in 1:3
            # Build a random permutation F.
            lut = collect(T, 0:(1 << N) - 1)
            shuffle!(rng, lut)
            F = SBox{N, T}(lut)

            # Build a random invertible L.
            cols = T[]
            basis = T[]
            while length(cols) < N
                v = rand(rng, T) & mask
                v == 0 && continue
                is_in_span(v, basis; nbits = N) && continue
                push!(cols, v); push!(basis, v)
                basis = linear_basis(basis; nbits = N)
            end
            L = F2LinearMap{N, T}(cols)
            G = L ∘ (F ∘ inv(L))         # conjugate by L on the input side

            @test VBF.are_linearly_equivalent_perm(F, G)
        end
    end
end

@testset "rollback preserves the previous input span after a failed branch" begin
    # Frozen witness: reducing a trial basis may change/reorder all its rows.
    # Popping its last row does not undo the trial vector and loses valid branches.
    F = SBox(UInt8[14, 6, 8, 2, 13, 15, 12, 0, 5, 4, 7, 3, 11, 10, 1, 9])
    L = F2LinearMap(UInt8[4, 2, 5, 15])
    G = L ∘ (F ∘ inv(L))
    @test G.lut == UInt8[8, 12, 15, 0, 7, 14, 2, 10, 4, 6, 9, 5, 11, 3, 13, 1]
    @test VBF.are_linearly_equivalent_perm(F, G)
    @test VBF.are_linearly_equivalent_perm(G, F)
end

@testset "asymmetry under affine offset (most pairs are not linear-equivalent)" begin
    # Adding a non-zero constant to G almost always breaks linear equivalence — every linear map sends 0 to 0, so F(0) = 0 forces G(0) = 0; if G(0) ≠ 0 and F(0) = 0, the algorithm must say "no".
    F = SBox(UInt8[0, 1, 9, 14, 13, 11, 7, 6, 15, 2, 12, 5, 10, 4, 3, 8])  # n=4 perm, F(0)=0
    @test F(0) == 0

    # Swap of F(0) and F(1): now G(0)=1 ≠ 0. Linear equivalence impossible.
    G_lut = copy(F.lut)
    G_lut[1], G_lut[2] = G_lut[2], G_lut[1]
    G = SBox{4, UInt8}(G_lut)
    @test G(0) == 0x1 && F(0) == 0x0       # confirm setup
    @test !VBF.are_linearly_equivalent_perm(F, G)
end

@testset "rejection: non-permutation inputs return false" begin
    # constant function (not a permutation)
    c = SBox(UInt8[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3])
    F = fixture_sbox("PRESENT")
    @test !is_permutation(c)
    @test !VBF.are_linearly_equivalent_perm(F, c)
    @test !VBF.are_linearly_equivalent_perm(c, F)
end

@testset "small-n exhaustive sanity: identity ~ every linear bijection" begin
    # Any linear bijection L is linearly equivalent to id (take L₁ = L, L₂ = I).
    rng = MersenneTwister(0xBFA52)
    N = 4
    T = UInt8
    id_sbox = SBox{N, T}(collect(T, 0:(1 << N) - 1))
    mask = T((T(1) << N) - T(1))
    for _ in 1:5
        cols = T[]
        basis = T[]
        while length(cols) < N
            v = rand(rng, T) & mask
            v == 0 && continue
            is_in_span(v, basis; nbits = N) && continue
            push!(cols, v); push!(basis, v)
            basis = linear_basis(basis; nbits = N)
        end
        L = F2LinearMap{N, T}(cols)
        # The S-box whose LUT IS L: bake L into an SBox via direct evaluation.
        L_sbox = SBox{N, T}(T[L(x) for x in 0:(1 << N) - 1])
        @test VBF.are_linearly_equivalent_perm(id_sbox, L_sbox)
        @test VBF.are_linearly_equivalent_perm(L_sbox, id_sbox)   # symmetry
    end
end

end
