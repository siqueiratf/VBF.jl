# Implements Theorem 4 from Section 3.
# Paper: Budaghyan, Helleseth, Kaleyski (2020), "A New Family of APN Quadrinomials",
#        IEEE Trans. Inf. Theory 66(11):7081–7087
# Section: 3 — Theorem 4 (four i-values give only trivial E_i solutions)
#
# Pseudocode:
#   For n = 2m with m odd and 3 ∤ m:
#   1. Compute the four Theorem 4 i-values: m-2, m, (m-2)^{-1} mod n, n-1
#   2. Verify system E_i (Eq. 2) has only trivial solutions for each
#   3. Verify C_i is APN for each (consistency check with Proposition 1)
# VBF API used: system_Ei_trivial, build_ci_sbox, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem4_i_values(n) -> Vector{Pair{Symbol,Int}}

Returns the four i-values from Theorem 4 for n=2m, m odd, 3∤m,
tagged by their case label.
"""
function theorem4_i_values(n::Int)
    m = n ÷ 2
    (m % 2 == 0 || m % 3 == 0) && error("Theorem 4 requires m=$m odd and 3 ∤ m")
    [
        :case1 => m - 2,            # Case 1: i = m-2
        :case2 => m,                # Case 2: i = m
        :case3 => invmod(m - 2, n), # Case 3: i = (m-2)^{-1} mod n
        :case4 => n - 1,            # Case 4: i = n-1
    ]
end

function theorem4_report(io::IO = stdout; n::Int = 10)
    m = n ÷ 2
    print_section("Theorem 4: four i-values give APN quadrinomials (n=$n, m=$m)", io)
    println(io, "  Conditions: n=2m=$n, m=$m odd ($(isodd(m))), 3∤m ($(m%3 != 0))")

    pairs = theorem4_i_values(n)
    all_ok = true
    for (label, i) in pairs
        ei_ok = system_Ei_trivial(n, i)
        F     = build_ci_sbox(n, i)
        apn   = differential_uniformity(F) == 2
        ok    = ei_ok && apn
        all_ok &= ok
        print_check("$(label): i=$i → E_i trivial=$(ei_ok), C_i APN=$(apn)", ok, io)
    end
    print_check("All four Theorem 4 cases verified for n=$n", all_ok, io)

    # Show contrasting i-values (non-Theorem-4) to confirm the result is tight
    theorem_is = Set(last(p) for p in pairs)
    other_is = [i for i in 1:n-1 if i ∉ theorem_is]
    non_trivial = count(i -> !system_Ei_trivial(n, i), other_is)
    print_check(
        "All other i ∈ {$(join(other_is, ','))} have non-trivial E_i solutions",
        non_trivial == length(other_is), io,
    )
end
