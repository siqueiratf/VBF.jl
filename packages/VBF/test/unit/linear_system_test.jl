@testitem "linear_system" setup=[SBoxFixtures] begin

using VBF
using Test
using Random

# ----- is_invertible / inv(::F2LinearMap) -----------------------------------

@testset "is_invertible / inv on identity and zero" begin
    id4 = identity_linear_map(4)
    @test is_invertible(id4)
    @test inv(id4) == id4              # identity is its own inverse

    z4 = zero_linear_map(4)
    @test !is_invertible(z4)
    @test_throws ArgumentError inv(z4)
end

@testset "inv: round-trip on canonical maps" begin
    # L = "shift bits left by 1 with wraparound" on F₂⁴: e₀↦e₁, e₁↦e₂, e₂↦e₃, e₃↦e₀.
    L = F2LinearMap(UInt8[2, 4, 8, 1])
    @test is_invertible(L)
    Linv = inv(L)
    # inv(inv(L)) == L
    @test inv(Linv) == L
    # L ∘ inv(L) == identity
    @test L ∘ Linv == identity_linear_map(4)
    @test Linv ∘ L == identity_linear_map(4)
end

@testset "inv: random invertible maps round-trip" begin
    rng = MersenneTwister(0xBFA_5_a)
    for N in (3, 4, 5, 6, 8)
        for _ in 1:10
            # Build a random invertible matrix by choosing N independent vectors.
            T = N ≤ 8 ? UInt8 : (N ≤ 16 ? UInt16 : UInt32)
            cols = T[]
            basis = T[]
            mask = T((T(1) << N) - T(1))
            while length(cols) < N
                v = rand(rng, T) & mask
                v == 0 && continue
                is_in_span(v, basis; nbits = N) && continue
                push!(cols, v)
                push!(basis, v)
                # gauss-reduce so subsequent is_in_span calls stay fast
                basis = linear_basis(basis; nbits = N)
            end
            L = F2LinearMap{N, T}(cols)
            @test is_invertible(L)
            @test inv(inv(L)) == L
            @test L ∘ inv(L) == identity_linear_map(N, T)
        end
    end
end

# ----- compose / ∘ ----------------------------------------------------------

@testset "compose: F2LinearMap ∘ F2LinearMap is associative" begin
    rng = MersenneTwister(0xBFA_5_b)
    N = 5
    T = UInt8
    rand_invertible() = begin
        cols = T[]
        basis = T[]
        mask = T((T(1) << N) - T(1))
        while length(cols) < N
            v = rand(rng, T) & mask
            v == 0 && continue
            is_in_span(v, basis; nbits = N) && continue
            push!(cols, v); push!(basis, v)
            basis = linear_basis(basis; nbits = N)
        end
        F2LinearMap{N, T}(cols)
    end
    L1, L2, L3 = rand_invertible(), rand_invertible(), rand_invertible()
    @test (L1 ∘ L2) ∘ L3 == L1 ∘ (L2 ∘ L3)
end

@testset "compose: SBox ∘ F2LinearMap and reverse" begin
    aes = fixture_sbox("AES")
    id8 = identity_linear_map(8)
    @test aes ∘ id8 == aes              # F ∘ id = F
    @test id8 ∘ aes == aes              # id ∘ F = F

    # A nontrivial L: shift each bit position by 1 (over GF(2^8))
    L = F2LinearMap{8, UInt8}(UInt8[2, 4, 8, 16, 32, 64, 128, 1])
    @test is_invertible(L)
    composed = L ∘ (aes ∘ inv(L))       # conjugate; should still be a permutation
    @test is_permutation(composed)
    @test inputbits(composed) == 8
end

# ----- solve_f2 ------------------------------------------------------------

@testset "solve_f2: identity, simple cases" begin
    # A = I (3×3): rows e₀, e₁, e₂.  b = 5 = 0b101.  Expect x = 5.
    A = UInt8[0b001, 0b010, 0b100]
    @test solve_f2(A, UInt8(0b101); nbits = 3) == 0b101
end

@testset "solve_f2: inconsistent system → nothing" begin
    # Two rows: [1 0] and [1 0]; b = (0, 1). The second row says 0 = 1.
    A = UInt8[0b01, 0b01]
    @test solve_f2(A, UInt8(0b10); nbits = 2) === nothing
end

@testset "solve_f2: underdetermined → some solution; verify A·x == b" begin
    # Underdetermined: 2 rows in 3 unknowns. Row 1: x₀ + x₁ = 1 Row 2: x₁ + x₂ = 0
    A = UInt8[0b011, 0b110]
    x = solve_f2(A, UInt8(0b01); nbits = 3)
    @test x !== nothing
    # Verify A · x == b
    b_check = zero(UInt8)
    for i in 1:length(A)
        bit = parity(A[i] & x)
        b_check |= UInt8(bit) << (i - 1)
    end
    @test b_check == 0b01
end

# ----- kernel_f2 -----------------------------------------------------------

@testset "kernel_f2: full-rank → empty kernel" begin
    A = UInt8[0b001, 0b010, 0b100]
    @test kernel_f2(A; nbits = 3) == UInt8[]
end

@testset "kernel_f2: rank-1 over 3 unknowns → 2 basis vectors" begin
    # A · x = 0 with A = [1 1 1] yields kernel of dimension 2.
    A = UInt8[0b111]
    basis = kernel_f2(A; nbits = 3)
    @test length(basis) == 2
    # Each basis vector v should satisfy A · v == 0
    for v in basis
        @test parity(A[1] & v) == 0
    end
end

@testset "kernel_f2: independent of nbits within domain" begin
    A = UInt8[0b011, 0b110]   # rank 2 in 3 unknowns → 1-D kernel
    k = kernel_f2(A; nbits = 3)
    @test length(k) == 1
    for v in k
        @test parity(A[1] & v) == 0 && parity(A[2] & v) == 0
    end
end

end
