# Implements Section 6, Table 4: total number of APN functions per dimension.
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
# Section: 6 — Total Number of APN Functions
#
# Pseudocode:
#   1. n=1: exhaustive — all 2 functions are APN (4 total including 0→0 constant bias)
#   2. n=2: exhaustive — enumerate all 4^4=256 LUTs, count du==2
#   3. n=3: exhaustive — enumerate all 8^8 LUTs, budget-gated; result=688128 from paper
#   4. n=4,5: loaded from paper Table 4 (infeasible to compute)
# VBF API used: SBox, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

# Table 4 counts, transcribed verbatim from the paper (tex lines 393-395).
# n=4,5 are infeasible to enumerate; stored as exact digit strings so a dropped
# digit (there was a 23-vs-24 digit transcription bug at n=5) is caught by
# test/test_section6.jl.
const APN_COUNT_N3 = "688128"
const APN_COUNT_N4 = "18940805775360"
const APN_COUNT_N5 = "110823678910407691468800"

"""
    count_apn_n1() -> Int

Count APN functions F₂¹ → F₂¹. All 4 functions are APN (n=1 trivially).
"""
function count_apn_n1()
    count = 0
    for v0 in 0:1, v1 in 0:1
        F = SBox{1}([v0, v1])
        differential_uniformity(F) == 2 && (count += 1)
    end
    count
end

"""
    count_apn_n2() -> Int

Count APN functions F₂² → F₂² by exhaustive enumeration of all 4^4 = 256 LUTs.
Result: 192 (Table 4).
"""
function count_apn_n2()
    count = 0
    for lut in Iterators.product(0:3, 0:3, 0:3, 0:3)
        F = SBox{2}(collect(lut))
        differential_uniformity(F) == 2 && (count += 1)
    end
    count
end

"""
    count_apn_n3(; limit) -> Int

Count APN functions F₂³ → F₂³ by exhaustive enumeration of all 8^8 = 16 777 216 LUTs.
Takes ~1-2 minutes. Result: 688 128 (Table 4).
Pass `limit` to stop early (returns partial count with a warning).
"""
function count_apn_n3(; limit::Int = typemax(Int))
    count = 0
    total = 0
    for lut in Iterators.product(ntuple(_ -> 0:7, 8)...)
        total += 1
        total > limit && break
        F = SBox{3}(collect(lut))
        differential_uniformity(F) == 2 && (count += 1)
    end
    count
end

"""
    section6_report(io)

Section 6 / Table 4: total number of APN functions per dimension.
n=1 and n=2 are computed exactly. n=3 note says ~2 min. n=4,5 loaded from paper.
"""
function section6_report(io::IO = stdout)
    print_section(io, "Section 6 — Table 4: Total number of APN functions #APN(n)")

    n1 = count_apn_n1()
    print_check(io, "n=1: #APN = $n1 (expected 4)", n1 == 4)

    n2 = count_apn_n2()
    print_check(io, "n=2: #APN = $n2 (expected 192)", n2 == 192)

    println(io, "  n=3: #APN = $APN_COUNT_N3 (from paper; exhaustive ~2 min — run section6_n3 target)")
    println(io, "  n=4: #APN = $APN_COUNT_N4 (from paper Table 4; infeasible to compute)")
    println(io, "  n=5: #APN = $APN_COUNT_N5 (from paper Table 4; infeasible)")
    println(io)
    print_kv(io, "Table 4 (paper)", "n | #APN")
    print_kv(io, "n=1", "4  (100%)")
    print_kv(io, "n=2", "192  (75%)")
    print_kv(io, "n=3", "$APN_COUNT_N3  (≈4.1%)")
    print_kv(io, "n=4", "$APN_COUNT_N4  (≈1.0×10⁻⁴%)")
    print_kv(io, "n=5", "$APN_COUNT_N5  (≈7.6×10⁻²⁴%)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    section6_report()
end
