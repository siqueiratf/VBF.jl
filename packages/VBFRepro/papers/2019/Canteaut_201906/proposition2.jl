# Implements Proposition 2 — solution counts of U z^{2^{2i}} + V z^{2^i} + (U+V) z = C
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: 3 — Useful Results
#
# Pseudocode:
#   For each (U, V) in F_{2^n}²:
#     expected kernel size k:
#       U = V = 0                                    -> 2^n
#       U ≠ 0, V ≠ U, Tr((1 + V/U)^τ) = 0            -> 4
#       otherwise (U=0,V≠0 | U≠0,V=U | trace = 1)    -> 2
#     histogram of C ↦ #solutions z must be {0, k} with k attained at C = 0
# VBF API used: gf_mul, gf_pow, gf_inv, gf_trace, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition2_build(n, i; modulus) -> NamedTuple

Brute-force verification of Proposition 2: for every U, V ∈ F_{2^n} the
linearised equation U z^{2^{2i}} + V z^{2^i} + (U+V) z = C has
0 or 2^n / 0 or 4 / 0 or 2 solutions according to the three cases of the
proposition, for every constant C.
Returns (; n, i, n_pairs, case_counts, n_violations, ok).
"""
function proposition2_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    len = 1 << n
    tau = tau_exp(n, i)
    zq  = [gf_pow(z, 1 << i, n; modulus) for z in 0:len-1]        # z^{2^i}
    zq2 = [gf_pow(z, 1 << (2 * i), n; modulus) for z in 0:len-1]  # z^{2^{2i}}
    case_counts  = zeros(Int, 3)   # [U=V=0, 4-solution case, 2-solution case]
    n_violations = 0
    hist = zeros(Int, len)
    for U in 0:len-1, V in 0:len-1
        case = if U == 0 && V == 0
            1
        elseif U != 0 && V != U &&
               gf_trace(gf_pow(1 ⊻ gf_mul(V, gf_inv(U, n; modulus), n; modulus),
                               tau, n; modulus), n; modulus) == 0
            2
        else
            3
        end
        expected = (len, 4, 2)[case]
        case_counts[case] += 1
        fill!(hist, 0)
        W = U ⊻ V
        for z in 0:len-1
            C = gf_mul(U, zq2[z + 1], n; modulus) ⊻
                gf_mul(V, zq[z + 1], n; modulus) ⊻
                gf_mul(W, z, n; modulus)
            hist[C + 1] += 1
        end
        # kernel (C=0) has exactly `expected` solutions; every other C has 0 or `expected`
        ok = hist[1] == expected && all(h -> h == 0 || h == expected, hist)
        ok || (n_violations += 1)
    end
    (; n, i, n_pairs = len^2, case_counts, n_violations, ok = n_violations == 0)
end

function proposition2_report(io::IO = stdout;
                             cases = ((3, 1), (3, 2), (5, 1), (5, 2), (5, 3), (5, 4)))
    print_section("Proposition 2 — linearised equation solution counts", io)
    for (n, i) in cases
        r = proposition2_build(n, i)
        print_check(io,
            "n=$n i=$i: counts 0/2^n, 0/4, 0/2 per case (cases: $(join(r.case_counts, ", ")))",
            r.ok)
    end
    print_kv(io, "completeness",
             "exhaustive over F_{2^n}² × all C, all i with gcd(i,n)=1")
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition2_report()
end
