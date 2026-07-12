# Implements §5 — Classification of quadratic APN functions in dimension 7.
# Paper: Kalgin, Idrisova (2020), "The classification of quadratic APN functions
#        in 7 variables", Cryptography and Communications 14, pp. 691–715.
# Section: §5 — Procedure P1/P2, five second-row cases, 488 CCZ-classes.
#
# Pseudocode:
#   1. Fix first row of QAM = (0,1,2,4,8,16,32) [standard basis rep, §5].
#   2. For all possible second rows (up to the P1/P2 EA-normalization), there
#      are exactly 5 valid cases (listed in §5 with their EA-class counts).
#   3. The sum 3+2+0+220+263 = 488 is the total CCZ-class count for n=7.
#   4. Each case is verified to be compatible with the first row (non-zero
#      entry at position [1,2] ensures Proposition 1 is not immediately violated).
#   5. Bounded demo: show the 5 cases and verify total arithmetic.
#      Full enumeration (exhaustive search) is computationally infeasible
#      within this reproduction scope.
#
# VBF API used: is_qam, quadratic_apn_matrix, gold_apn

include(joinpath(@__DIR__, "helpers.jl"))

# ── Data: canonical first row and five second-row cases for n=7 ─────────────

"""
    first_row_n7() -> Vector{Int}

The canonical first row of a lexicographically minimal n=7 QAM after EA-normalization:
row = (0, e_1, e_2, e_3, e_4, e_5, e_6) = (0, 1, 2, 4, 8, 16, 32). §5.
"""
first_row_n7() = [0, 1, 2, 4, 8, 16, 32]

"""
    second_row_cases_n7() -> Vector{Tuple{Vector{Int}, Int}}

The five possible second rows of a lexicographically minimal n=7 QAM, together
with the number of EA-inequivalent APN functions in each case. §5:

  Case 1: (1,0,4,8,16,32,64)  — 3 EA-classes  (all equivalent to monomial APNs)
  Case 2: (1,0,4,6,16,32,64)  — 2 EA-classes
  Case 3: (1,0,4,6,16,32,24)  — 0 EA-classes
  Case 4: (1,0,4,6,16,26,64)  — 220 EA-classes
  Case 5: (1,0,4,6,16,24,64)  — 263 EA-classes

Total: 3+2+0+220+263 = 488 CCZ-classes.
"""
function second_row_cases_n7()
    [
        ([1, 0, 4, 8, 16, 32, 64], 3),
        ([1, 0, 4, 6, 16, 32, 64], 2),
        ([1, 0, 4, 6, 16, 32, 24], 0),
        ([1, 0, 4, 6, 16, 26, 64], 220),
        ([1, 0, 4, 6, 16, 24, 64], 263),
    ]
end

"""
    build_partial_qam_n7(row1, row2) -> Matrix{Int}

Build the 7×7 partial QAM matrix with only the first two rows/columns fixed.
Remaining entries are 0 (unknown). Symmetric, zero diagonal.
"""
function build_partial_qam_n7(row1::AbstractVector{<:Integer}, row2::AbstractVector{<:Integer})
    n = 7
    M = zeros(Int, n, n)
    for j = 2:n
        M[1, j] = M[j, 1] = row1[j]
    end
    M[2, 1] = M[1, 2] = row2[1]    # must equal row1[2] = 1
    for j = 3:n
        M[2, j] = M[j, 2] = row2[j]
    end
    M
end

"""
    first_two_rows_compatible(row1, row2) -> Bool

Check that the fixed first two rows satisfy the basic symmetry and non-degeneracy
conditions required for a valid QAM:
- M[1,2] == M[2,1] (symmetry)
- M[1,2] != 0 (row 1 has a non-zero off-diagonal entry at col 2)
"""
function first_two_rows_compatible(row1::AbstractVector, row2::AbstractVector)
    row1[2] == row2[1] || return false      # M[1,2] == M[2,1]
    row1[2] != 0 || return false            # non-zero
    true
end

# ── Section report ───────────────────────────────────────────────────────────

"""
    section5_report(io; save_results) -> NamedTuple

§5 reproduction:
- Display the 5 second-row cases for n=7.
- Verify compatibility with first row (symmetry + non-zero).
- Verify total count arithmetic: 3+2+0+220+263 = 488.
- Note: full exhaustive enumeration is out of scope.
"""
function section5_report(io::IO = stdout; save_results::Bool = false) :: NamedTuple
    print_section("§5 — Classification of quadratic APN functions in dimension 7", io)

    row1 = first_row_n7()
    cases = second_row_cases_n7()

    print_kv("canonical first row", row1, io)
    print_kv("number of second-row cases", length(cases), io)

    total = 0
    all_compatible = true
    for (idx, (row2, count)) in enumerate(cases)
        compat = first_two_rows_compatible(row1, row2)
        all_compatible &= compat
        total += count
        print_kv("Case $idx row2", row2, io)
        print_kv("  EA-class count (from paper)", count, io)
        print_check("  Case $idx: symmetric and non-zero at (1,2)", compat, io)
    end

    print_kv("total CCZ-classes (3+2+0+220+263)", total, io)
    print_check("total = 488", total == 488, io)
    print_check("all five cases compatible with first row", all_compatible, io)

    print_kv(
        "exhaustive note",
        "full n=7 enumeration used supercomputer; counts loaded from paper — NOT recomputed",
        io,
    )

    # Verify Gold n=7 is quadratic APN (exists in classification)
    g7 = gold_apn(7)
    g7_du = differential_uniformity(g7)
    g7_deg = algebraic_degree(g7)
    print_check("Gold n=7 is quadratic APN (sanity check)", g7_du == 2 && g7_deg == 2, io)

    result = (;
        n_cases = length(cases),
        total_ccz_classes = total,
        all_cases_compatible = all_compatible,
        gold_n7_is_apn = g7_du == 2,
    )

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "section5.toml"), "w") do f
            println(f, "# section5 results")
            for (k, v) in pairs(result)
                println(f, "$k = $v")
            end
        end
    end

    result
end
