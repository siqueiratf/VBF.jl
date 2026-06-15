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
# VBF API used: SBox, walsh_transform, gf_mul, gf_absolute_trace, trace_component_is_bent

include(joinpath(@__DIR__, "theorem1.jl"))


function theorem4_report(io::IO = stdout)
    print_section("Theorem 4 — Tr(f) is bent for Family 1 (Section 4)", io)
    println(io, "  Claim: x ↦ Tr(F(x)) is a bent Boolean function on K = GF(2^{2k}).")
    println(io, "  Extended claim: x ↦ Tr(v·F(x)) is bent for all v ∈ GF(2^k).")
    println(io, "  (Tr = absolute trace GF(2^{2k}) → F₂; · = GF multiplication.)")
    println(io)

    k, s    = 3, 1
    n       = 2k
    modulus = primitive_polynomial(n)
    subf    = gf_subfield_nonzero_elements(n, k; modulus)

    for (label, ridx) in [("trinomial  (r=[0,0])", [0, 0]),
                           ("pentanomial (r=[ω⁹,0])", [1, 0])]
        F = theorem1_sbox(k, s, ridx; modulus)

        # Main claim: Tr(F(x)) is bent (v=1)
        tr_bent = trace_component_is_bent(F, 1; modulus)
        print_check("n=6 $label: Tr(F(x)) is bent  [v=1]", tr_bent, io)

        # Extended claim: Tr(v·F(x)) bent for all v ∈ GF(2^k)*
        all_bent = all(trace_component_is_bent(F, v; modulus) for v in subf)
        print_check("n=6 $label: all v ∈ GF(8)* → Tr(v·F(x)) bent  [$(length(subf)) checks]",
                    all_bent, io)
        println(io)
    end

    print_kv("completeness",
             "exhaustive Tr-bent check for n=6; N even guaranteed by n=2k", io)
end


if abspath(PROGRAM_FILE) == @__FILE__
    theorem4_report()
end
