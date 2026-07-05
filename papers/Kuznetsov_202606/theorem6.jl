# Reproduces + audits Theorem 6 (Main result) of
#   Kuznetsov (2026), "Quadratic APN Functions in Dimension 8 via Gröbner Basis
#   Search in a Self-Equivalence Subspace", arXiv:2606.11967.
#
# Theorem 6 claims each of CLASS-A..D is CCZ-inequivalent to
#   (1) the Beierle 2025 database,
#   (2) "the BBL2021 pre-2020 database" (the 12,921-function file), and
#   (3) both Gold classes,
# and uses this as the novelty certificate for the four classes.
#
# This script shows, via the VBFCatalog σ-oracle (VBF ortho-derivative σ; a σ
# mismatch certifies CCZ-inequivalence, Yoshiara+Canteaut):
#   * The three literal inequivalences HOLD (A..D absent from those three sets).
#   * But the PREMISE fails: database (2) is NOT "the pre-2020 database". The real
#     pre-2020 known set — Edel-Pott 2009 — contains σ-matches for all of A..D
#     (confirmed by exact code-equivalence in verify_edelpott.py). Hence Theorem 6
#     certifies inequivalence to a non-representative subset while calling it the
#     pre-2020 database; the novelty it is invoked to establish does not hold.
#
# Requires the σ-index side store (build: build_sigma_index!(load_catalog())).
# VBF API: representative_sboxes (helpers), gold_apn; VBFCatalog: sigma_hash,
#          _open_sigma_index, print_section/print_check/print_kv (VBF core).

using VBFCatalog, VBF
import DBInterface
include(joinpath(@__DIR__, "helpers.jl"))   # representative_sboxes

# databases named in Theorem 6, as VBFCatalog bulk-corpus names
const DB_BEIERLE2025 = "beierle2025_n8"        # Theorem 6 database (1)
const DB_BBL_FILE    = "beierleleander2022_n8" # Theorem 6 database (2) (the 12,921 file)
const DB_EDELPOTT    = "edelpott2009_n8"       # the genuine pre-2020 known set (Edel-Pott 2009)

# distinct catalog sources carrying σ(F)
function _sources_of(idx, F)
    h = VBFCatalog.sigma_hash(F)
    s = Set{String}()
    for r in DBInterface.execute(idx,
            "SELECT DISTINCT source FROM ccz_sigma_index WHERE sigma_hash = '" * h * "'")
        push!(s, String(r.source))
    end
    s
end

function theorem6_run()
    reps = representative_sboxes()
    idx = VBFCatalog._open_sigma_index()
    goldσ = Set(VBFCatalog.sigma_hash.((gold_apn(8, 1), gold_apn(8, 3))))
    map((:class_a, :class_b, :class_c, :class_d)) do nm
        F = getfield(reps, nm)
        srcs = _sources_of(idx, F)
        (; nm,
           in_beierle2025 = DB_BEIERLE2025 in srcs,
           in_bbl_file    = DB_BBL_FILE in srcs,
           is_gold        = VBFCatalog.sigma_hash(F) in goldσ,
           in_edelpott    = DB_EDELPOTT in srcs)
    end
end

function theorem6_report(io::IO = stdout)
    rs = theorem6_run()
    print_section("Theorem 6 (Main result) — reproduction + premise audit", io)

    # (a) the three inequivalences the theorem literally states
    print_kv("Theorem 6 claim", "CLASS-A..D CCZ-inequivalent to (1) Beierle-2025, " *
             "(2) the 12,921 file, (3) Gold", io)
    all_ineq = true
    for r in rs
        c = uppercase(String(r.nm))[end]
        ok = !r.in_beierle2025 && !r.in_bbl_file && !r.is_gold
        all_ineq &= ok
        print_check("  CLASS-$c inequiv to (1),(2),(3)", ok, io)
    end
    print_check("Theorem 6 literal inequivalences all hold", all_ineq, io)

    # (b) the premise: is database (2) really "the pre-2020 database"?
    print_kv("Premise under test", "database (2) = \"the pre-2020 database\"", io)
    all_in_ep = all(r.in_edelpott for r in rs)
    for r in rs
        c = uppercase(String(r.nm))[end]
        print_check("  CLASS-$c ∈ Edel-Pott 2009 (genuine pre-2020)", r.in_edelpott, io)
    end
    # the theorem is a valid novelty certificate ONLY if no pre-2020 set contains A..D
    print_check("PREMISE HOLDS (no pre-2020 set contains A..D)", !all_in_ep, io)

    print_kv("Conclusion",
        all_ineq && all_in_ep ?
        "Theorem 6's inequivalences are correct, but its premise is FALSE: A..D are " *
        "CCZ-equivalent to Edel-Pott 2009 (pre-2020). The novelty it certifies does " *
        "not hold — the four classes were published in 2009." :
        "unexpected — re-run build_sigma_index! (edelpott2009_n8 must be indexed)", io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem6_report()
end
