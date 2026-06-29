# gateway.jl — build the full-space NL-slice around an APN center F0 for the
# center-offset GPU searcher (apn_search ... <center_rows.bin>).
#
# The slice is F0 ⊕ span(free generators), where the free generators are the unit
# quadratics for the coefficient coords left free by the normalization level NL:
# NL=k fixes all pairs (p,q) with p ≤ k and frees those with p > k (each × 8 bits).
# NL=4 ⇒ free pairs (5,6),(5,7),(6,7) = 24 gens (the paper's slice); NL=3 ⇒ +(4,*) = 48.
# This slice lives in the full 224-dim space, so it reaches outside V_A — the gateway.
module Gateway
using JSON3
export free_coords, write_center_rows, write_generators_rows, slice_lut, rows_of_lut

# byte j of row i = F(e_i ⊕ e_j) = coefficient of x_i x_j  (n-row bilinear matrix)
function rows_of_lut(lut::AbstractVector{<:Integer}, n::Int=8)
    rows = zeros(UInt64, n)
    @inbounds for i in 0:(n-1), j in 0:(n-1)
        i == j && continue
        v = UInt64(lut[((1 << i) | (1 << j)) + 1])
        rows[i+1] |= v << (j * 8)
    end
    rows
end

# free coordinate list (p,q,k) for normalization level NL, in a fixed canonical order
function free_coords(NL::Int, n::Int=8)
    coords = Tuple{Int,Int,Int}[]
    for p in (NL+1):(n-1), q in (p+1):(n-1), k in 0:(n-1)
        push!(coords, (p, q, k))
    end
    coords
end

# unit-generator bilinear rows for coord (p,q,k): byte q of row p (and byte p of row q) = 1<<k
function gen_rows(p::Int, q::Int, k::Int, n::Int=8)
    rows = zeros(UInt64, n)
    rows[p+1] |= UInt64(1 << k) << (q * 8)
    rows[q+1] |= UInt64(1 << k) << (p * 8)
    rows
end

function write_center_rows(path, lut, n::Int=8)
    open(path, "w") do io; write(io, rows_of_lut(lut, n)); end
end

# generators.bin: n_free × n UInt64, one unit bilinear matrix per free coord
function write_generators_rows(path, coords, n::Int=8)
    open(path, "w") do io
        for (p, q, k) in coords; write(io, gen_rows(p, q, k, n)); end
    end
    length(coords)
end

# reconstruct a neighbour LUT from a found selector: F0 ⊕ (free gens picked by bits of sel)
function slice_lut(center_lut::AbstractVector{<:Integer}, coords, sel::Integer, n::Int=8)
    out = UInt8.(collect(center_lut))
    @inbounds for (b, (p, q, k)) in enumerate(coords)
        ((sel >> (b-1)) & 1) == 1 || continue
        for x in 0:((1<<n)-1)
            (((x >> p) & 1) == 1 && ((x >> q) & 1) == 1) && (out[x+1] ⊻= UInt8(1 << k))
        end
    end
    out
end
end # module
