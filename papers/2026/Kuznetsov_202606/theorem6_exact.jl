# Upgrades the Theorem 6 refutation from an invariant match to a decision.
#
# theorem6.jl uses the ortho-derivative signature sigma to compare CLASS-A..D
# against the catalog's indexed sources. That comparison is asymmetric: a sigma
# MISMATCH certifies CCZ-inequivalence (this is what the paper's Theorem 6
# legitimately uses), but a sigma MATCH is necessary and not sufficient. A match
# only LOCATES a candidate; on its own it proves nothing.
#
# This script closes that gap. It runs VBF's decision procedure
# are_ccz_equivalent on the four pairs that theorem6.jl locates. Both sides are
# quadratic APN, so the call routes through are_ea_equivalent, which is a
# COMPLETE decision on that class by Yoshiara's theorem (CCZ = EA for quadratic
# APN). A `true` is therefore a positive result of a complete decision, not a
# heuristic. Note the documented failure mode of that API runs the other way: an
# undecided query can degrade to `false`, so a `false` here would need scrutiny,
# while a `true` does not.
#
# Result: all four classes that Kuznetsov (2026) reports as new are
# CCZ-equivalent to functions published by Edel and Pott in 2009.
#
# NO SIGMA INDEX REQUIRED. Unlike theorem6.jl, this script does not open
# ccz_sigma_index.sqlite (a 682 MB gitignored side store). It reads the four
# Edel-Pott members straight from the tracked corpus edelpott2009_n8 and takes
# the paper's own representatives from helpers.jl, so it runs on a fresh clone.
#
# READ-ONLY against the paper: the representatives come from helpers.jl, which
# transcribes the author's own artifact. No paper-specific math is added to VBF.
#
# Run:  julia --project=. -t auto papers/2026/Kuznetsov_202606/theorem6_exact.jl

using VBF, VBFCatalog
import VBFCatalog: SQLite
include(joinpath(@__DIR__, "helpers.jl"))   # representative_sboxes

# The genuine pre-2020 known set that the paper's verification omitted.
const DB_EDELPOTT = "edelpott2009_n8"

# Each claimed-new class against the Edel-Pott member sigma placed it with.
# Member indices are 1-based, matching corpus_function.
const EXACT_PAIRS = (
    (:class_a, 18),
    (:class_b, 5),
    (:class_c, 3),
    (:class_d, 4),
)

"""
    theorem6_exact_run() -> Vector{NamedTuple}

Decide CCZ-equivalence for each claimed-new class against its Edel-Pott
counterpart. Returns one row per pair with the verdict and its wall time.
"""
function theorem6_exact_run()
    reps = representative_sboxes()
    db = SQLite.DB(VBFCatalog.catalog_path())
    try
        map(EXACT_PAIRS) do (nm, i)
            F = getfield(reps, nm)
            G = VBFCatalog.corpus_function(db, DB_EDELPOTT, i)
            seconds = @elapsed equivalent = are_ccz_equivalent(F, G)
            (; nm, member = i, equivalent, seconds)
        end |> collect
    finally
        SQLite.close(db)
    end
end

function theorem6_exact_report(io::IO = stdout)
    print_section("Theorem 6 — exact CCZ decision against Edel-Pott 2009", io)
    print_kv("Method", "are_ccz_equivalent (complete EA decision for quadratic APN)", io)
    print_kv("Reference set", "$DB_EDELPOTT (tracked corpus; no sigma index needed)", io)

    rows = theorem6_exact_run()
    for r in rows
        c = uppercase(String(r.nm))[end]
        print_check("  CLASS-$c CCZ-equivalent to $DB_EDELPOTT #$(r.member) " *
                    "($(round(r.seconds; digits = 1)) s)", r.equivalent, io)
    end

    all_equivalent = all(r.equivalent for r in rows)
    print_check("All four claimed-new classes are Edel-Pott 2009 functions", all_equivalent, io)
    print_kv("Total wall time", "$(round(sum(r.seconds for r in rows); digits = 1)) s", io)
    print_kv("Conclusion",
        all_equivalent ?
        "Decided, not merely sigma-matched: CLASS-A..D were published in 2009. " *
        "The novelty claim of Theorem 6 does not hold." :
        "unexpected — a sigma match did not survive the exact decision; re-check the pairing", io)
    rows
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem6_exact_report()
end
