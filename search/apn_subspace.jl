# search/apn_subspace.jl — the engine for Phases 2-4.
#
# Objects
# -------
# A homogeneous quadratic F : F_2^8 -> F_2^8 is 224 ANF coefficients
# c_{(p,q),k}: F_k(x) = XOR_{p<q} c_{(p,q),k} x_p x_q. Indexing matches
# Kuznetsov (2026) Eq. (2): col_idx(p,q,k) = pair_index(p,q)*8 + k.
#
# V_A = ker(M_A) is the subspace of those F commuting with A (F.A = A.F).
#
# The APN test used here
# ----------------------
# For a homogeneous quadratic F, the polarisation
#     B(x,y) = F(x+y) + F(x) + F(y)
# is bilinear, and D_a F(x) = B(x,a) + F(a) is affine. So
#
#     F is APN  <=>  for every a != 0, |ker(x -> B(x,a))| = 2.
#
# B(a,a) = 0 always, so a is always in that kernel; the condition is exactly
#     rank(L_a) = 7   for all a != 0,   where L_a(x) = B(x,a).
#
# This is worth doing rather than calling differential_uniformity because L_a is
# LINEAR IN THE COEFFICIENT VECTOR. Precomputing L_a for each basis vector of
# V_A turns "evaluate F, build its DDT" into "XOR d words, take one 8x8 rank",
# and a Gray-code walk makes it one XOR per candidate. Non-APN candidates almost
# always die on the first a tested, so the sweep is dominated by a single rank.
#
# Every APN found here is re-verified with VBF.differential_uniformity — a
# completely different code path — before it is ever reported.

using VBF
using TOML

const NBITS = 8
const NPTS = 1 << NBITS
const NPAIRS = 28
const NCOEF = 224

pair_index(p::Int, q::Int)::Int = p * (15 - p) ÷ 2 + q - p - 1
row_idx(j::Int, r::Int, s::Int)::Int = j * NPAIRS + pair_index(r, s)
col_idx(p::Int, q::Int, k::Int)::Int = pair_index(p, q) * NBITS + k

# pair number -> (p,q)
const PAIR_PQ = let v = Vector{Tuple{Int,Int}}(undef, NPAIRS)
    for p = 0:6, q = (p+1):7
        v[pair_index(p, q)+1] = (p, q)
    end
    v
end

# ── M_A and its kernel ──────────────────────────────────────────────────────

function build_M_A(A::Matrix{Bool})::BitMatrix
    M = falses(NCOEF, NCOEF)
    for j = 0:7, r = 0:6, s = (r+1):7
        row = row_idx(j, r, s) + 1
        for p = 0:6, q = (p+1):7
            val = (A[p+1, r+1] & A[q+1, s+1]) ⊻ (A[p+1, s+1] & A[q+1, r+1])
            val && (M[row, col_idx(p, q, j)+1] ⊻= true)
        end
        for k = 0:7
            A[j+1, k+1] && (M[row, col_idx(r, s, k)+1] ⊻= true)
        end
    end
    M
end

"""
    build_M_AB(A, B) -> BitMatrix

The self-equivalence system `F.A = B.F` over the 224 quadratic ANF coefficients.
[`build_M_A`](@ref) is the special case `B = A`.

This is the object BBL2021's Table 1 is about: their classes are PAIRS `(A, B)`
and `A != B` for 16 of the 32 n=8 classes, so the `A`-commutant and the
self-equivalence space genuinely differ there.

Both systems match only the DEGREE-2 part of `F.A` and `B.F`. `F(Ax)` can pick up
linear terms (the `r = s` diagonal of the expansion) that `B F(x)` has none of, so
these solve the equation modulo affine maps — which is the right notion here,
since the whole search works up to EA-equivalence anyway.
"""
function build_M_AB(A::Matrix{Bool}, B::Matrix{Bool})::BitMatrix
    M = falses(NCOEF, NCOEF)
    for j = 0:7, r = 0:6, s = (r+1):7
        row = row_idx(j, r, s) + 1
        for p = 0:6, q = (p+1):7
            val = (A[p+1, r+1] & A[q+1, s+1]) ⊻ (A[p+1, s+1] & A[q+1, r+1])
            val && (M[row, col_idx(p, q, j)+1] ⊻= true)
        end
        for k = 0:7
            B[j+1, k+1] && (M[row, col_idx(r, s, k)+1] ⊻= true)
        end
    end
    M
end

"""RREF over F_2 in place; returns (pivot_cols, free_cols), 1-based."""
function rref_f2!(M::BitMatrix)
    nrows, ncols = size(M)
    prow = 1
    pivots = Int[]
    for c = 1:ncols
        found = 0
        for r = prow:nrows
            if M[r, c]
                found = r
                break
            end
        end
        found == 0 && continue
        push!(pivots, c)
        if found != prow
            tmp = copy(M[found, :])
            M[found, :] = M[prow, :]
            M[prow, :] = tmp
        end
        pr = M[prow, :]
        for r = 1:nrows
            r == prow && continue
            M[r, c] && (M[r, :] .⊻= pr)
        end
        prow += 1
        prow > nrows && break
    end
    (pivots, setdiff(1:ncols, pivots))
end

"""
    kernel_basis(A) -> Vector{BitVector}

An explicit RREF parameterisation of V_A = ker(M_A): one basis vector per free
column, so `sum b_i * basis[i]` over `b in F_2^d` enumerates V_A exactly once
(uniformly, which is what Phase 3's density measurement needs).
"""
function kernel_basis(A::Matrix{Bool}, B::Union{Nothing,Matrix{Bool}} = nothing)
    M = B === nothing ? build_M_A(A) : build_M_AB(A, B)
    pivots, free = rref_f2!(M)
    basis = BitVector[]
    for f in free
        v = falses(NCOEF)
        v[f] = true
        for (i, pc) in enumerate(pivots)
            M[i, f] && (v[pc] = true)
        end
        push!(basis, v)
    end
    (basis = basis, rank = length(pivots), dim = length(free))
end

"""Verify a claimed kernel vector really satisfies M_A v = 0."""
function in_kernel(M::BitMatrix, v::BitVector)
    for r = 1:size(M, 1)
        acc = false
        @inbounds for c = 1:NCOEF
            v[c] && M[r, c] && (acc = !acc)
        end
        acc && return false
    end
    true
end

# ── coefficient vector <-> function ─────────────────────────────────────────

"""LUT of the homogeneous quadratic function with ANF coefficients `c`."""
function coeffs_to_lut(c::BitVector)::Vector{Int}
    lut = zeros(Int, NPTS)
    for x = 0:(NPTS-1)
        v = 0
        @inbounds for pi = 1:NPAIRS
            p, q = PAIR_PQ[pi]
            if ((x >> p) & 1) == 1 && ((x >> q) & 1) == 1
                base = (pi - 1) * NBITS
                for k = 0:7
                    c[base+k+1] && (v ⊻= (1 << k))
                end
            end
        end
        lut[x+1] = v
    end
    lut
end

"""ANF coefficients of an arbitrary homogeneous-quadratic LUT (Möbius, degree 2)."""
function lut_to_coeffs(lut::Vector{Int})::BitVector
    c = falses(NCOEF)
    for pi = 1:NPAIRS
        p, q = PAIR_PQ[pi]
        # coefficient of x_p x_q in F_k = sum over the 2-cube {0, e_p, e_q, e_p+e_q}
        # NOTE the parentheses: `|` binds looser than `+` in Julia, so
        # `(1<<p)|(1<<q)+1` would index e_0+e_p+e_q, not e_p+e_q.
        m = lut[1] ⊻ lut[(1<<p)+1] ⊻ lut[(1<<q)+1] ⊻ lut[((1<<p)|(1<<q))+1]
        base = (pi - 1) * NBITS
        for k = 0:7
            ((m >> k) & 1) == 1 && (c[base+k+1] = true)
        end
    end
    c
end

# ── the fast quadratic APN test ─────────────────────────────────────────────
#
# L_a packed as a UInt64: byte j (j = 0..7) is L_a(e_j) as an 8-bit column.

"""
    la_of_coeffs(c, a) -> UInt64

`L_a` for the single coefficient vector `c`. `L_a(e_j)_k = XOR_{r != j}
c_{pair(j,r),k} & a_r`.
"""
function la_of_coeffs(c::BitVector, a::Int)::UInt64
    out = UInt64(0)
    for j = 0:7
        colv = 0
        for r = 0:7
            r == j && continue
            ((a >> r) & 1) == 1 || continue
            p, q = min(j, r), max(j, r)
            base = pair_index(p, q) * NBITS
            for k = 0:7
                c[base+k+1] && (colv ⊻= (1 << k))
            end
        end
        out |= UInt64(colv & 0xff) << (8 * j)
    end
    out
end

"""
    rank8(m::UInt64) -> Int

F_2 rank of the 8 byte-columns packed in `m`.
"""
@inline function rank8(m::UInt64)
    # pivots[i] holds a reduced vector whose leading (lowest set) bit is i
    p0 = p1 = p2 = p3 = p4 = p5 = p6 = p7 = UInt8(0)
    r = 0
    @inbounds for j = 0:7
        v = UInt8((m >> (8 * j)) & 0xff)
        while v != 0
            b = trailing_zeros(v)
            pv = b == 0 ? p0 : b == 1 ? p1 : b == 2 ? p2 : b == 3 ? p3 :
                 b == 4 ? p4 : b == 5 ? p5 : b == 6 ? p6 : p7
            if pv == 0
                b == 0 ? (p0 = v) : b == 1 ? (p1 = v) : b == 2 ? (p2 = v) :
                b == 3 ? (p3 = v) : b == 4 ? (p4 = v) : b == 5 ? (p5 = v) :
                b == 6 ? (p6 = v) : (p7 = v)
                r += 1
                break
            end
            v ⊻= pv
        end
    end
    r
end

"""
    precompute_la(basis) -> Matrix{UInt64}

`P[a, i]` = `L_a` of basis vector `i`. `L_a` is linear in the coefficient
vector, so for `F = XOR_{i in S} basis[i]`, `L_a(F) = XOR_{i in S} P[a, i]`.
"""
function precompute_la(basis::Vector{BitVector})
    d = length(basis)
    P = Matrix{UInt64}(undef, NPTS - 1, d)
    for a = 1:(NPTS-1), i = 1:d
        P[a, i] = la_of_coeffs(basis[i], a)
    end
    P
end

"""
    is_apn_from_la(la_vec) -> Bool

`la_vec[a] = L_a`. APN iff every `L_a` has rank 7.
"""
function is_apn_from_la(la::Vector{UInt64})
    @inbounds for a = 1:(NPTS-1)
        rank8(la[a]) == 7 || return false
    end
    true
end

# Reference (slow, independent) APN test straight from the LUT.
function is_apn_reference(lut::Vector{Int})
    F = SBox{NBITS}(lut)
    differential_uniformity(F) == 2
end
