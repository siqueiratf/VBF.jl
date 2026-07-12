# Implements Theorem 2 from Section 3.
# Paper: Budaghyan, Helleseth, Kaleyski (2020), "A New Family of APN Quadrinomials",
#        IEEE Trans. Inf. Theory 66(11):7081–7087
# Section: 3 — Theorem 2 (tex:256): four i-values give only trivial E_i solutions
#
# Pseudocode:
#   For n = 2m with m odd and 3 ∤ m:
#   1. Compute the four Theorem 2 i-values: m-2, m, (m-2)^{-1} mod n, n-1
#   2. Verify system E_i (Eq. 2) has only trivial solutions for each
#   3. Verify C_i is APN for each (Proposition 1's implication)
#   4. Tightness: every other i ∈ 1..n-1 admits a non-trivial E_i solution
# VBF API used: system_Ei_trivial, build_ci_sbox, differential_uniformity
#
# NAMING. This file was previously `theorem4.jl`. The paper has NO Theorem 4;
# the result below is Theorem 2 (tex:256). A *Lemma 4* does exist (tex:433) and
# is a different statement — the odd-k system — implemented in `lemma4.jl`.

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem2_i_values(n) -> Vector{Pair{Symbol,Int}}

The four i-values of Theorem 2 for n = 2m, m odd, 3 ∤ m, tagged by case:
i ∈ {m−2, m, (m−2)^{-1} mod n, n−1}.
"""
function theorem2_i_values(n::Int)
    m = n ÷ 2
    (m % 2 == 0 || m % 3 == 0) && error("Theorem 2 requires m=$m odd and 3 ∤ m")
    [
        :case1 => m - 2,            # Case 1: i = m-2
        :case2 => m,                # Case 2: i = m
        :case3 => invmod(m - 2, n), # Case 3: i = (m-2)^{-1} mod n
        :case4 => n - 1,            # Case 4: i = n-1
    ]
end

function theorem2_report(io::IO = stdout; n::Int = 10)
    m = n ÷ 2
    print_section("Theorem 2: four i-values give trivial E_i solutions (n=$n, m=$m)", io)
    println(io, "  Conditions: n=2m=$n, m=$m odd ($(isodd(m))), 3∤m ($(m%3 != 0))")

    pairs = theorem2_i_values(n)
    all_ok = true
    for (label, i) in pairs
        ei_ok = system_Ei_trivial(n, i)
        apn   = differential_uniformity(build_ci_sbox(n, i)) == 2
        ok    = ei_ok && apn
        all_ok &= ok
        print_check("$(label): i=$i → E_i trivial=$(ei_ok), C_i APN=$(apn)", ok, io)
    end
    print_check("All four Theorem 2 cases verified for n=$n", all_ok, io)

    # Tightness: the complement must have non-trivial E_i solutions
    theorem_is = Set(last(p) for p in pairs)
    other_is = [i for i in 1:n-1 if i ∉ theorem_is]
    non_trivial = count(i -> !system_Ei_trivial(n, i), other_is)
    print_check(
        "All other i ∈ {$(join(other_is, ','))} have non-trivial E_i solutions",
        non_trivial == length(other_is), io,
    )
end

"""
    apn_i_values(n; k=0) -> Vector{Int}

Every i ∈ 1..n−1 for which the quadrinomial C_i (with the given k) is APN over
GF(2^n), by exhaustive differential uniformity. Backs the n=14 regression: the
paper claims (tex:421, experiments up to n=46) that Theorem 2's four values are
the *only* APN ones when k is even.
"""
apn_i_values(n::Int; k::Int = 0) =
    [i for i in 1:n-1 if differential_uniformity(build_ci_sbox(n, i, k)) == 2]

function theorem2_scope_report(io::IO = stdout; dims = (10, 14))
    print_section("Theorem 2 exhaustiveness for even k: APN i-values by dimension", io)
    println(io, "  Paper (tex:421): 'the values of i given in Theorem 2 are the only ones")
    println(io, "  for which C_i(x) is APN' (checked there up to n=46).")
    for n in dims
        expected = sort(collect(Set(last(p) for p in theorem2_i_values(n))))
        got = apn_i_values(n)
        print_check("n=$n: APN i-values $(got) == Theorem 2 values $(expected)",
                    got == expected, io)
    end
end
