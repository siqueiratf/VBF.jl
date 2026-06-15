# Implements Table I — CCZ-inequivalent quadratic APN polynomials over GF(2^9).
# Paper: Budaghyan et al. (2020), "Constructing APN Functions Through Isotopic Shifts",
#        IEEE Trans. Inf. Theory 66(8), pp. 5299–5309. DOI: 10.1109/TIT.2020.2974471
# Section: VII-B (Table I)
#
# Pseudocode:
#   1. Build catalog Gold APNs for n=9 (Gold x³, x⁵, x¹⁷)
#   2. Build new APN from Theorem VI.3 ([a,b,d]=[ζ^424,ζ,ζ^34])
#   3. Compute apn_ea_mugshot for each
#   4. Verify all mugshots are distinct (CCZ-inequivalent)
#   5. Report: catalog says paper found (old class 1.11) and new class N.8
# VBF API used: apn_ea_mugshot, load_apn_function (VBFCatalog)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "section6.jl"))
using Dates
using VBFCatalog

"""
    table1_entries() -> Vector{NamedTuple}

Build the Table I entries that are verifiable from the VBF catalog:
the three Gold families (in catalog) plus the new APN from Theorem VI.3.
The paper's full Table I has 9 entries; we reproduce 4 (3 Gold + 1 new).
"""
function table1_entries()
    entries = NamedTuple[]

    catalog_gold = [
        ("G_1 = x³",     "n9_Gold_x3"),
        ("G_2 = x⁵",     "n9_Gold_x5"),
        ("G_4 = x¹⁷",    "n9_Gold_x17"),
    ]
    for (label, name) in catalog_gold
        F   = load_apn_function(name)
        mug = apn_ea_mugshot(F)
        push!(entries, (; label, source = "catalog", apn = true, mugshot = mug))
    end

    # New function from Theorem VI.3
    F_new = section6_build_theorem_vi3_apn()
    mug_new = apn_ea_mugshot(F_new)
    push!(entries, (;
        label  = "New: G_{1,L}, [ζ^424,ζ,ζ^34]",
        source = "Theorem VI.3",
        apn    = differential_uniformity(F_new) == 2,
        mugshot = mug_new,
    ))

    entries
end

"""
    table1_check(; io) -> NamedTuple

Verify all Table I entries are APN and pairwise CCZ-inequivalent (by mugshot).
"""
function table1_check(; io::IO = devnull)
    entries = table1_entries()

    all_apn = all(e.apn for e in entries)
    mugshots = [e.mugshot for e in entries]
    all_distinct = length(unique(mugshots)) == length(mugshots)

    print_section(io, "Table I — Quadratic APN functions over GF(2^9) (partial)")
    print_kv(io, "entries verified", length(entries))
    for (idx, e) in enumerate(entries)
        print_kv(io, "  [$idx] $(e.label)", "($(e.source)) APN=$(e.apn)")
    end
    print_check(io, "all entries are APN", all_apn)
    print_check(io, "all mugshots distinct (pairwise CCZ-inequivalent)", all_distinct)
    print_kv(io, "note",
        "paper Table I has 9 entries; catalog holds 3 quadratic (Gold) for n=9; " *
        "remaining 5 are non-Gold quadratic APNs not yet in catalog")

    (; all_apn, all_distinct, n_entries = length(entries))
end

function table1_report(io::IO = stdout)
    print_section(io, "Table I: CCZ-inequivalent Quadratic APN Functions over GF(2^9)")
    table1_check(; io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    using Dates
    table1_report()
end
