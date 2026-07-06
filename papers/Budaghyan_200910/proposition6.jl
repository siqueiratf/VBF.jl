# Implements Proposition 6 — adjoint characterisation of x+L(x³) perm, n odd.
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218-4229.
# Section: III — Sufficient conditions for permutations x+L(x³).
#
# Proposition 6: n odd. x+L(x³) is a permutation iff for all b either L*(b)=0 or
#   trₙ(γ⁻¹b)=0, where L*(b)=γ³ (n odd ⇒ cubing is a bijection, γ unique).
#
# Pseudocode:
#   predicate(L,n): ∀b — L*(b)=0 OR trₙ(γ⁻¹b)=0 with γ = unique cube root of L*(b).
#   assert predicate(L,n) ⇔ is_permutation(x+L(x³)).
# VBF API used: gf_pow, gf_inv, gf_mul, gf_trace, is_permutation

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition5.jl"))    # reuse _cube_roots

"""
    predicate_prop6(Llut, n; modulus) -> Bool

The right-hand side of Proposition 6's iff (n odd, cubing bijective).
"""
function predicate_prop6(Llut::Vector{Int}, n::Integer; modulus::Integer = _mod(n))
    Lstar = adjoint_lut(Llut, n; modulus)
    root = _cube_roots(n; modulus)
    for b = 0:((1<<Int(n))-1)
        lb = Lstar[b+1]
        lb == 0 && continue
        γ = root[lb+1]
        γinv = gf_inv(γ, n; modulus)
        gf_trace(gf_mul(γinv, b, n; modulus), n; modulus) == 0 || return false
    end
    true
end

"""
    proposition6_report(io; save_results) -> NamedTuple

Verify Proposition 6's iff on odd-n linear maps (including the zero map, a
genuine permutation case, and non-permutation cases).
"""
function proposition6_report(io::IO = stdout; save_results::Bool = false)
    print_section("Proposition 6 — n odd: adjoint characterisation of x+L(x³) perm", io)
    all_ok = true
    rows = Tuple{Symbol,Int,Bool,Bool}[]
    for n in (5, 7)
        cands = [
            (:zero, zeros(Int, 1 << n)),               # x + 0 = x (permutation)
            (:trace, L_class_lut(:trace, n)),          # x+trₙ(x³) (not a perm, n odd)
            (:identity, collect(0:((1<<n)-1))),        # x+x³ (not a perm)
        ]
        for (name, Llut) in cands
            pred = predicate_prop6(Llut, n)
            perm = is_permutation(as_sbox(perm_from_L(Llut, n), n))
            ok = pred == perm
            all_ok &= ok
            print_check("n=$n L=$name: predicate=$pred ⇔ permutation=$perm", ok, io)
            push!(rows, (name, n, pred, perm))
        end
    end
    result = (; all_ok, rows)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "proposition6.toml"), "w") do f
            println(f, "# Proposition 6\nall_ok = $all_ok")
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition6_report()
end
