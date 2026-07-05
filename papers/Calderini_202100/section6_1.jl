# Implements Section 6.1 — Computational results.
# Paper: Calderini, Budaghyan, Carlet (2021), pp. 79–105
# Section: 6.1 — Computational results; 6.1.1 is n=2*4=8, 6.1.2 is n=10,
#                6.1.3 is n=12, 6.1.4 is n=16.
#
# The paper reports (Section 6.1.1, n=2*4=8, i=1):
#   F1, b!=0: (h=0,k=2,r=0) and (h=2,k=0,r=0) are swap-equivalent and produce a
#             new APN function of the Theorem 6.2 form.
#   F1, b=0:  h=3, r=2 gives the Taniguchi APN functions (Proposition 5.8).
#   F2, c!=0: k=1, r=2 gives the Taniguchi APN functions (Corollary 5.7).
#   h=k=r=0 cases are equivalent to the hexanomial class.
#   The new APN is CCZ-inequivalent to all known APN families at n=8.
#
# CCZ-distinctness argument codified here (all comparisons via apn_ea_mugshot,
# whose quadratic branch is the Walsh+DDT spectra of the ortho-derivative — an
# EA-class invariant, Canteaut-Couvreur-Perrin 2022):
#   * two quadratic APN functions are CCZ-equivalent iff EA-equivalent
#     (Yoshiara 2012), so mugshot inequality between quadratics certifies
#     CCZ-inequivalence;
#   * a quadratic APN CCZ-equivalent to a power function must be EA-equivalent
#     to a Gold function (Yoshiara 2016), so mugshot inequality vs Gold x^3 and
#     x^9 also rules out Kasami x^57 (the only other power APN class at n=8);
#   * CCZ-comparison against the external n=8 catalogs [52,53] is out of scope.
#
# Section 6.1.2 (n=10): the Taniguchi identifications are Prop 5.8 / Cor 5.7
#   instances, verified in theorem5_6_report(m=5). The aggregate F1/F2 sweep
#   (~256k SBox builds + DDTs at n=10 plus mugshots, est. 15-30 min) is opt-in:
#   section6_1_report(full_search=true) or `make section6_1_deep`.
# Section 6.1.3 (n=12): targeted case checks in section6_1_n12_report below;
#   the aggregate sweep (~900k builds x ~11 ms, est. days) is skipped.
# Section 6.1.4 (n=16): skipped. Single DDT at n=16 is ~4 s (2^32 entries) and
#   the sweep needs ~3*10^7 builds (est. years of CPU); the published outcomes
#   are again Prop 5.8 / Cor 5.7 patterns, verified here at m=4,5,6.
#
# VBF API used: gold_apn, kasami_apn, taniguchi_apn_representatives,
#               differential_uniformity, algebraic_degree, apn_ea_mugshot,
#               APNEAMugshot, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

# Classify a mugshot against the reference sets; returns a Symbol.
function _classify(mg, refs)
    for (name, set) in refs
        mg in set && return name
    end
    :new
end

"""
    section6_1_known_mugshots(m; modulus) -> Vector{Pair{Symbol,Set{APNEAMugshot}}}

Reference EA-mugshot sets of the known quadratic APN families at n=2m:
Gold, hexanomial (exact Theorem 3.1 form), Taniguchi, Zhou-Pott (m even).
"""
function section6_1_known_mugshots(m::Int; modulus::Int = primitive_polynomial(m))
    n = 2m
    gold = Set{APNEAMugshot}(apn_ea_mugshot(gold_apn(n, k))
                             for k in 1:(n - 1) if gcd(k, n) == 1)
    hex  = hexanomial_class_mugshots(m)
    tan  = Set{APNEAMugshot}(apn_ea_mugshot(r.sbox)
                             for r in taniguchi_apn_representatives(m))
    refs = [:gold => gold, :hexanomial => hex, :taniguchi => tan]
    if iseven(m)
        zp = Set{APNEAMugshot}()
        for i in 1:(m - 1)
            gcd(i, m) == 1 || continue
            for j in (0, 2), alpha in 1:(1 << m) - 1
                gf_is_dth_power(alpha, 3, m; modulus = modulus) && continue
                push!(zp, apn_ea_mugshot(zhou_pott_sbox(m, i, j, alpha;
                                                        modulus = modulus)))
            end
        end
        push!(refs, :zhou_pott => zp)
    end
    refs
end

"""
    section6_1_report([io]; full_search) -> NamedTuple

Section 6.1.1 computational results for n=8 (m=4, i=1): exhaustive F1/F2
case classification over (h,k,r,b,c), plus the Theorem 6.2 (b,c) search and
the CCZ-distinctness of the new class from all known families at n=8.
`full_search=true` additionally runs the n=10 aggregate sweep (Section 6.1.2,
est. 15-30 min).
"""
function section6_1_report(io::IO = stdout; full_search::Bool = false)
    m     = 4
    i     = 1
    n     = 2m
    mod_m = primitive_polynomial(m)

    print_section("Section 6.1.1 — n=8 computational results (i=$i)", io)

    # --- Theorem 6.2 (b,c) search (as before) ---
    valid_pairs = Tuple{Int,Int}[]
    for b in 0:(1 << m) - 1, c in 0:(1 << m) - 1
        theorem6_2_condition(m, i, b, c; modulus = mod_m) && push!(valid_pairs, (b, c))
    end
    print_kv("Theorem 6.2 valid (b,c) pairs", length(valid_pairs), io)

    new_mugs = Set{APNEAMugshot}()
    new_reps = NamedTuple[]
    for (b, c) in valid_pairs
        F  = theorem6_2_sbox(m, i, b, c; modulus = mod_m)
        mg = apn_ea_mugshot(F)
        mg in new_mugs && continue
        push!(new_mugs, mg)
        push!(new_reps, (; b, c, algebraic_degree = algebraic_degree(F)))
    end
    print_kv("distinct EA-classes from Theorem 6.2", length(new_mugs), io)
    for r in new_reps
        print_kv("    representative (b=$(r.b), c=$(r.c))", "deg=$(r.algebraic_degree)", io)
    end

    # --- Reference mugshot sets of the known families at n=8 ---
    refs = section6_1_known_mugshots(m; modulus = mod_m)
    for (name, set) in refs
        print_kv("$(name) EA-classes at n=$n", length(set), io)
    end

    # --- CCZ-distinctness of the new class (see header for the argument) ---
    ok_new_vs_known = all(_classify(mg, refs) == :new for mg in new_mugs)
    print_check("Thm 6.2 class(es) distinct from Gold/hexanomial/Taniguchi/Zhou-Pott " *
                "(=> CCZ-inequivalent, Yoshiara)", ok_new_vs_known, io)
    kas = kasami_apn(n, 3)             # x^57 at n=8
    ok_kasami = algebraic_degree(kas) != 2
    print_check("Kasami x^57 non-quadratic; ruled out via Gold checks (Yoshiara 2016)",
                ok_kasami, io)

    # --- Exhaustive F1/F2 case classification (Section 6.1.1) ---
    counts     = Dict{Symbol,Int}()
    case_class = Dict{Tuple{Symbol,Int,Int,Int},Set{Symbol}}()
    mug_cache  = Dict{Tuple{Symbol,Int,Int,Int},Set{APNEAMugshot}}()
    apn_total  = 0
    for h in 0:(m - 1), k in 0:(m - 1), r in 0:(m - 1)
        for b in 0:(1 << m) - 1, c in 1:(1 << m) - 1
            b == 0 && k > 0 && continue     # k is irrelevant when b=0
            F = f1_sbox(m, i, h, k, r, b, c; modulus = mod_m)
            differential_uniformity(F) == 2 || continue
            apn_total += 1
            mg  = apn_ea_mugshot(F)
            cls = _classify(mg, refs)
            cls == :new && !(mg in new_mugs) && (cls = :unknown)
            counts[cls] = get(counts, cls, 0) + 1
            key = (b == 0 ? :F1_b0 : :F1, h, k, r)
            push!(get!(case_class, key, Set{Symbol}()), cls)
            push!(get!(mug_cache, key, Set{APNEAMugshot}()), mg)
        end
    end
    for k in 0:(m - 1), r in 0:(m - 1), c in 1:(1 << m) - 1
        F = f2_sbox(m, i, k, r, c; modulus = mod_m)
        differential_uniformity(F) == 2 || continue
        apn_total += 1
        mg  = apn_ea_mugshot(F)
        cls = _classify(mg, refs)
        cls == :new && !(mg in new_mugs) && (cls = :unknown)
        counts[cls] = get(counts, cls, 0) + 1
        key = (:F2, 0, k, r)
        push!(get!(case_class, key, Set{Symbol}()), cls)
        push!(get!(mug_cache, key, Set{APNEAMugshot}()), mg)
    end

    print_kv("APN instances in F1/F2 sweep (h,k,r,b,c exhaustive, i=$i)", apn_total, io)
    for (cls, cnt) in sort(collect(counts); by = first)
        print_kv("    class $(cls)", cnt, io)
    end

    # every APN instance falls into a known family or the Thm 6.2 new class
    ok_all_classified = !haskey(counts, :unknown)
    print_check("every APN instance is Gold/hex/Taniguchi/Zhou-Pott or Thm 6.2 new",
                ok_all_classified, io)

    # paper's specific case claims (Section 6.1.1)
    ok_new_case = haskey(case_class, (:F1, 2, 0, 0)) &&
                  :new in case_class[(:F1, 2, 0, 0)]
    print_check("F1 b!=0 (h=2,k=0,r=0) produces the Thm 6.2 new class", ok_new_case, io)
    ok_swap = get(mug_cache, (:F1, 2, 0, 0), Set{APNEAMugshot}()) ==
              get(mug_cache, (:F1, 0, 2, 0), Set{APNEAMugshot}())
    print_check("Remark 6.3: (h=2,k=0,r=0) and (h=0,k=2,r=0) swap-equivalent " *
                "(same EA-class sets)", ok_swap, io)
    ok_tan_f1 = get(case_class, (:F1_b0, 3, 0, 2), Set{Symbol}()) == Set([:taniguchi])
    print_check("F1 b=0 (h=3,r=2) gives exactly the Taniguchi class", ok_tan_f1, io)
    ok_tan_f2 = get(case_class, (:F2, 0, 1, 2), Set{Symbol}()) == Set([:taniguchi])
    print_check("F2 (k=1,r=2) gives exactly the Taniguchi class", ok_tan_f2, io)
    ok_hex_000 = let s = union(get(case_class, (:F1, 0, 0, 0), Set{Symbol}()),
                               get(case_class, (:F1_b0, 0, 0, 0), Set{Symbol}()),
                               get(case_class, (:F2, 0, 0, 0), Set{Symbol}()))
        !isempty(s) && s == Set([:hexanomial])
    end
    print_check("h=k=r=0 cases fall in the hexanomial class", ok_hex_000, io)

    all_ok = length(new_mugs) >= 1 && ok_new_vs_known && ok_kasami &&
             ok_all_classified && ok_new_case && ok_swap &&
             ok_tan_f1 && ok_tan_f2 && ok_hex_000
    print_kv("completeness", "exhaustive over (h,k,r,b,c) at n=8, i=$i", io)

    r10 = full_search ? section6_1_n10_sweep(io) : nothing
    full_search || println(io,
        "  [skip] Section 6.1.2 aggregate n=10 sweep (est. 15-30 min); " *
        "run with full_search=true or `make section6_1_deep`")

    (; all_ok = all_ok && (r10 === nothing || r10.all_ok),
       valid_count = length(valid_pairs), ea_classes = length(new_mugs),
       new_classes = length(new_mugs), apn_total, counts,
       ok_all_classified, ok_new_case, ok_swap, ok_tan_f1, ok_tan_f2,
       ok_hex_000, ok_new_vs_known)
end

"""
    section6_1_n10_sweep([io]) -> NamedTuple

Section 6.1.2 aggregate search at n=10 (m=5, i in {1,2}): exhaustive F1/F2
sweep over (h,k,r,b,c), classifying every APN instance as hexanomial or
Taniguchi (the only classes the paper reports at n=10). Est. 15-30 min.
"""
function section6_1_n10_sweep(io::IO = stdout)
    m     = 5
    mod_m = primitive_polynomial(m)
    print_section("Section 6.1.2 — n=10 aggregate F1/F2 sweep (est. 15-30 min)", io)

    refs = section6_1_known_mugshots(m; modulus = mod_m)
    for (name, set) in refs
        print_kv("$(name) EA-classes at n=10", length(set), io)
    end

    counts    = Dict{Symbol,Int}()
    seen_mugs = Dict{APNEAMugshot,Symbol}()  # cache: mugshot -> class
    apn_total = 0
    for i in (1, 2)
        for h in 0:(m - 1), k in 0:(m - 1), r in 0:(m - 1)
            for b in 0:(1 << m) - 1, c in 1:(1 << m) - 1
                b == 0 && k > 0 && continue
                F = f1_sbox(m, i, h, k, r, b, c; modulus = mod_m)
                differential_uniformity(F) == 2 || continue
                apn_total += 1
                mg  = apn_ea_mugshot(F)
                cls = get!(() -> _classify(mg, refs), seen_mugs, mg)
                counts[cls] = get(counts, cls, 0) + 1
            end
        end
        for k in 0:(m - 1), r in 0:(m - 1), c in 1:(1 << m) - 1
            F = f2_sbox(m, i, k, r, c; modulus = mod_m)
            differential_uniformity(F) == 2 || continue
            apn_total += 1
            mg  = apn_ea_mugshot(F)
            cls = get!(() -> _classify(mg, refs), seen_mugs, mg)
            counts[cls] = get(counts, cls, 0) + 1
        end
    end

    print_kv("APN instances at n=10", apn_total, io)
    for (cls, cnt) in sort(collect(counts); by = first)
        print_kv("    class $(cls)", cnt, io)
    end
    all_ok = apn_total > 0 &&
             all(cls in (:hexanomial, :taniguchi) for cls in keys(counts))
    print_check("all n=10 APN instances are hexanomial or Taniguchi", all_ok, io)
    print_kv("completeness", "exhaustive over (i,h,k,r,b,c) at n=10", io)
    (; all_ok, apn_total, counts)
end

"""
    section6_1_n12_report([io]; deep) -> NamedTuple

Section 6.1.3 targeted case checks at n=12 (m=6, i=1). With `deep=false` only
the structural identity F1(b=0,h=3,r=0) == Theorem 6.2 (b=0) is checked;
`deep=true` adds the mugshot comparisons (a few n=12 mugshots, ~10 s).
The aggregate n=12 sweep (est. days) is out of scope.
"""
function section6_1_n12_report(io::IO = stdout; deep::Bool = true)
    m     = 6
    i     = 1
    mod_m = primitive_polynomial(m)
    print_section("Section 6.1.3 — n=12 targeted case checks (i=$i)", io)

    # structural: F1(b=0, h=m/2, r=0) is literally the Theorem 6.2 form with b=0
    c0 = first(c for c in 1:(1 << m) - 1
               if theorem6_2_condition(m, i, 0, c; modulus = mod_m))
    ok_struct = f1_sbox(m, i, 3, 0, 0, 0, c0; modulus = mod_m).lut ==
                theorem6_2_sbox(m, i, 0, c0; modulus = mod_m).lut
    print_check("F1(b=0,h=3,r=0) LUT == Theorem 6.2 (b=0) LUT (structural identity)",
                ok_struct, io)

    if !deep
        println(io, "  [skip] deep n=12 mugshot comparisons (deep=false)")
        return (; all_ok = ok_struct, ok_struct, deep = false)
    end

    # Theorem 6.2 class mugshots at n=12 (b=0 instances)
    thm62 = Set{APNEAMugshot}()
    for c in 1:(1 << m) - 1
        theorem6_2_condition(m, i, 0, c; modulus = mod_m) || continue
        F = theorem6_2_sbox(m, i, 0, c; modulus = mod_m)
        differential_uniformity(F) == 2 || continue
        push!(thm62, apn_ea_mugshot(F))
        length(thm62) >= 3 && break            # a few representatives suffice
    end
    print_kv("Theorem 6.2 (b=0) EA-classes sampled at n=12", length(thm62), io)

    # a couple of known-family mugshots at n=12 for comparison
    b_t  = first(b for b in 1:(1 << m) - 1
                 if bivariate_carlet_condition(m, i, 1, b; modulus = mod_m))
    tanm = apn_ea_mugshot(taniguchi_apn(m, i, 1, b_t; modulus = mod_m))
    gold = Set(apn_ea_mugshot(gold_apn(2m, k)) for k in (1, 5))

    # F2(k=3,r=0) is equivalent to a Theorem 6.2 function
    cB = findfirst(c -> differential_uniformity(
                            f2_sbox(m, i, 3, 0, c; modulus = mod_m)) == 2,
                   1:(1 << m) - 1)
    ok_B = cB !== nothing &&
           apn_ea_mugshot(f2_sbox(m, i, 3, 0, cB; modulus = mod_m)) in thm62
    print_check("F2(k=3,r=0,c=$cB) EA-class matches a Theorem 6.2 (b=0) class", ok_B, io)

    # F1(b=0,h=2,r=4): "could be inequivalent to the known cases"
    cA = findfirst(c -> differential_uniformity(
                            f1_sbox(m, i, 2, 0, 4, 0, c; modulus = mod_m)) == 2,
                   1:(1 << m) - 1)
    ok_A_apn = cA !== nothing
    print_check("F1(b=0,h=2,r=4,c=$cA) has an APN instance", ok_A_apn, io)
    mg_A = ok_A_apn ?
           apn_ea_mugshot(f1_sbox(m, i, 2, 0, 4, 0, cA; modulus = mod_m)) : nothing
    ok_A_new = ok_A_apn && !(mg_A in thm62) && mg_A != tanm && !(mg_A in gold)
    print_check("F1(b=0,h=2,r=4) differs from Thm 6.2/Taniguchi/Gold samples " *
                "(paper: 'could be inequivalent to the known cases')", ok_A_new, io)

    # F2(k=4,r=2): the paper says "equivalent to the second case for b=0".
    # Empirically it matches the F1(b=0,h=2,r=4) class — the FIRST-listed b=0
    # case — and NOT the Theorem 6.2 class (h=3,r=0); the paper's case
    # numbering appears to count differently. We assert the empirical match.
    cC = findfirst(c -> differential_uniformity(
                            f2_sbox(m, i, 4, 2, c; modulus = mod_m)) == 2,
                   1:(1 << m) - 1)
    mg_C = cC === nothing ? nothing :
           apn_ea_mugshot(f2_sbox(m, i, 4, 2, cC; modulus = mod_m))
    ok_C = cC !== nothing && ok_A_apn && mg_C == mg_A
    print_check("F2(k=4,r=2,c=$cC) EA-class matches the F1(b=0,h=2,r=4) class " *
                "(paper wording: 'second case for b=0'; it does NOT match Thm 6.2)",
                ok_C, io)

    # h=5,r=4 -> Taniguchi and F2(k=1,r=2) -> Taniguchi are Prop 5.8 / Cor 5.7
    # instances, verified in theorem5_6_report(m=6).
    println(io, "  note: (h=5,r=4) and F2(k=1,r=2) Taniguchi cases are covered by")
    println(io, "        theorem5_6_report(m=6) (Prop 5.8 / Cor 5.7 patterns)")

    all_ok = ok_struct && ok_B && ok_C && ok_A_apn && ok_A_new
    print_kv("completeness", "targeted spot-checks at n=12 (aggregate sweep est. days)", io)
    (; all_ok, ok_struct, ok_B, ok_C, ok_A_apn, ok_A_new, deep = true)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    section6_1_report()
    section6_1_n12_report()
end
