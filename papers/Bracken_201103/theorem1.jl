# Implements Theorem 1 — the quadrinomial APN construction.
# Paper: Bracken, Byrne, Markin, McGuire (2011), "A Few More Quadratic APN Functions",
#        Cryptography and Communications 3:43–53
# Section: 2 — New APN Functions
#
# Pseudocode:
#   1. For each (k,s) with (s,3k)=(3,k)=1 and 3∣(k+s):
#      a. u ← primitive element of GF(2^(3k))  (= field generator 2)
#      b. v,w ← elements of GF(2^k) with vw≠1
#      c. F ← bracken_lut(k,s,u,v,w)
#      d. assert differential_uniformity(SBox(F)) == 2
#   2. Verify all four subfamilies (v=w=0, v=0/w≠0, v≠0/w=0, v≠0/w≠0).
# VBF API used: SBox, differential_uniformity, gf_mul

include(joinpath(@__DIR__, "helpers.jl"))


const THEOREM1_CASES = [
    # (k, s, label, v_idx, w_idx)  — indices into GF(2^k)*; 0 means v or w = 0
    # n=6, k=2, s=1: smallest valid instance (3∤2, (1,6)=1, 2+1=3 divisible by 3)
    (2, 1, "n=6  Family 8  (v≠0, w≠0)",  1, 2),
    (2, 1, "n=6  Family 8W (v≠0, w=0)",  1, 0),
    (2, 1, "n=6  Family 7  (v=0, w≠0)",  0, 1),
    (2, 1, "n=6  Family 1  (v=0, w=0)",  0, 0),
    # n=12, k=4, s=5: the case used in the paper's Table 2
    (4, 5, "n=12 Family 8  (v≠0, w≠0)",   1, 5),
    (4, 5, "n=12 Family 8W (v≠0, w=0)",   1, 0),
    (4, 5, "n=12 Family 7  (v=0, w≠0)",   0, 1),
    (4, 5, "n=12 Family 1  (v=0, w=0)",   0, 0),
]


"""
    theorem1_sbox(k, s, v_idx, w_idx; modulus) -> SBox

Build a Bracken quadrinomial SBox with u = 2 (primitive), v and w chosen as
the v_idx-th and w_idx-th nonzero elements of GF(2^k) (0 → zero element).
"""
function theorem1_sbox(k::Int, s::Int, v_idx::Int, w_idx::Int;
                        modulus::Int = primitive_polynomial(3k))
    n = 3k
    v = v_idx == 0 ? 0 : gf_subfield_elem(n, k, v_idx - 1; modulus)
    w = w_idx == 0 ? 0 : gf_subfield_elem(n, k, w_idx - 1; modulus)
    SBox(bracken_lut(k, s, 2, v, w; modulus))
end


function theorem1_report(io::IO = stdout)
    print_section("Theorem 1 — Quadrinomial APN family (Bracken et al., Section 2)", io)
    println(io, "  F(x) = u^{2^k} x^{2^{2k}+2^{k+s}}")
    println(io, "        + u x^{2^s+1}")
    println(io, "        + v x^{2^{2k}+1}")
    println(io, "        + w u^{2^k+1} x^{2^{k+s}+2^s}")
    println(io, "  Conditions: (s,3k)=(3,k)=1, 3∣(k+s), u primitive, v,w ∈ GF(2^k), vw≠1.")
    println(io)
    all_pass = true
    for (k, s, label, vi, wi) in THEOREM1_CASES
        F   = theorem1_sbox(k, s, vi, wi)
        apn = differential_uniformity(F) == 2
        all_pass &= apn
        print_check(label, apn, io)
    end
    println(io)
    print_check("All Theorem 1 instances APN", all_pass, io)
    print_kv("completeness", "exhaustive over listed (k,s,subfamily) tuples", io)
end


if abspath(PROGRAM_FILE) == @__FILE__
    theorem1_report()
end
