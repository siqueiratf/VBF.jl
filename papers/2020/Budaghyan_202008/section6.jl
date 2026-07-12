# Implements Section VI — Isotopic Shifts of Gold Functions.
# Paper: Budaghyan et al. (2020), "Constructing APN Functions Through Isotopic Shifts",
#        IEEE Trans. Inf. Theory 66(8), pp. 5299–5309. DOI: 10.1109/TIT.2020.2974471
# Section: VI — Lemma VI.6 (monomial L), Theorem VI.3 (main APN construction)
#
# Pseudocode:
#   Lemma VI.6:
#     (i)  L(x) = u·x, u ∉ F₂  →  G_{i,L} linearly equivalent to G_i
#     (ii) n odd, L(x) = u·x^{2^i}  →  G_{i,L} APN, linearly equiv to G_{2i}
#     (iv) gcd(j,n)=1, j≠i (n odd)  →  G_{i,L} not APN
#   Theorem VI.3 (n=3m, q=2^m, k=3):
#     1. Compute [a,b,d] = [ζ^424, ζ, ζ^34] in GF(2^9)
#     2. Find c with c²+c = d
#     3. L(x) = a·x^{2^6} + b·x^{2^3} + c·x
#     4. G_{1,L}(x) = G_1(x ⊕ L(x)) ⊕ G_1(x) ⊕ G_1(L(x))
#     5. Verify differential_uniformity = 2
# VBF API used: gold_lut, isotopic_shift_lut, SBox, differential_uniformity,
#               are_linear_equivalent, apn_ea_mugshot

include(joinpath(@__DIR__, "helpers.jl"))
using Dates

"""
    section6_check_lemmaVI6(; io) -> NamedTuple

Verify Lemma VI.6 cases (i), (ii), (iv) for G_1 = x³ over GF(2⁵).
"""
function section6_check_lemmaVI6(; io::IO = devnull)
    n  = 5
    mod = primitive_polynomial(n)
    G1  = gold_lut(n, 1; modulus = mod)
    G2  = gold_lut(n, 2; modulus = mod)  # x⁵, APN since gcd(2,5)=1
    F1  = SBox{n}(G1)
    F2  = SBox{n}(G2)

    # Case (i): L(x) = ζ·x, ζ∉F₂  →  G_{1,L} lin-equiv to G_1
    zeta = 2  # primitive element of GF(2^5) under primitive_polynomial(5)
    L_scalar = linear_monomial_lut(n, 0, zeta; modulus = mod)  # j=0: L=ζ·x
    shift_i = SBox{n}(isotopic_shift_lut(G1, L_scalar))
    ok_i = are_linear_equivalent(shift_i, F1)

    # Case (ii): n=5 odd, j=i=1, L(x) = x^{2^1}=x²  →  G_{1,L} EA-equiv to G_2
    # G_{i,L}(x) = u·x^{2^{i+1}} + u^{2^i}·G_{2i}(x), so G_{1,L} = G_2 + linear → EA-equiv
    L_frob = linear_monomial_lut(n, 1, 1; modulus = mod)  # L(x)=x²
    shift_ii = SBox{n}(isotopic_shift_lut(G1, L_frob))
    ok_ii = are_ea_equivalent(shift_ii, F2)

    # Case (iv): gcd(j,n)=1, j≠i → not APN.  Take j=2, n=5: gcd(2,5)=1, j≠1=i
    L_j2 = linear_monomial_lut(n, 2, 1; modulus = mod)  # L(x)=x⁴
    shift_iv = SBox{n}(isotopic_shift_lut(G1, L_j2))
    ok_iv = differential_uniformity(shift_iv) > 2

    print_section(io, "Section VI — Lemma VI.6 (G_1 over GF(2⁵))")
    print_check(io, "Case (i):  L(x)=ζ·x  → G_{1,L} ≈_lin G_1", ok_i)
    print_check(io, "Case (ii): L(x)=x²   → G_{1,L} ≈_EA  G_2", ok_ii)
    print_check(io, "Case (iv): L(x)=x⁴, gcd(2,5)=1 → not APN", ok_iv)

    (; ok_i, ok_ii, ok_iv)
end

"""
    section6_theorem_vi3_parameters(; modulus) -> NamedTuple

Compute the parameters [a, b, c, d] for Theorem VI.3, n=9, m=3, k=3.
[a, b, d] = [ζ^424, ζ, ζ^34] from Section VII-B of the paper; c satisfies c²+c=d.
"""
function section6_theorem_vi3_parameters(;
    modulus::Int = primitive_polynomial(9),
)
    n   = 9
    zeta = 2  # ζ = primitive element of GF(2^9)
    a = gf_pow(zeta, 424, n; modulus = modulus)
    b = gf_pow(zeta,   1, n; modulus = modulus)  # = 2
    d = gf_pow(zeta,  34, n; modulus = modulus)
    c = find_c_for_d(d, n; modulus = modulus)
    (; n, modulus, zeta, a, b, c, d)
end

"""
    section6_build_theorem_vi3_apn(params) -> SBox{9}

Construct the APN function G_{1,L} from Theorem VI.3 (Section VII-B, n=9).
L(x) = a·x^{2^6} + b·x^{2^3} + c·x over GF(2^9).
"""
function section6_build_theorem_vi3_apn(params = section6_theorem_vi3_parameters())
    (; n, modulus, a, b, c) = params
    G1 = gold_lut(n, 1; modulus = modulus)              # x³
    L  = linear_trinomial_lut(n, 6, 3, a, b, c; modulus = modulus)
    SBox{n}(isotopic_shift_lut(G1, L))
end

"""
    section6_check_theoremVI3(; io) -> NamedTuple

Verify Theorem VI.3: G_{1,L} with [a,b,d]=[ζ^424,ζ,ζ^34] is APN over GF(2^9).
"""
function section6_check_theoremVI3(; io::IO = devnull)
    mod = primitive_polynomial(9)
    p   = section6_theorem_vi3_parameters(; modulus = mod)
    F   = section6_build_theorem_vi3_apn(p)

    du = differential_uniformity(F)
    is_apn = (du == 2)

    print_section(io, "Section VI — Theorem VI.3  (n=9, k=m=3, G_1 isotopic shift)")
    print_kv(io, "a = ζ^424", "0x$(string(p.a, base=16))")
    print_kv(io, "b = ζ",     "0x$(string(p.b, base=16))")
    print_kv(io, "d = ζ^34",  "0x$(string(p.d, base=16))")
    print_kv(io, "c (c²⊕c=d)","0x$(string(p.c, base=16))")
    print_kv(io, "differential uniformity", du)
    print_check(io, "G_{1,L} is APN (du=2)", is_apn)

    (; is_apn, du, F, params = p)
end

function section6_report(io::IO = stdout)
    print_section(io, "Section VI: Isotopic Shifts of Gold Functions")
    section6_check_lemmaVI6(; io)
    section6_check_theoremVI3(; io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    using Dates
    section6_report()
end
