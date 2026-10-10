# Implements Section 4.4 (Tables 6 and 7) from Canteaut–Couvreur–Perrin (2022).
# Paper: Canteaut, Couvreur, Perrin (2022),
#        "Recovering or Testing Extended-Affine Equivalence"
# Section: 4.4 — 6-Bit Quadratic APN Functions
#
# Claims reproduced:
#   (a) The 13 Banff functions (Table 6) are quadratic APN; number 5 is κ.
#   (b) The ortho-derivative differential spectrum (the mugshot) separates all
#       13 into distinct EA-classes — including Functions 9 and 10, which all
#       non-ortho-derivative invariants of Table 5 fail to distinguish.
#   (c) Table 7, entry by entry: thickness spectrum, linearity, Γ-rank,
#       Δ-rank, the upper bound on #EA-classes (number of 6-dim spaces in the
#       Walsh zeroes) and the differential spectrum of π_F.
#   (d) There are 7 distinct thickness spectra among the 13 functions.
#   (e) All ortho-derivatives have trivial thickness spectrum {0:1} except
#       π_{x³} = {0:1, 3:9, 6:54} and π_κ = {0:1, 6:5}, so both are
#       CCZ-equivalent to permutations.
#   (f) The catalog's quadratic 6-bit APN functions (≥ 15; the paper worked with
#       15, more named family reps have since been added, all landing in the same
#       classes) partition into 13 EA-classes with the same mugshots as the Banff
#       list (same-bucket pairs verified EA-equivalent with the core algorithm).
#
# The Table 7 "min #EA" lower-bound column (distinct thickness spectra across
# every EA representative of each CCZ-class) is verified for κ in
# section4_3.jl (8 spectra over 222 representatives, +1 from Prop 40). Doing
# the same sweep for the other 12 functions costs ≈ 1,480 further
# thickness-spectrum extractions ≈ 25–30 min single-core; pass
# `verify_min_ea = true` to run it.
#
# VBF API used: ortho_derivative, apn_ea_mugshot, are_ea_equivalent,
#               thickness_spectrum, walsh_zeroes, extract_linear_subspaces,
#               linearity, gamma_rank, delta_rank, differential_spectrum,
#               sorted_pairs, enumerate_ccz_class, is_ccz_equivalent_to_permutation
# VBFCatalog API used: load_catalog, list_functions, load_sbox

include(joinpath(@__DIR__, "helpers.jl"))

using VBFCatalog

# Table 7 expected values, in Table 6 order.
TABLE7_THICKNESS = [
    [0=>1, 1=>63, 2=>126], [0=>1, 1=>63, 2=>126], [0=>1, 1=>63, 2=>30],
    [0=>1, 1=>63, 2=>42], [0=>1, 1=>63, 2=>126, 3=>32], [0=>1, 1=>63, 2=>54],
    [0=>1, 1=>63, 2=>30], [0=>1, 1=>63, 2=>42], [0=>1, 1=>63, 2=>54],
    [0=>1, 1=>63, 2=>54], [0=>1, 1=>63, 2=>42, 3=>8], [0=>1, 1=>63, 2=>54, 3=>8],
    [0=>1, 1=>63, 2=>42],
]
TABLE7_LINEARITY = [16, 16, 16, 16, 16, 16, 32, 16, 16, 16, 16, 16, 16]
TABLE7_GAMMA = [1102, 1146, 1158, 1166, 1166, 1168, 1170, 1170, 1170, 1170, 1172, 1172, 1174]
TABLE7_DELTA = [94, 94, 96, 94, 96, 96, 96, 96, 96, 96, 96, 96, 96]
TABLE7_MAX_EA = [190, 190, 94, 106, 222, 118, 94, 106, 118, 118, 114, 126, 106]
TABLE7_MIN_EA = [3, 3, 4, 5, 8, 9, 6, 8, 9, 9, 20, 20, 9]  # raw spectra counts (κ: 8, "+1" via Prop 40)
TABLE7_PI_DIFFSPEC = [
    [0=>2205, 2=>1764, 8=>63],
    [0=>2583, 2=>1008, 4=>378, 8=>63],
    [0=>2454, 2=>1176, 4=>370, 6=>30, 10=>2],
    [0=>2338, 2=>1428, 4=>210, 6=>56],
    [0=>2373, 2=>1428, 4=>168, 8=>63],
    [0=>2442, 2=>1229, 4=>303, 6=>51, 8=>7],
    [0=>2401, 2=>1371, 4=>195, 6=>50, 14=>15],
    [0=>2426, 2=>1255, 4=>297, 6=>49, 8=>5],
    [0=>2439, 2=>1235, 4=>297, 6=>57, 8=>4],
    [0=>2422, 2=>1271, 4=>279, 6=>53, 8=>7],
    [0=>2385, 2=>1339, 4=>258, 6=>45, 8=>2, 12=>3],
    [0=>2404, 2=>1307, 4=>261, 6=>53, 8=>7],
    [0=>2414, 2=>1271, 4=>303, 6=>37, 8=>7],
]

"""
    section4_4_report(; io, verify_min_ea = false) -> NamedTuple

Reproduce Section 4.4: the Banff list, Table 7 and the EA-partition of the
catalog's 6-bit quadratic APN functions by the ortho-derivative invariant.
"""
function section4_4_report(; io::IO = stdout, verify_min_ea::Bool = false)
    print_section("Section 4.4: 6-bit quadratic APN functions (Tables 6–7)", io)

    # (a) Table 6 functions
    fns = banff_functions()
    ok_a = all(differential_uniformity(F) == 2 && algebraic_degree(F) == 2 for F in fns) &&
           fns[5].lut == kim_apn().lut
    print_check("Table 6: all 13 Banff functions are quadratic APN; #5 = κ", ok_a, io)

    # (b) mugshots separate all 13 (incl. functions 9 vs 10)
    mugs = [apn_ea_mugshot(F) for F in fns]
    ok_b = length(Set(mugs)) == 13
    print_check("π_F differential spectrum separates all 13 EA-classes", ok_b, io)

    # (c) Table 7 entry by entry
    ok_c = true
    seven = Set{Vector{Pair{Int,Int}}}()
    for (i, F) in enumerate(fns)
        tsp = counts(thickness_spectrum(F))
        push!(seven, tsp)
        nsp = length(extract_linear_subspaces(walsh_zeroes(F), 6; max_bits = 12))
        πF = ortho_derivative(F)
        ds = [Int(k) => v for (k, v) in sorted_pairs(differential_spectrum(πF))]
        row_ok = tsp == TABLE7_THICKNESS[i] &&
                 linearity(F) == TABLE7_LINEARITY[i] &&
                 gamma_rank(F) == TABLE7_GAMMA[i] &&
                 delta_rank(F) == TABLE7_DELTA[i] &&
                 nsp == TABLE7_MAX_EA[i] &&
                 ds == TABLE7_PI_DIFFSPEC[i]
        row_ok || print_check("Table 7 row $i", false, io)
        ok_c &= row_ok
    end
    print_check("Table 7: thickness spectrum, linearity, Γ/Δ-rank, max #EA, π-spectrum — all 13 rows", ok_c, io)

    # (d) 7 distinct thickness spectra
    ok_d = length(seven) == 7
    print_check("7 distinct thickness spectra among the 13 functions", ok_d, io)

    # (e) ortho-derivative thickness spectra
    ok_e = true
    for (i, F) in enumerate(fns)
        πF = ortho_derivative(F)
        tsπ = counts(thickness_spectrum(πF))
        if i == 1
            ok_e &= tsπ == [0 => 1, 3 => 9, 6 => 54] && is_ccz_equivalent_to_permutation(πF)
        elseif i == 5
            ok_e &= tsπ == [0 => 1, 6 => 5] && is_ccz_equivalent_to_permutation(πF)
        else
            ok_e &= tsπ == [0 => 1]
        end
    end
    print_check("π thickness spectra: trivial except π_{x³}={0:1,3:9,6:54}, π_κ={0:1,6:5} (both perm-CCZ)", ok_e, io)

    # optional: Table 7 min #EA lower bound (expensive sweep)
    ok_min = true
    if verify_min_ea
        for (i, F) in enumerate(fns)
            reps = enumerate_ccz_class(F)
            nspec = length(Set(thickness_spectrum(r) for r in reps))
            row = nspec == TABLE7_MIN_EA[i]
            row || print_check("Table 7 min #EA row $i (got $nspec, want $(TABLE7_MIN_EA[i]))", false, io)
            ok_min &= row
        end
        print_check("Table 7 min #EA (distinct rep thickness spectra) — all 13 rows", ok_min, io)
    else
        print_kv("Table 7 min #EA column",
                 "κ verified in section4_3 (8 spectra / 222 reps); other 12 SKIPPED " *
                 "(≈1,480 extractions ≈ 25–30 min; pass verify_min_ea=true)", io)
    end

    # (f) catalog partition (the original reproduction check)
    db = load_catalog()
    all_fns = list_functions(db; n = 6, is_apn = true)
    quad_fns = filter(f -> f.is_quadratic, all_fns)
    print_kv("n=6 quadratic APN functions in catalog", length(quad_fns), io)

    sboxes = [(f.canonical_name, load_sbox(db, f.id)) for f in quad_fns]
    buckets = Dict()
    for (name, sb) in sboxes
        push!(get!(buckets, apn_ea_mugshot(sb), Tuple{String,Any}[]), (name, sb))
    end
    n_classes = length(buckets)
    print_kv("EA-classes among catalog functions (distinct mugshots)", n_classes, io)
    for (i, (_, members)) in enumerate(sort(collect(buckets), by = v -> length(v[2]), rev = true))
        println(io, "  Class $i (size=$(length(members))): ", join([m[1] for m in members], ", "))
    end

    # catalog mugshot set == Banff mugshot set
    ok_f_set = Set(keys(buckets)) == Set(mugs)
    print_check("catalog mugshot set equals the Banff-list mugshot set", ok_f_set, io)

    # same-bucket pairs are EA-equivalent; one cross-bucket pair is not
    intra_ok = true
    for (_, members) in buckets
        for i in 1:length(members), j in (i+1):length(members)
            if !are_ea_equivalent(members[i][2], members[j][2])
                println(io, "  [FAIL] $(members[i][1]) ~EA $(members[j][1]) = false (same bucket)")
                intra_ok = false
            end
        end
    end
    print_check("all same-bucket catalog pairs are EA-equivalent", intra_ok, io)
    cross_ok = !are_ea_equivalent(fns[9], fns[10])
    print_check("functions 9 and 10 are EA-inequivalent (cross-bucket witness)", cross_ok, io)

    ok_f = n_classes == 13 && ok_f_set && intra_ok && cross_ok
    print_check("catalog partition: 13 EA-classes matching the Banff list", ok_f, io)

    all_ok = ok_a && ok_b && ok_c && ok_d && ok_e && ok_min && ok_f
    print_check("Section 4.4 overall", all_ok, io)

    return (;
        n_banff = length(fns),
        n_ea_classes = n_classes,
        table7_ok = ok_c,
        seven_spectra = ok_d,
        min_ea_checked = verify_min_ea,
        all_ok,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    section4_4_report()
end
