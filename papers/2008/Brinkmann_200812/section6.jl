# Implements Section 6, Table 4: total number of APN functions per dimension.
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
# Section: 6 — Total Number of APN Functions
#
# Pseudocode:
#   1. n=1: exhaustive — all 2 functions are APN (4 total including 0→0 constant bias)
#   2. n=2: exhaustive — enumerate all 4^4=256 LUTs, count du==2
#   3. n=3: exhaustive — enumerate all 8^8 LUTs, budget-gated; result=688128 from paper
#   4. g_order(n) — the order of the EA group G, eq. (10)
#   5. apn_count_from_orbits(n) — Σ |G|/|G_s| over the paper's stabiliser orders;
#      derives the n=4 and n=5 entries of Table 4 instead of transcribing them
# VBF API used: SBox, differential_uniformity

isdefined(@__MODULE__, :table2_luts) || include(joinpath(@__DIR__, "helpers.jl"))

# Table 4 counts, transcribed verbatim from the paper (tex lines 393-395).
# n=4,5 are infeasible to enumerate; stored as exact digit strings so a dropped
# digit (there was a 23-vs-24 digit transcription bug at n=5) is caught by
# test/test_section6.jl. `apn_count_from_orbits` re-derives n=4 and n=5 from
# Section 6's orbit-stabiliser apparatus, so these are now cross-checks rather
# than the only source.
const APN_COUNT_N3 = "688128"
const APN_COUNT_N4 = "18940805775360"
const APN_COUNT_N5 = "110823678910407691468800"

"""
    g_order(n) -> BigInt

The order of the group `G` of Section 6, eq. (10):

    |G| = |Gᵅ| · |Gᵝ| · |Gᵞ|
        = (2ⁿ · ∏_{i=0}^{n−1}(2ⁿ − 2ⁱ)) · (∏_{i=0}^{n−1}(2ⁿ − 2ⁱ)) · (2ⁿ)^{n+1}

with `α` an affine bijection, `β` a linear bijection and `γ` an arbitrary affine
function. The middle factor is the number of linear permutations (OEIS A002884).
"""
function g_order(n::Integer)
    nn = BigInt(n)
    q = BigInt(2)^nn
    gl = prod(q - BigInt(2)^i for i = 0:(nn-1))   # |GL(n,2)|
    (q * gl) * gl * q^(nn + 1)
end

"""
    stabiliser_orders(n) -> Vector{Int}

The orders `|G_s|` of the stabilisers of the EA-canonical APN representatives,
transcribed from the text of Section 6: "The orders of the stabilisers in
dimension 4 are 5760 and 384. In dimension 5, the orders are 4960, 4960, 160,
160, 155, 155, and 155."

One entry per EA class — 2 for n=4 (Table 2) and 7 for n=5 (Table 3).
`algorithm1.jl` re-derives the first n=5 entry (4960) from Note 9's explicit
generators.
"""
function stabiliser_orders(n::Integer)
    n == 4 && return [5760, 384]
    n == 5 && return [4960, 4960, 160, 160, 155, 155, 155]
    throw(ArgumentError("stabiliser_orders: the paper only gives n = 4 and n = 5, got $n"))
end

"""
    apn_count_from_orbits(n) -> BigInt

`#APN(n)` derived from Section 6 rather than transcribed: the EA classes are
exactly the orbits `Gs` of the action (9), and `|Gs| = |G|/|G_s|`
(orbit-stabiliser), so

    #APN(n) = Σ_s |G| / |G_s|

over one representative `s` per EA class. Reproduces the n=4 and n=5 rows of
Table 4 exactly.
"""
apn_count_from_orbits(n::Integer) =
    sum(div(g_order(n), BigInt(k)) for k in stabiliser_orders(n))

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
Pass `limit` to stop early; the result is then a partial count and a warning is
emitted, so a truncated run cannot be mistaken for a complete one.

`count_apn_backtrack(3)` in `algorithm1.jl` computes the same number with the
paper's own Algorithm 1 filter in well under a second.
"""
function count_apn_n3(; limit::Int = typemax(Int))
    count = 0
    total = 0
    for lut in Iterators.product(ntuple(_ -> 0:7, 8)...)
        total += 1
        if total > limit
            @warn "count_apn_n3 truncated at limit=$limit; result is a partial count, \
not #APN(3)" partial_count = count
            break
        end
        F = SBox{3}(collect(lut))
        differential_uniformity(F) == 2 && (count += 1)
    end
    count
end

"""
    section6_report(io)

Section 6 / Table 4: total number of APN functions per dimension.
n=1 and n=2 are computed exactly, n=3 takes ~2 min by leaf enumeration (or < 1 s
via Algorithm 1), and n=4, n=5 are derived from the orbit-stabiliser formula
rather than transcribed.
"""
function section6_report(io::IO = stdout)
    print_section(io, "Section 6 — Table 4: Total number of APN functions #APN(n)")

    n1 = count_apn_n1()
    print_check(io, "n=1: #APN = $n1 (expected 4)", n1 == 4)

    n2 = count_apn_n2()
    print_check(io, "n=2: #APN = $n2 (expected 192)", n2 == 192)

    println(io, "  n=3: #APN = $APN_COUNT_N3 (exhaustive ~2 min — run section6_n3 target,")
    println(io, "       or count_apn_backtrack(3) in algorithm1.jl, which takes < 1 s)")

    print_section(io, "Section 6 — Table 4 n=4,5 derived from the orbit-stabiliser formula")
    println(io, "  EA classes are the orbits Gs of the action (9), so #APN(n) = Σ_s |G|/|G_s|.")
    for (n, transcribed) in [(4, APN_COUNT_N4), (5, APN_COUNT_N5)]
        derived = apn_count_from_orbits(n)
        print_kv(io, "|G| for n=$n", string(g_order(n)))
        print_kv(io, "|G_s| for n=$n", join(stabiliser_orders(n), ", "))
        print_check(io, "n=$n: Σ |G|/|G_s| = $derived == Table 4 value",
                    string(derived) == transcribed)
    end
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
