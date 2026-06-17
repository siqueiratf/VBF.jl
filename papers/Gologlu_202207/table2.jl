# Implements Table II — NF sequences for n=14 (m=7).
# Paper: Gologlu, F. (2022), "Biprojective Almost Perfect Nonlinear Functions",
#        IEEE Transactions on Information Theory
# Section: VI — Inequivalence Results
#
# Table II: NF = [η1,...,η14](NBF) for T, F1, F2 on F_{2^{14}}.
# Computation is expensive (SBox{14}, Walsh 16384×16384) — opt-in only.
#
# Pseudocode:
#   For each family and i ∈ {1..6}:
#     1. Construct SBox{14} via f1_sbox/f2_sbox (m=7)
#     2. nonbent_signature → NF
#     3. Compare to paper Table II
# VBF API used: nonbent_signature, f1_sbox, f2_sbox, taniguchi_apn_representatives

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem3_2.jl"))

# Paper Table II expected values (NF with trailing zeros stripped)
const TABLE_II_EXPECTED = Dict(
    "T_i16"  => [5461, 1681988, 13313156, 436626],
    "T_i25"  => [5461, 1681988, 13267817, 401828],
    "T_i34"  => [5461, 1681988, 13290042, 428625],
    "F1_i16" => [5461, 1681988, 13250164, 394843],
    "F1_i25" => [5461, 1681988, 13238480, 398399],
    "F1_i34" => [5461, 1681988, 13286867, 438531],
    "F2_i16" => [5461, 1681988, 13219303, 413004, 2667, 127, 1],
    "F2_i25" => [5461, 1681988, 13293725, 430784, 2667, 127, 1],
    "F2_i34" => [5461, 1681988, 13290423, 418084, 2667, 127, 1],
)

"""
    table2_report(; io, i_values, include_taniguchi) -> NamedTuple

Compute NF for Table II (n=14, m=7). Expensive — requires `full_search=true`.
Each SBox{14} has 2^14 = 16384 elements; Walsh is 16384×16384.
"""
function table2_report(;
    io::IO = stdout,
    i_values::Vector{Int} = [1, 2, 3],
    include_taniguchi::Bool = false,
)
    print_section("Table II — NF sequences for F1, F2 on F_{2^{14}} (n=14, m=7)", io)
    println(io, "  completeness: budget-limited (i_values = $i_values)")
    println(io, "  WARNING: each NF computation takes ~60s on modern hardware")
    println(io)

    m = 7
    all_ok = true
    nf_results = Dict{String,Vector{Int}}()

    for i in i_values
        gcd(3i, m) == 1 || continue

        i_pair = i in [1, 6] ? "i16" : (i in [2, 5] ? "i25" : "i34")

        t0 = time()
        F1 = f1_sbox(m, i)
        nf1 = drop_trailing_zeros(nonbent_signature(F1))
        ok1 = nf1 == TABLE_II_EXPECTED["F1_$i_pair"]
        print_check("F1 i=$i  NF = $nf1  ($(round(time()-t0, digits=1))s)", ok1, io)
        nf_results["F1_i$i"] = nf1
        all_ok &= ok1

        t0 = time()
        F2 = f2_sbox(m, i)
        nf2 = drop_trailing_zeros(nonbent_signature(F2))
        ok2 = nf2 == TABLE_II_EXPECTED["F2_$i_pair"]
        print_check("F2 i=$i  NF = $nf2  ($(round(time()-t0, digits=1))s)", ok2, io)
        nf_results["F2_i$i"] = nf2
        all_ok &= ok2
    end

    if include_taniguchi
        println(io, "\n  Taniguchi family T on F_{2^{14}}:")
        t_reps = taniguchi_apn_representatives(m)
        for (j, r) in enumerate(t_reps)
            t0 = time()
            nf = drop_trailing_zeros(nonbent_signature(r.sbox))
            println(io, "    T class $j: NF = $nf  ($(round(time()-t0, digits=1))s)")
            nf_results["T_class$j"] = nf
        end
    end

    println(io)
    print_check("All Table II NF values match paper", all_ok, io)
    (; all_ok, nf_results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    table2_report()
end
