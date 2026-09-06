# bench/calibration.toml generator — times VBF/VBFCatalog primitives on THIS machine.
# Read-only against packages/ and papers/ (it only *includes* paper helpers).
using VBF, VBFCatalog
const SQLite = VBFCatalog.SQLite
const DBInterface = VBFCatalog.DBInterface
using Printf, Dates

const ROOT = "/home/tiago/VBF.jl"

function timeit(f, reps::Int)
    f()                       # warm-up / JIT
    ts = Float64[]
    for _ in 1:reps
        push!(ts, @elapsed f())
    end
    sort!(ts)
    (min = ts[1], median = ts[(length(ts)+1)÷2], n = reps)
end

results = Dict{String,Any}()

# ── 1. is_apn at n = 8, 9, 10 ────────────────────────────────────────────────
# is_apn(F) == (differential_uniformity(F) == 2); use a genuine APN input so the
# scan never short-circuits early on a large DDT entry.
for n in (8, 9, 10)
    F = gold_apn(n, 1)
    @assert differential_uniformity(F) == 2
    r = timeit(() -> differential_uniformity(F) == 2, n <= 8 ? 20 : (n == 9 ? 10 : 5))
    results["is_apn_n$(n)"] = r
    @printf("is_apn n=%d  min=%.6f  median=%.6f\n", n, r.min, r.median)
end

# ── 2. ortho_derivative and the full signature sigma(F) ──────────────────────
# sigma(F) = (diff-spectrum(pi_F), abs-Walsh-spectrum(pi_F))  == VBFCatalog.sigma_key
for n in (8, 9, 10)
    F = gold_apn(n, 1)
    r_od = timeit(() -> ortho_derivative(F), n <= 8 ? 20 : (n == 9 ? 10 : 4))
    results["ortho_derivative_n$(n)"] = r_od
    r_sig = timeit(() -> VBFCatalog.sigma_key(F), n <= 8 ? 20 : (n == 9 ? 8 : 3))
    results["sigma_key_n$(n)"] = r_sig
    r_hash = timeit(() -> VBFCatalog.sigma_hash(F), n <= 8 ? 20 : (n == 9 ? 8 : 3))
    results["sigma_hash_n$(n)"] = r_hash
    @printf("n=%d  od=%.6f  sigma_key=%.6f  sigma_hash=%.6f\n",
            n, r_od.min, r_sig.min, r_hash.min)
end

# ── 3. one signature lookup against the known-set index ─────────────────────
idx = VBFCatalog._open_sigma_index()
nrows = first(DBInterface.execute(idx, "SELECT count(*) AS c FROM ccz_sigma_index")).c
ndist = first(DBInterface.execute(idx, "SELECT count(DISTINCT sigma_hash) AS c FROM ccz_sigma_index")).c
results["sigma_index_rows"] = nrows
results["sigma_index_distinct"] = ndist
F8 = gold_apn(8, 1)
h8 = VBFCatalog.sigma_hash(F8)
lookup() = collect(DBInterface.execute(idx,
    "SELECT source, member_idx FROM ccz_sigma_index WHERE sigma_hash = ? LIMIT 1", (h8,)))
r_lk = timeit(lookup, 200)
results["sigma_index_lookup"] = r_lk
r_cls = timeit(() -> classify_ccz(F8; index = idx), 20)
results["classify_ccz_n8"] = r_cls
@printf("index rows=%d distinct=%d  lookup=%.8f  classify_ccz=%.6f\n",
        nrows, ndist, r_lk.min, r_cls.min)

# ── 4. one ker(M_A) self-equivalence subspace solve ─────────────────────────
# The BBL2021 V_A subspace: build M_A (224x224 over F2) from A and RREF it.
include(joinpath(ROOT, "papers", "2026", "Kuznetsov_202606", "helpers.jl"))
A = build_A_matrix()
r_ma = timeit(() -> fc22_sol22(A), 10)
sol = fc22_sol22(A)
results["ker_MA_solve_n8"] = r_ma
results["ker_MA_dim"] = length(sol.free_cols)
results["ker_MA_rank"] = length(sol.pivot_cols)
@printf("ker(M_A) solve=%.6f  rank=%d dim=%d\n",
        r_ma.min, length(sol.pivot_cols), length(sol.free_cols))

# ── 5. one Groebner solve on our smallest reference APN system ─────────────
# papers/2026/Kuznetsov_202606/phase2.jl: 24 free vars over GF(2), msolve backend.
# SINGLE = the 1-solution NL=4 slice embedded as ground truth in test/test_phase2.jl.
include(joinpath(ROOT, "papers", "2026", "Kuznetsov_202606", "phase2.jl"))
SINGLE = UInt8[0,0,0,128,0,80,240,32,0,144,160,176,16,208,64,0,0,168,210,250,111,151,77,53,212,236,166,30,171,195,41,193,
  0,114,191,77,84,118,27,185,193,35,222,188,133,55,106,88,128,90,237,183,187,49,38,44,149,223,88,146,190,164,131,25,
  0,175,228,203,145,110,133,250,168,151,236,83,41,70,157,114,80,87,102,225,174,249,104,191,44,187,186,173,194,5,164,227,
  240,45,171,246,53,184,158,147,153,212,98,175,76,81,71,218,32,85,169,92,138,175,243,86,157,120,180,209,39,146,254,203,
  0,228,177,213,56,140,121,77,210,166,195,55,250,222,27,191,144,220,243,63,199,219,84,200,150,74,85,9,209,93,226,238,
  160,54,174,184,204,10,50,116,179,181,29,155,207,153,145,71,176,142,108,210,179,221,159,113,119,217,11,37,100,154,232,150,
  16,91,69,142,185,162,28,135,106,177,159,196,211,88,214,221,208,51,87,52,22,165,97,82,126,13,89,170,168,139,127,220,
  64,121,170,19,189,212,167,78,251,82,177,152,22,239,172,213,0,145,56,41,146,83,90,27,111,110,247,118,237,188,133,84]
out = phase2_slice(SINGLE)
@assert length(out) == 1 && out[1].lut == SINGLE
r_gb = timeit(() -> phase2_slice(SINGLE), 3)
results["groebner_slice_n8_single"] = r_gb
results["groebner_slice_solutions"] = length(out)
@printf("groebner slice (24 vars, GF(2), msolve) = %.4f s, %d solution(s)\n",
        r_gb.min, length(out))

# ── emit TOML ───────────────────────────────────────────────────────────────
open(joinpath(ROOT, "bench", "calibration.toml"), "w") do io
    println(io, "# bench/calibration.toml — measured on THIS machine. Do not edit by hand.")
    println(io, "# Regenerate: julia --project=. bench/calibrate.jl")
    println(io, "")
    println(io, "[meta]")
    println(io, "generated_utc  = \"", Dates.format(Dates.now(Dates.UTC), "yyyy-mm-ddTHH:MM:SSZ"), "\"")
    println(io, "julia_version  = \"", string(VERSION), "\"")
    println(io, "cpu            = \"", Sys.cpu_info()[1].model, "\"")
    println(io, "cpu_threads    = ", Sys.CPU_THREADS)
    println(io, "julia_threads  = ", Threads.nthreads())
    println(io, "total_memory_gb = ", round(Sys.total_memory() / 2^30, digits = 1))
    println(io, "unit           = \"seconds, single-threaded unless stated\"")
    println(io, "statistic      = \"min of N repetitions after one warm-up call\"")
    println(io, "")
    for k in sort(collect(keys(results)))
        v = results[k]
        if v isa NamedTuple
            println(io, "[", k, "]")
            @printf(io, "min_seconds    = %.9g\n", v.min)
            @printf(io, "median_seconds = %.9g\n", v.median)
            println(io, "reps           = ", v.n)
            println(io, "")
        else
            println(io, "[", k, "]")
            println(io, "value          = ", v)
            println(io, "")
        end
    end
end
println("WROTE bench/calibration.toml")
