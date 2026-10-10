# Implements Proposition 4 — a trace sufficient condition for x+L(x³) perm.
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218-4229.
# Section: III — Sufficient conditions for permutations x+L(x³).
#
# Proposition 4: L linear. If for every u with L(u)≠0,
#     trₙ( u / L(u)³ ) = 0  (n odd) / 1  (n even),
# then F(x)=x+L(x³) is a permutation.
#
# Pseudocode:
#   satisfies(L,n): ∀u with L(u)≠0, trₙ(u·L(u)⁻³) == (n even ? 1 : 0)
#   for each (L,n): report satisfies(L,n) and is_permutation(x+L(x³)); the
#   theorem asserts satisfies ⟹ permutation.
# VBF API used: gf_mul, gf_pow, gf_inv, gf_trace, is_permutation

include(joinpath(@__DIR__, "helpers.jl"))

"""
    satisfies_prop4(Llut, n; modulus) -> Bool

Whether L (as a full LUT) meets the Proposition 4 trace condition.
"""
function satisfies_prop4(Llut::Vector{Int}, n::Integer; modulus::Integer = _mod(n))
    want = iseven(Int(n)) ? 1 : 0
    for u = 1:((1<<Int(n))-1)
        lu = apply_L(Llut, u)
        lu == 0 && continue
        inv3 = gf_pow(gf_inv(lu, n; modulus), 3, n; modulus)
        gf_trace(gf_mul(u, inv3, n; modulus), n; modulus) == want || return false
    end
    true
end

"""
    proposition4_report(io; save_results) -> NamedTuple

Verify: where the Prop-4 condition holds, x+L(x³) is a permutation (sufficient,
not necessary). Cross-check the odd-n trace class fails both.
"""
function proposition4_report(io::IO = stdout; save_results::Bool = false)
    print_section("Proposition 4 — trace condition ⟹ x+L(x³) permutation", io)
    cases = [(:trace, 6), (:trace, 8), (:class2, 6), (:class3, 6), (:trace, 5), (:trace, 7)]
    all_ok = true
    rows = Tuple{Symbol,Int,Bool,Bool}[]
    for (cls, n) in cases
        Llut = L_class_lut(cls, n)
        cond = satisfies_prop4(Llut, n)
        perm = is_permutation(as_sbox(perm_from_L(Llut, n), n))
        # Theorem: cond ⟹ perm. Consistency also expects (for these classes) cond ⇔ perm.
        ok = (!cond || perm) && (cond == perm)
        all_ok &= ok
        print_check("L=$cls n=$n: Prop-4 cond=$cond ⟹ permutation=$perm", ok, io)
        push!(rows, (cls, n, cond, perm))
    end
    print_kv("note", "Proposition 4 is sufficient (holds ⟹ permutation)", io)
    result = (; all_ok, rows)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "proposition4.toml"), "w") do f
            println(f, "# Proposition 4\nall_ok = $all_ok")
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition4_report()
end
