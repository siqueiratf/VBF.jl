# Implements Theorem 2 — First construction, s and n both odd
# Paper: Zha, Hu, Sun (2014), "Constructing new differentially 4-uniform
#        permutations from the inverse function", Finite Fields Appl.
# Section: 3.1
#
# Pseudocode:
#   1. For each valid (s,n) with s,n odd, find t ∈ F_q* with t³=1
#   2. Build f via Construction 1 (Eq. 3), verify Δ_f = 4
#   Note: when s is odd, 3 ∤ (2^s − 1) but 3 | (2^{sn} − 1) when sn is even-free.
#         Actually when s,n odd, sn odd → 2^{sn} ≡ 2 (mod 3), so 3 ∤ (2^{sn}−1).
#         But we need t ∈ F_q*. When s odd, ω ∉ F_q.
#         The paper says t ∈ F_q*, NOT t³=1 for odd s.
#         Re-reading: Theorem 2 just requires t ∈ F_q*.
# VBF API used: SBox, is_permutation, differential_uniformity, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

function theorem2_verify(s::Int, n::Int; modulus::Int = primitive_polynomial(s * n))
    @assert isodd(s) && isodd(n) "Theorem 2 requires s,n both odd"
    N = s * n
    # t ∈ F_q* — use t=1 (simplest nonzero element always in F_q)
    t = 1
    lut = construction1_lut(s, n, t; modulus)
    sbox = SBox{N}(lut)
    perm = is_permutation(sbox)
    du = differential_uniformity(sbox)
    (; s, n, N, t, perm, du, sbox)
end

function theorem2_report(io::IO = stdout;
                         params = [(1, 3), (1, 5), (1, 7), (3, 3)])
    print_section("Theorem 2 — Construction 1, s,n odd → Δ_f = 4", io)
    for (s, n) in params
        r = theorem2_verify(s, n)
        label = "s=$s, n=$n (N=$(r.N))"
        print_check("$label: permutation", r.perm, io)
        print_check("$label: Δ_f = 4", r.du == 4, io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem2_report()
end
