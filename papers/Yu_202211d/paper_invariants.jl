# Class invariants used by Yu–Perrin to sort functions into CCZ-classes.
#
# ── Paper mapping ───────────────────────────────────────────────────────────
# Source: Yu and Perrin (2022), Section "Using class invariants".
#
#   * Ortho-derivative π_F (Definition; from Canteaut–Couvreur–Perrin 2022): the
#     unique π_F with π_F(0)=0, π_F(a)≠0, and π_F(a)·(F(x+a)+F(x)+F(a)+F(0))=0.
#     Two EA-equivalent quadratic APN have affine-equivalent π_F, hence equal
#     *extended Walsh* and *differential* spectra of π_F. The pair of spectra is
#     the main sorting key (it gave the 6547 lower bound and the 5412 classes).
#   * Σ_4^F(0) (Kaleyski 2021): the multiset {Σ F(x_i) : Σ x_i = 0}. The paper's
#     optimized form relies on the Walsh coefficients of F — VBF's
#     `sigma_multiplicities`.
#   * Extended Walsh spectrum W_1, W_2, W_3 of F itself (N_i = #{(a,b), b≠0 :
#     |W_F(a,b)|=i}); none of the new functions gave a new spectrum.
#   * Γ-rank and Δ-rank (CCZ-invariants): "1500 hours" for the whole set vs
#     "21 seconds" for the ortho-derivative spectra. Here Γ/Δ-ranks are computed
#     only for n ≤ 7 (VBF guards n ≤ 7); for n = 8 they are deliberately skipped.
#
# All invariants reuse VBF (`ortho_derivative`, `absolute_walsh_spectrum`,
# `differential_spectrum`, `sigma_multiplicities`, `lat`, `gamma_rank`,
# `delta_rank`); this file only assembles the paper's specific fingerprints.

isdefined(@__MODULE__, :MAGMA_MODULUS) || include(joinpath(@__DIR__, "helpers.jl"))
using VBF, Random

"""
    ortho_derivative_fingerprint(F) -> Union{NamedTuple, Nothing}

The paper's main sorting key for quadratic APN `F`: the extended Walsh spectrum
and the differential spectrum of the ortho-derivative `π_F`, as comparable
sorted `(value => count)` pairs. `nothing` if `F` is not quadratic APN.
"""
function ortho_derivative_fingerprint(F::SBox)
    π = ortho_derivative(F)
    π === nothing && return nothing
    (
        walsh = sorted_pairs(absolute_walsh_spectrum(π)),
        diff = sorted_pairs(differential_spectrum(π)),
    )
end

"""
    sigma_invariant(F; k = 4) -> Vector

The Σ_4^F(0) invariant as comparable sorted pairs, via `sigma_multiplicities`.
Unlike the ortho-derivative it needs neither quadraticity nor APN-ness.
"""
sigma_invariant(F::SBox; k::Int = 4) = sorted_pairs(sigma_multiplicities(F; k = k))

"""
    extended_walsh_spectrum(F) -> Dict{Int,Int}

`N_i = #{(a,b) ∈ F_{2^n}×(F_{2^n}∖{0}) : |W_F(a,b)| = i}` — the paper's extended
Walsh spectrum (the `b ≠ 0` convention).
"""
function extended_walsh_spectrum(F::SBox)
    L = lat(F)
    n = inputbits(F)
    counts = Dict{Int,Int}()
    @inbounds for a = 0:((1 << n) - 1), b = 1:((1 << n) - 1)
        v = abs(Int(L[a + 1, b + 1]))
        counts[v] = get(counts, v, 0) + 1
    end
    counts
end

# The three extended Walsh spectra the paper observed on F_{2^8} (Section
# "Using class invariants"); W_1 occurs 5084×, W_2 324×, W_3 4×.
const PAPER_WALSH_SPECTRA = Dict(
    :W1 => Dict(0 => 16320, 16 => 43520, 32 => 5440),
    :W2 => Dict(0 => 15600, 16 => 44544, 32 => 5120, 64 => 16),
    :W3 => Dict(0 => 14880, 16 => 45568, 32 => 4800, 64 => 32),
)

"""
    paper_walsh_class(F) -> Symbol

`:W1`, `:W2`, `:W3` if `F`'s extended Walsh spectrum matches one of the paper's
n=8 spectra, `:other` if not, `:na` if `n ≠ 8`.
"""
function paper_walsh_class(F::SBox)
    inputbits(F) == 8 || return :na
    s = extended_walsh_spectrum(F)
    for (name, target) in PAPER_WALSH_SPECTRA
        s == target && return name
    end
    :other
end

"""
    design_ranks(F) -> NamedTuple

`(gamma, delta, available)` — the Γ- and Δ-ranks of `F` when `n ≤ 7` (VBF's
support; the paper notes n=8 ranks cost ~1500 h). For `n ≥ 8`, `available =
false` and the ranks are `nothing`.
"""
function design_ranks(F::SBox)
    if inputbits(F) <= 7
        (gamma = gamma_rank(F), delta = delta_rank(F), available = true)
    else
        (gamma = nothing, delta = nothing, available = false)
    end
end

"""
    distinct_ccz_lower_bound(funcs) -> Int

The number of distinct ortho-derivative fingerprints among `funcs` — a lower
bound on the number of CCZ-classes, exactly the sorting the paper used.
"""
function distinct_ccz_lower_bound(funcs)
    fps = Set()
    for F in funcs
        fp = ortho_derivative_fingerprint(F)
        fp === nothing || push!(fps, fp)
    end
    length(fps)
end

"""
    invariants_demo(; seed) -> NamedTuple

Catalog-free demonstration of the sorting method:
  * the 13 quadratic APN classes on F_{2^6} are perfectly separated by the
    ortho-derivative fingerprint;
  * the ortho-derivative fingerprint and Σ_4 invariant are EA-invariant (a
    deterministic linear-equivalent copy of Gold x^3 shares both);
  * Σ_4 total mass is 2^n; Γ/Δ-ranks are computable at n=6.
"""
function invariants_demo(; seed::Int = 1)
    cls = search_qam_full(6; limit = 13, max_evaluations = 1 << 24)
    n6_classes = length(cls)
    n6_distinct = distinct_ccz_lower_bound(cls)

    F = gold_apn(6, 1)
    rng = MersenneTwister(seed)
    A = random_linear_permutation(rng, Val(6))
    B = random_linear_permutation(rng, Val(6))
    G = compose(A, compose(F, B))            # EA-equivalent to F
    fp_invariant =
        ortho_derivative_fingerprint(G) == ortho_derivative_fingerprint(F)
    sigma_invariant_eq = sigma_invariant(G) == sigma_invariant(F)

    dr = design_ranks(F)
    (
        n6_classes = n6_classes,
        n6_distinct_fingerprints = n6_distinct,
        ortho_ea_invariant = fp_invariant,
        sigma_ea_invariant = sigma_invariant_eq,
        sigma_mass_ok = total_mass(sigma_multiplicities(F)) == 1 << 6,
        gamma_rank_n6 = dr.gamma,
        delta_rank_n6 = dr.delta,
        seed = seed,
    )
end

function paper_invariants_report(io::IO = stdout)
    print_section("Class invariants: ortho-derivative, Σ_4, Walsh, Γ/Δ-ranks", io)
    d = invariants_demo()
    print_check("ortho-derivative separates all $(d.n6_classes) quadratic APN classes on F_2^6",
                d.n6_distinct_fingerprints == d.n6_classes, io)
    print_kv("    distinct ortho-derivative fingerprints / classes (n=6)",
             "$(d.n6_distinct_fingerprints) / $(d.n6_classes)", io)
    print_check("ortho-derivative fingerprint is EA-invariant", d.ortho_ea_invariant, io)
    print_check("Σ_4^F(0) invariant is EA-invariant", d.sigma_ea_invariant, io)
    print_check("Σ_4^F(0) total mass == 2^n", d.sigma_mass_ok, io)
    print_kv("    Γ-rank, Δ-rank of Gold x^3 on F_2^6 (deterministic seed $(d.seed))",
             "$(d.gamma_rank_n6), $(d.delta_rank_n6)", io)
    println(io, "  Note: Γ/Δ-ranks are guarded to n ≤ 7 (paper: ~1500 h on the full")
    println(io, "  n=8 set vs ~21 s for the ortho-derivative spectra).")

    # informational: the extended Walsh class of the Gold x^3 seed on F_2^8
    walsh_class_seed = :na
    if isdefined(@__MODULE__, :h8_base)
        seedF = qam_to_sbox(h8_base())
        walsh_class_seed = paper_walsh_class(seedF)
        print_kv("    extended Walsh class of the Gold x^3 seed on F_2^8",
                 walsh_class_seed, io)
    end

    (
        n6_classes = d.n6_classes,
        n6_distinct_fingerprints = d.n6_distinct_fingerprints,
        ortho_ea_invariant = d.ortho_ea_invariant,
        sigma_ea_invariant = d.sigma_ea_invariant,
        sigma_mass_ok = d.sigma_mass_ok,
        gamma_rank_n6 = d.gamma_rank_n6,
        delta_rank_n6 = d.delta_rank_n6,
        seed = d.seed,
        walsh_class_seed = walsh_class_seed,
        n8_design_ranks_computed = false,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    paper_invariants_report()
end
