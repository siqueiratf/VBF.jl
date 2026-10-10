# Implements Example 1 — Construction 3 over F_{2^4}, Δ_f = 4
# Paper: Zha, Hu, Sun (2014), "Constructing new differentially 4-uniform
#        permutations from the inverse function", Finite Fields Appl.
# Section: 4
#
# Pseudocode:
#   1. Let s=2, n=2 (q=4, N=4), t₁,t₂ ∈ F_4*
#   2. Build f = (x+t₂)^{-1} + (x^4+x+t₁)^{15}(x^{-1}+(x+t₂)^{-1})
#   3. Verify Δ_f = 4 for all valid t₁,t₂
# VBF API used: SBox, is_permutation, differential_uniformity, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

function example1_verify(; modulus::Int = primitive_polynomial(4))
    s, n, N = 2, 2, 4
    results = NamedTuple[]
    # t₁,t₂ ∈ F_4* = nonzero elements of F_4
    fq_star = [x for x in subfield_elements(N, s; modulus) if x != 0]
    for t1 in fq_star
        # Tr_s^{sn}(t₁) = Tr_2^4(t₁) must be 0 for S to be non-empty
        if gf_relative_trace(t1, N, s; modulus) != 0
            continue
        end
        for t2 in fq_star
            lut = construction3_lut(s, n, t1, t2; modulus)
            sbox = SBox{N}(lut)
            perm = is_permutation(sbox)
            du = differential_uniformity(sbox)
            push!(results, (; t1, t2, perm, du, sbox))
        end
    end
    results
end

function example1_report(io::IO = stdout)
    print_section("Example 1 — Construction 3 over F_{2^4}, Δ_f = 4", io)
    results = example1_verify()
    if isempty(results)
        println(io, "  No valid (t₁,t₂) pairs found with Tr(t₁)=0")
        return
    end
    all_perm = all(r -> r.perm, results)
    all_4 = all(r -> r.du == 4, results)
    print_check("All $(length(results)) instances are permutations", all_perm, io)
    print_check("All instances have Δ_f = 4", all_4, io)
    for r in results
        print_kv("t₁=$(r.t1), t₂=$(r.t2)", "Δ_f=$(r.du)", io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    example1_report()
end
