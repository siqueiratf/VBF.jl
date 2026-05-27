using BFA
using Test

# Direct unit tests for the dyadic-bitset substrate. These functions are
# internal (prefixed `_db_`); we test through `BFA.<name>`.

@testset "single-chunk: 4-bit, 8-bit, 16-bit, 32-bit, 64-bit init" begin
    for nb in (4, 8, 16, 32, 64)
        @test BFA._db_size(BFA._db_empty(nb)) == 0
        @test BFA._db_isempty(BFA._db_empty(nb))
        @test BFA._db_size(BFA._db_full(nb)) == nb
        @test !BFA._db_isempty(BFA._db_full(nb))
    end
end

@testset "multi-chunk init: 128, 256, 1024" begin
    for nb in (128, 256, 1024)
        @test BFA._db_size(BFA._db_empty(nb)) == 0
        @test BFA._db_size(BFA._db_full(nb)) == nb
    end
end

@testset "add!, in, least, elements" begin
    b = BFA._db_empty(16)
    BFA._db_add!(b, 3)
    BFA._db_add!(b, 7)
    BFA._db_add!(b, 15)
    @test BFA._db_in(3, b)
    @test BFA._db_in(7, b)
    @test BFA._db_in(15, b)
    @test !BFA._db_in(0, b)
    @test !BFA._db_in(4, b)
    @test BFA._db_least(b) == 3
    @test sort(BFA._db_elements(b)) == [3, 7, 15]
    @test BFA._db_size(b) == 3
end

@testset "set algebra: intersect, unite, setminus, invert" begin
    nb = 16
    a = BFA._db_add!(BFA._db_empty(nb), 1)
    BFA._db_add!(a, 3)
    BFA._db_add!(a, 5)
    b = BFA._db_add!(BFA._db_empty(nb), 3)
    BFA._db_add!(b, 5)
    BFA._db_add!(b, 7)
    @test sort(BFA._db_elements(BFA._db_intersect(a, b))) == [3, 5]
    @test sort(BFA._db_elements(BFA._db_unite(a, b))) == [1, 3, 5, 7]
    @test sort(BFA._db_elements(BFA._db_setminus(a, b, nb))) == [1]
    @test BFA._db_size(BFA._db_invert(a, nb)) == nb - 3
end

@testset "_db_xor_shift: small case, deterministic check" begin
    # XOR-translate {0, 1, 5} by 3 in nbits=16 → {3, 2, 6}
    nb = 16
    b = BFA._db_empty(nb)
    BFA._db_add!(b, 0)
    BFA._db_add!(b, 1)
    BFA._db_add!(b, 5)
    shifted = BFA._db_xor_shift(b, 3, nb)
    @test sort(BFA._db_elements(shifted)) == [2, 3, 6]

    # XOR-shift {0, ..., nb-1} by any s should permute the elements (size invariant).
    full = BFA._db_full(nb)
    for s in 0:(nb - 1)
        @test BFA._db_size(BFA._db_xor_shift(full, s, nb)) == nb
    end

    # XOR-shift the empty set is empty.
    @test BFA._db_isempty(BFA._db_xor_shift(BFA._db_empty(nb), 5, nb))
end

@testset "_db_xor_shift: exhaustive vs naive (nbits=16)" begin
    # Compare against the naïve definition for many random subsets.
    using Random
    rng = MersenneTwister(0xBFA62)
    nb = 16
    for _ in 1:30
        ref = Set(rand(rng, 0:(nb - 1), rand(rng, 1:nb)))
        b = BFA._db_empty(nb)
        for e in ref
            BFA._db_add!(b, e)
        end
        for s in 0:(nb - 1)
            shifted = BFA._db_xor_shift(b, s, nb)
            expected = Set(e ⊻ s for e in ref)
            @test Set(BFA._db_elements(shifted)) == expected
        end
    end
end

@testset "_db_xor_shift: multi-chunk (nbits=128) sanity" begin
    # Hits the inter-chunk swap branch (s ≥ 64).
    nb = 128
    b = BFA._db_empty(nb)
    BFA._db_add!(b, 0)
    BFA._db_add!(b, 65)
    BFA._db_add!(b, 100)
    for s in (1, 63, 64, 65, 127)
        shifted = BFA._db_xor_shift(b, s, nb)
        @test sort(BFA._db_elements(shifted)) == sort([0 ⊻ s, 65 ⊻ s, 100 ⊻ s])
    end
end
