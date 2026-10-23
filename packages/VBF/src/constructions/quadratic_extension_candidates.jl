"""Stable Walsh-candidate ordering and partner bitmap construction.

The dense path reuses the completed flat histogram as counting-sort positions,
then fills candidate coordinates, signed values and the partner bitmap in one
sequential Walsh-array pass. Histogram-derived keys must be consumed first.
The bitmap contains t with g5(t)≤thb. If a=g5(t)≥-2nW(U)/3-thb, a partner
b=g5(t+x)>thb cannot satisfy a+b≤-2nW(U)/3, so the search avoids reading it.
"""

"""Build stable candidate lists and reset the partner bitmap from a signed Walsh array.

For dense inputs, `bins` must contain the current `_v5_flat_histogram` counts.
Those counts are consumed and overwritten. Sparse arrays keep the ordinary
stable sorting path, since their histogram does not populate dense scratch.
Candidate coordinates exclude zero; the bitmap includes it when eligible.
"""
Base.@noinline function _v5_candidate_lists!(g5::Vector{Int16}, nWmin::Int,
                                          bitmap::Vector{UInt64}, bins::Vector{Int})
    length(g5) >= 4096 && length(bins) == 65536 &&
        return _v5_candidate_lists_dense!(g5, nWmin, bitmap, bins)
    _v5_candidate_lists_sparse!(g5, nWmin, bitmap)
end

"""Retain the direct stable sorting reference when dense histogram scratch is unavailable."""
function _v5_candidate_lists_sparse!(g5::Vector{Int16}, nWmin::Int, bitmap::Vector{UInt64})
    L = UInt32[]
    @inbounds for i in 2:length(g5)
        3 * Int(g5[i]) <= -nWmin && push!(L, UInt32(i-1))
    end
    sort!(L; by=t -> g5[Int(t)+1])
    Lv = [g5[Int(t)+1] for t in L]
    thb = -(nWmin ÷ 6)
    resize!(bitmap, max(1, cld(length(g5), 64)))
    fill!(bitmap, UInt64(0))
    @inbounds for i in eachindex(g5)
        t = i-1
        g5[i] <= thb && (bitmap[(t >> 6)+1] |= UInt64(1) << (t & 63))
    end
    L, Lv, thb
end

"""Consume histogram counts as stable bucket cursors and fuse all remaining Walsh-array scans."""
function _v5_candidate_lists_dense!(g5::Vector{Int16}, nWmin::Int,
                                   bitmap::Vector{UInt64}, bins::Vector{Int})
    threshold = clamp(fld(-nWmin, 3), -32769, 32767)
    lastbin = threshold+32769
    zerobin = Int(g5[1])+32769
    next_position = 1
    @inbounds for bin in 1:lastbin
        count = bins[bin] - Int(bin == zerobin)
        bins[bin] = next_position
        next_position += count
    end
    L = Vector{UInt32}(undef, next_position-1)
    Lv = Vector{Int16}(undef, next_position-1)
    thb = -(nWmin ÷ 6)
    resize!(bitmap, max(1, cld(length(g5), 64)))
    fill!(bitmap, UInt64(0))
    g5[1] <= thb && (bitmap[1] |= UInt64(1))
    @inbounds for i in 2:length(g5)
        value = Int(g5[i])
        t = i-1
        if value <= threshold
            bin = value+32769
            position = bins[bin]
            L[position] = UInt32(t)
            Lv[position] = g5[i]
            bins[bin] = position+1
        end
        value <= thb && (bitmap[(t >> 6)+1] |= UInt64(1) << (t & 63))
    end
    L, Lv, thb
end
