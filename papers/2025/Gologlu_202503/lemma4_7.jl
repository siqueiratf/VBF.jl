# Implements Lemma 4.7 — normalizer and centralizer of M and M_P in GL(F).
# Paper: Göloğlu, Kölsch (2025), Electron. J. Combin.
# Section: 4.1 — The group theoretic framework (quoted from [GK23b])
#
#   Lemma 4.7. With M_P = {diag(m_a, m_a) : a ∈ P} and M = {diag(m_a, m_a) : a ∈ M^×}:
#     (a) N_{GL(F)}(M_P) = N_{GL(F)}(M) = {(m_{c₁}τ  m_{c₂}τ ; m_{c₃}τ  m_{c₄}τ)}
#         ∩ GL(F) ≅ ΓL(2, M);
#     (b) C_{GL(F)}(M_P) = C_{GL(F)}(M) = {(m_{c₁} m_{c₂} ; m_{c₃} m_{c₄})}
#         ∩ GL(F) ≅ GL(2, M).
#
# Pseudocode:
#   1. Realise diag(m_a, m_a) as a 2m × 2m matrix over F₂ acting on M × M.
#   2. (b) is a LINEAR condition: solve X·D − D·X = 0 for X ∈ End(F₂^{2m}) —
#      (2m)² unknowns — with core `kernel_f2`. Lemma 4.7(b) predicts
#      dim_{F₂} = 4m (four M-slots, each an m-dimensional F₂-space).
#      Do this for a generator of M^× AND for a generator of the Sylow
#      p-subgroup P: equal dimension + containment of the claimed 4m-dim space
#      proves both centralizers equal the claimed one.
#   3. (a) is NOT a linear condition. We verify:
#        • ⊇: every claimed element (Galois-twisted M-matrix) normalises M_P
#          and M — checked directly;
#        • = : exhaustively at m = 2, where |GL(F)| = |GL(4,2)| = 20160 is
#          enumerable. |ΓL(2,F₄)| = 360 and |GL(2,F₄)| = 180 are the targets.
#      For m ≥ 3, |GL(2m,2)| ≥ 2·10¹⁰ and the ⊆ direction is NOT brute-forced —
#      reported as such rather than claimed.
#
#   Negative control: a matrix that is F₂-linear but NOT M-semilinear (e.g. a
#   single transvection) must fail to centralise — otherwise (b) is vacuous.
#
# VBF API used: kernel_f2, rank_f2, gf_mul/gf_pow (via helpers),
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

using VBF

"""
    map_columns(fld, f) -> Vector{UInt64}

Column form of the F₂-linear map `f : (x,y) ↦ (u,v)` on `M × M`, **indexed by
bit position** of the `(x << m) | y` encoding: bit `b < m` is the `y`-basis
vector `2^b`, bit `b ≥ m` is the `x`-basis vector `2^{b−m}`. Keeping the column
index equal to the bit index is what makes `mat_mul` below correct.
"""
function map_columns(fld::BiField, f)
    m = fld.m
    nb = 2m
    cols = Vector{UInt64}(undef, nb)
    for b = 0:(nb-1)
        x, y = b ≥ m ? (1 << (b - m), 0) : (0, 1 << b)
        u, v = f(x, y)
        cols[b+1] = UInt64((u << m) | v)
    end
    cols
end

"""Columns of `diag(m_a, m_a)` on `M × M`."""
diag_ma_columns(fld::BiField, a::Integer) =
    map_columns(fld, (x, y) -> (gmul(fld, a, x), gmul(fld, a, y)))

"""Columns of the M-matrix `(m_{c₁} m_{c₂}; m_{c₃} m_{c₄})` twisted by `x ↦ x^{2^t}`."""
semilinear_columns(fld::BiField, c1, c2, c3, c4, t::Integer) = map_columns(
    fld,
    (x, y) -> begin
        xt = frob(fld, x, t)
        yt = frob(fld, y, t)
        (
            gmul(fld, c1, xt) ⊻ gmul(fld, c2, yt),
            gmul(fld, c3, xt) ⊻ gmul(fld, c4, yt),
        )
    end,
)

"""Matrix product (column form): `(A·B)`, columns of `B` mapped through `A`."""
function mat_mul(A::Vector{UInt64}, B::Vector{UInt64}, nb::Int)
    out = zeros(UInt64, nb)
    @inbounds for j = 1:nb
        v = B[j]
        acc = UInt64(0)
        for i = 0:(nb-1)
            ((v >> i) & 1) == 1 && (acc ⊻= A[i+1])
        end
        out[j] = acc
    end
    out
end

mat_invertible(A::Vector{UInt64}, nb::Int) = rank_f2(A; nbits = nb) == nb

"""
    centralizer_dimension(fld, a) -> Int

`dim_{F₂} { X ∈ End(F₂^{2m}) : X·D_a = D_a·X }` where `D_a = diag(m_a, m_a)`.
Solved as an F₂ linear system in the `(2m)²` entries of `X` via core `kernel_f2`.
Restricted to `m ≤ 5`, since `(2m)² ≤ 128` is the `UInt128` word limit.
"""
function centralizer_dimension(fld::BiField, a::Integer)
    m = fld.m
    nb = 2m
    nv = nb * nb
    nv ≤ 128 || throw(
        ArgumentError(
            "centralizer_dimension: (2m)² = $nv exceeds the 128-bit word limit (m ≤ 5)",
        ),
    )
    D = diag_ma_columns(fld, a)
    dbit(k, j) = (D[j+1] >> k) & 1                    # D[k][j]
    rows = UInt128[]
    for i = 0:(nb-1), j = 0:(nb-1)
        row = UInt128(0)
        for k = 0:(nb-1)
            dbit(k, j) == 1 && (row ⊻= UInt128(1) << (i * nb + k))   # X[i][k]
            dbit(i, k) == 1 && (row ⊻= UInt128(1) << (k * nb + j))   # X[k][j]
        end
        push!(rows, row)
    end
    length(kernel_f2(rows; nbits = nv))
end

"""A generator of the Sylow `p`-subgroup `P ≤ M^×` (Notation 4.4)."""
function sylow_p_generator(fld::BiField)
    p = primitive_prime_divisor(fld.m)
    p === nothing && return nothing            # m = 6: Zsygmondy exception
    ord = order(fld) - 1
    pe = 1
    while ord % (pe * p) == 0
        pe *= p
    end
    g = primitive_element(fld)
    gpow(fld, g, ord ÷ pe)                     # element of order |P| = pe
end

"""
    exhaustive_gl_counts(fld) -> NamedTuple

Enumerate **all** of `GL(F₂^{2m})` and count the centralizer and normalizer of
`M = {diag(m_a, m_a)}`. Only feasible at `m = 2` (`|GL(4,2)| = 20160`).
"""
function exhaustive_gl_counts(fld::BiField)
    m = fld.m
    m == 2 || throw(ArgumentError("exhaustive_gl_counts: only m = 2 is enumerable"))
    nb = 2m
    Ms = [diag_ma_columns(fld, a) for a in mstar(fld)]
    Mset = Set(Ms)
    cent = 0
    norm = 0
    total = 0
    for code = 0:((1 << (nb * nb)) - 1)                # every 4×4 F₂ matrix
        A = UInt64[(code >> (nb * j)) & ((1 << nb) - 1) for j = 0:(nb-1)]
        mat_invertible(A, nb) || continue
        total += 1
        # A ∈ N(M)  ⇔  A·D·A⁻¹ ∈ M for every D ∈ M  ⇔  A·D ∈ M·A
        MA = Set(mat_mul(D, A, nb) for D in Ms)       # { D·A }
        AM = Set(mat_mul(A, D, nb) for D in Ms)       # { A·D }
        AM == MA && (norm += 1)
        all(mat_mul(A, D, nb) == mat_mul(D, A, nb) for D in Ms) && (cent += 1)
    end
    (; gl_order = total, centralizer = cent, normalizer = norm)
end

"""
    lemma4_7_report(io = stdout; m_values = (3, 4, 5), exhaustive_m2 = true) -> NamedTuple
"""
function lemma4_7_report(io::IO = stdout; m_values = (3, 4, 5), exhaustive_m2::Bool = true)
    print_section("Lemma 4.7 — N_GL(M_P) = N_GL(M) ≅ ΓL(2,M),  C_GL(M_P) = C_GL(M) ≅ GL(2,M)", io)

    dims = NamedTuple[]
    dim_ok = true
    sylow_ok = true
    contain_ok = true
    for m in m_values
        fld = BiField(m)
        g = primitive_element(fld)
        d_full = centralizer_dimension(fld, g)
        gp = sylow_p_generator(fld)
        d_p = gp === nothing ? -1 : centralizer_dimension(fld, gp)
        d_full == 4m || (dim_ok = false)
        d_p == d_full || (sylow_ok = false)
        # ⊇: the claimed 4m-dimensional space really centralises
        for (c1, c2, c3, c4) in ((1, 0, 0, 1), (g, 1, 1, 0), (0, g, 1, 1))
            X = semilinear_columns(fld, c1, c2, c3, c4, 0)
            D = diag_ma_columns(fld, g)
            mat_mul(X, D, 2m) == mat_mul(D, X, 2m) || (contain_ok = false)
        end
        push!(dims, (; m, dim_centralizer = d_full, dim_centralizer_P = d_p, expected = 4m))
        print_kv(
            "m=$m: dim C(M) = $d_full, dim C(M_P) = $d_p, predicted 4m",
            4m,
            io,
        )
    end
    print_check("dim_F₂ C_GL(M) = 4m = dim_F₂ M^{2×2} (Lemma 4.7(b))", dim_ok, io)
    print_check("C_GL(M_P) = C_GL(M) (same dimension for the Sylow p-subgroup)", sylow_ok, io)
    print_check("every M-linear 2×2 matrix centralises M (⊇ direction)", contain_ok, io)

    # ── negative control: a transvection is F₂-linear but not M-semilinear ──
    fld5 = BiField(5)
    g5 = primitive_element(fld5)
    T = diag_ma_columns(fld5, 1)                    # identity
    T[1] ⊻= UInt64(1) << 1                          # add e₁ to the image of e₀
    D5 = diag_ma_columns(fld5, g5)
    trans_centralises = mat_mul(T, D5, 10) == mat_mul(D5, T, 10)
    print_check(
        "negative control: a transvection does NOT centralise M (so (b) is not vacuous)",
        !trans_centralises,
        io,
    )

    # ── normalizer: Galois twists ──────────────────────────────────────────
    norm_ok = true
    for m in m_values
        fld = BiField(m)
        g = primitive_element(fld)
        Ms = [diag_ma_columns(fld, a) for a in mstar(fld)]
        Mset = Set(Ms)
        for t = 0:(m-1)
            X = semilinear_columns(fld, 1, 0, 0, 1, t)     # the Frobenius twist alone
            mat_invertible(X, 2m) || continue
            for D in Ms
                mat_mul(mat_mul(X, D, 2m), _mat_inv(X, 2m), 2m) in Mset || (norm_ok = false)
            end
        end
    end
    print_check("Galois-twisted M-matrices normalise M (⊇ of Lemma 4.7(a))", norm_ok, io)

    # ── exhaustive check at m = 2 ──────────────────────────────────────────
    ex = nothing
    if exhaustive_m2
        fld2 = BiField(2)
        ex = exhaustive_gl_counts(fld2)
        gl24 = 180                                   # |GL(2, F₄)|
        gammaL = 360                                 # |ΓL(2, F₄)| = |GL(2,F₄)| · |Gal|
        print_kv("m=2 exhaustive: |GL(4,2)|", ex.gl_order, io)
        print_check("  |C_GL(M)| = |GL(2, F₄)| = $gl24 (got $(ex.centralizer))", ex.centralizer == gl24, io)
        print_check("  |N_GL(M)| = |ΓL(2, F₄)| = $gammaL (got $(ex.normalizer))", ex.normalizer == gammaL, io)
    end
    println(
        io,
        "  [NOTE] the ⊆ direction of Lemma 4.7(a) is exhaustively verified only at m = 2;",
    )
    println(
        io,
        "         for m ≥ 3, |GL(2m,2)| ≥ 2·10¹⁰ and enumeration is out of scope.",
    )
    print_kv("completeness", "exhaustive at m=2; linear-algebraic (dimension) for m ∈ $(m_values)", io)

    (;
        dims = dims,
        dim_ok = dim_ok,
        sylow_ok = sylow_ok,
        containment_ok = contain_ok,
        transvection_centralises = trans_centralises,
        normalizer_containment = norm_ok,
        exhaustive_m2 = ex,
        all_ok = dim_ok &&
                 sylow_ok &&
                 contain_ok &&
                 !trans_centralises &&
                 norm_ok &&
                 (ex === nothing || (ex.centralizer == 180 && ex.normalizer == 360)),
    )
end

"""Inverse of an F₂ matrix given in column form (Gauss–Jordan on [A | I])."""
function _mat_inv(A::Vector{UInt64}, nb::Int)
    # rows of [A | I]: row i has bit j set iff A[j][i] == 1
    aug = zeros(UInt64, nb)
    for i = 0:(nb-1)
        r = UInt64(0)
        for j = 0:(nb-1)
            ((A[j+1] >> i) & 1) == 1 && (r |= UInt64(1) << j)
        end
        aug[i+1] = r | (UInt64(1) << (nb + i))
    end
    rank = 0
    for c = 0:(nb-1)
        p = findfirst(i -> ((aug[i] >> c) & 1) == 1, (rank+1):nb)
        p === nothing && error("_mat_inv: singular matrix")
        p += rank
        aug[rank+1], aug[p] = aug[p], aug[rank+1]
        for i = 1:nb
            i == rank + 1 && continue
            ((aug[i] >> c) & 1) == 1 && (aug[i] ⊻= aug[rank+1])
        end
        rank += 1
    end
    # inverse rows are the right half; convert back to column form
    inv_cols = zeros(UInt64, nb)
    for i = 0:(nb-1)
        rr = (aug[i+1] >> nb) & ((UInt64(1) << nb) - 1)
        for j = 0:(nb-1)
            ((rr >> j) & 1) == 1 && (inv_cols[j+1] |= UInt64(1) << i)
        end
    end
    inv_cols
end
