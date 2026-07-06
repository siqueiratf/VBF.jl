# Implements Theorem 1 — First construction, s even
# Paper: Zha, Hu, Sun (2014), "Constructing new differentially 4-uniform
#        permutations from the inverse function", Finite Fields Appl.
# Section: 3.1
#
# Pseudocode:
#   1. For each valid (s,n) with s even, build f via Construction 1 (Eq. 3)
#   2. Verify f is a permutation with Δ_f = 4
# VBF API used: SBox, is_permutation, differential_uniformity, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

function theorem1_verify(s::Int, n::Int; modulus::Int = primitive_polynomial(s * n))
    @assert iseven(s) "Theorem 1 requires s even"
    N = s * n
    t = find_t_construction1(s, n; modulus)
    lut = construction1_lut(s, n, t; modulus)
    sbox = SBox{N}(lut)
    perm = is_permutation(sbox)
    du = differential_uniformity(sbox)
    (; s, n, N, t, perm, du, sbox)
end

function theorem1_report(io::IO = stdout;
                         params = [(2, 2), (2, 3), (2, 4), (4, 2)])
    print_section("Theorem 1 — Construction 1, s even → Δ_f = 4", io)
    for (s, n) in params
        r = theorem1_verify(s, n)
        label = "s=$s, n=$n (N=$(r.N))"
        print_check("$label: permutation", r.perm, io)
        print_check("$label: Δ_f = 4", r.du == 4, io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem1_report()
end
