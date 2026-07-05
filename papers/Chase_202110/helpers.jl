# Implements shared helpers for Chase & Lisoněk (2021) reproduction.
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces", Cryptography and Communications (2022) / preprint 2021.
# Section: General — Gold dual exponent, coordinate conversion, WZ-space
#          packing, Proposition 2.2 permutation builder.
#
# Conventions:
#   * A WZ-space element (a, b) ∈ F_{2^n} × F_{2^n} is packed as the UInt32
#     `(a << n) | b` in FIELD coordinates (integer bits = polynomial-basis
#     coefficients). Spaces are sorted vectors of 2^n packed elements.
#   * VBF's `lat` / `walsh_zeroes` use MASK coordinates (bitwise dot product).
#     `trace_mask_table` converts: parity(m(a) & x) == Tr(a·x) for all x.
#
# VBF API used: gf_mul, gf_pow, gf_inv, gf_trace, primitive_polynomial,
#   parity, linear_basis, rank_f2, F2LinearMap, F2AffineMap,
#   ccz_equivalent_function, walsh_zeroes, gold_apn, print_banner

using VBF
using Dates
using Random

gold_exp(i::Int) = (1 << i) + 1

"1/(2^i+1) mod 2^n-1 (exists since n is odd and gcd(i,n)=1)."
inv_gold_exp(n::Int, i::Int) = invmod(gold_exp(i), (1 << n) - 1)

"-1/(2^i+1) mod 2^n-1."
neg_inv_gold_exp(n::Int, i::Int) = mod(-inv_gold_exp(n, i), (1 << n) - 1)

"""
    gold_dual(b, n, i; modulus) -> Int

`b ↦ b^{-1/(2^i+1)}` with the paper's convention `0^{-1/(2^i+1)} = 0`
(introduced just before Definition 3.2).
"""
function gold_dual(b::Int, n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    b == 0 && return 0
    gf_pow(b, neg_inv_gold_exp(n, i), n; modulus)
end

"Lookup table of `gold_dual` over the whole field; `tab[b+1] = b^{-1/(2^i+1)}`."
gold_dual_table(n::Int, i::Int; modulus::Int = primitive_polynomial(n)) =
    [gold_dual(b, n, i; modulus) for b = 0:(1<<n)-1]

"""
    trace_mask(a, n; modulus) -> Int

Mask `m` with `parity(m & x) == Tr(a·x)` for all `x` — converts a field
element used as a trace-pairing functional into VBF's mask convention.
"""
function trace_mask(a::Int, n::Int; modulus::Int = primitive_polynomial(n))
    m = 0
    for j = 0:n-1
        gf_trace(gf_mul(a, 1 << j, n; modulus), n; modulus) == 1 && (m |= 1 << j)
    end
    m
end

"Lookup table of `trace_mask`; `tab[a+1] = m(a)`. A linear bijection."
trace_mask_table(n::Int; modulus::Int = primitive_polynomial(n)) =
    [trace_mask(a, n; modulus) for a = 0:(1<<n)-1]

# ---------------------------------------------------------------------------
# Space packing and subspace predicates.
# ---------------------------------------------------------------------------

field_pack(a::Int, b::Int, n::Int) = (UInt32(a) << n) | UInt32(b)

"Pack a list of field pairs into a sorted field-coordinate span."
field_pack_span(pairs, n::Int) =
    sort!(UInt32[field_pack(a, b, n) for (a, b) in pairs])

"""
    to_mask_coords(span, tm, n) -> Vector{UInt32}

Convert a field-packed span to VBF's LAT/mask coordinates
`(m(a) << n) | m(b)` using a `trace_mask_table` `tm`. Linear bijection, so
subspaces map to subspaces of the same dimension.
"""
function to_mask_coords(span::Vector{UInt32}, tm::Vector{Int}, n::Int)
    mask = (UInt32(1) << n) - UInt32(1)
    sort!(UInt32[
        (UInt32(tm[Int(u>>n)+1]) << n) | UInt32(tm[Int(u&mask)+1]) for u in span
    ])
end

"True iff `els` is exactly the span of a `dim`-dimensional F2-subspace."
function is_linear_span(els::Vector{UInt32}, dim::Int, nbits::Int)
    length(els) == (1 << dim) || return false
    allunique(els) || return false
    UInt32(0) in els || return false
    length(linear_basis(els; nbits)) == dim
end

# ---------------------------------------------------------------------------
# WZ-space predicates.
# ---------------------------------------------------------------------------

"Trivial WZ space Z_a0 = {(a, 0)} (field-packed span)."
z_a0_span(n::Int) = sort!(UInt32[UInt32(a) << n for a = 0:(1<<n)-1])

"Trivial WZ space Z_0b = {(0, b)} (field-packed span)."
z_0b_span(n::Int) = UInt32.(0:(1<<n)-1)

"True iff the two spans share only the zero element."
intersects_trivially(s1::Vector{UInt32}, s2::Vector{UInt32}) =
    length(intersect(Set(s1), Set(s2))) == 1

"""
    is_walsh_zero_gold(a, b, n, i; modulus) -> Bool

Proposition 3.1 (Walsh zero test): `(a, b)` is a Walsh zero of the Gold APN
permutation `x^{2^i+1}` iff `Tr(a·b^{-1/(2^i+1)}) = 0` or `a ≠ b = 0`.
Note `(0, 0)` is NOT a Walsh zero (`W_f(0,0) = 2^n`).
"""
function is_walsh_zero_gold(
    a::Int,
    b::Int,
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
)
    b == 0 && return a != 0
    d = gold_dual(b, n, i; modulus)
    gf_trace(gf_mul(a, d, n; modulus), n; modulus) == 0
end

"""
    is_wz_space_gold(span, n, i; modulus, dual, tm) -> Bool

Check that a field-packed span is a WZ space of `x^{2^i+1}` using the
Proposition 3.1 test (fast; no LAT). `dual` is a `gold_dual_table`, `tm` a
`trace_mask_table` (used for `Tr(a·d) = parity(m(d) & a)`).
"""
function is_wz_space_gold(
    span::Vector{UInt32},
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
    dual::Vector{Int} = gold_dual_table(n, i; modulus),
    tm::Vector{Int} = trace_mask_table(n; modulus),
)
    is_linear_span(span, n, 2 * n) || return false
    mask = (UInt32(1) << n) - UInt32(1)
    for u in span
        u == UInt32(0) && continue
        a = Int(u >> n)
        b = Int(u & mask)
        if b == 0
            a != 0 || return false
        else
            parity(tm[dual[b+1]+1] & a) == 0 || return false
        end
    end
    true
end

"""
    is_wz_space_lat(span, F, tm; zset) -> Bool

Check that a field-packed span is a WZ space of `F` against the ACTUAL
Walsh transform (`walsh_zeroes(F)`, mask coordinates) — independent of
Proposition 3.1.
"""
function is_wz_space_lat(
    span::Vector{UInt32},
    F::SBox{N},
    tm::Vector{Int};
    zset::Set{UInt32} = Set(walsh_zeroes(F)),
) where {N}
    m = to_mask_coords(span, tm, N)
    is_linear_span(m, N, 2 * N) || return false
    all(u -> u == UInt32(0) || u in zset, m)
end

# ---------------------------------------------------------------------------
# Proposition 2.2 machinery (see proposition2_2.jl for the claim driver).
# ---------------------------------------------------------------------------

"""
    wz_pair_to_permutation_masks(F, Sm, Tm) -> SBox

Core of Proposition 2.2, operating on MASK-coordinate spans. Basis rows of
`S` become the x'-block (`G'_1`) and rows of `T` the y'-block (`G'_2`);
columns of `G'` are read as `(x', g(x'))` via `ccz_equivalent_function`.
Throws if the spaces are not n-dimensional or do not intersect trivially.
"""
function wz_pair_to_permutation_masks(
    F::SBox{N,T},
    Sm::Vector{UInt32},
    Tm::Vector{UInt32},
) where {N,T}
    bS = linear_basis(Sm; nbits = 2 * N)
    bT = linear_basis(Tm; nbits = 2 * N)
    (length(bS) == N && length(bT) == N) || throw(
        ArgumentError("wz_pair_to_permutation: spaces must be n-dimensional"),
    )
    rank_f2(UInt32[bS; bT]; nbits = 2 * N) == 2 * N || throw(
        ArgumentError("wz_pair_to_permutation: spaces must intersect trivially"),
    )
    # transpose(L) computes bit k of the image as parity(cols[k+1] & (x, f(x)));
    # T's basis fills bits 0..n-1 (the y' half), S's basis bits n..2n-1 (x').
    L = transpose(F2LinearMap{2 * N,UInt32}(UInt32[bT; bS]))
    g = ccz_equivalent_function(F, F2AffineMap(L, UInt32(0)))
    g === nothing &&
        error("wz_pair_to_permutation: image graph is not a function graph")
    g
end

"""
    wz_pair_to_permutation(F, Sspan, Tspan; tm) -> SBox

Proposition 2.2: given two trivially intersecting WZ spaces of `F`
(field-packed spans), construct a permutation CCZ-equivalent to `F`.
"""
function wz_pair_to_permutation(
    F::SBox{N,T},
    Sspan::Vector{UInt32},
    Tspan::Vector{UInt32};
    tm::Vector{Int} = trace_mask_table(N),
) where {N,T}
    wz_pair_to_permutation_masks(
        F,
        to_mask_coords(Sspan, tm, N),
        to_mask_coords(Tspan, tm, N),
    )
end

# ---------------------------------------------------------------------------
# Exact enumeration of ALL WZ spaces of a Gold APN permutation, via the
# Walsh zero test (Proposition 3.1). Thickness-stratified: for a WZ space V,
# let B = π_b(V) (dimension t) and A0 = V ∩ (F_{2^n} × {0}). Writing
# V = {(γ(b) + a0, b) : b ∈ B, a0 ∈ A0}, the Walsh zero test forces
#   * d(B∖0) to span a t-dimensional space (d = gold_dual is injective, so
#     B ∪ {0} must be i-compatible in the sense of Definition 3.2),
#   * A0 = the trace-orthogonal complement of span(d(B∖0)), and
#   * Tr(γ(b)·d(b)) = 0 for all b ∈ B∖0 — a linear system in γ.
# This reproduces the sboxU-style enumeration without generic subspace
# search (which is infeasible for n ≥ 7 on Z(f) of size ~2^{2n-1}).
# ---------------------------------------------------------------------------

"""
    enumerate_wz_spaces_gold(n, i; modulus, dual, tm) -> Vector{Vector{UInt32}}

All n-dimensional WZ spaces of `x^{2^i+1}` (n odd, gcd(i,n)=1) as
field-packed spans, computed exactly from the Proposition 3.1
characterization (verified against the actual LAT in proposition3_1.jl).
Runs in well under a second for n ≤ 7 and in ~30 s for n = 9.
"""
function enumerate_wz_spaces_gold(
    n::Int,
    i::Int;
    modulus::Int = primitive_polynomial(n),
    dual::Vector{Int} = gold_dual_table(n, i; modulus),
    tm::Vector{Int} = trace_mask_table(n; modulus),
)
    spaces = Vector{Vector{UInt32}}()
    push!(spaces, z_a0_span(n))                     # t = 0
    all_nz = UInt32.(1:(1<<n)-1)
    for t = 1:n
        for bB in extract_linear_subspaces(all_nz, t; max_bits = n)
            Bspan = span_from_basis(bB)             # index bits ↔ bB coords
            duals = UInt32[UInt32(dual[Int(b)+1]) for b in Bspan if b != 0]
            dbasis = linear_basis(duals; nbits = n)
            length(dbasis) == t || continue          # B must be i-compatible
            # A0 = trace-orthogonal complement of span(d(B∖0)); C a complement.
            dm = [tm[Int(d)+1] for d in dbasis]
            A0 = UInt32[x for x = 0:(1<<n)-1 if all(m -> parity(m & x) == 0, dm)]
            bA0 = linear_basis(A0; nbits = n)
            C = setdiff(complete_basis(copy(bA0), n), bA0)   # t coset reps
            # Linear system for γ: unknowns g_{jk} (bit j*t+k), Γ_j = Σ_k g_{jk}·C_k.
            rows = UInt128[]
            for idx = 1:(1<<t)-1
                mask_db = tm[dual[Int(Bspan[idx+1])+1]+1]
                row = UInt128(0)
                for j = 0:t-1
                    (idx >> j) & 1 == 1 || continue
                    for k = 0:t-1
                        parity(mask_db & Int(C[k+1])) == 1 &&
                            (row |= UInt128(1) << (j * t + k))
                    end
                end
                push!(rows, row)
            end
            ker = kernel_f2(rows; nbits = t * t)
            length(ker) <= 24 ||
                error("enumerate_wz_spaces_gold: unexpectedly large γ kernel")
            gammas = Vector{Int}(undef, t)
            for combo = 0:(1<<length(ker))-1
                gbits = UInt128(0)
                for kk = 0:length(ker)-1
                    (combo >> kk) & 1 == 1 && (gbits ⊻= ker[kk+1])
                end
                for j = 0:t-1
                    gj = 0
                    for k = 0:t-1
                        (gbits >> (j * t + k)) & 1 == 1 && (gj ⊻= Int(C[k+1]))
                    end
                    gammas[j+1] = gj
                end
                els = Vector{UInt32}(undef, 1 << n)
                pos = 1
                for idx = 0:(1<<t)-1
                    gb = 0
                    for j = 0:t-1
                        (idx >> j) & 1 == 1 && (gb ⊻= gammas[j+1])
                    end
                    b = Bspan[idx+1]
                    for a0 in A0
                        els[pos] = (UInt32(gb ⊻ Int(a0)) << n) | b
                        pos += 1
                    end
                end
                push!(spaces, sort!(els))
            end
        end
    end
    spaces
end

# ---------------------------------------------------------------------------
# Twist machinery for EA classification (Section 6.1) — Canteaut-Perrin
# style twists driven by a WZ space placed in the x'-block.
# ---------------------------------------------------------------------------

"Mask-coordinate image of one field-packed pair."
mask_of_pair(u::UInt32, tm::Vector{Int}, n::Int) =
    (UInt32(tm[Int(u >> n)+1]) << n) |
    UInt32(tm[Int(u & ((UInt32(1) << n) - UInt32(1)))+1])

"""
    twist_from_field_bases(F, bS, bT, tm) -> SBox

Twist of `F` by the space spanned by `bS` (field-packed basis, x'-block),
completed by `bT` (y'-block; need not be a WZ space). When `bS` spans a WZ
space the image is always a function graph (its simplex-code rows separate
points); the result is a permutation iff `bT` also spans a WZ space
(Proposition 2.2).
"""
function twist_from_field_bases(
    F::SBox{N,T},
    bS::Vector{UInt32},
    bT::Vector{UInt32},
    tm::Vector{Int},
) where {N,T}
    length(bS) == N && length(bT) == N ||
        throw(ArgumentError("twist: bases must have n elements"))
    rank_f2(UInt32[bS; bT]; nbits = 2 * N) == 2 * N ||
        throw(ArgumentError("twist: bases must span F_2^{2n}"))
    cols = UInt32[
        [mask_of_pair(u, tm, N) for u in bT]
        [mask_of_pair(u, tm, N) for u in bS]
    ]
    L = transpose(F2LinearMap{2 * N,UInt32}(cols))
    g = ccz_equivalent_function(F, F2AffineMap(L, UInt32(0)))
    g === nothing && error("twist: image graph is not a function graph")
    g
end

"""
    scale_pair(u, p, n, i; modulus) -> UInt32

The graph-automorphism action of μ-scaling on Walsh-zero pairs:
`(a, b) ↦ (u·a, u^{2^i+1}·b)`. It preserves the Walsh zero test of
Proposition 3.1 since `Tr(ua·(u^{2^i+1}b)^{-1/(2^i+1)}) = Tr(a·b^{-1/(2^i+1)})`,
and comes from the automorphism `(x, y) ↦ (u⁻¹x, u^{-(2^i+1)}y)` of the
graph of `x^{2^i+1}`.
"""
function scale_pair(u::Int, p::UInt32, n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    mask = (UInt32(1) << n) - UInt32(1)
    a = gf_mul(u, Int(p >> n), n; modulus)
    b = gf_mul(gf_pow(u, gold_exp(i), n; modulus), Int(p & mask), n; modulus)
    (UInt32(a) << n) | UInt32(b)
end

scale_span(u::Int, span::Vector{UInt32}, n::Int, i::Int; modulus::Int = primitive_polynomial(n)) =
    sort!(UInt32[scale_pair(u, p, n, i; modulus) for p in span])

"""
    completion_drift_certificate(bS, bT, bT2, g, g2, tm, n) -> Bool

Explicit EA certificate for completion independence: with `x'`-block `bS`
fixed, the twists by completions `bT` and `bT2` satisfy
`g2(x) = β(g(x)) ⊕ α(x)` for the matrices `(α, β)` obtained by expanding
`bT2` in the basis `[bS; bT]` (`β` invertible) — i.e. `g` and `g2` are
EA-equivalent with drift `α`. Returns `true` iff the identity holds
pointwise.
"""
function completion_drift_certificate(
    bS::Vector{UInt32},
    bT::Vector{UInt32},
    bT2::Vector{UInt32},
    g::SBox{N},
    g2::SBox{N},
    tm::Vector{Int},
) where {N}
    M = F2LinearMap{2 * N,UInt32}(UInt32[
        [mask_of_pair(u, tm, N) for u in bS]
        [mask_of_pair(u, tm, N) for u in bT]
    ])
    Minv = inv(M)
    nmask = (1 << N) - 1
    alpha = Vector{Int}(undef, N)
    beta = Vector{Int}(undef, N)
    for k = 1:N
        c = Int(Minv(mask_of_pair(bT2[k], tm, N)))
        alpha[k] = c & nmask
        beta[k] = c >> N
    end
    rank_f2(UInt32.(beta); nbits = N) == N || return false
    for x = 0:(1<<N)-1
        y = 0
        gx = Int(g.lut[x+1])
        for k = 1:N
            y |= (parity(alpha[k] & x) ⊻ parity(beta[k] & gx)) << (k - 1)
        end
        y == Int(g2.lut[x+1]) || return false
    end
    true
end

# ---------------------------------------------------------------------------
# Report banner.
# ---------------------------------------------------------------------------

function paper_banner(io::IO = stdout)
    print_banner(
        io,
        "Chase, Lisoněk (2021)",
        "Construction of APN permutations via Walsh zero spaces",
        "Cryptography and Communications (2022); preprint 2021",
        "Julia $(VERSION)  |  $(Dates.today())",
    )
end
