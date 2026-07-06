# Implements Theorem 3 — APN property of Family 2, plus Lemma 2 checks.
# Paper: Bracken, Byrne, Markin, McGuire (2008),
#        "New Families of Quadratic Almost Perfect Nonlinear Trinomials and Multinomials",
#        Finite Fields and Their Applications 14 (2008), 703–714
# Section: 3 — Proof of APN property for family (2)
#
# Pseudocode (Theorem 3):
#   For each (k, s) with gcd(s,3k)=1, k≢0 mod 3, k+s≡0 mod 3:
#     1. u ← primitive element of GF(2^{3k})
#     2. For v=0 (binomial) and v=subfield_element (trinomial):
#        F ← family2_lut(k, s, u, v)
#        assert differential_uniformity(SBox(F)) == 2
#
# Pseudocode (Lemma 2):
#   For GF(2^{3k}), k not divisible by 3:
#     (i)  all θ ∈ GF(2^k)* are 7th powers in GF(2^k)    [7∤(2^k−1) since 3∤k]
#     (ii) u primitive in GF(2^{3k}) → u is NOT a 7th power
#     (iii) u^{2^k−1} is NOT a 7th power in GF(2^{3k})
#     (iv) θ^{2^t−1} IS a 7th power in GF(2^{3k}) when 3∣t
# VBF API used: SBox, differential_uniformity, gf_pow, gf_is_dth_power

include(joinpath(@__DIR__, "helpers.jl"))


const THEOREM3_CASES = [
    # (k, s, label, v_idx)  — v_idx=0 means v=0 (binomial); v_idx≥1 means nonzero GF(2^k) elem
    # k=2, s=1, n=6: gcd(1,6)=1, 3∤2, 3|(2+1)=3
    (2, 1, "n=6  k=2 s=1  v=0 (binomial, ref. [2])",  0),
    (2, 1, "n=6  k=2 s=1  v=ω²¹ (trinomial, new)",    1),
    # k=4, s=5, n=12: gcd(5,12)=1, 3∤4, 3|(4+5)=9
    (4, 5, "n=12 k=4 s=5  v=0 (binomial)",             0),
    (4, 5, "n=12 k=4 s=5  v=ω²⁷³ (trinomial)",        1),
]


"""
    theorem3_sbox(k, s, v_idx; modulus) -> SBox

Build a Family 2 SBox with u=2 (primitive) and v chosen as the
v_idx-th nonzero element of GF(2^k) in GF(2^{3k}) (v_idx=0 → v=0).
"""
function theorem3_sbox(k::Int, s::Int, v_idx::Int;
                        modulus::Int = primitive_polynomial(3k))
    n    = 3k
    v    = v_idx == 0 ? 0 : filter(!iszero, subfield_elements(n, k; modulus))[v_idx]
    SBox(family2_lut(k, s, 2, v; modulus))
end


function lemma2_report(io::IO = stdout)
    print_section("Lemma 2 — Seventh-power properties in GF(2^{3k}) (Section 3)", io)
    println(io, "  7 | 2^r−1 iff 3 | r.  For k=2, n=6:")
    println(io)

    k, n = 2, 6
    modulus = primitive_polynomial(n)
    subf    = filter(!iszero, subfield_elements(n, k; modulus))   # GF(4)* in GF(64)

    # (i) Every θ ∈ GF(2^k)* is a 7th power in GF(2^k): since 3∤k=2, 7∤(2^k−1)=3
    all_in_k_are_7th = all(gf_is_dth_power(θ, 7, n; modulus) for θ in subf)
    print_check("(i)  all θ ∈ GF(4)* are 7th powers in GF(4) [7∤(2^2−1)=3]",
                all_in_k_are_7th, io)

    # (ii) u=2 primitive in GF(64) is NOT a 7th power [7|(2^6−1)=63]
    u = 2
    print_check("(ii) u=2 primitive in GF(64) is not a 7th power [7|63]",
                !gf_is_dth_power(u, 7, n; modulus), io)

    # (iii) u^{2^k−1} = u^3 is NOT a 7th power in GF(64)
    u3 = gf_pow(u, (1 << k) - 1, n; modulus)
    print_check("(iii) u^{2^k−1}=u^3 is not a 7th power in GF(64)",
                !gf_is_dth_power(u3, 7, n; modulus), io)

    # (iv) θ^{2^t−1} is a 7th power for 3∣t: check t=3 and t=6
    t3 = gf_pow(u, (1 << 3) - 1, n; modulus)   # u^7
    t6 = gf_pow(u, (1 << 6) - 1, n; modulus)   # u^63 = 1
    print_check("(iv) u^{2^3−1}=u^7 is a 7th power in GF(64) [3|3]",
                gf_is_dth_power(t3, 7, n; modulus), io)
    print_check("(iv) u^{2^6−1}=1 is a 7th power in GF(64) [3|6]",
                gf_is_dth_power(t6, 7, n; modulus), io)
    println(io)
end


function theorem3_report(io::IO = stdout)
    lemma2_report(io)

    print_section("Theorem 3 — Family 2 trinomial APN (Section 3)", io)
    println(io, "  F(x) = u·x^{2^{n−k}+2^{k+s}} + u^{2^k}·x^{2^s+1} + v·x^{2^{k+s}+2^s}")
    println(io, "  Conditions: gcd(s,3k)=1, k≢0 mod 3, k+s≡0 mod 3,")
    println(io, "              u primitive in GF(2^{3k}), v ∈ GF(2^k).")
    println(io, "  v=0: binomial from [Budaghyan-Carlet-Felke-Leander 2006].")
    println(io)

    all_pass = true
    for (k, s, label, vidx) in THEOREM3_CASES
        F   = theorem3_sbox(k, s, vidx)
        apn = differential_uniformity(F) == 2
        all_pass &= apn
        print_check(label, apn, io)
    end
    println(io)
    print_check("All Theorem 3 instances APN", all_pass, io)
    print_kv("u", "2 = ω (primitive in GF(2^n))", io)
    print_kv("completeness",
             "n=6 exhaustive (binomial+trinomial); n=12 exhaustive (two subfamilies)", io)
end


if abspath(PROGRAM_FILE) == @__FILE__
    theorem3_report()
end
