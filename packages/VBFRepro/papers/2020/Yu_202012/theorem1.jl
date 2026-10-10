# Implements Section 3.1, Theorem 1 (and Definition 3, Definition 4)
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
#
# Theorem 1 [27]. Let F(x) = Σ_{0≤t<i≤n-1} c_{i,t} x^{2^i+2^t} be a homogeneous quadratic
# (n,n)-function, C_F the symmetric hollow coefficient matrix, and H = Mα^t C_F Mα. Then
#
#     δ(F) = 2^k   ⟺   every nonzero F₂-linear combination of the n rows of H has rank ≥ n-k.
#
# In particular F is APN ⟺ H is a QAM (Definition 4: rank exactly n-1 for every nonzero
# row combination).
#
# BASIS NOTE (unlike Theorem 2, this one is safe here): Theorem 1 holds for H built from
# *any* basis α — the normal basis is only needed for Theorem 2. VBF's quadratic_apn_matrix
# is exactly H for the bit basis bᵢ = 2^{i-1}, since M[i,j] = D_{bⱼ}F(bᵢ) is the associated
# symmetric bilinear form evaluated at the basis pair. So Theorem 1 IS testable as printed.
#
# Restating the iff as an equation: k = n − min_rank, hence
#     δ(F) = 2^(n − qam_min_row_rank(H)).
# We test that equation against the directly computed differential_uniformity(F).
#
# Pseudocode:
#   1. For a sample of homogeneous quadratics with F₂ coefficients (n = 4..7), build H
#   2. Predict δ(F) = 2^(n − min row-combination rank of H)
#   3. Compare against differential_uniformity(F) — must agree on APN *and* non-APN alike
#   4. Corollary: δ(F) == 2 ⟺ is_qam(H)
# VBF API used: quadratic_apn_matrix, is_qam, differential_uniformity, rank_f2

include(joinpath(@__DIR__, "helpers.jl"))

using Random

"""
    theorem1_delta(F) -> Int

The differential uniformity of the homogeneous quadratic `F` **as predicted by
Theorem 1** from its derivative matrix alone: `δ(F) = 2^(n − min row-combination rank)`.
Never calls `differential_uniformity`, so comparing the two is a real test.
"""
function theorem1_delta(F::SBox{N}) where {N}
    1 << (N - qam_min_row_rank(quadratic_apn_matrix(F)))
end

# All homogeneous quadratic exponents 2^i + 2^t (0 ≤ t < i ≤ n-1) — the monomials whose
# F₂-linear combinations are exactly the functions Theorem 1 speaks about.
_quad_exponents(n::Int) = [(1 << i) + (1 << t) for i = 0:(n-1) for t = 0:(i-1)]

"""
    theorem1_examples(; trials_per_n) -> NamedTuple

Test Theorem 1 on a seeded random sample of homogeneous quadratics with F₂ coefficients
over GF(2ⁿ), n = 4..7. The sample deliberately includes **non-APN** functions: a sweep
that only ever saw APN inputs could not distinguish Theorem 1 from `is_qam`, and would
be vacuous.
"""
function theorem1_examples(; trials_per_n::Int = 30)
    checks = Tuple{String,Bool}[]
    rng = MersenneTwister(20_201_207)     # fixed seed: the sweep is reproducible
    deltas = Dict{Int,Int}()
    n_agree = 0
    n_total = 0
    n_apn = 0
    corollary_ok = true

    for n = 4:7
        E = _quad_exponents(n)
        for _ = 1:trials_per_n
            k = rand(rng, 1:length(E))
            exps = sort(collect(Set(rand(rng, E, k))))
            F = sbox_from_exponents(n, exps)
            all(x -> Int(F(x)) == 0, 0:((1<<n)-1)) && continue    # skip the zero map

            du = differential_uniformity(F)
            pred = theorem1_delta(F)
            n_total += 1
            deltas[du] = get(deltas, du, 0) + 1
            pred == du && (n_agree += 1)
            du == 2 && (n_apn += 1)

            # "In particular, F is APN iff H is a QAM"
            is_qam(quadratic_apn_matrix(F)) == (du == 2) || (corollary_ok = false)
        end
    end

    push!(
        checks,
        ("Theorem 1: δ(F) = 2^(n − min row-rank) on all $(n_total) sampled quadratics",
         n_agree == n_total),
    )
    push!(checks, ("Theorem 1 corollary: F is APN ⟺ H is a QAM", corollary_ok))

    # Non-vacuity guards: the sweep must actually exercise both sides of the iff.
    push!(checks, ("sample contains APN functions (δ=2)", n_apn > 0))
    push!(
        checks,
        ("sample contains non-APN functions (δ>2) — the sweep is not vacuous",
         any(d > 2 for d in keys(deltas))),
    )
    push!(
        checks,
        ("sample spans ≥ 4 distinct δ values (δ = $(sort(collect(keys(deltas)))))",
         length(deltas) >= 4),
    )

    (; checks, n_total, n_apn, delta_histogram = sort(collect(deltas)))
end

function theorem1_report(io::IO = stdout)
    print_section(io, "Theorem 1 — δ(F) = 2^k ⟺ every nonzero row-combination of H has rank ≥ n−k")
    result = theorem1_examples()
    print_kv(io, "quadratics sampled (n=4..7)", result.n_total)
    print_kv(io, "of which APN", result.n_apn)
    print_kv(io, "δ histogram", join(["2^$(Int(log2(d)))×$(c)" for (d, c) in result.delta_histogram], "  "))
    for (desc, ok) in result.checks
        print_check(io, desc, ok)
    end
    all_pass = all(ok for (_, ok) in result.checks)
    print_kv(io, "overall", all_pass ? "all checks pass" : "SOME CHECKS FAILED")
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem1_report()
end
