# Implements shared helpers for Calderini (2020) paper reproduction.
# Paper: Calderini (2020), "On the EA-classes of known APN functions in small dimensions"
# Cryptography and Communications 12:821-840
#
# Field convention: the paper computes in MAGMA, whose default GF(2⁶) generator
# is the Conway-polynomial root (x⁶+x⁴+x³+x+1). All ζ-power coefficients from
# the paper are therefore interpreted with `conway_polynomial(n)` as modulus and
# ζ = 0b10. Empirical confirmation: the Section 5.1 polynomials F₁, F₂, F₃ are
# APN permutations under the Conway modulus, and are NOT APN under
# `primitive_polynomial(6)` = x⁶+x+1; likewise VBF's `kim_apn()` (Conway) matches
# the paper's Kim function x³ + ζx²⁴ + x¹⁰ exactly.
#
# Pseudocode:
#   1. C₂(F), C₃(F), C₄(F): equivalence codes of Section 4 (Theorems 5/6).
#      NOTE the paper's numbering: C₂ = EA code (1,x,F(x)) ∪ (0,0,y);
#      C₃ = affine code, adds (0,z,0); C₄ = permutation affine code, third
#      block (1,z,0) over ALL z (2ⁿ columns, so 3·2ⁿ-1 total).
#      (VBF's `ea_matrix` packs its y-columns at the wrong row offset — bits
#      land in the constant/x rows instead of the F(x) block — so this file
#      builds the Edel-Pott C₂ itself; see `c2_matrix`.)
#   2. code_weight_enumerator / shortened_weight_enumerators: cheap code
#      invariants (equivalent codes ⟹ equal enumerators) used to separate
#      EA-classes and to demonstrate the Theorem 6 C₄ separation.
#   3. ZW(λ), S_F: Procedure 2 sets (Section 3, eq. 4).
#   4. sbox_from_zeta_terms: build an SBox from paper (ζ-power, exponent) terms.
#   5. Utilities: power_sbox (via gf_monomial_lut), component_degrees,
#      component_walsh_spectra, cyclotomic_coset.
# VBF API used: lat, conway_polynomial, gf_pow, gf_monomial_lut, terms_to_lut,
#               algebraic_degree, is_permutation, walsh_hadamard

using VBF

"""
    c2_matrix(F) -> BitMatrix

(2n+1) × (2^{n+1}-1) generator matrix of the EA-equivalence code C₂(F)
(Section 4): columns (1, x, F(x)) for x ∈ F₂ⁿ plus (0, 0, y) for y ∈ F₂ⁿ*.
F EA-equivalent to G iff C₂(F) ≅ C₂(G) (Theorem 5, [Edel-Pott Thm 10]).
"""
function c2_matrix(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    M = falses(2N + 1, 2n_size - 1)
    @inbounds for x = 0:(n_size - 1)
        M[1, x + 1] = true
        v = (UInt64(x) << N) | UInt64(F.lut[x + 1])
        for b = 0:(2N - 1)
            M[b + 2, x + 1] = ((v >> b) & 1) == 1
        end
    end
    @inbounds for y = 1:(n_size - 1)
        col = n_size + y
        for b = 0:(N - 1)
            M[N + b + 2, col] = ((UInt64(y) >> b) & 1) == 1
        end
    end
    return M
end

"""
    c3_matrix(F) -> BitMatrix

(2n+1) × (2^{n+1}+2ⁿ-2) generator matrix of the affine-equivalence code C₃(F)
(Section 4): columns (1,x,F(x))ₓ, (0,0,y)_{y≠0}, (0,z,0)_{z≠0}.
For non-permutations with NL≠0: F affine-equivalent to G iff C₃(F) ≅ C₃(G).
For permutations: C₃(F) ≅ C₃(G) iff F is affine-equivalent to G *or* G⁻¹
(Theorem 5, third item — C₃ cannot separate F from F⁻¹).
"""
function c3_matrix(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    M = falses(2N + 1, 3n_size - 2)
    @inbounds for x = 0:(n_size - 1)
        M[1, x + 1] = true
        v = (UInt64(x) << N) | UInt64(F.lut[x + 1])
        for b = 0:(2N - 1)
            M[b + 2, x + 1] = ((v >> b) & 1) == 1
        end
    end
    @inbounds for y = 1:(n_size - 1)
        col = n_size + y
        for b = 0:(N - 1)
            M[N + b + 2, col] = ((UInt64(y) >> b) & 1) == 1
        end
    end
    @inbounds for z = 1:(n_size - 1)
        col = 2n_size - 1 + z
        for b = 0:(N - 1)
            M[b + 2, col] = ((UInt64(z) >> b) & 1) == 1
        end
    end
    return M
end

"""
    c4_matrix(F) -> BitMatrix

(2n+1) × (3·2ⁿ-1) generator matrix of the permutation affine-equivalence code
C₄(F) (Theorem 6): columns (1,x,F(x))ₓ, (0,0,y)_{y≠0}, (1,z,0) for ALL z ∈ F₂ⁿ
(including z = 0 — the paper's third block ranges over the whole field, giving
2^{n+1}+2ⁿ-1 columns). Permutations F and G are affine-equivalent iff
C₄(F) ≅ C₄(G+b) for some b.
"""
function c4_matrix(F::SBox{N,T}) where {N,T}
    is_permutation(F) || throw(ArgumentError("c4_matrix: F must be a permutation"))
    n_size = 1 << N
    M = falses(2N + 1, 3n_size - 1)
    @inbounds for x = 0:(n_size - 1)
        M[1, x + 1] = true
        v = (UInt64(x) << N) | UInt64(F.lut[x + 1])
        for b = 0:(2N - 1)
            M[b + 2, x + 1] = ((v >> b) & 1) == 1
        end
    end
    @inbounds for y = 1:(n_size - 1)
        col = n_size + y
        for b = 0:(N - 1)
            M[N + b + 2, col] = ((UInt64(y) >> b) & 1) == 1
        end
    end
    @inbounds for z = 0:(n_size - 1)
        col = 2n_size - 1 + z + 1
        M[1, col] = true
        for b = 0:(N - 1)
            M[b + 2, col] = ((UInt64(z) >> b) & 1) == 1
        end
    end
    return M
end

"""
    code_weight_enumerator(M::AbstractMatrix{Bool}) -> Vector{Int}

Weight distribution `counts[w+1] = #codewords of Hamming weight w` of the
binary linear code spanned by the rows of `M` (counted with multiplicity
2^(rows - rank), which cancels when comparing codes of equal dimension).
Equivalent codes have equal weight enumerators, so unequal enumerators
*prove* code inequivalence (the converse does not hold).
"""
function code_weight_enumerator(M::AbstractMatrix{Bool})
    r, len = size(M)
    nw = (len + 63) >>> 6
    rows = [zeros(UInt64, nw) for _ = 1:r]
    for i = 1:r, j = 1:len
        M[i, j] && (rows[i][((j - 1) >>> 6) + 1] |= UInt64(1) << ((j - 1) & 63))
    end
    cur = zeros(UInt64, nw)
    counts = zeros(Int, len + 1)
    counts[1] = 1
    for g = 1:((1 << r) - 1)
        row = rows[trailing_zeros(g) + 1]
        wt = 0
        @inbounds for w = 1:nw
            cur[w] ⊻= row[w]
            wt += count_ones(cur[w])
        end
        counts[wt + 1] += 1
    end
    return counts
end

"""
    shortened_weight_enumerators(M::AbstractMatrix{Bool}) -> Vector{Vector{Int}}

Sorted multiset of the weight enumerators of the code shortened at each single
coordinate (codewords that are 0 at that position, with the position deleted).
A finer code invariant than the plain weight enumerator: equivalent codes have
equal multisets (a coordinate permutation maps shortenings to shortenings).
"""
function shortened_weight_enumerators(M::AbstractMatrix{Bool})
    r, len = size(M)
    nw = (len + 63) >>> 6
    rows = [zeros(UInt64, nw) for _ = 1:r]
    for i = 1:r, j = 1:len
        M[i, j] && (rows[i][((j - 1) >>> 6) + 1] |= UInt64(1) << ((j - 1) & 63))
    end
    ens = Vector{Vector{Int}}(undef, len)
    for p = 1:len
        ens[p] = zeros(Int, len)
        ens[p][1] = 1
    end
    cur = zeros(UInt64, nw)
    for g = 1:((1 << r) - 1)
        row = rows[trailing_zeros(g) + 1]
        wt = 0
        @inbounds for w = 1:nw
            cur[w] ⊻= row[w]
            wt += count_ones(cur[w])
        end
        @inbounds for p = 1:len
            if (cur[((p - 1) >>> 6) + 1] >> ((p - 1) & 63)) & 1 == 0
                ens[p][wt + 1] += 1
            end
        end
    end
    return sort!(ens)
end

"""
    zw_set(F, λ) -> Vector{Int}

ZW(λ) = {a ∈ F₂ⁿ : W_{F_λ}(a) = 0} — zero-Walsh set for the λ-component of F.
Used in Procedure 2 to find admissible linear maps (Section 3).
"""
function zw_set(F::SBox{N,T}, λ::Integer) where {N,T}
    n_size = 1 << N
    L = lat(F)
    return Int[a for a = 0:(n_size - 1) if L[a + 1, Int(λ) + 1] == 0]
end

"""
    sf_set(F) -> Vector{Int}

S_F = {λ ∈ F₂ⁿ : ZW(λ) ≠ ∅} ∪ {0} — support set for Procedure 2 (Section 3, eq. 4).
"""
function sf_set(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    L = lat(F)
    S = Int[0]
    for λ = 1:(n_size - 1)
        if any(L[a + 1, λ + 1] == 0 for a = 1:(n_size - 1))
            push!(S, λ)
        end
    end
    return S
end

"""
    sbox_from_zeta_terms(n, terms) -> SBox

Build `Σ ζ^c · x^e` over GF(2ⁿ) from `(c, e)` pairs, with ζ the Conway
generator (paper/MAGMA convention; see the field-convention note above).
"""
function sbox_from_zeta_terms(n::Int, terms::Vector{Tuple{Int,Int}})
    mod = conway_polynomial(n)
    ts = Tuple{Int,Int}[(gf_pow(2, c, n; modulus = mod), e) for (c, e) in terms]
    SBox{n}(terms_to_lut(ts, n, mod))
end

"""
    power_sbox(n, d) -> SBox

x ↦ xᵈ over GF(2ⁿ) with Conway polynomial modulus (paper/MAGMA convention).
Thin wrapper over the VBF core export `gf_monomial_lut`.
"""
power_sbox(n::Int, d::Int) =
    SBox{n}(gf_monomial_lut(n, d; modulus = conway_polynomial(n)))

"""
    component_degrees(F) -> Dict{Int,Int}

Algebraic degree distribution of the 2ⁿ-1 non-zero components of F.
Each component is Fb(x) = Tr(b·F(x)) ∈ F₂. Returns `degree => count`.
An EA-invariant for components of degree ≥ 2 (unlike the per-coordinate
`degree_spectrum`, which is basis-dependent).
"""
function component_degrees(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    degs = Dict{Int,Int}()
    for b = 1:(n_size - 1)
        comp_lut = UInt8[count_ones(b & UInt(F.lut[x + 1])) % 2 for x = 0:(n_size - 1)]
        d = algebraic_degree(SBox{N,UInt8}(comp_lut))
        degs[d] = get(degs, d, 0) + 1
    end
    return degs
end

"""
    component_walsh_spectra(F) -> Vector{Pair{Vector{Pair{Int,Int}},Int}}

Multiset of per-component Walsh spectra: for each non-zero component λ the
sorted `value => multiplicity` spectrum of W_{F_λ}, collected as sorted
`spectrum => #components` pairs. This is the paper's Section 5.1 per-component
multi-set; the multiset of *absolute* spectra is an EA-invariant, and the
signed version used here is invariant under EA maps with linear (constant-free)
drift, matching the paper's table.
"""
function component_walsh_spectra(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    L = lat(F)
    seen = Dict{Vector{Pair{Int,Int}},Int}()
    for λ = 1:(n_size - 1)
        spec = Dict{Int,Int}()
        for a = 0:(n_size - 1)
            w = L[a + 1, λ + 1]
            spec[w] = get(spec, w, 0) + 1
        end
        key = sort!(collect(spec); by = first)
        seen[key] = get(seen, key, 0) + 1
    end
    return sort!(collect(seen); by = last)
end

"""
    cyclotomic_coset(d, m) -> Vector{Int}

Cyclotomic coset of `d` modulo `m` (orbit of d under multiplication by 2).
`x^d` and `x^e` over GF(2ⁿ) (m = 2ⁿ-1) are linearly equivalent when `e` lies
in the coset of `d`.
"""
function cyclotomic_coset(d::Int, m::Int)
    c = Int[]
    x = mod(d, m)
    while true
        push!(c, x)
        x = mod(2x, m)
        x == c[1] && break
    end
    return c
end

# ---------------------------------------------------------------------------
# Section 5.1 explicit representatives (paper eq. after line "Let", Section 5.1)
# (ζ-power, exponent) pairs transcribed from the published polynomials.
# F₁: not affine-equivalent to its inverse; F₂, F₃: AE to their inverses
# (Remark 4). VBF's `dillon_apn_permutation()` is affine-equivalent to F₂.
# ---------------------------------------------------------------------------

const CALDERINI_F1_TERMS = Tuple{Int,Int}[
    (57, 60), (56, 58), (43, 57), (31, 56), (29, 53), (27, 52), (28, 51),
    (35, 50), (54, 49), (51, 48), (1, 46), (54, 44), (50, 43), (50, 42),
    (32, 41), (49, 40), (36, 39), (14, 38), (16, 37), (15, 35), (43, 34),
    (23, 33), (7, 32), (7, 30), (57, 29), (11, 26), (49, 25), (36, 24),
    (42, 23), (40, 22), (34, 21), (9, 20), (28, 19), (4, 18), (50, 17),
    (58, 16), (1, 15), (48, 14), (33, 13), (31, 12), (43, 11), (14, 10),
    (5, 9), (45, 8), (60, 7), (31, 6), (42, 5), (10, 4), (10, 3), (48, 1),
]
const CALDERINI_F2_TERMS = Tuple{Int,Int}[
    (3, 60), (33, 58), (18, 57), (8, 56), (38, 53), (28, 52), (5, 51),
    (37, 50), (9, 49), (45, 48), (10, 46), (54, 44), (25, 43), (50, 42),
    (55, 41), (30, 40), (45, 39), (41, 38), (14, 37), (49, 36), (31, 35),
    (0, 34), (46, 33), (20, 32), (47, 30), (32, 29), (57, 28), (47, 26),
    (44, 25), (17, 24), (19, 23), (61, 22), (31, 21), (31, 20), (48, 19),
    (58, 18), (21, 17), (0, 16), (39, 15), (44, 14), (35, 13), (21, 12),
    (15, 11), (54, 10), (62, 9), (42, 8), (62, 7), (14, 6), (3, 5),
    (29, 4), (34, 3), (5, 2), (46, 1),
]
const CALDERINI_F3_TERMS = Tuple{Int,Int}[
    (61, 60), (60, 58), (49, 57), (24, 56), (21, 54), (16, 53), (36, 52),
    (35, 51), (17, 50), (28, 49), (14, 48), (62, 46), (9, 45), (21, 44),
    (29, 43), (22, 42), (35, 41), (41, 40), (51, 39), (46, 38), (37, 37),
    (7, 36), (32, 35), (45, 34), (16, 33), (55, 32), (11, 30), (8, 29),
    (29, 28), (6, 27), (58, 26), (28, 24), (15, 23), (44, 22), (35, 21),
    (32, 20), (53, 19), (42, 18), (50, 17), (0, 16), (12, 15), (27, 14),
    (30, 13), (7, 12), (52, 11), (43, 10), (7, 9), (17, 8), (5, 7),
    (17, 6), (43, 5), (13, 4), (57, 3), (35, 2), (49, 1),
]

"Section 5.1 representative F₁ (not AE to its inverse)."
calderini_f1() = sbox_from_zeta_terms(6, CALDERINI_F1_TERMS)
"Section 5.1 representative F₂ (AE to its inverse, Remark 4)."
calderini_f2() = sbox_from_zeta_terms(6, CALDERINI_F2_TERMS)
"Section 5.1 representative F₃ (AE to its inverse, Remark 4)."
calderini_f3() = sbox_from_zeta_terms(6, CALDERINI_F3_TERMS)

# ---------------------------------------------------------------------------
# EA-classes inside the CCZ-class of a quadratic APN via automorphism orbits.
#
# EA-classes in the CCZ-class of F correspond to orbits of the n-dim
# Walsh-zero subspaces of Γ_F under the CCZ-automorphism group of the graph
# (acting in the Walsh domain by (L⁻¹)ᵀ). For a *quadratic* APN F, every CCZ
# self-equivalence of Γ_F induces a linear self-equivalence of the
# ortho-derivative π_F (Canteaut-Couvreur-Perrin 2022), so lifting all linear
# self-equivalences of π_F (× all constant offsets, validated against the
# graph) recovers the full automorphism group — making the orbit count exact.
#
# VBF's `automorphisms_from_ortho_derivative` obtains the self-equivalences
# via the permutation-only `linear_equivalences` and silently returns nothing
# for even n (π_F non-bijective, e.g. every n=6 case here), so this file
# carries a collect-all variant of the core `are_linearly_equivalent_general`
# backtracking search.
# ---------------------------------------------------------------------------

# Fold constraint L(u) = v into a partial linear map kept in reduced form.
function _p2_lin_add!(bin::Vector{Int}, bout::Vector{Int}, u::Integer, v::Integer)
    r = Int(u)
    o = 0
    @inbounds for k in eachindex(bin)
        p = bin[k]
        hb = 1 << (8 * sizeof(Int) - 1 - leading_zeros(p))
        if r & hb != 0
            r ⊻= p
            o ⊻= bout[k]
        end
    end
    if r == 0
        return Int(v) == o
    else
        push!(bin, r)
        push!(bout, Int(v) ⊻ o)
        return true
    end
end

"""
    linear_self_equivalences_general(F) -> Vector{Tuple{F2LinearMap,F2LinearMap}}

All invertible pairs (L₁, L₂) with L₁∘F∘L₂ = F, for arbitrary (possibly
non-bijective) F. Collect-all adaptation of the VBF core decision procedure
`are_linearly_equivalent_general` (promote-to-core candidate).
"""
function linear_self_equivalences_general(F::SBox{N,T}) where {N,T}
    NN = 1 << N
    Fl = F.lut
    L2 = fill(-1, NN)
    L2[1] = 0
    used = Int[]
    sols = Vector{Tuple{Vector{Int},Vector{Int},Vector{Int}}}()

    indep = function (v::Int)
        v == 0 && return false
        r = v
        @inbounds for u in used
            hb = 1 << (8 * sizeof(Int) - 1 - leading_zeros(u))
            r & hb != 0 && (r ⊻= u)
        end
        r != 0
    end

    rec = function (i::Int, bin::Vector{Int}, bout::Vector{Int})
        if i == N
            rank_f2(UInt32.(bout); nbits = N) == length(bin) &&
                push!(sols, (copy(used), copy(bin), copy(bout)))
            return
        end
        b = 1 << i
        @inbounds for img = 1:(NN - 1)
            indep(img) || continue
            bin2 = copy(bin)
            bout2 = copy(bout)
            newpos = Int[]
            ok = true
            for x = 0:(NN - 1)
                x >> i == 0 || continue
                nx = x ⊻ b
                L2[nx + 1] = L2[x + 1] ⊻ img
                push!(newpos, nx)
                if !_p2_lin_add!(bin2, bout2, Fl[L2[nx + 1] + 1], Fl[nx + 1])
                    ok = false
                    break
                end
            end
            if ok
                push!(used, img)
                rec(i + 1, bin2, bout2)
                pop!(used)
            end
            for p in newpos
                L2[p + 1] = -1
            end
        end
    end

    bin = Int[]
    bout = Int[]
    _p2_lin_add!(bin, bout, Fl[1], Fl[1])
    rec(0, bin, bout)

    out = Tuple{F2LinearMap{N,T},F2LinearMap{N,T}}[]
    for (l2imgs, sbin, sbout) in sols
        M2 = F2LinearMap{N,T}(T.(l2imgs))
        length(sbin) == N || continue   # L₁ underdetermined (image span < n): skip
        cols = Vector{T}(undef, N)
        determined = true
        for i = 0:(N - 1)
            r = 1 << i
            o = 0
            changed = true
            while changed && r != 0
                changed = false
                for k in eachindex(sbin)
                    p = sbin[k]
                    hb = 1 << (8 * sizeof(Int) - 1 - leading_zeros(p))
                    if r & hb != 0
                        r ⊻= p
                        o ⊻= sbout[k]
                        changed = true
                    end
                end
            end
            r == 0 || (determined = false; break)
            cols[i + 1] = T(o)
        end
        determined || continue
        M1 = F2LinearMap{N,T}(cols)
        is_invertible(M1) || continue
        all(M1(F.lut[M2(T(x)) + 1]) == F.lut[x + 1] for x = 0:(NN - 1)) &&
            push!(out, (M1, M2))
    end
    return out
end

"""
    graph_automorphisms_quadratic(F) -> Vector{F2LinearMap{2N,UInt32}}

CCZ-automorphisms of graph(F) for a quadratic APN F, lifted from the linear
self-equivalences of the ortho-derivative (each candidate validated with
`graph_xor_equivalence`, so every returned map genuinely fixes the graph up
to translation). Complete for quadratic APN by [CCP 2022] (see block comment).
"""
function graph_automorphisms_quadratic(F::SBox{N,T}) where {N,T}
    π = ortho_derivative(F)
    π === nothing && return F2LinearMap{2N,UInt32}[]
    eqs = linear_self_equivalences_general(π)
    n_size = 1 << N
    G = FunctionGraph(F)
    s = F.lut
    result = F2LinearMap{2N,UInt32}[]
    for (M1, M2) in eqs
        L_A_inv = inv(M2)
        L_B_T = transpose(M1)
        s_LAinv = T[s[L_A_inv(T(x)) + 1] for x = 0:(n_size - 1)]
        for delta = 0:(n_size - 1)
            C0 = s[delta + 1] ⊻ L_B_T(s_LAinv[1])
            img = Vector{T}(undef, N)
            for i = 0:(N - 1)
                ei = 1 << i
                img[i + 1] = C0 ⊻ s[(ei ⊻ delta) + 1] ⊻ L_B_T(s_LAinv[ei + 1])
            end
            L = ea_mapping(L_A_inv, L_B_T, F2LinearMap{N,T}(img))
            isempty(graph_xor_equivalence(G, graph_image_by(G, L))) || push!(result, L)
        end
    end
    return result
end

# Full point set of the span of a basis (packed 2n-bit points), sorted.
function _span_set(basis, M::Int)
    pts = UInt32[0]
    for b in basis
        pts = vcat(pts, UInt32[p ⊻ UInt32(b) for p in pts])
    end
    return sort!(pts)
end

"""
    ea_class_orbits(F) -> NamedTuple

For a quadratic APN F: the n-dim Walsh-zero subspaces of Γ_F, the graph
automorphisms, and the orbit partition of the subspaces (= the EA-classes in
the CCZ-class of F). Returns
`(; bases, nspaces, nauts, orbits)` with `orbits::Vector{Vector{Int}}`
(indices into `bases`, matching `enumerate_ccz_class` order).
"""
function ea_class_orbits(F::SBox{N,T}) where {N,T}
    Z = walsh_zeroes(F)
    bases = extract_linear_subspaces(Z, N; max_bits = 2N)
    nb = length(bases)
    auts = graph_automorphisms_quadratic(F)
    spans = [_span_set(b, 2N) for b in bases]
    key = Dict{Vector{UInt32},Int}(s => i for (i, s) in enumerate(spans))
    parent = collect(1:nb)
    function find(i)
        while parent[i] != i
            parent[i] = parent[parent[i]]
            i = parent[i]
        end
        return i
    end
    for L in auts
        Dm = transpose(inv(L))
        for (i, s) in enumerate(spans)
            img = sort!(UInt32[UInt32(Dm(p)) for p in s])
            j = get(key, img, 0)
            j == 0 && continue    # cannot happen for validated automorphisms
            ri, rj = find(i), find(j)
            ri != rj && (parent[ri] = rj)
        end
    end
    orbits = Dict{Int,Vector{Int}}()
    for i = 1:nb
        push!(get!(orbits, find(i), Int[]), i)
    end
    return (; bases, nspaces = nb, nauts = length(auts), orbits = collect(values(orbits)))
end
