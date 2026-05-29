@testitem "walsh" begin
using VBFCatalog
using VBF
using Test
using Random

@testset "walsh_hadamard! on small inputs" begin
    # length 1 — no-op
    v = [5]
    walsh_hadamard!(v)
    @test v == [5]

    # length 2: [a, b] ↦ [a+b, a-b]
    v = [3, 5]
    walsh_hadamard!(v)
    @test v == [8, -2]

    # length 4: hand-traced
    # input [1, 1, 1, -1]
    # stage 1 (block=1):
    #   pair (1,1) → (2, 0); pair (1,-1) → (0, 2). v = [2, 0, 0, 2]
    # stage 2 (block=2):
    #   pair (2,0) → (2, 2); pair (0,2) → (2, -2). v = [2, 2, 2, -2]
    v = [1, 1, 1, -1]
    walsh_hadamard!(v)
    @test v == [2, 2, 2, -2]
end

@testset "involution: FWHT² == 2^N · I" begin
    rng = MersenneTwister(0xBFA)
    @testset "n=$n" for n in 1:8
        len = 1 << n
        v = rand(rng, -100:100, len)
        v_orig = copy(v)
        walsh_hadamard!(v)
        walsh_hadamard!(v)
        @test v == len .* v_orig
    end
end

@testset "Parseval identity" begin
    rng = MersenneTwister(0xC0FFEE)
    @testset "n=$n" for n in 1:8
        len = 1 << n
        v = rand(rng, -10:10, len)
        before = sum(abs2, v)
        walsh_hadamard!(v)
        after = sum(abs2, v)
        @test after == len * before
    end
end

@testset "validation" begin
    @test_throws ArgumentError walsh_hadamard!(Int[])
    @test_throws ArgumentError walsh_hadamard!([1, 2, 3])
    @test_throws ArgumentError walsh_transform([0, 0, 0])
    @test_throws ArgumentError walsh_transform([0, 2])     # 2 ∉ {0,1}
end

@testset "allocating walsh_hadamard preserves input" begin
    v = [1, 2, 3, 4]
    out = walsh_hadamard(v)
    @test v == [1, 2, 3, 4]
    @test out != v
end

@testset "walsh_transform on canonical Booleans" begin
    @testset "constant 0 function" begin
        # f(x) = 0 for all x ↦ g(x) = +1 ↦ spectrum [2^N, 0, …, 0]
        @testset "n=$n" for n in 1:6
            f = zeros(Int, 1 << n)
            w = walsh_transform(f)
            @test w[1] == 1 << n
            @test all(==(0), w[2:end])
        end
    end

    @testset "constant 1 function" begin
        # f(x) = 1 ↦ g = -1 ↦ spectrum [-2^N, 0, …, 0]
        @testset "n=$n" for n in 1:6
            f = ones(Int, 1 << n)
            w = walsh_transform(f)
            @test w[1] == -(1 << n)
            @test all(==(0), w[2:end])
        end
    end

    @testset "f(x) = x_0 concentrates on u = 1" begin
        # n=3: truth table indexed by x = x_2 x_1 x_0
        # f(x) = x_0 → tt = [0, 1, 0, 1, 0, 1, 0, 1].
        # W_f(u) = ∑_x (-1)^{u·x + f(x)} = ∑_x (-1)^{u·x + x_0}.
        # For u = 1 (u·x = x_0), the exponent is 2 x_0 ≡ 0 mod 2 so W(1) = +2^n.
        f = [0, 1, 0, 1, 0, 1, 0, 1]
        w = walsh_transform(f)
        @test w[1] == 0
        @test w[2] == 8     # W(1) = +2^n
        @test all(==(0), w[3:end])
    end

    @testset "f(x) = x_0 ⊕ x_1 concentrates on u = 3" begin
        # n=2: tt = [0, 1, 1, 0]; same reasoning: W(3) = +2^n.
        f = [0, 1, 1, 0]
        w = walsh_transform(f)
        @test w[1] == 0
        @test w[2] == 0
        @test w[3] == 0
        @test w[4] == 4
    end
end

@testset "walsh_transform output range" begin
    # Spectrum entries are bounded by 2^n in absolute value.
    rng = MersenneTwister(0xDEADBEEF)
    @testset "n=$n" for n in 3:7
        len = 1 << n
        f = rand(rng, 0:1, len)
        w = walsh_transform(f)
        @test all(x -> abs(x) ≤ len, w)
    end
end

end
