# Top-level report driver for Kuznetsov (2026) reproduction.
# Paper: Kuznetsov (2026), "Quadratic APN Functions in Dimension 8 via
#        Gröbner Basis Search in a Self-Equivalence Subspace",
#        IEEE Trans. Inf. Theory (2026) / arXiv:2606.11967
#
# Pseudocode:
#   1. Print banner (paper title, parameters, scope)
#   2. Section IV  — V_A construction and RREF (section4_report)
#   3. Algorithm 1 — bounded Phase 1 sampling (algorithm1_report)
#   4. Theorem 4   — CCZ-class structure via Table VII (theorem4_report)
#   5. Table II    — σ-signature distinctness (table2_report)
#   6. Table III   — CCZ-class vs V_A membership (table3_report)
# VBF API used: print_banner, print_section, print_kv

include("section4.jl")
include("algorithm1.jl")
include("theorem4.jl")
include("table2.jl")
include("table3.jl")
include("phase2.jl")

function paper_report(
    io::IO = stdout;
    sample_size::Int = 100,
    seed::Int        = 42,
)
    print_header(io)

    print_section("Reproduction Scope", io)
    print_kv("Section IV  (V_A via RREF)", "exact", io)
    print_kv("Algorithm 1 (Phase 1 sampling)", "bounded — $(sample_size) samples, seed $(seed)", io)
    print_kv("Phase 2     (Gröbner basis / msolve)", "exact — open-source GB over GF(2), no Magma", io)
    print_kv("Theorem 4   (Table VII S-box checks)", "exact", io)
    print_kv("Table II    (σ-signature distinctness)", "exact", io)
    print_kv("Table III   (CCZ-class vs V_A)", "exact", io)
    print_kv("Phase 4/5   (database comparison)", "not executed — requires sboxU + BBL2021 data", io)
    println(io)

    section4_report(io)
    algorithm1_report(io; sample_size, seed)
    theorem4_report(io)
    table2_report(io)
    table3_report(io)
    phase2_report(io)
end

"""
Phase 2 demonstration: run the open-source (msolve) Gröbner-basis slice solver on
a known APN center and report the APN functions found in its NL=4 slice. Uses the
CLASS-A representative (a genuine APN center) so the report is self-contained.
"""
function phase2_report(io::IO = stdout)
    print_section("Phase 2 — Gröbner-basis NL=4 slice (msolve, no Magma)", io)
    center = representative_sboxes().class_a
    t = @elapsed found = phase2_slice(center)
    print_kv("center", "CLASS-A representative (APN, in V_A)", io)
    print_kv("backend", "AlgebraicSolving.jl / msolve — GB over GF(2)", io)
    print_kv("APN functions in slice", length(found), io)
    print_check("center recovered in variety", center.lut in (F.lut for F in found), io)
    print_check("all slice solutions are APN (δ = 2)",
                all(differential_uniformity(F) == 2 for F in found), io)
    print_kv("slice solve time", string(round(t; digits = 1)) * " s", io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    sample_size = parse(Int, get(ENV, "SAMPLE_SIZE", "100"))
    seed        = parse(Int, get(ENV, "SEED", "42"))
    paper_report(stdout; sample_size, seed)
end
