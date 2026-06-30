# Implements Section 6.1 — Computational results (n=8).
# Paper: Calderini, Budaghyan, Carlet (2021), pp. 79–105
# Section: 6.1 — Computational results for n=2*4
#
# The paper reports (Section 6.1.4, n=2*4):
#   F1 case with b=0, h=m/2=2, k=0, r=0: produces new APN (Theorem 6.2 form)
#   All other F1/F2 cases for n=8 give hexanomial or Taniguchi classes.
#   The new APN is CCZ-inequivalent to all known APN families at n=8.
#
# Pseudocode:
#   1. Enumerate all (b,c) with theorem6_2_condition(4,1,b,c) = true
#   2. Build SBoxes, compute EA-mugshots, deduplicate
#   3. Compare against taniguchi_apn_representatives(4) EA-mugshots
#   4. Check: new mugshots not in Taniguchi reps => new CCZ class
# VBF API used: taniguchi_apn_representatives, differential_uniformity, algebraic_degree,
#               apn_ea_mugshot, APNEAMugshot, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    section6_1_report([io]; full_search) -> NamedTuple

Section 6.1 computational results for n=8 (m=4, i=1).
Enumerates all valid (b,c) pairs for Theorem 6.2, deduplicates by EA-mugshot,
and checks CCZ-distinctness from the Taniguchi family.
"""
function section6_1_report(io::IO = stdout; full_search::Bool = false)
    m     = 4
    i     = 1
    n     = 2m
    mod_m = primitive_polynomial(m)

    print_section("Section 6.1 — n=8 computational results (Theorem 6.2)", io)
    println(io, "  F(x,y)=(xy, x^3+x^8*y^4+b*xy^2+c*y^3) over GF(2^4) x GF(2^4)")
    println(io, "  Searching all (b,c) in GF(2^4)^2 for APN instances...")

    # Collect all APN (b,c) and their EA-mugshots
    valid_pairs = Tuple{Int,Int}[]
    for b in 0:(1 << m) - 1, c in 0:(1 << m) - 1
        theorem6_2_condition(m, i, b, c; modulus = mod_m) && push!(valid_pairs, (b, c))
    end

    print_kv("valid (b,c) pairs (condition holds)", length(valid_pairs), io)

    # Deduplicate by EA-mugshot
    seen  = Set{APNEAMugshot}()
    reps  = NamedTuple[]
    for (b, c) in valid_pairs
        F  = theorem6_2_sbox(m, i, b, c; modulus = mod_m)
        mg = apn_ea_mugshot(F)
        mg in seen && continue
        push!(seen, mg)
        push!(reps, (; b, c, algebraic_degree = algebraic_degree(F), mugshot = mg))
    end
    print_kv("distinct EA-classes from Theorem 6.2", length(reps), io)

    # Taniguchi EA-classes for comparison
    tan_reps = taniguchi_apn_representatives(m)
    tan_mugs = Set(apn_ea_mugshot(r.sbox) for r in tan_reps)
    print_kv("Taniguchi EA-classes at n=$n", length(tan_mugs), io)

    # CCZ-distinctness check: new mugshots not in Taniguchi set
    new_reps = filter(r -> r.mugshot ∉ tan_mugs, reps)
    ok_new   = !isempty(new_reps)
    print_check("found EA-class(es) from Thm 6.2 distinct from all Taniguchi classes", ok_new, io)
    print_kv("  new EA-classes (not in Taniguchi)", length(new_reps), io)
    for r in new_reps
        print_kv("    (b=$(r.b), c=$(r.c))", "deg=$(r.algebraic_degree)", io)
    end

    print_kv("completeness", "exhaustive over GF(2^4)^2", io)
    (; all_ok = ok_new, valid_count = length(valid_pairs),
       ea_classes = length(reps), new_classes = length(new_reps))
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    section6_1_report()
end
