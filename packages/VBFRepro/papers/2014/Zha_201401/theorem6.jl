# Implements Theorem 6 — Affine subspace modification, Δ_f ≤ 6
# Paper: Zha, Hu, Sun (2014), "Constructing new differentially 4-uniform
#        permutations from the inverse function", Finite Fields Appl.
# Section: 4
#
# Pseudocode:
#   1. Find t₁ ∈ F_{q^n}* with Tr_s^{sn}(t₁) = 0, t₂ ∈ F_q*
#   2. Build S = { x : x^q + x = t₁ }
#   3. Build f via Construction 3, verify Δ_f ≤ 6
# VBF API used: SBox, is_permutation, differential_uniformity, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

function theorem6_verify(s::Int, n::Int; modulus::Int = primitive_polynomial(s * n))
    N = s * n
    t1 = find_t1_construction3(s, n; modulus)
    t2 = 1  # t₂ ∈ F_q*
    lut = construction3_lut(s, n, t1, t2; modulus)
    sbox = SBox{N}(lut)
    perm = is_permutation(sbox)
    du = differential_uniformity(sbox)
    S = build_affine_subspace(s, n, t1; modulus)
    (; s, n, N, t1, t2, perm, du, s_size = length(S), sbox)
end

function theorem6_report(io::IO = stdout;
                         params = [(2, 2), (2, 3), (1, 4)])
    print_section("Theorem 6 — Construction 3, affine subspace → Δ_f ≤ 6", io)
    for (s, n) in params
        r = theorem6_verify(s, n)
        label = "s=$s, n=$n (N=$(r.N))"
        print_check("$label: permutation", r.perm, io)
        print_check("$label: Δ_f ≤ 6", r.du <= 6, io)
        print_kv("$label: Δ_f", r.du, io)
        print_kv("$label: |S|", r.s_size, io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem6_report()
end
