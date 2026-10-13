# search/phase2_control.jl — PHASE 2 positive control. MANDATORY before any
# novelty claim.
#
# The control subspace is the commutant of the Frobenius map (squaring on
# GF(2^8)) — i.e. V_A for A = Frob. It is known to contain APN functions:
# x^{2^k+1}(x^2) = (x^{2^k+1})^2, so every Gold function commutes with squaring,
# and Gold is APN over GF(2^8) exactly when gcd(k,8) = 1, i.e. k in {1,3,5,7}.
# Over GF(2^8) those fall into two CCZ-classes, x^3 and x^9 (x^{2^k+1} is
# equivalent to x^{2^{8-k}+1}), which is precisely the pair the brief asks the
# pipeline to recover.
#
# dim V_Frob = 28, so the whole subspace is swept exhaustively — the control is
# not a sample.
#
# What must hold for the pipeline to be trusted:
#   1. The sweep terminates as Exhausted (the whole subspace was walked).
#   2. Gold x^3's and x^9's homogeneous quadratic parts are IN V_A.
#   3. The sweep finds APN functions, and among their ortho-derivative
#      signatures both sigma(x^3) and sigma(x^9) appear.
#   4. Every APN reported by the fast test is confirmed APN by
#      VBF.differential_uniformity (enforced inside sweep_subspace).
#
# Writes: search/control/phase2_result.toml

include(joinpath(@__DIR__, "sweep.jl"))

using VBFCatalog: sigma_key, sigma_hash
using TOML

const ROOT = normpath(joinpath(@__DIR__, ".."))
const OUTDIR = joinpath(ROOT, "search", "control")

function frobenius_matrix()
    mod8 = primitive_polynomial(8)
    A = falses(8, 8)
    for j = 0:7
        img = gf_pow(1 << j, 2, 8; modulus = mod8)
        for k = 0:7
            ((img >> k) & 1) == 1 && (A[k+1, j+1] = true)
        end
    end
    Matrix{Bool}(A)
end

gold_lut(k::Int) = [gf_pow(x, (1 << k) + 1, 8; modulus = primitive_polynomial(8)) for x = 0:255]

function main()
    mkpath(OUTDIR)
    logpath = joinpath(ROOT, "search", "run.log")
    log_io = open(logpath, "a")
    _log(log_io, "=== PHASE 2 positive control: Frobenius commutant ===")

    A = frobenius_matrix()
    M = build_M_A(A)
    kb = kernel_basis(A)
    _log(log_io, "V_Frob: rank(M_A)=$(kb.rank) dim=$(kb.dim) |V_A|=2^$(kb.dim)")

    # ── check 2: the Gold representatives really are in this subspace ────────
    gold_in = Dict{Int,Bool}()
    gold_sigma = Dict{Int,String}()
    gold_sigma_full = Dict{Int,Any}()
    for k in (1, 3)
        lut = gold_lut(k)
        c = lut_to_coeffs(lut)
        gold_in[k] = in_kernel(M, c)
        F = SBox{8}(lut)
        gold_sigma[k] = sigma_hash(F)
        gold_sigma_full[k] = sigma_key(F)
        _log(log_io, "Gold x^$((1<<k)+1): in V_A = $(gold_in[k]), du = $(differential_uniformity(F)), sigma = $(gold_sigma[k][1:16])…")
    end
    all(values(gold_in)) || error("phase2: a Gold representative is NOT in the control subspace — the M_A construction is wrong")

    # ── check 1 + 3: sweep the whole subspace ────────────────────────────────
    region = SearchRegion(:subspace, "control/frobenius_commutant";
                          size = BigInt(2)^kb.dim,
                          params = Dict{String,Any}("A" => "frobenius", "dim" => kb.dim))
    ckpt = joinpath(OUTDIR, "phase2.ckpt.toml")
    t0 = time()
    outcome = sweep_subspace(kb.basis, region;
                             nprobe = 8, lo_bits = 20, max_hits = 400_000,
                             checkpoint_path = ckpt, progress_every = 1800.0,
                             log_io = log_io)
    _log(log_io, "sweep: $(coverage_note(outcome))")
    _log(log_io, "sweep: tested $(nodes_visited(outcome)) points in $(round(elapsed_seconds(outcome), digits=1)) s")

    sols = search_solutions(outcome)      # subspace coordinates, not LUTs
    _log(log_io, "APN functions found: $(length(sols))")

    # ── signatures ──────────────────────────────────────────────────────────
    # Dedup by sigma. sigma is an EA-invariant and CCZ = EA for quadratic APN,
    # so distinct sigma ⇒ distinct CCZ-class (the converse does NOT hold).
    sig_counts = Dict{String,Int}()
    sig_rep = Dict{String,Vector{Int}}()
    for b in sols
        lut = lut_of(kb.basis, b, kb.dim)
        h = sigma_hash(SBox{8}(lut))
        sig_counts[h] = get(sig_counts, h, 0) + 1
        haskey(sig_rep, h) || (sig_rep[h] = lut)
    end
    _log(log_io, "distinct sigma among the hits: $(length(sig_counts))")

    found_x3 = haskey(sig_counts, gold_sigma[1])
    found_x9 = haskey(sig_counts, gold_sigma[3])
    _log(log_io, "recovered sigma(Gold x^3): $found_x3  (multiplicity $(get(sig_counts, gold_sigma[1], 0)))")
    _log(log_io, "recovered sigma(Gold x^9): $found_x9  (multiplicity $(get(sig_counts, gold_sigma[3], 0)))")
    _log(log_io, "sigma(x^3) != sigma(x^9): $(gold_sigma[1] != gold_sigma[3])")

    density = length(sols) / 2.0^kb.dim
    _log(log_io, "measured APN density in V_Frob: $density")

    passed = is_exhausted(outcome) && found_x3 && found_x9 &&
             gold_sigma[1] != gold_sigma[3] && all(values(gold_in))

    open(joinpath(OUTDIR, "phase2_result.toml"), "w") do io
        println(io, "# PHASE 2 positive control — generated by search/phase2_control.jl")
        println(io, "passed = ", passed)
        println(io, "subspace = \"Frobenius commutant (A = squaring on GF(2^8))\"")
        println(io, "rank_M_A = ", kb.rank)
        println(io, "dim_V_A = ", kb.dim)
        println(io, "points_tested = ", nodes_visited(outcome))
        println(io, "outcome = ", repr(string(outcome_tag(outcome))))
        println(io, "coverage_note = ", repr(coverage_note(outcome)))
        println(io, "exhausted = ", is_exhausted(outcome))
        println(io, "apn_found = ", length(sols))
        println(io, "distinct_sigma = ", length(sig_counts))
        println(io, "apn_density = ", density)
        println(io, "elapsed_seconds = ", elapsed_seconds(outcome))
        println(io, "gold_x3_in_subspace = ", gold_in[1])
        println(io, "gold_x9_in_subspace = ", gold_in[3])
        println(io, "gold_x3_sigma = ", repr(gold_sigma[1]))
        println(io, "gold_x9_sigma = ", repr(gold_sigma[3]))
        println(io, "recovered_gold_x3 = ", found_x3)
        println(io, "recovered_gold_x9 = ", found_x9)
        println(io, "gold_sigmas_differ = ", gold_sigma[1] != gold_sigma[3])
    end

    # Persist the distinct signatures for later phases.
    open(joinpath(OUTDIR, "phase2_sigmas.toml"), "w") do io
        println(io, "# distinct sigma hashes found in the control subspace")
        for (h, n) in sort(collect(sig_counts), by = x -> -x[2])
            println(io, "[[sigma]]")
            println(io, "hash = ", repr(h))
            println(io, "multiplicity = ", n)
            println(io, "representative_lut = ", sig_rep[h])
        end
    end

    _log(log_io, "PHASE 2 CONTROL: " * (passed ? "PASS" : "FAIL"))
    close(log_io)
    passed || error("phase2: positive control FAILED — pipeline is not trustworthy, stopping")
    return 0
end

main()
