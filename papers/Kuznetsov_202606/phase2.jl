# Implements Phase 2 — Gröbner-Basis NL=4 slice enumeration (open-source / no Magma)
# Paper: Kuznetsov (2026), "Quadratic APN Functions in Dimension 8 via
#        Gröbner Basis Search in a Self-Equivalence Subspace",
#        IEEE Trans. Inf. Theory (2026) / arXiv:2606.11967
# Section: V.B — Phase 2: Gröbner basis slice computation
#
# Open-source replacement for the original Magma V2.28-9 step. The Gröbner basis
# over GF(2) is computed by msolve via `AlgebraicSolving.jl`; the slice variety is
# enumerated and filtered to APN functions. Validated to reproduce the author's
# Magma results exactly (per-slice set equality vs data/apn_all.json).
#
# Encoding (faithful to the author's `find_apn_centers.py`, NOT V_A-restricted):
#   * Work in the full quadratic ANF space: 224 coefficients c_{(p,q),j},
#     0<=p<q<=7, j=0..7, laid out as vi = j*K + pair_index(p,q), K=28.
#   * NL=4 normalization: fix the 200 coefficients of pairs with p<=4 to the
#     APN center's values; the 24 coefficients of pairs (5,6),(5,7),(6,7) are free.
#   * APN ideal: for each difference a in 1..255, the derivative matrix M_a has
#     a in its kernel, so rank(M_a) <= 7 always; APN at a  <=>  rank(M_a) = 7
#     <=>  p_a = prod_{R,C}(1 + det M_a^{(R,C)}) = 0  (over all 7x7 minors).
#     I = <p_1,...,p_255> + field equations c_i^2 + c_i, grevlex over GF(2).
#   * Var(I) (24 free vars) -> reconstruct S-boxes -> keep differential_uniformity == 2.
# VBF API used: SBox, differential_uniformity

using VBF
import AlgebraicSolving as AS

# ─── ANF layout (author's NL=4 convention) ───────────────────────────────────
const PH2_N     = 8
const PH2_PAIRS = [(p, q) for p in 0:7 for q in (p + 1):7]   # 28 pairs, lexicographic
const PH2_K     = length(PH2_PAIRS)                           # 28
const PH2_PIDX  = Dict(PH2_PAIRS[i] => i - 1 for i in eachindex(PH2_PAIRS))  # 0-based
const PH2_FREE_PAIRS = [(5, 6), (5, 7), (6, 7)]              # p > 4 -> intra-slice

"""0-based ANF coefficient index of c_{(p,q),j} (pair unordered, j output bit)."""
ph2_vi(j::Int, p::Int, q::Int) = j * PH2_K + PH2_PIDX[(min(p, q), max(p, q))]

"""0-based indices of the 24 free (intra-slice) coefficients, sorted."""
function ph2_free_indices()
    v = Int[]
    for (p, q) in PH2_FREE_PAIRS, j in 0:7
        push!(v, ph2_vi(j, p, q))
    end
    sort!(v)
end

# ─── ANF <-> S-box (purely quadratic) ────────────────────────────────────────

"""
Quadratic ANF coefficients of an 8-bit S-box LUT as a `BitVector` of length 224.
`c[ph2_vi(j,p,q)+1] == 1` iff monomial x_p·x_q appears in output bit j.
Assumes a purely quadratic function (the Phase-1 centers are homogeneous quadratic).
"""
function quad_anf_coeffs(lut::AbstractVector{<:Integer})
    c = falses(PH2_N * PH2_K)
    for (p, q) in PH2_PAIRS
        xp = 1 << p; xq = 1 << q
        v = lut[1] ⊻ lut[xp + 1] ⊻ lut[xq + 1] ⊻ lut[(xp | xq) + 1]
        for j in 0:7
            ((v >> j) & 1 == 1) && (c[ph2_vi(j, p, q) + 1] = true)
        end
    end
    c
end

"""256-element `UInt8` LUT of the purely quadratic function with ANF coefficients `c`."""
function coeffs_to_lut(c::AbstractVector{Bool})
    lut = zeros(UInt8, 256)
    for x in 0:255
        val = UInt8(0)
        for j in 0:7
            fj = false
            for (p, q) in PH2_PAIRS
                (((x >> p) & 1) == 1 && ((x >> q) & 1) == 1 && c[ph2_vi(j, p, q) + 1]) && (fj = !fj)
            end
            fj && (val |= UInt8(1) << j)
        end
        lut[x + 1] = val
    end
    lut
end

# ─── Fast Boolean polynomials over the 24 free vars (monomial = bitmask) ──────
# A polynomial is a Set of UInt32 monomial masks (XOR semantics over GF(2)).
const PH2_BP = Set{UInt32}
ph2_bxor!(a::PH2_BP, p::PH2_BP) = (for m in p; (m in a) ? delete!(a, m) : push!(a, m); end; a)
function ph2_bmul(p::PH2_BP, q::PH2_BP)
    r = PH2_BP()
    for x in p, y in q
        m = x | y
        (m in r) ? delete!(r, m) : push!(r, m)
    end
    r
end

"""Determinant (over GF(2), multilinear) of the `rows`×`cols` submatrix, by subset DP."""
function ph2_det(M::Matrix{PH2_BP}, rows::Vector{Int}, cols::Vector{Int})
    m = length(rows); full = (1 << m) - 1
    dp = Vector{PH2_BP}(undef, full + 1); dp[1] = PH2_BP([UInt32(0)])  # mask 0 -> 1
    for mask in 1:full
        ri = count_ones(UInt32(mask)); acc = PH2_BP()
        for ci in 1:m
            b = 1 << (ci - 1); (mask & b) == 0 && continue
            e = M[rows[ri], cols[ci]]; isempty(e) && continue
            sub = dp[(mask ⊻ b) + 1]; isempty(sub) && continue
            ph2_bxor!(acc, ph2_bmul(e, sub))
        end
        dp[mask + 1] = acc
    end
    dp[full + 1]
end

"""
Build the APN ideal generators p_a (as Boolean polynomials over the 24 free vars)
for the slice through `center_coeffs`. Returns `(:ok, gens, free)` or
`(:infeasible, _, free)` if some p_a is the constant 1 (no APN in the slice).
"""
function ph2_build(center_coeffs::AbstractVector{Bool})
    free = ph2_free_indices()
    bitof = Dict(free[i] => UInt32(1) << (i - 1) for i in eachindex(free))
    csym = [PH2_BP() for _ in 1:(PH2_N * PH2_K)]
    for v in 0:(PH2_N * PH2_K - 1)
        if haskey(bitof, v)
            push!(csym[v + 1], bitof[v])          # free variable (singleton monomial)
        elseif center_coeffs[v + 1]
            push!(csym[v + 1], UInt32(0))         # fixed constant 1
        end
    end
    cc(j, p, q) = csym[ph2_vi(j, p, q) + 1]
    function M_a(a)
        M = Matrix{PH2_BP}(undef, 8, 8)
        for j in 0:7, l in 0:7
            e = PH2_BP()
            for pp in 0:(l - 1); ((a >> pp) & 1 == 1) && ph2_bxor!(e, cc(j, pp, l)); end
            for qq in (l + 1):7; ((a >> qq) & 1 == 1) && ph2_bxor!(e, cc(j, l, qq)); end
            M[j + 1, l + 1] = e
        end
        M
    end
    subs = [[r for r in 1:8 if r != d] for d in 1:8]   # the 8 size-7 index subsets
    gens = PH2_BP[]
    for a in 1:255
        M = M_a(a); prod = PH2_BP([UInt32(0)])         # constant 1
        for rs in subs, cs in subs
            minor = ph2_det(M, rs, cs); q = copy(minor); ph2_bxor!(q, PH2_BP([UInt32(0)]))  # 1 + minor
            prod = ph2_bmul(prod, q)
            isempty(prod) && break
        end
        if isempty(prod)
            # p_a ≡ 0: constraint vacuous for this a, skip
        elseif length(prod) == 1 && (UInt32(0) in prod)
            return (:infeasible, PH2_BP[], free)        # p_a ≡ 1: slice has no APN
        else
            push!(gens, prod)
        end
    end
    (:ok, gens, free)
end

# ─── Gröbner basis (msolve) + variety enumeration ────────────────────────────

"""
Enumerate the {0,1}^24 variety of a Gröbner basis given as Boolean polynomials
`gbBP` over the 24 free vars, via pruned DFS (evaluate each GB poly once all its
variables are assigned). Returns the satisfying 24-bit assignments.
"""
function ph2_variety(gbBP::Vector{PH2_BP})
    vmask = [reduce(|, g; init = UInt32(0)) for g in gbBP]
    sols = UInt32[]
    function dfs(idx::Int, asg::UInt32, fixed::UInt32)
        if idx < 0
            push!(sols, asg); return
        end
        bit = UInt32(1) << idx
        for val in (UInt32(0), bit)
            a2 = asg | val; f2 = fixed | bit; ok = true
            for gi in eachindex(gbBP)
                if (vmask[gi] & f2) == vmask[gi]
                    cnt = 0
                    for m in gbBP[gi]; ((a2 & m) == m) && (cnt ⊻= 1); end
                    cnt != 0 && (ok = false; break)
                end
            end
            ok && dfs(idx - 1, a2, f2)
        end
    end
    dfs(23, UInt32(0), UInt32(0))
    sols
end

"""Convert an `AlgebraicSolving` polynomial in 24 vars to a Boolean-mask polynomial."""
function ph2_to_bp(g)
    p = PH2_BP()
    for ev in AS.exponent_vectors(g)
        mask = UInt32(0)
        for i in 1:24; ev[i] != 0 && (mask |= UInt32(1) << (i - 1)); end
        (mask in p) ? delete!(p, mask) : push!(p, mask)
    end
    p
end

"""
Phase 2 for one APN center (given as an 8-bit S-box LUT or `SBox{8}`).

Computes all APN functions in the center's NL=4 slice by Gröbner basis (msolve)
over GF(2), returning them as a `Vector{SBox{8}}` (deduplicated). The center is
always among them. Pass `verify = false` to skip the final δ=2 sanity filter
(the variety is APN by construction).
"""
function phase2_slice(center; verify::Bool = true)
    lut = center isa SBox ? center.lut : center
    coeffs = quad_anf_coeffs(lut)
    status, gensBP, free = ph2_build(coeffs)
    status === :infeasible && return SBox{8}[]

    R, cv = AS.polynomial_ring(AS.GF(2), ["c$i" for i in 1:24])
    to_as(p::PH2_BP) = isempty(p) ? R(0) : sum(begin
        mon = R(1)
        for i in 0:23; (m >> i) & 1 == 1 && (mon *= cv[i + 1]); end
        mon
    end for m in p)
    gens = AS.elem_type(R)[to_as(p) for p in gensBP]
    for i in 1:24; push!(gens, cv[i]^2 + cv[i]); end

    gb = AS.groebner_basis(AS.Ideal(gens))
    (length(gb) == 1 && AS.is_constant(gb[1]) && !iszero(gb[1])) && return SBox{8}[]
    gbBP = PH2_BP[ph2_to_bp(g) for g in gb]; filter!(g -> !isempty(g), gbBP)

    seen = Set{Vector{UInt8}}(); out = SBox{8}[]
    for sol in ph2_variety(gbBP)
        c = copy(coeffs)
        for (i, v) in enumerate(free); c[v + 1] = ((sol >> (i - 1)) & 1) == 1; end
        l = coeffs_to_lut(c)
        F = SBox{8}(l)
        verify && differential_uniformity(F) != 2 && continue
        l in seen && continue
        push!(seen, l); push!(out, F)
    end
    out
end
