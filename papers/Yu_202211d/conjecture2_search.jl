# Conjecture 2 — the H_8 model and its modified-entry QAM search.
#
# ── Paper mapping ───────────────────────────────────────────────────────────
# Source: Yu and Perrin (2022), Section "New 8-bit quadratic APN functions",
# Definition (QAM), Theorem 1 (Yu–Wang–Li 2014), and Conjecture 2.
#
# Definition (QAM). H ∈ F_{2^n}^{n×n} is a Quadratic APN Matrix iff
#   (1) H is symmetric with zero main diagonal, and
#   (2) every nonzero F_2-linear combination of the n rows of H has rank n-1.
# Theorem 1 (Yu–Wang–Li). With H = M_α^t C_F M_α, F is APN iff H is a QAM,
#   a one-to-one correspondence between quadratic homogeneous APN F and QAMs.
# Both are provided by VBF: `is_qam` (the rank test) and `qam_to_sbox` /
# `quadratic_apn_matrix` (the correspondence). This file does not re-implement
# them; it builds the specific matrix H_8 and drives the search.
#
# Conjecture 2. Let
#
#   H_8 =
#   ┌ 0     g^34  g^81  g^83  g^170 g^106 x13  x7 ┐
#   │ g^34  0     g^68  g^162 g^166 g^85  x12  x6 │
#   │ g^81  g^68  0     g^136 g^69  g^77  x11  x5 │
#   │ g^83  g^162 g^136 0     g^17  g^138 x10  x4 │
#   │ g^170 g^166 g^69  g^17  0     g^34  x9   x3 │
#   │ g^106 g^85  g^77  g^138 g^34  0     x8   x2 │
#   │ x13   x12   x11   x10   x9    x8    0    x1 │
#   └ x7    x6    x5    x4    x3    x2    x1   0  ┘
#
# The left-upper 6×6 block equals the QAM of x^3 (built here in the normal
# basis γ = g^11). Conjecture 2 claims every CCZ-class of quadratic APN on
# F_{2^8} is reached by letting x_1,…,x_13 traverse F_{2^8}. The full traversal
# is ≈2^50 (Conjecture 3) — centuries of CPU — so this file only runs *bounded*
# prefixes and always reports whether a run was exhaustive or budget-limited.
#
# ── Routine pseudocode (Algorithm 1 of Yu–Wang–Li 2014, as used here) ───────
#   build H_8 with the fixed 6×6 block and the seed values of x_1..x_13;
#   for each assignment of the *varied* x_i (in the order x_13, x_12, …, x_1,
#       each over its candidate set; the others stay at the x^3 seed):
#     if is_qam(H_8):                       # Definition/Theorem 1 test
#         F = qam_to_sbox(H_8)              # the corresponding APN function
#         keep F if apn_ea_mugshot(F) is new    # one per EA(=CCZ)-class
#     stop after `limit` classes or `max_evaluations` candidates.

isdefined(@__MODULE__, :MAGMA_MODULUS) || include(joinpath(@__DIR__, "helpers.jl"))
using VBF

# The literal g-power entries of the upper-left 6×6 block of H_8 (−1 == 0 on the
# diagonal). Used to cross-check the normal-basis QAM-of-x^3 reconstruction.
const H8_BLOCK6_EXPONENTS = [
    -1  34  81  83 170 106
    34  -1  68 162 166  85
    81  68  -1 136  69  77
    83 162 136  -1  17 138
   170 166  69  17  -1  34
   106  85  77 138  34  -1
]

# Position (row, col) of variable x_i in H_8 (1-indexed). Column 7 holds
# x13,x12,x11,x10,x9,x8 (rows 1..6); column 8 holds x7,x6,x5,x4,x3,x2; the
# corner H_8[7,8] holds x1.
const H8_VAR_POSITION = [
    (7, 8),  # x1
    (6, 8),  # x2
    (5, 8),  # x3
    (4, 8),  # x4
    (3, 8),  # x5
    (2, 8),  # x6
    (1, 8),  # x7
    (6, 7),  # x8
    (5, 7),  # x9
    (4, 7),  # x10
    (3, 7),  # x11
    (2, 7),  # x12
    (1, 7),  # x13
]

"""
    h8_base() -> Matrix{Int}

The seed matrix `H_8`: the full normal-basis (γ = g^11) QAM of `x^3` on
`F_{2^8}`. Its upper-left 6×6 block is the fixed block of Conjecture 2 and its
last two columns hold the `x^3` values of `x_1,…,x_13`.
"""
function h8_base()
    nb = normal_basis()
    [gold3_polar(nb[u], nb[v]) for u = 1:8, v = 1:8]
end

"""
    h8_base_vars() -> Vector{Int}

The seed values `[x_1, …, x_13]` of the last two columns of `h8_base()` (the
`x^3` assignment), indexed so that result `[i]` is `x_i`.
"""
function h8_base_vars()
    H = h8_base()
    [H[H8_VAR_POSITION[i]...] for i = 1:13]
end

"""
    h8_from_vars(x; base = h8_base()) -> Matrix{Int}

`H_8` with its 13 free entries set from `x` (`x[i]` is `x_i`), keeping the fixed
6×6 block from `base`. Symmetry is enforced.
"""
function h8_from_vars(x::AbstractVector{<:Integer}; base::AbstractMatrix{<:Integer} = h8_base())
    length(x) == 13 || throw(ArgumentError("h8_from_vars: need 13 values x_1..x_13"))
    H = Matrix{Int}(copy(base))
    for i = 1:13
        r, c = H8_VAR_POSITION[i]
        H[r, c] = Int(x[i])
        H[c, r] = Int(x[i])
    end
    H
end

"""
    base_matches_paper() -> Bool

Verify that the normal-basis QAM of `x^3` reproduces the literal `g`-power block
of Conjecture 2 (the upper-left 6×6 of `H_8`).
"""
function base_matches_paper()
    H = h8_base()
    paper = [e == -1 ? 0 : gpow(e) for e in H8_BLOCK6_EXPONENTS]
    H[1:6, 1:6] == paper
end

"""
    conjecture2_search(; vary, candidates, limit, max_evaluations,
                         full_search, qam_test) -> NamedTuple

Run the Conjecture-2 / Algorithm-1 routine over a *bounded* prefix. `vary` lists
the indices `i` of the `x_i` to traverse (default `[13]`); every other `x_i`
stays at its `x^3` seed value. Each varied `x_i` ranges over `candidates[i]` if
given, otherwise over all of `F_{2^8}` (`0:255`). Candidates are swept in the
paper's order (`x_13` first, then decreasing index). A matrix passing
`qam_test` (default [`is_qam`](@ref)) is converted with `qam_to_sbox` and kept
once per EA(=CCZ)-class via `apn_ea_mugshot`.

The scan stops after `limit` classes or `max_evaluations` candidates. Unless
`full_search=true`, `max_evaluations` is also clamped so a default run can never
launch an infeasible traversal. Returns the distinct functions found and
bookkeeping (`evaluated`, `qam_hits`, `exhaustive`, …).

TODO (Section "Avoiding EA-equivalent APN functions"; Algorithm 1 of
Yu–Wang–Li 2014, Conjecture 3). The full search that reaches the paper's ≈2^50
complexity is NOT reproduced. Implemented: the H_8 model, the Algorithm-1
traversal order (x_13 first), EA-class deduplication, and the Proposition-3
candidate sets (passed via `candidates`). Missing — and infeasible here — is the
per-variable on-the-fly pruning of x_11,x_10,x_9,x_8,x_5,x_4,x_3 whose candidate
cardinalities fluctuate as earlier variables are fixed (the paper's product
estimates ≈2^{47..49.8}). The explicit pseudocode for that pruning lives in
Algorithm 1 of Yu–Wang–Li 2014, which is not part of the local sources;
porting it is the open item needed before the full n=8 traversal is even
attemptable (still centuries of CPU).
"""
function conjecture2_search(;
    vary::AbstractVector{<:Integer} = [13],
    candidates::Union{Nothing,AbstractDict{<:Integer,<:AbstractVector}} = nothing,
    limit::Int = typemax(Int),
    max_evaluations::Int = 1 << 20,
    full_search::Bool = false,
    qam_test = is_qam,
)
    base = h8_base()
    seed = h8_base_vars()
    varied = sort(collect(Int.(vary)); rev = true)   # x_13 first (Algorithm 1)

    # per-variable candidate lists
    domain(i) =
        candidates !== nothing && haskey(candidates, i) ? collect(Int.(candidates[i])) :
        collect(0:255)
    lists = [domain(i) for i in varied]
    sizes = length.(lists)
    space = isempty(sizes) ? 1 : prod(BigInt.(sizes))

    # budget: never let a default run blow up; explicit full_search lifts the cap
    budget = full_search ? max_evaluations : min(max_evaluations, 1 << 22)

    found = SBox{8}[]
    seenmug = Set{APNEAMugshot}()
    x = copy(seed)
    counter = zeros(Int, length(varied))
    evaluated = 0
    qam_hits = 0
    exhausted_space = true

    while true
        if evaluated >= budget
            exhausted_space = false
            break
        end
        for (k, i) in enumerate(varied)
            x[i] = lists[k][counter[k] + 1]
        end
        H = h8_from_vars(x; base = base)
        evaluated += 1
        if qam_test(H)
            qam_hits += 1
            F = qam_to_sbox(H)
            mug = apn_ea_mugshot(F)
            if !(mug in seenmug)
                push!(seenmug, mug)
                push!(found, F)
                if length(found) >= limit
                    exhausted_space = false
                    break
                end
            end
        end
        # odometer over the varied variables
        p = 1
        while p <= length(varied)
            counter[p] += 1
            counter[p] < sizes[p] && break
            counter[p] = 0
            p += 1
        end
        p > length(varied) && break
    end

    (
        found = found,
        n_classes = length(found),
        evaluated = evaluated,
        qam_hits = qam_hits,
        candidate_space = space,
        exhaustive = exhausted_space,
        budget = budget,
        vary = collect(Int.(varied)),
    )
end

"""
    conjecture2_recovers_seed() -> NamedTuple

Sanity check: the seed `H_8` is a QAM, its S-box is APN of degree 2, and it lies
in the Gold `x^3` EA-class — i.e. the routine recovers its own seed.
"""
function conjecture2_recovers_seed()
    H = h8_base()
    F = qam_to_sbox(H)
    (
        base_is_qam = is_qam(H),
        sbox_is_apn = differential_uniformity(F) == 2,
        sbox_is_quadratic = algebraic_degree(F) == 2,
        is_gold_class = apn_ea_mugshot(F) == apn_ea_mugshot(gold_apn(8, 1)),
        matches_paper_block = base_matches_paper(),
    )
end

function conjecture2_report(io::IO = stdout; max_evaluations::Int = 1 << 20)
    print_section("Conjecture 2: the H_8 model (n = 8)", io)

    s = conjecture2_recovers_seed()
    print_check("normal-basis QAM(x^3) reproduces the literal g-power 6×6 block",
                s.matches_paper_block, io)
    print_check("seed H_8 is a QAM (Definition QAM / Theorem 1)", s.base_is_qam, io)
    print_check("seed S-box is APN (differential uniformity 2)", s.sbox_is_apn, io)
    print_check("seed S-box is quadratic (algebraic degree 2)", s.sbox_is_quadratic, io)
    print_check("seed S-box is in the Gold x^3 EA-class", s.is_gold_class, io)

    r = conjecture2_search(; vary = [13], max_evaluations = max_evaluations)
    print_kv("bounded search: varied variables", r.vary, io)
    print_kv("bounded search: candidates evaluated",
             search_completeness_label(r.exhaustive, r.evaluated, r.budget), io)
    print_kv("bounded search: QAM hits / distinct EA-classes",
             "$(r.qam_hits) / $(r.n_classes)", io)
    println(io, "  Note: with the other 12 entries held at the x^3 seed, only the")
    println(io, "  seed value of x_13 keeps H_8 a QAM. New functions require the")
    println(io, "  full coupled traversal of x_1..x_13 (≈2^50, Conjecture 3),")
    println(io, "  which is intentionally not run here.")

    (
        matches_paper_block = s.matches_paper_block,
        base_is_qam = s.base_is_qam,
        sbox_is_apn = s.sbox_is_apn,
        sbox_is_quadratic = s.sbox_is_quadratic,
        is_gold_class = s.is_gold_class,
        vary = r.vary,
        evaluated = r.evaluated,
        budget = r.budget,
        exhaustive = r.exhaustive,
        candidate_space = r.candidate_space,
        qam_hits = r.qam_hits,
        n_classes = r.n_classes,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    conjecture2_report()
end
