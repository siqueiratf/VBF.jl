# search/phase1_targets.jl — PHASE 1 target selection.
#
# For every BBL2021 n=8 LE-automorphism class, build
#
#     V_A = ker(M_A),   M_A the 224 x 224 F_2 matrix expanding  F.A = A.F
#                       over the 224 quadratic ANF coefficients c_{(p,q),k}
#                       (28 unordered index pairs x 8 output bits),
#
# and record dim(V_A). Ranks candidates by tractability (smallest dim first).
#
# The M_A construction mirrors Kuznetsov (2026) Eq. (2) as implemented in
# papers/2026/Kuznetsov_202606/helpers.jl:build_M_A (read, not modified, and
# re-implemented here so this run does not depend on paper-local code). The
# built-in control is class 22: the audit (F002) and bench/calibration.toml
# both record rank(M_A) = 184 and dim V_A = 40 for it.
#
# Writes: search/targets.yaml

using TOML

const ROOT = normpath(joinpath(@__DIR__, ".."))
const TUPLES8 = joinpath(ROOT, "papers", "2021", "Beierle_202107", "tuples",
                         "AllTuplesMatrices8.toml")
const CALIB = joinpath(ROOT, "bench", "calibration.toml")

# ── BBL2021 Table 1, n = 8 column, transcribed from the paper's own LaTeX ────
# input/Beierle et al. - 2021 - ....tex lines 716-786.
#   :alg1  — "no (Alg. 1)": the authors ran the exhaustive search and it
#            terminated with no APN permutation.
#   :prop4 / :prop5 — excluded by a proved admissibility filter.
#   :open  — "?": the caption says this means they could NOT exclude the tuple
#            by Prop. 4 or 5, NOR finish the exhaustive search. The authors'
#            own BudgetHit.
const TABLE1_N8 = Dict(
    1 => :alg1,   2 => :alg1,   3 => :prop5,  4 => :alg1,   5 => :alg1,
    6 => :alg1,   7 => :prop5,  8 => :alg1,   9 => :alg1,  10 => :alg1,
   11 => :prop5, 12 => :prop5, 13 => :prop4, 14 => :alg1,  15 => :alg1,
   16 => :alg1,  17 => :prop5, 18 => :prop4, 19 => :prop4, 20 => :prop4,
   21 => :prop4, 22 => :open,  23 => :alg1,  24 => :prop5, 25 => :prop4,
   26 => :prop4, 27 => :alg1,  28 => :prop4, 29 => :alg1,  30 => :open,
   31 => :alg1,  32 => :prop4,
)

# ── M_A ─────────────────────────────────────────────────────────────────────

pair_index(p::Int, q::Int)::Int = p * (15 - p) ÷ 2 + q - p - 1
row_idx(j::Int, r::Int, s::Int)::Int = j * 28 + pair_index(r, s)
col_idx(p::Int, q::Int, k::Int)::Int = pair_index(p, q) * 8 + k

function build_M_A(A::Matrix{Bool})::BitMatrix
    M = falses(224, 224)
    for j = 0:7, r = 0:6, s = (r+1):7
        row = row_idx(j, r, s) + 1
        for p = 0:6, q = (p+1):7
            val = (A[p+1, r+1] & A[q+1, s+1]) ⊻ (A[p+1, s+1] & A[q+1, r+1])
            val && (M[row, col_idx(p, q, j)+1] ⊻= true)
        end
        for k = 0:7
            A[j+1, k+1] && (M[row, col_idx(r, s, k)+1] ⊻= true)
        end
    end
    M
end

"""RREF over F_2, in place. Returns (pivot_cols, free_cols), 1-based."""
function rref_f2!(M::BitMatrix)
    nrows, ncols = size(M)
    prow = 1
    pivots = Int[]
    for c = 1:ncols
        found = 0
        for r = prow:nrows
            if M[r, c]
                found = r
                break
            end
        end
        found == 0 && continue
        push!(pivots, c)
        if found != prow
            tmp = copy(M[found, :])
            M[found, :] = M[prow, :]
            M[prow, :] = tmp
        end
        pr = M[prow, :]
        for r = 1:nrows
            r == prow && continue
            M[r, c] && (M[r, :] .⊻= pr)
        end
        prow += 1
        prow > nrows && break
    end
    free = setdiff(1:ncols, pivots)
    (pivots, free)
end

# ── Load the class matrices ─────────────────────────────────────────────────

function load_classes8()
    data = TOML.parsefile(TUPLES8)
    blocks = sort(data["blocks"], by = b -> Int(b["index"]))
    out = Dict{Int,Matrix{Bool}}()
    for b in blocks
        rows = b["A"]
        A = falses(8, 8)
        for (i, row) in enumerate(rows), (j, v) in enumerate(row)
            A[i, j] = (Int(v) == 1)
        end
        out[Int(b["index"])] = Matrix{Bool}(A)
    end
    out
end

# ── Cost model from bench/calibration.toml ──────────────────────────────────

function cost_model()
    c = TOML.parsefile(CALIB)
    (; groebner_slice = c["groebner_slice_n8_single"]["median_seconds"],
       is_apn = c["is_apn_n8"]["median_seconds"],
       sigma_key = c["sigma_key_n8"]["median_seconds"],
       ortho = c["ortho_derivative_n8"]["median_seconds"])
end

# ── Main ────────────────────────────────────────────────────────────────────

function main()
    classes = load_classes8()
    cm = cost_model()

    println("class  verdict      rank(M_A)  dim V_A   #NL4-hyperplanes(=2^dim-ish)")
    rows = NamedTuple[]
    for i = 1:32
        A = classes[i]
        M = build_M_A(A)
        pivots, free = rref_f2!(M)
        rank = length(pivots)
        dim = 224 - rank
        verdict = TABLE1_N8[i]
        push!(rows, (; index = i, verdict, rank, dim))
        println(rpad(string(i), 6), rpad(string(verdict), 12),
                rpad(string(rank), 10), rpad(string(dim), 9))
    end

    # ── Control: class 22 must reproduce the audited figures ────────────────
    c22 = only(filter(r -> r.index == 22, rows))
    ctrl_ok = (c22.rank == 184 && c22.dim == 40)
    println()
    println("CONTROL class 22: rank=$(c22.rank) (audited 184), dim=$(c22.dim) (audited 40) => ",
            ctrl_ok ? "PASS" : "FAIL")
    ctrl_ok || error("phase1: M_A control failed — the construction disagrees with F002 " *
                     "and bench/calibration.toml; do not trust any dimension above.")

    # ── Ranking ────────────────────────────────────────────────────────────
    # Cost grows with dim: the number of NL=4 hyperplanes to enumerate scales
    # like 2^dim, and each Groebner slice costs ~31 s (calibration).
    open_classes = sort(filter(r -> r.verdict === :open, rows), by = r -> r.dim)
    alg1_classes = sort(filter(r -> r.verdict === :alg1, rows), by = r -> r.dim)

    io = IOBuffer()
    println(io, "# search/targets.yaml — PHASE 1 target ranking (n = 8).")
    println(io, "#")
    println(io, "# Generated by search/phase1_targets.jl. Do not edit by hand.")
    println(io, "#")
    println(io, "# V_A = ker(M_A) over the 224 quadratic ANF coefficients, M_A expanding")
    println(io, "# F.A = A.F. Verdicts are transcribed from BBL2021 Table 1's own n=8 column")
    println(io, "# (input/*.tex lines 716-786), NOT from the repo's stored search results —")
    println(io, "# the repo has zero stored n=8 results (see phase0_callsite_audit.md).")
    println(io, "#")
    println(io, "# IMPORTANT SCOPE NOTE. BBL2021 Table 1 decides the existence of APN")
    println(io, "# PERMUTATIONS F with F.A = B.F. This search targets quadratic APN")
    println(io, "# FUNCTIONS (not necessarily permutations) in the commutant F.A = A.F.")
    println(io, "# A class marked 'no (Alg. 1)' is therefore NOT excluded as a target: the")
    println(io, "# authors proved no APN permutation exists there, which says nothing about")
    println(io, "# non-bijective quadratic APN functions in V_A. Target selection does not")
    println(io, "# rest on any claim that their pruning was unsound.")
    println(io)
    println(io, "meta:")
    println(io, "  n: 8")
    println(io, "  anf_coefficients: 224")
    println(io, "  source_table: \"BBL2021 Table 1, n=8 column\"")
    println(io, "  control_class_22: {rank: $(c22.rank), dim: $(c22.dim), expected_rank: 184, expected_dim: 40, pass: true}")
    println(io, "  groebner_seconds_per_slice: $(cm.groebner_slice)")
    println(io, "  is_apn_seconds: $(cm.is_apn)")
    println(io, "  sigma_key_seconds: $(cm.sigma_key)")
    println(io)
    println(io, "# Tier 1 — the authors' own '?': not excluded by Prop 4/5 AND the exhaustive")
    println(io, "# search did not finish. Genuinely undecided by BBL2021's own statement.")
    println(io, "tier1_open:")
    for r in open_classes
        prior = r.index == 22 ?
            "Kuznetsov 2026 covered 428 of ~2^40 slices (F021); all 6 reported reps are sigma-matches" :
            "no prior examination found in this tree"
        println(io, "  - class: $(r.index)")
        println(io, "    verdict: \"?\"")
        println(io, "    rank_M_A: $(r.rank)")
        println(io, "    dim_V_A: $(r.dim)")
        println(io, "    prior_work: \"$prior\"")
    end
    println(io)
    println(io, "# Tier 2 — 'no (Alg. 1)': BBL2021 report a terminated exhaustive search for")
    println(io, "# APN PERMUTATIONS. Still valid targets for quadratic APN functions (see the")
    println(io, "# scope note above), but a weaker motivation than tier 1.")
    println(io, "tier2_alg1_permutation_negative:")
    for r in alg1_classes
        println(io, "  - {class: $(r.index), rank_M_A: $(r.rank), dim_V_A: $(r.dim)}")
    end
    println(io)
    println(io, "# Tier 3 — excluded by a proved filter (Prop 4 or Prop 5) for permutations.")
    println(io, "tier3_filter_excluded:")
    for r in sort(filter(x -> x.verdict in (:prop4, :prop5), rows), by = x -> x.dim)
        println(io, "  - {class: $(r.index), verdict: $(r.verdict), rank_M_A: $(r.rank), dim_V_A: $(r.dim)}")
    end
    write(joinpath(ROOT, "search", "targets.yaml"), String(take!(io)))
    println("\nwrote search/targets.yaml")

    println("\nTier 1 (authors' own '?'), smallest dim first:")
    for r in open_classes
        println("  class $(r.index): dim V_A = $(r.dim)")
    end
end

main()
