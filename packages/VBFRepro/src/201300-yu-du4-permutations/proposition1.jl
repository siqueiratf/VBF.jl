# Implements Proposition 1 + Application (Section II.2)
# Paper: Yu, Wang, Li (2013), "Constructing Differentially 4 Uniform
#        Permutations from Known Ones"
# Section: II.1 — Proposition 1: APN swap → δ∈{2,4}
#          II.2 — Application: Dillon perm, Example 1, 1176 count
#
# Pseudocode:
#   1. Load Dillon APN permutation (Table 1)
#   2. For each pair (i,j) with i<j, build F_{(i,j)} by swapping F(i) and F(j)
#   3. Compute δ(F_{(i,j)}) — verify ∈ {2,4}
#   4. If δ=4, compute A and check if A < 2^n - 1
#   5. Count examples with A < 2^n - 1
# VBF API used: dillon_apn_permutation, SBox, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

function proposition1_report(io::IO = stdout)
    print_section("Proposition 1 + Application (Dillon APN, n=6)", io)

    F = dillon_apn_permutation()
    n = 6
    N = 1 << n
    print_check(io, "F is APN permutation", is_permutation(F) && differential_uniformity(F) == 2)

    # Traverse all pairs (i,j) with i<j
    all_valid = true
    count_du4 = 0
    count_problem1 = 0
    example1_ok = false

    for i in 0:N-2
        for j in i+1:N-1
            G = swap_function(F, i, j)
            du = differential_uniformity(G)
            if du ∉ (2, 4)
                all_valid = false
            end
            if du == 4
                count_du4 += 1
                A = parameter_A_from_ddt(G)
                if A < N - 1
                    count_problem1 += 1
                end
                if i == 0 && j == 1
                    print_kv(io, "Example 1: F_{(0,1)} δ", du)
                    print_kv(io, "Example 1: F_{(0,1)} A", A)
                    print_check(io, "Example 1: δ=4 and A=54", du == 4 && A == 54)
                    example1_ok = (du == 4 && A == 54)
                end
            end
        end
    end

    print_check(io, "all swaps give δ ∈ {2,4} (Proposition 1)", all_valid)
    print_kv(io, "pairs with δ=4", count_du4)
    print_kv(io, "pairs with A < 2^n-1 (Problem 1)", count_problem1)
    print_check(io, "1176 examples found", count_problem1 == 1176)

    (; all_valid, example1_ok, count_du4, count_problem1)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition1_report()
end
