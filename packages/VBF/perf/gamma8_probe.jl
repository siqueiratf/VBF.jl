# packages/VBF/perf/gamma8_probe.jl — Gamma-rank probe that is not subject to the n <= 7 guard.
#
# This is a verbatim out-of-src copy of the bit-packed F_2 elimination in
# packages/VBF/src/invariants/design_ranks.jl, minus `_design_rank_guard`. It
# exists so the audit can MEASURE what that guard refuses, without editing core.
#
# Measured on this machine (see packages/VBF/perf/historical/calibration.toml, [design_rank_gamma]):
#   n = 5  ->   330 in 0.150 s      (matches the value in the core docstring)
#   n = 6  ->  1102 in 0.077 s
#   n = 7  ->  3610 in 3.659 s      (matches gamma_rank(gold_apn(7,1)))
#   n = 8  -> 11818 in 166.8 s, ~0.95 GB peak   <- the guard says "hours, use Magma"
#
# Do NOT use this in place of VBF.gamma_rank for n <= 7; it is the same code and
# the exported function is the supported entry point.

using VBF

function _rank_wide!(rows::Vector{Vector{UInt64}}, ncols::Int)
    nwords = cld(ncols, 64)
    nrows = length(rows)
    r = 1
    rk = 0
    @inbounds for col in 0:(ncols - 1)
        w = (col >> 6) + 1
        b = col & 63
        sel = 0
        for i in r:nrows
            if (rows[i][w] >> b) & 1 == 1
                sel = i
                break
            end
        end
        sel == 0 && continue
        rows[r], rows[sel] = rows[sel], rows[r]
        for i in (r + 1):nrows
            if (rows[i][w] >> b) & 1 == 1
                @simd for k in w:nwords
                    rows[i][k] ⊻= rows[r][k]
                end
            end
        end
        r += 1
        rk += 1
        r > nrows && break
    end
    rk
end

"""
    design_2rank_unguarded(points, m) -> Int

`F_2`-rank of the incidence matrix `B[p,q] = [p ⊻ q ∈ points]` on `F_2^m`.
Allocates `2^m` rows of `cld(2^m, 64)` words: 512 MB at `m = 16` (n = 8).
"""
function design_2rank_unguarded(points::Vector{Int}, m::Int)
    M = 1 << m
    nwords = cld(M, 64)
    rows = [zeros(UInt64, nwords) for _ in 1:M]
    @inbounds for p in 0:(M - 1), s in points
        q = p ⊻ s
        rows[p + 1][(q >> 6) + 1] |= (UInt64(1) << (q & 63))
    end
    _rank_wide!(rows, M)
end

"""
    gamma8(F::SBox{N}) -> Int

Gamma-rank of APN `F` with no dimension guard. Identical to `VBF.gamma_rank`
for `N <= 7`; usable at `N = 8` (~2.8 min, ~0.95 GB). `N >= 9` needs a
`2^18 x 2^18` matrix (~8.6 GB) and is not recommended here.
"""
gamma8(F::SBox{N}) where {N} =
    design_2rank_unguarded([Int(x) | (Int(F.lut[x + 1]) << N) for x in 0:((1 << N) - 1)], 2N)
