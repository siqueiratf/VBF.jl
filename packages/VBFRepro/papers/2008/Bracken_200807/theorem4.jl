# Implements Theorem 4 — Tr(f) is a bent function for Family 1.
# Paper: Bracken, Byrne, Markin, McGuire (2008),
#        "New Families of Quadratic Almost Perfect Nonlinear Trinomials and Multinomials",
#        Finite Fields and Their Applications 14 (2008), 703–714
# Section: 4 — Proof of bent property
#
# Pseudocode:
#   For F a Family 1 instance on K=GF(2^{2k}):
#     1. Compute g(x) = Tr(F(x)) = F(x) ⊕ F(x)^2 ⊕ ... ⊕ F(x)^{2^{2k−1}} ∈ {0,1}
#     2. Verify g is a bent Boolean function (all |Walsh coeff|^2 = 2^{2k})
#     3. For all v ∈ GF(2^k)*, verify x ↦ Tr(v·F(x)) is also bent
#     4. Verify the same for b a *cube* — Theorem 4 imposes no condition on b,
#        so bentness must survive where the Theorem 1 APN property does not.
# VBF API used: SBox, walsh_transform, gf_mul, gf_trace, in_subfield,
#               differential_uniformity, trace_component_is_bent

include(joinpath(@__DIR__, "theorem1.jl"))


"""
    theorem4_sbox(k, s, b, c, r; modulus) -> SBox

The function of Theorem 4 on K = GF(2^{2k}):

    f(x) = b·x^{2^s+1} + b^{2^k}·x^{2^{k+s}+2^k} + c·x^{2^k+1}
           + Σ_{j=1}^{k−1} r_j·x^{2^{k+j}+2^j}

Theorem 4's hypotheses are strictly weaker than Theorem 1's: it assumes only
`c ∉ GF(2^k)` and `r_j ∈ GF(2^k)`. In particular it puts **no** condition on `b`
and none on the parity of `k` and `s`. `theorem1_sbox` cannot express that, since
it hard-codes the non-cube `b = ω`; this builder therefore validates Theorem 4's
own hypotheses and then bypasses `family1_lut`'s Theorem 1 check.
"""
function theorem4_sbox(k::Int, s::Int, b::Int, c::Int, r::Vector{Int} = Int[];
                        modulus::Int = primitive_polynomial(2k))
    n = 2k
    in_subfield(c, k, n; modulus) && throw(ArgumentError(
        "theorem4_sbox: Theorem 4 requires c ∉ GF(2^$k), got c=$c"))
    length(r) ≤ k - 1 || throw(ArgumentError(
        "theorem4_sbox: r has $(length(r)) entries but only k−1 = $(k - 1) are used"))
    for (j, rj) in pairs(r)
        in_subfield(rj, k, n; modulus) || throw(ArgumentError(
            "theorem4_sbox: r[$j]=$rj must lie in GF(2^$k)"))
    end
    SBox(family1_lut(k, s, b, c, r; modulus, validate = false))
end


"""
    theorem4_strictly_weaker_report(io)

Theorem 4 ⊅ Theorem 1: for every `b` that *is* a cube in GF(64) — a value
Theorem 1 forbids and `family1_lut` rejects — `Tr(v·f(x))` is still bent for all
`v ∈ GF(8)*`, while `f` is no longer APN. This is the check that distinguishes
Theorem 4's hypotheses from Theorem 1's; reusing `theorem1_sbox` cannot.
"""
function theorem4_strictly_weaker_report(io::IO = stdout)
    k, s    = 3, 1
    n       = 2k
    modulus = primitive_polynomial(n)
    subf    = filter(!iszero, subfield_elements(n, k; modulus))
    c       = gf_pow(2, 2, n; modulus)

    println(io, "  Theorem 4 imposes no condition on b (Theorem 1 needs b a non-cube).")
    println(io, "  For cube b the function is bent but *not* APN — so the two")
    println(io, "  hypothesis sets are genuinely different:")
    all_ok = true
    for b in (1, 3, 8)
        @assert gf_is_dth_power(b, 3, n; modulus)   # b really is a cube
        F    = theorem4_sbox(k, s, b, c, [0, 0]; modulus)
        bent = all(trace_component_is_bent(F, v; modulus) for v in subf)
        du   = differential_uniformity(F)
        ok   = bent && du != 2
        all_ok &= ok
        print_check("n=6 b=$b (a cube): Tr(v·f) bent for all v ∈ GF(8)*, du = $du ≠ 2",
                    ok, io)
    end
    println(io)
    print_check("Theorem 4 holds strictly beyond Theorem 1's hypotheses", all_ok, io)
    println(io)
end


function theorem4_report(io::IO = stdout)
    print_section("Theorem 4 — Tr(f) is bent for Family 1 (Section 4)", io)
    println(io, "  Claim: x ↦ Tr(f(x)) is a bent Boolean function on K = GF(2^{2k}).")
    println(io, "  Extended claim: x ↦ Tr(v·f(x)) is bent for all v ∈ GF(2^k).")
    println(io, "  Hypotheses: c ∉ GF(2^k), r_j ∈ GF(2^k). Nothing is assumed about b.")
    println(io, "  (Tr = absolute trace GF(2^{2k}) → F₂; · = GF multiplication.)")
    println(io)

    k, s    = 3, 1
    n       = 2k
    modulus = primitive_polynomial(n)
    subf    = filter(!iszero, subfield_elements(n, k; modulus))

    for (label, r_exp) in [("trinomial    (r=[0, 0])",          [nothing, nothing]),
                           ("quadrinomial (r=[ω⁹=24, 0])",      [9, nothing]),
                           ("pentanomial  (r=[ω⁹=24, ω¹⁸=15])", [9, 18])]
        F = theorem1_sbox(k, s, r_exp; modulus)

        # Main claim: Tr(f(x)) is bent (v=1)
        tr_bent = trace_component_is_bent(F, 1; modulus)
        print_check("n=6 $label: Tr(f(x)) is bent  [v=1]", tr_bent, io)

        # Extended claim: Tr(v·f(x)) bent for all v ∈ GF(2^k)*
        all_bent = all(trace_component_is_bent(F, v; modulus) for v in subf)
        print_check("n=6 $label: all v ∈ GF(8)* → Tr(v·f(x)) bent  [$(length(subf)) checks]",
                    all_bent, io)
        println(io)
    end

    theorem4_strictly_weaker_report(io)

    print_kv("completeness",
             "all 7 v ∈ GF(8)* for 3 Family-1 shapes and 3 cube-b instances at " *
             "n=6; N even guaranteed by n=2k", io)
end


if abspath(PROGRAM_FILE) == @__FILE__
    theorem4_report()
end
