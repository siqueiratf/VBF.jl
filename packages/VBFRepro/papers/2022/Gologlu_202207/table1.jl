# Implements Tables I and III — NF sequences for n=10 (m=5).
# Paper: Gologlu, F. (2022), "Biprojective Almost Perfect Nonlinear Functions",
#        IEEE Transactions on Information Theory
# Section: VI — Inequivalence Results
#
# Table I: NF = [η1,...,η10](NBF) for families T, F1, F2, F3 on F_{2^{10}}.
# Table III: NF for known quadratic APN on F_{2^{10}}.
#
# Pseudocode:
#   For each function F:
#     1. Construct SBox{10} (bivariate or catalog)
#     2. nonbent_signature(F) → NF vector (length 10, trailing zeros stripped)
#     3. Compare to paper values
# VBF API used: nonbent_signature, f1_sbox, f2_sbox, f3_sbox, gold_apn,
#               taniguchi_apn_representatives, load_catalog, load_sbox

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem3_2.jl"))

# Paper Table I expected values (NF with trailing zeros stripped)
const TABLE_I_EXPECTED = Dict(
    "T_i14"  => [341, 6820, 3720, 31],
    "T_i23"  => [341, 6820, 3565],
    "F1_i14" => [341, 6820, 3565],
    "F1_i23" => [341, 6820, 3720, 31],
    "F2_i14" => [341, 6820, 4030, 62, 1],
    "F2_i23" => [341, 6820, 3720, 62, 1],
    "F3"     => [341, 6324, 2573, 62, 2],
)

# Paper Table III expected values (known quadratic APN on F_{2^{10}})
# Non-quadratic power functions (x^57, x^339) have NBF = all of F_{2^10} → NF is N/A
const TABLE_III_EXPECTED = Dict(
    "x3"   => [341, 6820, 5115, 341, 11],
    "x9"   => [341, 6820, 5115, 341, 11],
    "x3tr" => [341, 6820, 4215, 66, 1],
    "xu"   => [341, 6820, 4400],
)

"""
    table1_report(; io, include_table3) -> NamedTuple

Compute NF sequences for families on F_{2^{10}} and compare to paper Tables I and III.
"""
function table1_report(;
    io::IO = stdout,
    include_table3::Bool = true,
    include_taniguchi::Bool = false,
)
    print_section("Table I — NF sequences for F1, F2, F3 on F_{2^{10}} (n=10, m=5)", io)
    println(io, "  completeness: exhaustive (all i=1..4 for F1/F2)")
    println(io)

    m = 5
    all_ok = true
    nf_results = Dict{String,Vector{Int}}()

    # --- Families F1, F2, F3 ---
    for i in [1, 2, 3, 4]
        F1 = f1_sbox(m, i)
        nf1 = drop_trailing_zeros(nonbent_signature(F1))
        key1 = i in [1, 4] ? "F1_i14" : "F1_i23"
        ok1 = nf1 == TABLE_I_EXPECTED[key1]
        print_check("F1 i=$i  NF = $nf1", ok1, io)
        nf_results["F1_i$i"] = nf1
        all_ok &= ok1

        F2 = f2_sbox(m, i)
        nf2 = drop_trailing_zeros(nonbent_signature(F2))
        key2 = i in [1, 4] ? "F2_i14" : "F2_i23"
        ok2 = nf2 == TABLE_I_EXPECTED[key2]
        print_check("F2 i=$i  NF = $nf2", ok2, io)
        nf_results["F2_i$i"] = nf2
        all_ok &= ok2
    end

    F3 = f3_sbox()
    nf3 = drop_trailing_zeros(nonbent_signature(F3))
    ok3 = nf3 == TABLE_I_EXPECTED["F3"]
    print_check("F3      NF = $nf3", ok3, io)
    nf_results["F3"] = nf3
    all_ok &= ok3

    # --- Taniguchi family on n=10 (opt-in: slow due to apn_ea_mugshot) ---
    if include_taniguchi
        println(io, "\n  Taniguchi family T on F_{2^{10}} (using taniguchi_apn_representatives):")
        t_reps = taniguchi_apn_representatives(m)
        t_nfs = [drop_trailing_zeros(nonbent_signature(r.sbox)) for r in t_reps]
        t_nf_set = unique(t_nfs)
        print_kv("  T distinct NF classes", length(t_nf_set), io)
        for (j, nf) in enumerate(t_nf_set)
            ok_t14 = nf == TABLE_I_EXPECTED["T_i14"]
            ok_t23 = nf == TABLE_I_EXPECTED["T_i23"]
            matched = ok_t14 ? "matches T_i14" : (ok_t23 ? "matches T_i23" : "unmatched")
            println(io, "    T class $j: NF = $nf  ($matched)")
            all_ok &= (ok_t14 || ok_t23)
            nf_results["T_class$j"] = nf
        end
    else
        println(io, "\n  Taniguchi T NF (paper Table I, not recomputed — pass include_taniguchi=true):")
        println(io, "    T i=1,4: NF = $(TABLE_I_EXPECTED["T_i14"])")
        println(io, "    T i=2,3: NF = $(TABLE_I_EXPECTED["T_i23"])")
    end

    # --- Table III: known quadratic APN on F_{2^10} ---
    if include_table3
        print_section("Table III — NF for known quadratic APN on F_{2^{10}}", io)
        println(io, "  (non-power quadratic APN; power functions x^57, x^339 are non-quadratic)")

        n = 2m

        # Gold x^3 and x^9 (= x^{2^3+1}, Gold with k=3, gcd(3,10)=1? No: gcd(3,10)=1 ✓)
        G3 = gold_apn(n, 1)   # X^3 = X^{2^1+1}
        nf_g3 = drop_trailing_zeros(nonbent_signature(G3))
        ok_g3 = nf_g3 == TABLE_III_EXPECTED["x3"]
        print_check("x^3  NF = $nf_g3", ok_g3, io)
        nf_results["table3_x3"] = nf_g3
        all_ok &= ok_g3

        G9 = gold_apn(n, 3)   # X^9 = X^{2^3+1}? gcd(3,10)=1 ✓
        nf_g9 = drop_trailing_zeros(nonbent_signature(G9))
        ok_g9 = nf_g9 == TABLE_III_EXPECTED["x9"]
        print_check("x^9  NF = $nf_g9", ok_g9, io)
        nf_results["table3_x9"] = nf_g9
        all_ok &= ok_g9
    end

    println(io)
    print_check("All Table I/III NF values match paper", all_ok, io)
    (; all_ok, nf_results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    table1_report()
end
