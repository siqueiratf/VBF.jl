# Implements paper-local helpers for the Kuznetsov (2026) reproduction.
# Paper: Kuznetsov (2026), "Quadratic APN Functions in Dimension 8 via
#        Gröbner Basis Search in a Self-Equivalence Subspace",
#        IEEE Trans. Inf. Theory (2026) / arXiv:2606.11967
# Section: General — V_A construction, RREF, fc22+sol22 parameterization
#
# VBF API used: print_banner, differential_uniformity, ortho_derivative,
#               differential_spectrum, absolute_walsh_spectrum,
#               algebraic_degree, is_permutation, gold_apn, SBox

using VBF

function print_header(io::IO = stdout)
    print_banner(io,
        "Kuznetsov (2026): Quadratic APN Functions in Dimension 8",
        "via Gröbner Basis Search in a Self-Equivalence Subspace",
        "IEEE Trans. Inf. Theory (2026) / arXiv:2606.11967",
        "n = 8,  V_A: BBL2021 class index 22,  dim(V_A) = 40")
end

# ─── Section IV.A — The automorphism A ──────────────────────────────────────

"""
Build the 8×8 binary matrix A = block_diag(C(q), C(q)) ∈ GL(8, F₂),
where q = X⁴+X³+X²+X+1.  A[i+1, j+1] is the (i,j) entry (0-indexed i,j).
Eq.(1) in the paper.
"""
function build_A_matrix()::Matrix{Bool}
    # Rows 0..3 (cols 0..7): C(q) block in top-left
    # Rows 4..7 (cols 0..7): C(q) block in bottom-right
    A = falses(8, 8)
    # C(q): row i has a 1 in col 3 for all i, plus a 1 in col (i-1) for i≥1
    A[1, 4] = true                    # row 0: col 3
    A[2, 1] = true; A[2, 4] = true   # row 1: cols 0,3
    A[3, 2] = true; A[3, 4] = true   # row 2: cols 1,3
    A[4, 3] = true; A[4, 4] = true   # row 3: cols 2,3
    A[5, 8] = true                    # row 4: col 7
    A[6, 5] = true; A[6, 8] = true   # row 5: cols 4,7
    A[7, 6] = true; A[7, 8] = true   # row 6: cols 5,7
    A[8, 7] = true; A[8, 8] = true   # row 7: cols 6,7
    A
end

"""Apply the 8×8 F₂ matrix A to an 8-bit integer x. Returns A·x as UInt8."""
function apply_matrix(A::Matrix{Bool}, x::Integer)::UInt8
    result = UInt8(0)
    xi = Int(x)
    for i in 0:7
        bit = 0
        for j in 0:7
            bit ⊻= (A[i+1, j+1] ? 1 : 0) & ((xi >> j) & 1)
        end
        result |= UInt8(bit & 1) << i
    end
    result
end

"""Multiply two 8×8 F₂ matrices."""
function matmul_f2(A::Matrix{Bool}, B::Matrix{Bool})::Matrix{Bool}
    C = falses(8, 8)
    for i in 1:8, j in 1:8, k in 1:8
        C[i, j] ⊻= A[i, k] & B[k, j]
    end
    C
end

"""Build the 256-element LUT of A: A_lut[x+1] = A(x) for x ∈ 0:255."""
function build_A_lut(A::Matrix{Bool})::Vector{UInt8}
    UInt8[apply_matrix(A, UInt8(x)) for x in 0:255]
end

# ─── Section IV.B — The linear system M_A ───────────────────────────────────

"""
Lexicographic index of pair (p,q) with 0 ≤ p < q ≤ 7.
idx(p,q) = p*(2*8-p-1)/2 + q - p - 1 ∈ {0,...,27}.
"""
function pair_index(p::Int, q::Int)::Int
    p * (15 - p) ÷ 2 + q - p - 1
end

"""Row index in M_A for equation (j, r, s): j∈0:7, 0≤r<s≤7."""
row_idx(j::Int, r::Int, s::Int) = j * 28 + pair_index(r, s)

"""Column index in M_A for coefficient c_{(p,q),k}: 0≤p<q≤7, k∈0:7."""
col_idx(p::Int, q::Int, k::Int) = pair_index(p, q) * 8 + k

"""
Build the 224×224 BitMatrix M_A such that V_A = ker(M_A).

For each output bit j ∈ {0..7} and each pair (r,s) with r<s, the equation
enforcing the coefficient of x_r·x_s in [F(Ax) ⊕ A(Fx)]_j = 0 gives one row
of M_A.  Formula (2) in the paper:

  M_A[row(j,r,s), col(p,q,k)] = (A[p,r]·A[q,s] ⊕ A[p,s]·A[q,r])·[k=j]
                                 ⊕ A[j,k]·[(p,q)=(r,s)]
"""
function build_M_A(A::Matrix{Bool})::BitMatrix
    M = falses(224, 224)
    for j in 0:7, r in 0:6, s in (r+1):7
        row = row_idx(j, r, s) + 1
        # LHS contribution: coefficient of c_{(p,q),j} for all pairs (p,q)
        for p in 0:6, q in (p+1):7
            val = (A[p+1, r+1] & A[q+1, s+1]) ⊻ (A[p+1, s+1] & A[q+1, r+1])
            val && (M[row, col_idx(p, q, j) + 1] ⊻= true)
        end
        # RHS contribution: coefficient of c_{(r,s),k} for all k
        for k in 0:7
            A[j+1, k+1] && (M[row, col_idx(r, s, k) + 1] ⊻= true)
        end
    end
    M
end

# ─── Section IV.C — RREF and fc22+sol22 ─────────────────────────────────────

"""
Compute the fc22+sol22 parameterization from M_A.

Returns a NamedTuple with:
  pivot_cols  — 184 column indices (1-based) of pivot variables
  free_cols   — 40 column indices (1-based) of free variables
  S           — S[i] = indices j ∈ 1:40 s.t. RREF row i has 1 in free_cols[j]
"""
function fc22_sol22(A::Matrix{Bool})
    M = build_M_A(A)
    pivot_cols, free_cols = VBF.rref_f2!(M)
    n_pivots = length(pivot_cols)
    n_free   = length(free_cols)
    S = [Int[] for _ in 1:n_pivots]
    for i in 1:n_pivots
        for (j, fc) in enumerate(free_cols)
            M[i, fc] && push!(S[i], j)
        end
    end
    (; pivot_cols, free_cols, S)
end

"""
Map b ∈ {0,1}^40 → c ∈ {0,1}^224 via fc22+sol22 (Eqs. 3–4).
"""
function apply_fc22_sol22(
    b::AbstractVector{Bool},
    pivot_cols::Vector{Int},
    free_cols::Vector{Int},
    S::Vector{Vector{Int}},
)::Vector{Bool}
    c = falses(224)
    for (k, fc) in enumerate(free_cols)
        c[fc] = b[k]
    end
    for (i, pc) in enumerate(pivot_cols)
        val = false
        for j in S[i]
            val ⊻= b[j]
        end
        c[pc] = val
    end
    c
end

"""
Build the 256-element LUT of the purely quadratic function F with ANF
coefficient vector c (c[pair_index(p,q)*8 + k + 1] = 1 iff x_p·x_q
appears in output bit k of F).
"""
function quadratic_lut(c::AbstractVector{Bool})::Vector{UInt8}
    lut = zeros(UInt8, 256)
    pidx = 0
    for p in 0:6, q in (p+1):7
        # Aggregate the 8-bit contribution row for pair (p,q)
        contrib = UInt8(0)
        for k in 0:7
            c[pidx * 8 + k + 1] && (contrib |= UInt8(1 << k))
        end
        if contrib != 0
            for x in 0:255
                ((x >> p) & 1 == 1) && ((x >> q) & 1 == 1) && (lut[x+1] ⊻= contrib)
            end
        end
        pidx += 1
    end
    lut
end

# ─── V_A membership test ─────────────────────────────────────────────────────

"""
Return true iff F(A(x)) = A(F(x)) for all x ∈ {0,...,255}.
"""
function in_va(
    lut::AbstractVector{UInt8},
    A_lut::AbstractVector{UInt8},
    A::Matrix{Bool},
)::Bool
    for x in 0:255
        Ax  = Int(A_lut[x+1])
        FAx = lut[Ax+1]
        AFx = apply_matrix(A, Int(lut[x+1]))
        FAx == AFx || return false
    end
    true
end

# ─── Representative S-boxes (Table VII) ──────────────────────────────────────

"""
The six representative S-boxes from Table VII / Table III of the paper
(one genuine CCZ-class representative per class).  Source: the author's
artifact `codes_mencioned_in_original_paper/ccz_verify_representatives.m`
(github.com/KuznetsovKarazin/apn-gb-search).  Per Table III, CLASS-A, E, F
lie inside V_A (F∘A = A∘F); CLASS-B, C, D lie outside.  CLASS-E is a V_A
copy of Gold x³/x¹²⁹; CLASS-F a V_A copy of Gold x⁹/x³³ (note these are the
self-equivalent copies, NOT the canonical monomials, which are not in V_A).
"""
function representative_sboxes()
    # CLASS-A — sig 9d95d9c4 — new (CLASS-001)
    class_a = UInt8[
        0,0,0,50,0,41,100,127,0,250,77,133,200,27,225,0,0,106,12,84,175,236,199,182,46,190,111,205,73,240,108,231,
        0,62,203,199,7,16,168,141,177,117,55,193,126,147,156,67,158,202,89,63,54,75,149,218,1,175,139,23,97,230,143,58,
        0,134,99,215,121,214,126,227,14,114,32,110,191,234,245,146,225,13,142,80,55,242,60,203,193,215,227,199,223,224,153,148,
        211,107,123,241,173,60,97,194,108,46,137,249,218,177,91,2,172,126,8,232,125,134,189,116,61,21,212,206,36,37,169,154,
        0,212,252,26,198,59,94,145,237,195,92,64,227,228,54,3,200,118,56,180,161,54,53,144,11,79,182,192,170,199,115,44,
        50,216,5,221,243,48,160,81,110,126,20,54,103,94,121,114,100,228,95,237,10,163,85,206,22,108,96,40,176,227,162,195,
        86,4,201,169,233,146,18,91,181,29,103,253,194,67,116,199,127,71,236,230,111,126,152,187,178,112,108,156,106,129,208,9,
        183,219,227,189,15,74,63,72,229,115,252,88,149,42,232,101,0,6,88,108,23,56,43,54,124,128,105,167,163,118,210,53,
    ]

    # CLASS-B — sig c5f52f56 — new (CLASS-004)
    class_b = UInt8[
        0,0,0,38,0,148,76,254,0,161,216,95,135,178,19,0,0,185,253,98,62,19,143,132,52,44,17,47,141,1,228,78,
        0,131,157,56,21,2,196,245,99,65,38,34,241,71,248,104,226,216,130,158,201,103,229,109,181,46,13,176,25,22,237,196,
        0,207,246,31,213,142,111,18,42,68,4,76,120,130,26,198,25,111,18,66,242,16,181,113,7,208,212,37,107,40,244,145,
        160,236,203,161,96,184,71,185,233,4,90,145,174,215,81,14,91,174,205,30,165,196,127,56,38,114,104,26,95,159,93,187,
        0,124,113,43,28,244,33,239,90,135,243,8,193,136,36,75,138,79,6,229,168,249,104,31,228,128,176,242,65,177,89,143,
        185,70,85,140,176,219,16,93,128,222,180,204,14,196,118,154,209,151,192,160,230,52,187,79,220,59,21,212,108,31,233,188,
        104,219,239,122,161,134,106,107,24,10,71,115,86,208,69,229,251,241,129,173,12,146,58,130,191,20,29,144,207,240,33,56,
        113,65,107,125,173,9,251,121,98,243,160,23,57,60,183,148,0,137,231,72,226,255,73,114,39,15,24,22,66,254,49,171,
    ]

    # CLASS-C — sig 74a30c1a — new (CLASS-006)
    class_c = UInt8[
        0,0,0,38,0,148,76,254,0,161,216,95,135,178,19,0,0,185,253,98,62,19,143,132,52,44,17,47,141,1,228,78,
        0,131,157,56,21,2,196,245,99,65,38,34,241,71,248,104,226,216,130,158,201,103,229,109,181,46,13,176,25,22,237,196,
        0,207,246,31,213,142,111,18,42,68,4,76,120,130,26,198,25,111,18,66,242,16,181,113,7,208,212,37,107,40,244,145,
        94,18,53,95,158,70,185,71,23,250,164,111,80,41,175,240,165,80,51,224,91,58,129,198,216,140,150,228,161,97,163,69,
        0,124,113,43,28,244,33,239,90,135,243,8,193,136,36,75,138,79,6,229,168,249,104,31,228,128,176,242,65,177,89,143,
        71,184,171,114,78,37,238,163,126,32,74,50,240,58,136,100,47,105,62,94,24,202,69,177,34,197,235,42,146,225,23,66,
        104,219,239,122,161,134,106,107,24,10,71,115,86,208,69,229,251,241,129,173,12,146,58,130,191,20,29,144,207,240,33,56,
        113,65,107,125,173,9,251,121,98,243,160,23,57,60,183,148,0,137,231,72,226,255,73,114,39,15,24,22,66,254,49,171,
    ]

    # CLASS-D — sig 024ba500 — new (CLASS-003)
    class_d = UInt8[
        0,0,0,207,0,138,113,52,0,45,251,25,226,69,104,0,0,237,39,5,170,205,252,84,130,66,94,81,202,128,103,226,
        0,52,53,206,78,240,10,123,187,162,117,163,23,132,168,244,106,179,120,110,142,221,237,113,83,167,186,129,85,43,205,124,
        0,24,104,191,106,248,115,46,131,182,16,234,11,180,233,153,76,185,3,57,140,243,178,2,77,149,249,238,111,61,170,55,
        151,187,202,41,179,21,159,246,175,174,9,199,105,226,190,250,177,112,203,197,63,116,52,176,11,231,138,169,103,1,151,62,
        0,221,47,61,207,152,145,9,203,59,31,32,230,156,67,246,19,35,27,228,118,204,15,122,90,71,169,123,221,74,95,7,
        219,50,193,231,90,57,49,157,171,111,74,65,200,134,88,217,162,166,159,84,137,7,197,132,80,121,150,112,153,58,46,66,
        121,188,62,52,220,147,234,106,49,217,141,170,118,20,187,22,38,14,70,161,41,139,56,85,236,233,119,189,1,142,235,171,
        53,196,71,121,222,165,221,105,198,26,79,92,207,153,55,174,0,28,85,134,65,215,101,60,113,64,223,33,210,105,13,121,
    ]

    # CLASS-E — sig 11cc72af — Gold x^3/x^129 (CLASS-005)
    class_e = UInt8[
        0,0,0,38,0,148,76,254,0,161,216,95,135,178,19,0,0,185,253,98,62,19,143,132,52,44,17,47,141,1,228,78,
        0,131,157,56,21,2,196,245,99,65,38,34,241,71,248,104,226,216,130,158,201,103,229,109,181,46,13,176,25,22,237,196,
        0,207,246,31,213,142,111,18,42,68,4,76,120,130,26,198,25,111,18,66,242,16,181,113,7,208,212,37,107,40,244,145,
        52,120,95,53,244,44,211,45,125,144,206,5,58,67,197,154,207,58,89,138,49,80,235,172,178,230,252,142,203,11,201,47,
        0,124,113,43,28,244,33,239,90,135,243,8,193,136,36,75,138,79,6,229,168,249,104,31,228,128,176,242,65,177,89,143,
        45,210,193,24,36,79,132,201,20,74,32,88,154,80,226,14,69,3,84,52,114,160,47,219,72,175,129,64,248,139,125,40,
        104,219,239,122,161,134,106,107,24,10,71,115,86,208,69,229,251,241,129,173,12,146,58,130,191,20,29,144,207,240,33,56,
        113,65,107,125,173,9,251,121,98,243,160,23,57,60,183,148,0,137,231,72,226,255,73,114,39,15,24,22,66,254,49,171,
    ]

    # CLASS-F — sig d15183d1 — Gold x^9/x^33 (CLASS-002)
    class_f = UInt8[
        0,0,0,207,0,138,113,52,0,45,251,25,226,69,104,0,0,237,39,5,170,205,252,84,130,66,94,81,202,128,103,226,
        0,52,53,206,78,240,10,123,187,162,117,163,23,132,168,244,106,179,120,110,142,221,237,113,83,167,186,129,85,43,205,124,
        0,24,104,191,106,248,115,46,131,182,16,234,11,180,233,153,76,185,3,57,140,243,178,2,77,149,249,238,111,61,170,55,
        203,231,150,117,239,73,195,170,243,242,85,155,53,190,226,166,237,44,151,153,99,40,104,236,87,187,214,245,59,93,203,98,
        0,221,47,61,207,152,145,9,203,59,31,32,230,156,67,246,19,35,27,228,118,204,15,122,90,71,169,123,221,74,95,7,
        135,110,157,187,6,101,109,193,247,51,22,29,148,218,4,133,254,250,195,8,213,91,153,216,12,37,202,44,197,102,114,30,
        121,188,62,52,220,147,234,106,49,217,141,170,118,20,187,22,38,14,70,161,41,139,56,85,236,233,119,189,1,142,235,171,
        53,196,71,121,222,165,221,105,198,26,79,92,207,153,55,174,0,28,85,134,65,215,101,60,113,64,223,33,210,105,13,121,
    ]

    (;
        class_a = SBox{8}(class_a),
        class_b = SBox{8}(class_b),
        class_c = SBox{8}(class_c),
        class_d = SBox{8}(class_d),
        class_e = SBox{8}(class_e),
        class_f = SBox{8}(class_f),
    )
end

# M_A and quadratic_lut use pair-major coefficients, unlike phase2.jl's
# output-major polynomial variables. These indices always use col_idx.
const SLICE_INTRA_PAIRS = ((5, 6), (5, 7), (6, 7))
slice_intra_indices() = [col_idx(p, q, k) + 1 for (p, q) in SLICE_INTRA_PAIRS for k in 0:7]
slice_center_indices() = setdiff(collect(1:224), slice_intra_indices())

"""Lossless identity of the 200 fixed coordinates of a phase-2 slice."""
function slice_identifier(c::AbstractVector)
    length(c) == 224 || throw(ArgumentError("expected 224 pair-major coefficients"))
    Tuple(Bool(c[i]) for i in slice_center_indices())
end

"""Exact GF(2) geometry; a slice is the full center projection, not 16 bits."""
function slice_geometry(A = build_A_matrix())
    M = build_M_A(A)
    intra, center = slice_intra_indices(), slice_center_indices()
    rank_intra = length(first(VBF.rref_f2!(copy(M[:, intra]))))
    rank_center = length(first(VBF.rref_f2!(copy(M[:, center]))))
    rank_total = length(first(VBF.rref_f2!(copy(M))))
    dimension = size(M, 2) - rank_total
    fiber_dimension = length(intra) - rank_intra
    projection_dimension = dimension - fiber_dimension
    _, free_cols = VBF.rref_f2!(copy(M))
    (; rank_total, rank_intra, rank_center, dimension, fiber_dimension,
       projection_dimension, slice_count = big(2)^projection_dimension,
       free_intra = count(in(intra), free_cols), free_center = count(in(center), free_cols))
end
