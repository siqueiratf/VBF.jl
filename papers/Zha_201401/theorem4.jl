# Implements Theorem 4 — Second construction, n odd, s even
# Paper: Zha, Hu, Sun (2014), "Constructing new differentially 4-uniform
#        permutations from the inverse function", Finite Fields Appl.
# Section: 3.2
#
# Pseudocode:
#   1. For (s,n) with n odd, s even, find t₁ ∈ F_q with Tr(t₁⁻¹)=1, t₂ ∈ F_q
#   2. Build f via Construction 2 (Eq. 8), verify Δ_f = 4
# VBF API used: SBox, is_permutation, differential_uniformity, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

function theorem4_verify(s::Int, n::Int; modulus::Int = primitive_polynomial(s * n))
    @assert iseven(s) && isodd(n) "Theorem 4 requires s even, n odd"
    N = s * n
    t1 = find_t1_construction2(s, N; modulus)
    t2 = 0  # t₂ ∈ F_q, 0 is valid
    lut = construction2_lut(s, n, t1, t2; modulus)
    sbox = SBox{N}(lut)
    perm = is_permutation(sbox)
    du = differential_uniformity(sbox)
    (; s, n, N, t1, t2, perm, du, sbox)
end

function theorem4_report(io::IO = stdout;
                         params = [(2, 3)])
    print_section("Theorem 4 — Construction 2, n odd, s even → Δ_f = 4", io)
    for (s, n) in params
        r = theorem4_verify(s, n)
        label = "s=$s, n=$n (N=$(r.N))"
        print_check("$label: permutation", r.perm, io)
        print_check("$label: Δ_f = 4", r.du == 4, io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem4_report()
end
