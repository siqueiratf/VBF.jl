# Implements Theorem 5 — Second construction, sn odd
# Paper: Zha, Hu, Sun (2014), "Constructing new differentially 4-uniform
#        permutations from the inverse function", Finite Fields Appl.
# Section: 3.2
#
# Pseudocode:
#   1. For (s,n) with sn odd, find t₁ ∈ F_q* with Tr(t₁⁻¹)=1, t₂ ∈ F_q*
#   2. Build f via Construction 2 (Eq. 8), verify Δ_f = 4
# VBF API used: SBox, is_permutation, differential_uniformity, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

function theorem5_verify(s::Int, n::Int; modulus::Int = primitive_polynomial(s * n))
    @assert isodd(s) && isodd(n) "Theorem 5 requires s,n both odd"
    N = s * n
    t1 = find_t1_construction2(s, N; modulus)
    t2 = 1  # t₂ ∈ F_q*, use simplest nonzero
    lut = construction2_lut(s, n, t1, t2; modulus)
    sbox = SBox{N}(lut)
    perm = is_permutation(sbox)
    du = differential_uniformity(sbox)
    (; s, n, N, t1, t2, perm, du, sbox)
end

function theorem5_report(io::IO = stdout;
                         params = [(1, 3), (1, 5), (1, 7), (3, 3)])
    print_section("Theorem 5 — Construction 2, sn odd → Δ_f = 4", io)
    for (s, n) in params
        r = theorem5_verify(s, n)
        label = "s=$s, n=$n (N=$(r.N))"
        print_check("$label: permutation", r.perm, io)
        print_check("$label: Δ_f = 4", r.du == 4, io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem5_report()
end
