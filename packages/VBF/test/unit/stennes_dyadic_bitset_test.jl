@testitem "stennes_dyadic_bitset" begin
using VBFCatalog
using VBF
using Test

# Direct unit tests for the dyadic-bitset substrate. These functions are internal (prefixed `_db_`); we test through `VBF.<name>`.

@testset "single-chunk: 4-bit, 8-bit, 16-bit, 32-bit, 64-bit init" begin
    for nb in (4, 8, 16, 32, 64)
        @test VBF._db_size(VBF._db_empty(nb)) == 0
        @test VBF._db_isempty(VBF._db_empty(nb))
        @test VBF._db_size(VBF._db_full(nb)) == nb
        @test !VBF._db_isempty(VBF._db_full(nb))
    end
end

@testset "multi-chunk init: 128, 256, 1024" begin
    for nb in (128, 256, 1024)
        @test VBF._db_size(VBF._db_empty(nb)) == 0
        @test VBF._db_size(VBF._db_full(nb)) == nb
    end
end

@testset "add!, in, least, elements" begin
    b = VBF._db_empty(16)
    VBF._db_add!(b, 3)
    VBF._db_add!(b, 7)
    VBF._db_add!(b, 15)
    @test VBF._db_in(3, b)
    @test VBF._db_in(7, b)
    @test VBF._db_in(15, b)
    @test !VBF._db_in(0, b)
    @test !VBF._db_in(4, b)
    @test VBF._db_least(b) == 3
    @test sort(VBF._db_elements(b)) == [3, 7, 15]
    @test VBF._db_size(b) == 3
end

@testset "set algebra: intersect, unite, setminus, invert" begin
    nb = 16
    a = VBF._db_add!(VBF._db_empty(nb), 1)
    VBF._db_add!(a, 3)
    VBF._db_add!(a, 5)
    b = VBF._db_add!(VBF._db_empty(nb), 3)
    VBF._db_add!(b, 5)
    VBF._db_add!(b, 7)
    @test sort(VBF._db_elements(VBF._db_intersect(a, b))) == [3, 5]
    @test sort(VBF._db_elements(VBF._db_unite(a, b))) == [1, 3, 5, 7]
    @test sort(VBF._db_elements(VBF._db_setminus(a, b, nb))) == [1]
    @test VBF._db_size(VBF._db_invert(a, nb)) == nb - 3
end

@testset "_db_xor_shift: small case, deterministic check" begin
    # XOR-translate {0, 1, 5} by 3 in nbits=16 → {3, 2, 6}
    nb = 16
    b = VBF._db_empty(nb)
    VBF._db_add!(b, 0)
    VBF._db_add!(b, 1)
    VBF._db_add!(b, 5)
    shifted = VBF._db_xor_shift(b, 3, nb)
    @test sort(VBF._db_elements(shifted)) == [2, 3, 6]

    # XOR-shift {0, ..., nb-1} by any s should permute the elements (size invariant).
    full = VBF._db_full(nb)
    for s in 0:(nb - 1)
        @test VBF._db_size(VBF._db_xor_shift(full, s, nb)) == nb
    end

    # XOR-shift the empty set is empty.
    @test VBF._db_isempty(VBF._db_xor_shift(VBF._db_empty(nb), 5, nb))
end

@testset "_db_xor_shift: exhaustive vs naive (nbits=16)" begin
    # Compare against the naïve definition for many random subsets.
    using Random
    rng = MersenneTwister(0xBFA62)
    nb = 16
    for _ in 1:30
        ref = Set(rand(rng, 0:(nb - 1), rand(rng, 1:nb)))
        b = VBF._db_empty(nb)
        for e in ref
            VBF._db_add!(b, e)
        end
        for s in 0:(nb - 1)
            shifted = VBF._db_xor_shift(b, s, nb)
            expected = Set(e ⊻ s for e in ref)
            @test Set(VBF._db_elements(shifted)) == expected
        end
    end
end

@testset "_db_xor_shift: multi-chunk (nbits=128) sanity" begin
    # Hits the inter-chunk swap branch (s ≥ 64).
    nb = 128
    b = VBF._db_empty(nb)
    VBF._db_add!(b, 0)
    VBF._db_add!(b, 65)
    VBF._db_add!(b, 100)
    for s in (1, 63, 64, 65, 127)
        shifted = VBF._db_xor_shift(b, s, nb)
        @test sort(VBF._db_elements(shifted)) == sort([0 ⊻ s, 65 ⊻ s, 100 ⊻ s])
    end
end

end
