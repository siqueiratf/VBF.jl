# Implements verification of Propositions 1, 2, and Corollary 3.
# Paper: Kaleyski, N. (2022), "Deciding EA-equivalence via invariants",
#        Cryptography and Communications, 2021
# Section: 2 — A family of EA-invariants
#
# Pseudocode (Proposition 1, Corollary 3):
#   Given F, G quadratic APN with G = L1 ∘ F ∘ L2 ⊕ A (EA-equivalent):
#     1. Compute multiset of sigma-multiplicities for F and G.
#     2. Multisets must be equal for any even k (Prop 1) and any k (Cor 3,
#        quadratic case via Prop 2).
# VBF API used: SBox, sigma_multiplicities, are_ea_equivalent, ea_partition

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog


"""
    proposition1_ea_invariance(; io, n, k_values) -> NamedTuple

Proposition 1: sigma multiset is EA-invariant for even k.
Corollary 3: for quadratic functions, any k.

Constructs G(x) = F(x ⊕ 1) ⊕ 2 from Gold x^3 (an EA-equivalent variant),
then checks sigma_multiplicities(F) == sigma_multiplicities(G) for each k.
"""
function proposition1_ea_invariance(;
    io::IO = stdout,
    n::Int = 6,
    k_values::Vector{Int} = [2, 3, 4, 6],
)
    F = gold_x3(n)
    # G = F(x ⊕ 1) ⊕ 2: EA-equivalent to F (affine input/output shifts)
    sz = 1 << n
    G_lut = UInt8[UInt8(xor(Int(F.lut[xor(x, 1) + 1]), 2)) for x = 0:(sz - 1)]
    G = SBox{n,UInt8}(G_lut)

    print_section("Proposition 1 / Corollary 3 — EA-invariance of sigma multisets (n=$n)", io)
    print_kv("F", "Gold x^3 over F_2^$n", io)
    print_kv("G(x)", "F(x ⊕ 1) ⊕ 2  (EA-equivalent to F)", io)
    print_kv("EA-equivalent", are_ea_equivalent(F, G), io)

    all_ok = true
    for k in k_values
        sp_F = sigma_multiplicities(F; k = k)
        sp_G = sigma_multiplicities(G; k = k)
        ok = (sp_F == sp_G)
        all_ok &= ok
        parity = (k % 2 == 0) ? "even k" : "odd k (Corollary 3: quadratic)"
        print_check("sigma_k=$k multiset equal ($parity)", ok, io)
    end

    return (; all_ok, n, k_values)
end

"""
    proposition2_quadratic_normalization(; io, n) -> NamedTuple

Proposition 2: for quadratic APN functions F, G related by
    A1 ∘ F ∘ A2 + A = G (A1, A2 affine with nonzero constants),
there exist linear L1, L2 such that L1 ∘ F ∘ L2 + A' = G.

Demonstrated by: building G from affine maps with c1=2, c2=1 (nonzero constants),
then showing are_ea_equivalent(F, G) = true.
"""
function proposition2_quadratic_normalization(; io::IO = stdout, n::Int = 5)
    F = gold_x3(n)
    sz = 1 << n
    # A2(x) = x ⊕ c2 (bijective, constant c2 = 1 ≠ 0)
    # A1(x) = x ⊕ c1 (bijective, constant c1 = 3 ≠ 0)
    # G(x) = A1(F(A2(x))) = F(x ⊕ 1) ⊕ 3
    c1 = 3
    c2 = 1
    G_lut = UInt8[UInt8(xor(Int(F.lut[xor(x, c2) + 1]), c1)) for x = 0:(sz - 1)]
    G = SBox{n,UInt8}(G_lut)

    print_section("Proposition 2 — Quadratic normalization to linear A1, A2 (n=$n)", io)
    print_kv("F", "Gold x^3 over F_2^$n", io)
    print_kv("G(x)", "F(x ⊕ $c2) ⊕ $c1  (affine A2 with c2=$c2≠0, A1 with c1=$c1≠0)", io)

    ok = are_ea_equivalent(F, G)
    print_check("are_ea_equivalent(F, G) == true (linear L1,L2 exist)", ok, io)
    # sigma multisets must also be equal (even k), consistent with Prop 1
    sp_ok = (sigma_multiplicities(F; k = 4) == sigma_multiplicities(G; k = 4))
    print_check("sigma_4 multisets equal (Prop 1 check)", sp_ok, io)

    return (; ok, sp_ok, n)
end

function proposition1_report(; io::IO = stdout)
    print_header(io)
    r1 = proposition1_ea_invariance(; io, n = 6, k_values = [2, 3, 4, 6])
    r2 = proposition2_quadratic_normalization(; io, n = 5)
    return (; r1, r2)
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition1_report()
end
