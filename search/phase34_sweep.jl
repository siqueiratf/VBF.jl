# search/phase34_sweep.jl — PHASES 3 + 4.
#
# WHAT THIS DOES INSTEAD OF SAMPLE-THEN-GROEBNER, AND WHY
# --------------------------------------------------------
# The brief's Phase 3 samples V_A for APN "centers" and Phase 4 then enumerates
# each center's hyperplane with a Groebner basis, tracking coverage as a
# fraction of the ~2^dim hyperplanes. For dim(V_A) <= ~40 that is strictly
# dominated by simply walking V_A itself:
#
#   * L_a is linear in the ANF coefficient vector, so a Gray-code walk tests one
#     point of V_A per XOR-plus-rank — measured 5.4M points/s single-threaded.
#     A Groebner slice costs ~31 s (bench/calibration.toml), i.e. ~1.7e8 times
#     more per unit of space covered.
#   * Walking V_A directly yields EVERY APN function in it, so coverage is 100%
#     of the subspace and the outcome is a certified `Exhausted` — versus the
#     ~1e-9 coverage the hyperplane route could reach in a day.
#   * No sampling means no density estimate is needed to interpret the result,
#     and no center/hyperplane bookkeeping can bias it.
#
# So Phase 3's "measure the APN density" becomes an exact count rather than an
# estimate, and Phase 4's "Exhausted vs BudgetHit per hyperplane" becomes the
# same distinction per subspace. Classes too large to walk (dim >= 48) return a
# BudgetHit with the exact fraction covered, and are reported as unexamined.
#
# Discovery unit: one file per (class, distinct sigma), written under
# search/centers/ as it is found and never rewritten. A dim-32 class yields
# ~10^6 individual APN points, so a file per point is not useful; a file per
# distinct sigma is, because distinct sigma is exactly what distinct CCZ-class
# means for quadratic APN.
#
# Usage: julia -t auto --project=. search/phase34_sweep.jl [max_dim] [budget_seconds]

include(joinpath(@__DIR__, "sweep.jl"))

using VBFCatalog: sigma_key, sigma_hash
using TOML
using Base.Threads

const ROOT = normpath(joinpath(@__DIR__, ".."))
const TUPLES8 = joinpath(ROOT, "papers", "2021", "Beierle_202107", "tuples",
                         "AllTuplesMatrices8.toml")
const CENTERS = joinpath(ROOT, "search", "centers")
const STATE = joinpath(ROOT, "search", "state")
const RUNLOG = joinpath(ROOT, "search", "run.log")

const TABLE1_N8 = Dict(
    1 => :alg1, 2 => :alg1, 3 => :prop5, 4 => :alg1, 5 => :alg1,
    6 => :alg1, 7 => :prop5, 8 => :alg1, 9 => :alg1, 10 => :alg1,
    11 => :prop5, 12 => :prop5, 13 => :prop4, 14 => :alg1, 15 => :alg1,
    16 => :alg1, 17 => :prop5, 18 => :prop4, 19 => :prop4, 20 => :prop4,
    21 => :prop4, 22 => :open, 23 => :alg1, 24 => :prop5, 25 => :prop4,
    26 => :prop4, 27 => :alg1, 28 => :prop4, 29 => :alg1, 30 => :open,
    31 => :alg1, 32 => :prop4,
)

function load_classes8()
    data = TOML.parsefile(TUPLES8)
    out = Dict{Int,NamedTuple{(:A, :B),Tuple{Matrix{Bool},Matrix{Bool}}}}()
    for b in data["blocks"]
        A = falses(8, 8)
        B = falses(8, 8)
        for (i, row) in enumerate(b["A"]), (j, v) in enumerate(row)
            A[i, j] = (Int(v) == 1)
        end
        for (i, row) in enumerate(b["B"]), (j, v) in enumerate(row)
            B[i, j] = (Int(v) == 1)
        end
        out[Int(b["index"])] = (A = Matrix{Bool}(A), B = Matrix{Bool}(B))
    end
    out
end

# :commutant  — V_A = {F : F.A = A.F}, as the brief specifies.
# :selfequiv  — V_{A,B} = {F : F.A = B.F}, the space BBL2021's classes actually
#               name. A != B for 16 of the 32 n=8 classes, so the two differ
#               there; where A == B they coincide.
basis_for(m::NamedTuple, mode::Symbol) =
    mode === :selfequiv ? kernel_basis(m.A, m.B) : kernel_basis(m.A)

"""
    sigmas_of(basis, bs, d) -> (counts, representatives)

Signature multiset over every hit, computed in parallel. Accumulates into
per-thread dictionaries and merges, rather than materialising one hash string
per hit: class 22 holds on the order of 10^8 APN points, and a
`Vector{String}` of 64-char hex digests for those would be several GB, while the
number of DISTINCT signatures is tiny.

Indexed by the `@threads` loop variable, not `threadid()` — task migration makes
threadid-indexed state unsafe.
"""
function sigmas_of(basis, bs::Vector{UInt64}, d::Int)
    n = length(bs)
    nt = max(1, nthreads())
    part = [((t - 1) * n ÷ nt + 1):(t * n ÷ nt) for t = 1:nt]
    counts = [Dict{String,Int}() for _ = 1:nt]
    reps = [Dict{String,UInt64}() for _ = 1:nt]
    @threads for t = 1:nt
        c, r = counts[t], reps[t]
        for i in part[t]
            h = sigma_hash(SBox{8}(lut_of(basis, bs[i], d)))
            c[h] = get(c, h, 0) + 1
            haskey(r, h) || (r[h] = bs[i])
        end
    end
    C = Dict{String,Int}()
    R = Dict{String,UInt64}()
    for t = 1:nt
        for (h, k) in counts[t]
            C[h] = get(C, h, 0) + k
        end
        for (h, b) in reps[t]
            haskey(R, h) || (R[h] = b)
        end
    end
    (C, R)
end

"""
    sigma_pass(basis, bs, d; state_path, log_io, chunk) -> (counts, reps)

The signature pass, checkpointed. At ~2 ms per signature, class 22's projected
~9e7 hits are hours of work; without checkpointing a crash at hour seven would
discard all of it while the sweep result sat complete on disk. Progress is saved
every chunk, so a restart resumes at the next unprocessed hit.
"""
function sigma_pass(basis, bs::Vector{UInt64}, d::Int; state_path::String,
                    log_io = nothing, chunk::Int = 200_000)
    counts = Dict{String,Int}()
    reps = Dict{String,UInt64}()
    next_i = 1
    if isfile(state_path)
        st = TOML.parsefile(state_path)
        if get(st, "d", -1) == d && get(st, "n_hits", -1) == length(bs)
            next_i = get(st, "next_index", 1)
            for e in get(st, "sigma", [])
                counts[e["hash"]] = e["count"]
                reps[e["hash"]] = UInt64(e["rep"])
            end
            _log(log_io, "sigma_pass resume: $(next_i-1)/$(length(bs)) done, $(length(counts)) sigma so far")
        end
    end
    n = length(bs)
    t0 = time()
    while next_i <= n
        hi = min(next_i + chunk - 1, n)
        C, R = sigmas_of(basis, bs[next_i:hi], d)
        for (h, k) in C
            counts[h] = get(counts, h, 0) + k
        end
        for (h, b) in R
            haskey(reps, h) || (reps[h] = b)
        end
        next_i = hi + 1
        tmp = state_path * ".tmp"
        open(tmp, "w") do io
            println(io, "d = ", d)
            println(io, "n_hits = ", n)
            println(io, "next_index = ", next_i)
            for (h, k) in counts
                println(io, "[[sigma]]")
                println(io, "hash = ", repr(h))
                println(io, "count = ", k)
                println(io, "rep = ", Int(reps[h]))
            end
        end
        mv(tmp, state_path; force = true)
        el = time() - t0
        frac = (next_i - 1) / n
        _log(log_io, @sprintf("sigma_pass: %d/%d (%.2f%%), %d distinct, elapsed %.0fs, eta %.0fs",
                              next_i - 1, n, 100frac, length(counts), el,
                              frac > 0 ? el * (1 - frac) / frac : NaN))
    end
    (counts, reps)
end

function run_class(idx::Int, m::NamedTuple; mode::Symbol, budget_seconds, log_io)
    kb = basis_for(m, mode)
    d = kb.dim
    verdict = TABLE1_N8[idx]
    tag = mode === :selfequiv ? "selfequiv" : "commutant"
    region = SearchRegion(:subspace, "n8/$(tag)/class$(idx)";
                          size = BigInt(2)^d,
                          params = Dict{String,Any}("class" => idx, "dim" => d, "mode" => tag,
                                                    "bbl2021_verdict" => string(verdict)))
    _log(log_io, "--- class $idx [$tag] (BBL2021: $verdict), dim = $d, size = 2^$d ---")

    # dim 0 means the only homogeneous quadratic solution is F = 0: the subspace
    # is a single point and holds no APN function. Nothing to walk.
    if d == 0
        _log(log_io, "class $idx [$tag]: dim 0 — V is {0}, contains no APN function (trivially exhausted)")
        return (; idx, verdict, dim = 0, mode = tag,
                outcome = Exhausted(region, UInt64[]; nodes_visited = 1, elapsed_seconds = 0.0),
                covered = BigInt(1), total = BigInt(1), frac = 1.0,
                n_apn = 0, sigmas = Dict{String,Int}(), basis = kb.basis)
    end

    ckpt = joinpath(STATE, "$(tag)_class$(idx).ckpt.toml")
    # Both walks produce identical results (verified); the threaded one just
    # spreads independent blocks over the thread pool.
    sweeper = nthreads() > 1 ? sweep_subspace_threaded : sweep_subspace
    # max_hits must exceed the true APN count or the sweep aborts as a BudgetHit
    # and the exhaustive result is lost. Class 22 measured ~8.2e-5 density over
    # 2^40, i.e. on the order of 9e7 points, so the default 2e7 is far too low.
    # A coordinate is 8 bytes, so 3e8 of them is ~2.4 GB — within budget here.
    outcome = sweeper(kb.basis, region;
                      nprobe = 8, lo_bits = min(20, d),
                      max_hits = 300_000_000,
                      budget_seconds = budget_seconds,
                      checkpoint_path = ckpt,
                      progress_every = 1800.0, log_io = log_io)

    bs = search_solutions(outcome)
    total = BigInt(2)^d
    # An Exhausted outcome covered the subspace by definition; for anything else
    # the fraction is what the walk actually got through.
    covered = is_exhausted(outcome) ? total : BigInt(nodes_visited(outcome))
    frac = Float64(covered) / Float64(total)
    _log(log_io, "class $idx: $(coverage_note(outcome))")
    _log(log_io, "class $idx: coverage $(covered)/$(total) = $(frac)")
    _log(log_io, "class $idx: APN points found = $(length(bs))")

    sig_counts = Dict{String,Int}()
    sig_rep = Dict{String,UInt64}()
    if !isempty(bs)
        sig_counts, sig_rep = sigma_pass(kb.basis, bs, d;
            state_path = joinpath(STATE, "$(tag)_class$(idx).sigma.toml"),
            log_io = log_io)
    end
    _log(log_io, "class $idx: distinct sigma = $(length(sig_counts))")

    # one append-only file per (class, sigma)
    mkpath(CENTERS)
    for (h, cnt) in sig_counts
        path = joinpath(CENTERS, "$(tag)_class$(idx)_sigma_$(h[1:16]).toml")
        isfile(path) && continue        # never rewritten in place
        b = sig_rep[h]
        lut = lut_of(kb.basis, b, d)
        F = SBox{8}(lut)
        open(path, "w") do io
            println(io, "class = ", idx)
            println(io, "mode = ", repr(tag))
            println(io, "bbl2021_verdict = ", repr(string(verdict)))
            println(io, "dim_V = ", d)
            println(io, "sigma_hash = ", repr(h))
            println(io, "multiplicity_in_V_A = ", cnt)
            println(io, "subspace_coordinate = ", Int(b))
            println(io, "differential_uniformity = ", differential_uniformity(F))
            println(io, "algebraic_degree = ", algebraic_degree(F))
            println(io, "is_permutation = ", is_permutation(F))
            println(io, "lut = ", lut)
            println(io, "anf_coefficients = ", Int.(coeffs_of(kb.basis, b, d)))
            println(io, "region = ", repr(region.id))
            println(io, "outcome = ", repr(string(outcome_tag(outcome))))
            println(io, "coverage_fraction = ", frac)
        end
    end

    (; idx, verdict, dim = d, mode = tag, outcome, covered, total, frac,
       n_apn = length(bs), sigmas = sig_counts, basis = kb.basis)
end

function main()
    max_dim = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 32
    mode = length(ARGS) >= 2 ? Symbol(ARGS[2]) : :commutant
    mode in (:commutant, :selfequiv) || error("mode must be commutant or selfequiv")
    budget = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : nothing
    mkpath(CENTERS); mkpath(STATE)
    log_io = open(RUNLOG, "a")
    _log(log_io, "=== PHASE 3+4 sweep: mode=$mode max_dim=$max_dim budget=$(budget) threads=$(nthreads()) ===")

    classes = load_classes8()
    dims = Dict(i => basis_for(classes[i], mode).dim for i = 1:32)
    targets = sort([i for i = 1:32 if dims[i] <= max_dim], by = i -> (dims[i], i))
    _log(log_io, "targets (dim <= $max_dim): $targets")
    _log(log_io, "dims: " * join(["$i=>$(dims[i])" for i in targets], " "))

    results = []
    t0 = time()
    for i in targets
        push!(results, run_class(i, classes[i]; mode = mode, budget_seconds = budget, log_io = log_io))
        el = time() - t0
        done = length(results)
        _log(log_io, "PROGRESS: $done/$(length(targets)) classes, elapsed $(round(el, digits=0))s, " *
                     "exhausted=$(count(r -> is_exhausted(r.outcome), results)), " *
                     "budget_hit=$(count(r -> is_budget_hit(r.outcome), results)), " *
                     "total APN points=$(sum(r.n_apn for r in results)), " *
                     "distinct sigma so far=$(length(union([Set(keys(r.sigmas)) for r in results]...)))")
    end

    # ── summary ─────────────────────────────────────────────────────────────
    open(joinpath(ROOT, "search", "phase34_summary_$(mode).toml"), "w") do io
        println(io, "# PHASE 3+4 summary — generated by search/phase34_sweep.jl")
        println(io, "mode = ", repr(string(mode)))
        println(io, "threads = ", nthreads())
        println(io, "max_dim = ", max_dim)
        println(io, "classes_run = ", length(results))
        println(io, "classes_exhausted = ", count(r -> is_exhausted(r.outcome), results))
        println(io, "classes_budget_hit = ", count(r -> is_budget_hit(r.outcome), results))
        for r in results
            println(io)
            println(io, "[[class]]")
            println(io, "index = ", r.idx)
            println(io, "mode = ", repr(r.mode))
            println(io, "bbl2021_verdict = ", repr(string(r.verdict)))
            println(io, "dim_V = ", r.dim)
            println(io, "outcome = ", repr(string(outcome_tag(r.outcome))))
            println(io, "exhausted = ", is_exhausted(r.outcome))
            println(io, "proves_subspace_empty = ", proves_emptiness(r.outcome))
            println(io, "points_tested = ", Int(r.covered))
            println(io, "subspace_size = ", string(r.total))
            println(io, "coverage_fraction = ", r.frac)
            println(io, "apn_points = ", r.n_apn)
            println(io, "distinct_sigma = ", length(r.sigmas))
            println(io, "sigma_hashes = [", join(map(repr, sort(collect(keys(r.sigmas)))), ", "), "]")
            println(io, "coverage_note = ", repr(coverage_note(r.outcome)))
        end
    end
    _log(log_io, "=== PHASE 3+4 done ($mode): wrote search/phase34_summary_$(mode).toml ===")
    close(log_io)
end

main()
