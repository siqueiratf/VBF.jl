# Implements Algorithm 1 — Phase 1 APN-Center Search in V_A
# Paper: Kuznetsov (2026), "Quadratic APN Functions in Dimension 8 via
#        Gröbner Basis Search in a Self-Equivalence Subspace",
#        IEEE Trans. Inf. Theory (2026) / arXiv:2606.11967
# Section: V.A — Phase 1: Random Sampling in V_A
#
# Pseudocode (Algorithm 1):
#   Input: sample_size N, seed
#   1. Build A, precompute fc22+sol22 parameterization
#   2. For i = 1..N:
#      a. Sample b ∈ F₂^40 uniformly at random
#      b. Map b → c via fc22+sol22
#      c. Build quadratic LUT from c
#      d. Check APN: differential_uniformity(F) == 2?
#      e. Record: sample index, APN flag
#   3. Report APN count and empirical APN density
# VBF API used: differential_uniformity, SBox, print_section, print_check, print_kv

import Random

include("helpers.jl")

function algorithm1_run(; sample_size::Int = 100, seed::Int = 42)
    sample_size > 0 || throw(ArgumentError("sample_size must be positive"))
    A     = build_A_matrix()
    A_lut = build_A_lut(A)
    param = fc22_sol22(A)
    n_free = length(param.free_cols)

    rng = Random.MersenneTwister(seed)
    n_apn = 0

    for _ in 1:sample_size
        b   = rand(rng, Bool, n_free)
        c   = apply_fc22_sol22(b, param.pivot_cols, param.free_cols, param.S)
        lut = quadratic_lut(c)
        F   = SBox{8}(lut)
        if differential_uniformity(F) == 2
            n_apn += 1
        end
    end

    density = n_apn / sample_size
    (; n_apn, sample_size, density, seed, exhaustive = false, sampling = :with_replacement)
end

function algorithm1_report(io::IO = stdout; kwargs...)
    r = algorithm1_run(; kwargs...)
    print_section("Algorithm 1 — Phase 1: Random Sampling in V_A", io)
    print_kv("seed", r.seed, io)
    print_kv("sample size", r.sample_size, io)
    print_kv("APN functions found", r.n_apn, io)
    print_kv("empirical APN density", string(round(r.density * 100; digits=2)) * " %", io)
    completeness = "random sampling with replacement; exhaustive=false"
    print_kv("completeness", "$completeness ($(r.sample_size) evaluated)", io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    algorithm1_report()
end
