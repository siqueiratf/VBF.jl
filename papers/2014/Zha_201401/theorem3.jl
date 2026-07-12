# Implements Theorem 3 — First construction, s odd, n even
# Paper: Zha, Hu, Sun (2014), "Constructing new differentially 4-uniform
#        permutations from the inverse function", Finite Fields Appl.
# Section: 3.1
#
# Pseudocode:
#   1. For (s,n) with s odd, n even, build f via Construction 1 (Eq. 3)
#   2. Verify Δ_f = 6 when s≥5 or (s∈{1,3} and n/2 even)
#   3. Verify Δ_f = 4 when s∈{1,3} and n/2 odd
# VBF API used: SBox, is_permutation, differential_uniformity, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

function expected_du_theorem3(s::Int, n::Int)
    if s >= 5
        return 6
    elseif s in (1, 3) && iseven(n ÷ 2)
        return 6
    else
        return 4
    end
end

function theorem3_verify(s::Int, n::Int; modulus::Int = primitive_polynomial(s * n))
    @assert isodd(s) && iseven(n) "Theorem 3 requires s odd, n even"
    N = s * n
    t = 1  # t ∈ F_q* — simplest choice
    lut = construction1_lut(s, n, t; modulus)
    sbox = SBox{N}(lut)
    perm = is_permutation(sbox)
    du = differential_uniformity(sbox)
    expected = expected_du_theorem3(s, n)
    (; s, n, N, t, perm, du, expected, sbox)
end

function theorem3_report(io::IO = stdout;
                         params = [(1, 2), (1, 4), (1, 6), (3, 2)])
    print_section("Theorem 3 — Construction 1, s odd, n even → Δ_f = 6 or 4", io)
    for (s, n) in params
        r = theorem3_verify(s, n)
        label = "s=$s, n=$n (N=$(r.N))"
        print_check("$label: permutation", r.perm, io)
        print_check("$label: Δ_f = $(r.expected)", r.du == r.expected, io)
        print_kv("$label: expected", r.expected, io)
        print_kv("$label: computed", r.du, io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem3_report()
end
