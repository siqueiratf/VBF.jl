# Implements paper-local helpers for the Kalgin–Idrisova (2020) reproduction.
# Paper: Kalgin, Idrisova (2020), "The classification of quadratic APN functions
#        in 7 variables", Cryptography and Communications 14, pp. 691–715.
# Section: General — shared helpers, I/O, formatting
#
# VBF API used: SBox, anf, mobius!, apn_ea_mugshot, algebraic_degree,
#               ea_mappings_from_ortho_derivative, primitive_polynomial

using VBF

# ── Field pinning (§4) ───────────────────────────────────────────────────────
# The paper pins GF(2^7) by the minimal polynomial x^7 + x + 1 of its primitive
# element a. Every univariate coefficient a^i in §4 is meaningless under any
# other modulus, so assert that VBF's default for n = 7 is the paper's.
const PAPER_MODULUS_N7 = 0b10000011      # x^7 + x + 1 = 131

primitive_polynomial(7) == PAPER_MODULUS_N7 || error(
    "Kalgin_202000: paper pins GF(2^7) = F_2[x]/(x^7+x+1) = $(PAPER_MODULUS_N7), " *
    "but primitive_polynomial(7) = $(primitive_polynomial(7)); §4's a^i coefficients " *
    "would be read in the wrong field.",
)

# ── Report formatting ────────────────────────────────────────────────────────

function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Kalgin, Idrisova (2020): Classification of Quadratic APN Functions")
    println(io, "in 7 Variables — Cryptography and Communications 14, pp. 691–715")
    println(io, "=" ^ 72)
end

# ── Quadratic-part extraction ────────────────────────────────────────────────

"""
    quadratic_part(F::SBox{N,T}) -> SBox{N}

The quadratic part F^{(2)} of F: keeps only degree-2 ANF monomials.
Kalgin–Idrisova §6 uses this to define stacked APN functions.
"""
function quadratic_part(F::SBox{N,T}) where {N,T}
    a = anf(F)
    @inbounds for m = 0:(1 << N - 1)
        count_ones(m) == 2 || (a[m+1] = T(0))
    end
    mobius!(a)
    SBox{N}(Int.(a))
end

# ── EA-class deduplication ───────────────────────────────────────────────────

"""
    are_ea_equivalent_quadratic(F, G) -> Bool

EA-equivalence *decision* for two quadratic APN functions: `true` iff
`ea_mappings_from_ortho_derivative(F, G)` is non-empty. That set is built from
the linear equivalences of the ortho-derivatives and every candidate is then
verified on the graph, so it is non-empty **iff** `F ~EA G`. For quadratic APN,
EA-equivalence coincides with CCZ-equivalence (Yoshiara 2012), so this decides
the CCZ-class too.

Do **not** use `apn_ea_mugshot` equality for this: equal mugshots are necessary
but *not* sufficient (VBF's own docstring says so). Gold x^3 and x^5 over GF(2^5)
have identical mugshots and are CCZ-inequivalent — see `test_section4.jl`.
"""
are_ea_equivalent_quadratic(F::SBox{N,T}, G::SBox{N,T}) where {N,T} =
    !isempty(ea_mappings_from_ortho_derivative(F, G))

"""
    dedup_ea(fns) -> Vector

One representative per EA-class from a list of quadratic APN SBox-es.

`apn_ea_mugshot` is used only to **bucket** (a cheap necessary condition); every
bucket is then split by the exact decision `are_ea_equivalent_quadratic`. Grouping
on the mugshot alone under-counts: Gold x^3 and x^5 over GF(2^5) share a mugshot
yet are EA- (and CCZ-) inequivalent, so a mugshot-only dedup reports 1 class where
there are 2. For quadratic APNs, EA-equivalence equals CCZ-equivalence
(Yoshiara 2012), so the returned list is one representative per CCZ-class.
"""
function dedup_ea(fns)
    buckets = Dict{Any,Vector{eltype(fns)}}()
    out = eltype(fns)[]
    for f in fns
        reps = get!(() -> eltype(fns)[], buckets, apn_ea_mugshot(f))
        any(g -> are_ea_equivalent_quadratic(f, g), reps) && continue
        push!(reps, f)
        push!(out, f)
    end
    out
end
