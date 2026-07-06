# Implements Proposition 7 — subfield-coefficient permutations force L²=0.
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218-4229.
# Section: III — Sufficient conditions for permutations x+L(x³).
#
# Proposition 7: n even, L linear with x+L(x³) a permutation. If all coefficients
#   of L lie in GF(2^{n/2}) then L(GF(2^{n/2})) = {0} and L² = 0.
#
# Pseudocode:
#   L = trₙ  (coeffs all in GF(2)⊆GF(2^{n/2}); x+trₙ(x³) is a permutation):
#     assert L(a)=0 ∀a∈GF(2^{n/2}) and L(L(x))=0 ∀x.
# VBF API used: gf_trace, subfield_elements, is_permutation

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition7_report(io; save_results) -> NamedTuple

Verify the conclusion of Proposition 7 for L=trₙ at even n (its coefficients are
all 1 ∈ GF(2) ⊆ GF(2^{n/2}) and x+trₙ(x³) is a permutation).
"""
function proposition7_report(io::IO = stdout; save_results::Bool = false)
    print_section("Proposition 7 — n even, L-coeffs in GF(2^{n/2}) ⟹ L(GF(2^{n/2}))=0, L²=0", io)
    all_ok = true
    rows = Tuple{Int,Bool,Bool,Bool}[]
    for n in (6, 8)
        Llut = L_class_lut(:trace, n)
        is_perm = is_permutation(as_sbox(perm_from_L(Llut, n), n))       # hypothesis
        sub = subfield_elements(n, n ÷ 2)
        vanishes_on_sub = all(a -> apply_L(Llut, a) == 0, sub)
        l_squared_zero = all(x -> apply_L(Llut, apply_L(Llut, x)) == 0, 0:((1<<n)-1))
        ok = is_perm && vanishes_on_sub && l_squared_zero
        all_ok &= ok
        print_check(
            "n=$n L=trₙ: perm=$is_perm ⟹ L|GF(2^$(n÷2))=0 ($vanishes_on_sub), L²=0 ($l_squared_zero)",
            ok,
            io,
        )
        push!(rows, (n, is_perm, vanishes_on_sub, l_squared_zero))
    end
    result = (; all_ok, rows)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "proposition7.toml"), "w") do f
            println(f, "# Proposition 7\nall_ok = $all_ok")
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition7_report()
end
