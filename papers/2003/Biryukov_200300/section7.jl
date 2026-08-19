# Implements Section 7 — Decomposition of Large S-Boxes Using Smaller S-Boxes
# (Table 1) and Appendix C — The Number of Equivalence Classes (Table 5).
# Paper: Biryukov et al. (2003), "A Toolbox for Cryptanalysis: Linear and Affine
#        Equivalence Algorithms", Eurocrypt 2003.
# Section: 7 (Table 1, SPN-layer lower bound) and Appendix C (Table 5, class counts)
#
# Pseudocode:
#   Appendix C / Table 5 (EXACT for n<=3):
#     1. Enumerate every permutation of GF(2)^n (Heap's algorithm).
#     2. Bucket by canonical linear_representative / affine_representative.
#     3. Count distinct representatives => #linear and #affine equivalence classes.
#     n=4,5 are transcribed from the paper (16! .. 2^25! permutations — infeasible
#     to enumerate; the paper obtains them by Polya theory, Lorens/Harrison).
#   Section 7 / Table 1 (counting-argument lower bound):
#     l = smallest number of m-bit SPN layers whose representable-function count
#         reaches the total number 2^n! of n-bit S-boxes, using the paper's
#         displayed formula:
#           (2^m!)^k * ( (1/k!) * (2^m!/|AGL(m,2)|^2)^k * |AGL(n,2)| )^(l-1)
#           first layer      : (2^m!)^k                [k = n/m arbitrary S-boxes]
#           each next round  : |AGL(n,2)| * C_m^k / k! [1 affine mix + k S-boxes,
#                                                       each in a distinct affine
#                                                       class; /k! because the k
#                                                       classes are unordered]
#         C_m = #affine classes of m-bit permutations: exact (Table 5) for m<=4,
#         the approximation 2^m!/|AGL(m,2)|^2 beyond (paper footnote 6).
# VBF API used: linear_representative, affine_representative

include(joinpath(@__DIR__, "helpers.jl"))

# ----------------------------------------------------------------------------
# Appendix C — Table 5. Number of linear / affine equivalence classes of the
# permutations of GF(2)^n.  (#Lin, #Af)
# ----------------------------------------------------------------------------
const TABLE5 = Dict{Int,Tuple{BigInt,BigInt}}(
    1 => (big"2", big"1"),
    2 => (big"2", big"1"),
    3 => (big"10", big"4"),
    4 => (big"52246", big"302"),
    5 => (big"2631645209645100680144", big"2569966041123963092"),
)

# Record the canonical linear / affine representative of one permutation.
# Kept as a plain function (not a closure) so the hot loop stays type-stable.
function _record_reps!(
    lin::Set{Vector{UInt8}},
    aff::Set{Vector{UInt8}},
    a::Vector{UInt8},
    ::Val{n},
) where {n}
    s = SBox{n,UInt8}(copy(a))
    push!(lin, copy(linear_representative(s).representative.lut))
    push!(aff, copy(affine_representative(s).lut))
    nothing
end

# Recursive Heap's algorithm: visits every permutation of `a` exactly once
# (k! visits), recording each one's representatives.  Type-stable via Val{n}.
function _heap_reps!(
    lin::Set{Vector{UInt8}},
    aff::Set{Vector{UInt8}},
    a::Vector{UInt8},
    ::Val{n},
    k::Int,
) where {n}
    if k == 1
        _record_reps!(lin, aff, a, Val(n))
    else
        @inbounds for i = 1:k
            _heap_reps!(lin, aff, a, Val(n), k - 1)
            if iseven(k)
                a[i], a[k] = a[k], a[i]
            else
                a[1], a[k] = a[k], a[1]
            end
        end
    end
    nothing
end

# Enumerate every permutation of 0:(N-1) and count the distinct canonical
# linear / affine representatives.  EXACT, exhaustive.
function equivalence_class_counts(n::Int)
    N = 1 << n
    lin = Set{Vector{UInt8}}()
    aff = Set{Vector{UInt8}}()
    a = collect(UInt8, 0:(N-1))
    _heap_reps!(lin, aff, a, Val(n), N)
    (length(lin), length(aff))
end

# ----------------------------------------------------------------------------
# Section 7 — Table 1. SPN-layer lower bound.
# ----------------------------------------------------------------------------

# |AGL(n,2)| = 2^n * |GL(n,2)| = 2^n * prod_{i=0}^{n-1}(2^n - 2^i).
function agl_order(n::Int)
    g = BigInt(1)
    for i = 0:(n-1)
        g *= (BigInt(2)^n - BigInt(2)^i)
    end
    (BigInt(2)^n) * g
end

# #affine equivalence classes of m-bit permutations.  Appendix C of the paper:
# "for S-box sizes 3 and 4 we used exact values and for the larger sizes we used
# the approximation" 2^m!/|AGL(m,2)|^2.  So the exact branch is gated at m <= 4,
# matching the paper's own method rather than the largest m we happen to know.
# This is immaterial to Table 1: the only column with m = 5 is (n,m) = (10,5),
# and exact (2569966041123963092) vs approximate (2569966024555163104) both give
# l = 39.
function affine_class_count(m::Int)
    m <= 4 && haskey(TABLE5, m) && return TABLE5[m][2]
    div(factorial(BigInt(2)^m), agl_order(m)^2)
end

# Smallest number of layers l whose representable count reaches 2^n!.
# Per-round factor is (1/k!)*(2^m!/|AGL(m,2)|^2)^k*|AGL(n,2)| from the paper's
# displayed formula: the k S-boxes of a round must sit in k *distinct* affine
# classes, and an unordered choice of k classes is counted k! times.
function spn_layer_bound(n::Int, m::Int)
    k = div(n, m)
    per_round = div(agl_order(n) * affine_class_count(m)^k, factorial(big(k)))
    target = factorial(BigInt(2)^n)
    total = factorial(BigInt(2)^m)^k          # l = 1 (first layer only)
    l = 1
    while total < target
        total *= per_round
        l += 1
    end
    l
end

# Table 1 columns: (n, m, k, l_paper).  The trailing n=16 column in the paper's
# printed table is truncated (m/k/l missing) — an OCR/typesetting artifact — so
# only the eight fully-specified columns are reproduced here.
const TABLE1 = [
    (6, 3, 2, 8),
    (8, 4, 2, 20),
    (9, 3, 3, 43),
    (10, 5, 2, 39),
    (12, 3, 4, 276),
    (12, 4, 3, 246),
    (12, 6, 2, 75),
    (16, 4, 4, 3196),
]

function section7_report(io::IO = stdout; full_search::Bool = false)
    all_ok = true

    # --- Appendix C / Table 5 -------------------------------------------------
    print_section(io, "Appendix C — Number of equivalence classes of permutations (Table 5)")
    # n = 1, 2 are cheap and always verified exactly.
    for n = 1:2
        got = equivalence_class_counts(n)
        exp = TABLE5[n]
        ok = big(got[1]) == exp[1] && big(got[2]) == exp[2]
        print_check(io, "n=$n  #lin=$(got[1]) (exp $(exp[1])), #aff=$(got[2]) (exp $(exp[2]))", ok)
        all_ok &= ok
    end
    # n = 3 is exact but ~8! permutations; opt-in to keep the default fast.
    if full_search
        got = equivalence_class_counts(3)
        exp = TABLE5[3]
        ok = big(got[1]) == exp[1] && big(got[2]) == exp[2]
        print_check(io, "n=3  #lin=$(got[1]) (exp $(exp[1])), #aff=$(got[2]) (exp $(exp[2]))", ok)
        all_ok &= ok
    else
        println(io, "  [SKIP] n=3 exact enumeration (8! perms); run with full_search=true")
    end
    print_kv(io, "n=4,5", "transcribed (16! .. 2^25! perms — enumeration infeasible; Polya theory)")
    print_kv(io, "  n=4 (#lin,#aff)", "$(TABLE5[4][1]), $(TABLE5[4][2])")
    print_kv(io, "  n=5 (#lin,#aff)", "$(TABLE5[5][1]), $(TABLE5[5][2])")

    # --- Section 7 / Table 1 --------------------------------------------------
    print_section(io, "Section 7 — SPN-layer lower bound (Table 1, counting argument)")
    for (n, m, k, lp) in TABLE1
        got = spn_layer_bound(n, m)
        ok = got == lp
        print_check(io, "n=$n, m=$m, k=$k → l=$got (paper $lp)", ok)
        all_ok &= ok
    end
    print_kv(io, "completeness", "Table 5 exact for n≤2 (n≤3 with full_search); Table 1 all 8 columns exact")

    return all_ok
end

if abspath(PROGRAM_FILE) == @__FILE__
    full = lowercase(get(ENV, "FULL_SEARCH", "false")) == "true"
    ok = section7_report(; full_search = full)
    exit(ok ? 0 : 1)
end
