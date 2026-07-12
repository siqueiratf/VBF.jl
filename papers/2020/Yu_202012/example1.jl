# Implements Section 3.2, Example 1
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
#
# Example 1 (n=6). A QAM for an F₂-coefficient function must take the form
#
#     H = [ 0      a      b      c      b^{2⁴}  a^{2⁵} ]
#         [ a      0      a²     b²     c²      b^{2⁵} ]
#         [ b      a²     0      a^{2²} b^{2²}  c^{2²} ]
#         [ c      b²     a^{2²} 0      a^{2³}  b^{2³} ]
#         [ b^{2⁴} c²     b^{2²} a^{2³} 0       a^{2⁴} ]
#         [ a^{2⁵} b^{2⁵} c^{2²} b^{2³} a^{2⁴}  0      ]
#
# for a, b, c ∈ F_{2⁶} — i.e. THREE free variables. The paper then notes:
#   "the condition H[u+1,v+1] = H[u,v]² implies that c = c^{2³}, which further reduces
#    the complexity of the search."
# so c is confined to the subfield GF(2³) ⊂ GF(2⁶): the search is 64 × 64 × 8 = 2¹⁵.
#
# The claims are combinatorial facts about the index action (i,j) ↦ (i+1, j+1) mod 6 and
# are therefore BASIS-INDEPENDENT — unlike Theorem 2's iff (see theorem2.jl), they are
# reproducible as printed.
#
# Pseudocode:
#   1. qam_cyclic_orbits(6,1) must give exactly 3 orbits — the free variables a, b, c
#   2. their lengths must be 6, 6, 3 (a and b have full Frobenius orbits; c's closes at 3)
#   3. c = c^{2³} ⟺ c ∈ GF(2³), giving |GF(2³)| = 8 admissible values
#   4. hence the search space is 64·64·8 = 2¹⁵
#   5. the iff, tested exhaustively over all 2¹⁸ triples (a,b,c):
#        qam_from_cyclic(6,1,[a,b,c]) has Frobenius-shift structure  ⟺  c ∈ GF(2³)
# VBF API used: qam_cyclic_orbits, qam_from_cyclic, gf_pow, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

"""
    subfield_gf8_of_gf64() -> Vector{Int}

The elements of GF(2⁶) fixed by `x ↦ x^{2³}` — i.e. the subfield GF(2³), the admissible
values of the paper's `c`.
"""
function subfield_gf8_of_gf64()
    mod = primitive_polynomial(6)
    [x for x = 0:63 if gf_pow(x, 8, 6; modulus = mod) == x]
end

"""
    example1_verify(; exhaustive_iff) -> NamedTuple

Reproduce Example 1's structural claims for n=6.
"""
function example1_verify(; exhaustive_iff::Bool = true)
    checks = Tuple{String,Bool}[]
    orbits = qam_cyclic_orbits(6, 1)
    lens = length.(orbits)

    push!(checks, ("n=6: exactly 3 free variables (a, b, c)", length(orbits) == 3))
    push!(checks, ("n=6: orbit lengths are [6, 6, 3]", sort(lens) == [3, 6, 6]))

    sub3 = subfield_gf8_of_gf64()
    push!(checks, ("c is confined to GF(2³): |{c : c = c^{2³}}| == 8", length(sub3) == 8))

    space = 64 * 64 * length(sub3)
    push!(checks, ("search space is 64·64·8 = 2¹⁵ = $(space)", space == 1 << 15))

    n_iff_violations = 0
    n_in = 0
    n_out = 0
    if exhaustive_iff
        i3 = findfirst(o -> length(o) == 3, orbits)      # the orbit carrying c
        others = [k for k = 1:3 if k != i3]
        vals = zeros(Int, 3)
        for a = 0:63, b = 0:63, c = 0:63
            vals[others[1]] = a
            vals[others[2]] = b
            vals[i3] = c
            got = has_f2_cyclic_structure(qam_from_cyclic(6, 1, vals), 6)
            want = c in sub3
            got == want || (n_iff_violations += 1)
            want ? (n_in += 1) : (n_out += 1)
        end
        push!(
            checks,
            ("exhaustive iff over all 2¹⁸ triples: Frobenius-shift structure ⟺ c ∈ GF(2³) " *
             "($(n_in) in-subfield, $(n_out) out — both sides non-empty)",
             n_iff_violations == 0 && n_in > 0 && n_out > 0),
        )
    end

    (; checks, orbit_lengths = lens, c_values = length(sub3), search_space = space,
       iff_violations = n_iff_violations)
end

function example1_report(io::IO = stdout)
    print_section(io, "Example 1 — the n=6 QAM shape (3 free variables a, b, c; c ∈ GF(2³))")
    result = example1_verify()
    print_kv(io, "orbit lengths", result.orbit_lengths)
    print_kv(io, "admissible c values", result.c_values)
    print_kv(io, "search space", "$(result.search_space) = 2^15")
    for (desc, ok) in result.checks
        print_check(io, desc, ok)
    end
    all_pass = all(ok for (_, ok) in result.checks)
    print_kv(io, "overall", all_pass ? "all checks pass" : "SOME CHECKS FAILED")
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    example1_report()
end
