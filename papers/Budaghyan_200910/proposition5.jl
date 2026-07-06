# Implements Proposition 5 — adjoint characterisation of x+L(x³) perm, n even.
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218-4229.
# Section: III — Sufficient conditions for permutations x+L(x³).
#
# Proposition 5: n even. x+L(x³) is a permutation of GF(2ⁿ) iff for every
#   b∈GF(2ⁿ)* with L*(b)≠0 there is γ with L*(b)=γ³ and trₙ²(γ⁻¹b) ≠ 0
#   (L* = adjoint of L w.r.t. the trace form).
#
# Pseudocode:
#   predicate(L,n): ∀b≠0 with L*(b)≠0 — L*(b) is a cube γ³ AND tr_{n/2}(γ⁻¹b)≠0.
#   assert predicate(L,n) ⇔ is_permutation(x+L(x³)).
# VBF API used: gf_pow, gf_inv, gf_mul, gf_relative_trace, is_permutation

include(joinpath(@__DIR__, "helpers.jl"))

"""Map cube → one cube root over GF(2ⁿ) (`0` where no root)."""
function _cube_roots(n::Integer; modulus::Integer = _mod(n))
    N = 1 << Int(n)
    root = fill(-1, N)
    for γ = 0:(N-1)
        c = gf_pow(γ, 3, n; modulus)
        root[c+1] == -1 && (root[c+1] = γ)
    end
    root
end

"""
    predicate_prop5(Llut, n; modulus) -> Bool

The right-hand side of Proposition 5's iff.
"""
function predicate_prop5(Llut::Vector{Int}, n::Integer; modulus::Integer = _mod(n))
    Lstar = adjoint_lut(Llut, n; modulus)
    root = _cube_roots(n; modulus)
    for b = 1:((1<<Int(n))-1)
        lb = Lstar[b+1]
        lb == 0 && continue
        γ = root[lb+1]
        γ == -1 && return false                    # L*(b) not a cube
        γinv = gf_inv(γ, n; modulus)
        gf_relative_trace(gf_mul(γinv, b, n; modulus), n, 2; modulus) != 0 || return false
    end
    true
end

"""
    proposition5_report(io; save_results) -> NamedTuple

Verify Proposition 5's iff on several even-n linear maps.
"""
function proposition5_report(io::IO = stdout; save_results::Bool = false)
    print_section("Proposition 5 — n even: adjoint characterisation of x+L(x³) perm", io)
    all_ok = true
    rows = Tuple{Symbol,Int,Bool,Bool}[]
    for n in (6, 8)
        cands = [
            (:trace, L_class_lut(:trace, n)),
            (:identity, collect(0:((1<<n)-1))),        # x+x³ (not a permutation)
        ]
        n % 6 == 0 && append!(
            cands,
            [(:class2, L_class_lut(:class2, n)), (:class3, L_class_lut(:class3, n))],
        )
        for (name, Llut) in cands
            pred = predicate_prop5(Llut, n)
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
        open(joinpath(@__DIR__, "results", "proposition5.toml"), "w") do f
            println(f, "# Proposition 5\nall_ok = $all_ok")
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition5_report()
end
