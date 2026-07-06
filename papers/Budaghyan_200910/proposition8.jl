# Implements Proposition 8 — characterisation of permutations L(x³)+L'(x).
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218-4229 (Prop. 5 of ref. [2]).
# Section: III — Sufficient conditions for permutations x+L(x³).
#
# Proposition 8: F(x)=L(x³)+L'(x) is a permutation of GF(2ⁿ) iff for every
#   u∈GF(2ⁿ)* and every v with trₙ(v)=trₙ(1): L(u³·v) ≠ L'(u).
#
# Pseudocode:
#   predicate(L,L',n): ∀u≠0 ∀v[trₙ(v)=trₙ(1)]  L(u³v) ≠ L'(u).
#   assert predicate ⇔ is_permutation(L(x³)+L'(x)).
# VBF API used: gf_pow, gf_mul, gf_trace, is_permutation

include(joinpath(@__DIR__, "helpers.jl"))

"""
    predicate_prop8(Llut, Lplut, n; modulus) -> Bool

The right-hand side of Proposition 8's iff.
"""
function predicate_prop8(
    Llut::Vector{Int},
    Lplut::Vector{Int},
    n::Integer;
    modulus::Integer = _mod(n),
)
    N = 1 << Int(n)
    t1 = gf_trace(1, n; modulus)                         # trₙ(1)
    vs = [v for v = 0:(N-1) if gf_trace(v, n; modulus) == t1]
    for u = 1:(N-1)
        lpu = Lplut[u+1]
        u3 = gf_pow(u, 3, n; modulus)
        for v in vs
            apply_L(Llut, gf_mul(u3, v, n; modulus)) == lpu && return false
        end
    end
    true
end

"""
    proposition8_report(io; save_results) -> NamedTuple

Verify Proposition 8's iff on several (L, L') pairs.
"""
function proposition8_report(io::IO = stdout; save_results::Bool = false)
    print_section("Proposition 8 — L(x³)+L'(x) permutation characterisation", io)
    all_ok = true
    rows = Tuple{Int,Symbol,Bool,Bool}[]
    for n in (5, 6, 8)
        idlut = collect(0:((1<<n)-1))
        zerolut = zeros(Int, 1 << n)
        trlut = L_class_lut(:trace, n)
        cands = [
            (:tr_x3_plus_x, trlut, idlut),      # x+trₙ(x³): perm for even n only
            (:tr_x3, trlut, zerolut),           # trₙ(x³): never a permutation
            (:x3_plus_x, idlut, idlut),         # x³+x: not a permutation
        ]
        for (name, Llut, Lplut) in cands
            pred = predicate_prop8(Llut, Lplut, n)
            F = [apply_L(Llut, gf_pow(x, 3, n)) ⊻ Lplut[x+1] for x = 0:((1<<n)-1)]
            perm = is_permutation(as_sbox(F, n))
            ok = pred == perm
            all_ok &= ok
            print_check("n=$n $name: predicate=$pred ⇔ permutation=$perm", ok, io)
            push!(rows, (n, name, pred, perm))
        end
    end
    result = (; all_ok, rows)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "proposition8.toml"), "w") do f
            println(f, "# Proposition 8\nall_ok = $all_ok")
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition8_report()
end
