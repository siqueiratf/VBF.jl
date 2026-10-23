@testitem "Walsh candidate buckets preserve stable ties and exact bitmap scope" begin
    using VBF, Test, Random
    Q = VBF.QuadraticExtensions
    function expected_lists(g5, nWmin)
        pairs = [(Int(g5[i]), UInt32(i-1)) for i in 2:length(g5)
                 if 3*Int(g5[i]) <= -nWmin]
        sort!(pairs; by=first)
        threshold = -(nWmin ÷ 6)
        bitmap = zeros(UInt64, max(1, cld(length(g5), 64)))
        for word in eachindex(bitmap), bit in 0:63
            t = 64*(word-1)+bit
            t < length(g5) && g5[t+1] <= threshold &&
                (bitmap[word] |= UInt64(1) << bit)
        end
        (UInt32[last(pair) for pair in pairs], Int[first(pair) for pair in pairs], threshold), bitmap
    end
    values = Int16[-9, -3, -9, 0, -3, 8, -9, 1]
    bitmap = UInt64[]
    L, Lv, threshold = Q._v5_candidate_lists!(values, 9, bitmap, Int[])
    @test L == UInt32[2, 6, 1, 4]
    @test Lv == [-9, -9, -3, -3]
    @test threshold == -1
    @test bitmap == UInt64[0x57]

    rng = MersenneTwister(0x50a7)
    for n in (0, 1, 2, 63, 64, 65, 4095, 4096, 4097, 8192)
        for nWmin in (-98_305, -98_304, -98_303, -1, 0, 1, 98_303, 98_304, 98_305)
            for g5 in (fill(typemin(Int16), n), fill(typemax(Int16), n),
                       rand(rng, Int16, n), Int16[mod(i, 7)-3 for i in 1:n])
                bins = Int[]
                histogram = Q._v5_flat_histogram(g5, bins)
                retained_histogram = copy(histogram)
                expected, expected_bitmap = expected_lists(g5, nWmin)
                bitmap = fill(typemax(UInt64), 13)
                actual = Q._v5_candidate_lists!(g5, nWmin, bitmap, bins)
                @test actual == expected
                @test bitmap == expected_bitmap
                @test histogram == retained_histogram
            end
        end
    end
end

@testitem "Walsh candidate buckets reset histogram positions and retain sparse fallback" begin
    using VBF, Test
    Q = VBF.QuadraticExtensions
    bins = Int[]; bitmap = UInt64[]
    dense = repeat(Int16[-9, -3, -9, 0, -3, 8, -9, 1], 512)
    Q._v5_flat_histogram(dense, bins)
    first_result = Q._v5_candidate_lists!(dense, 9, bitmap, bins)
    first_snapshot = deepcopy(first_result)
    positions = copy(bins)
    sparse = Int16[-9, -3, -9, 0, -3, 8, -9, 1]
    Q._v5_flat_histogram(sparse, bins)
    actual = Q._v5_candidate_lists!(sparse, 9, bitmap, bins)
    @test actual == (UInt32[2, 6, 1, 4], [-9, -9, -3, -3], -1)
    @test bins == positions
    @test bitmap == UInt64[0x57]
    @test first_result == first_snapshot

    Q._v5_flat_histogram(dense, bins)
    @test Q._v5_candidate_lists!(dense, 9, bitmap, bins) == first_snapshot
    @test Q._v5_candidate_lists!(dense, 9, bitmap, Int[]) == first_snapshot
    other = fill(Int16(-2), 4096)
    Q._v5_flat_histogram(other, bins)
    L, Lv, threshold = Q._v5_candidate_lists!(other, 0, bitmap, bins)
    @test L == UInt32.(1:4095)
    @test Lv == fill(-2, 4095)
    @test threshold == 0
    @test bitmap == fill(typemax(UInt64), 64)
    Q._v5_flat_histogram(other, bins)
    bytes = @allocated Q._v5_candidate_lists!(other, 0, bitmap, bins)
    @test bytes < 12length(other)+4096
end
