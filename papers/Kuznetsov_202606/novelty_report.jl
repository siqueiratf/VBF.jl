# novelty_report.jl — Phase-2 oracle report.
# 1. Representation sanity: BLP22 entries are APN & quadratic under VBF.
# 2. Validation vs pre-Kuznetsov known (BLP22 ∪ Gold): paper classes A–D should be
#    :new and E,F :known (= Gold) — a CCZ-invariant confirmation of the 2026 claim.
# 3. If the 2025 catalog (BLP25, 3.78M) is present: report whether the paper's
#    "new" classes were already among Beierle et al. 2025, and cache the full
#    known-APN σ-index used as the Phase-3 novelty oracle.
include(joinpath(@__DIR__, "novelty.jl"))

function novelty_report(io::IO = stdout)
    print_section("Phase 2 — CCZ novelty oracle", io)

    cat_blp = load_catalog(blp22=true, paper=false, reps=false, gold=false)
    if isempty(cat_blp)
        print_kv("catalog", "MISSING — run ./fetch_catalog.sh", io); return
    end
    sample = cat_blp[1:min(50, end)]
    print_check("BLP22 sample APN under VBF (representation matches)",
                all(F -> differential_uniformity(F) == 2, sample), io)
    print_check("BLP22 sample quadratic", all(F -> algebraic_degree(F) <= 2, sample), io)
    print_kv("BLP22 catalog size", string(length(cat_blp)), io)

    reps = representative_sboxes()
    classes = (:class_a, :class_b, :class_c, :class_d, :class_e, :class_f)

    # (2) pre-Kuznetsov = BLP22 ∪ Gold
    pre = sigma_index(load_catalog(blp22=true, gold=true, paper=false, reps=false))
    print_kv("pre-Kuznetsov σ-index (BLP22 ∪ Gold)", string(length(pre)), io)
    for nm in classes
        print_kv("paper $(uppercase(String(nm))) vs pre-Kuznetsov",
                 String(classify_against_catalog(getfield(reps, nm), pre)), io)
    end
    print_check("paper A–D :new vs pre-Kuznetsov (2026 claim confirmed)",
        all(classify_against_catalog(getfield(reps, nm), pre) == :new for nm in classes[1:4]), io)

    # (3) BLP25 (2025, 3.78M) — the headline check + full oracle cache
    if isfile(BLP25)
        print_kv("BLP25 catalog", "streaming $(BLP25) … (threads=$(Threads.nthreads()))", io)
        s = sigma_index(load_catalog(blp22=true, gold=true, paper=false, reps=false))
        add_sigmas_file!(s, BLP25)
        print_kv("known σ-index (BLP25 ∪ BLP22 ∪ Gold)", string(length(s)), io)
        for nm in classes[1:4]
            print_kv("paper $(uppercase(String(nm))) vs Beierle-et-al-2025",
                     String(classify_against_catalog(getfield(reps, nm), s)), io)
        end
        nnew = count(nm -> classify_against_catalog(getfield(reps, nm), s) == :new, classes[1:4])
        print_kv("paper classes A–D still novel vs 2025", "$nnew / 4", io)
        # full Phase-3 oracle index = known ∪ paper ∪ reps, cached
        add_sigmas!(s, load_catalog(blp22=false, gold=false, paper=true, reps=true))
        save_index(s, SIG_CACHE)
        print_kv("full Phase-3 σ-index", string(length(s)), io)
        print_kv("  cached to", relpath(SIG_CACHE, @__DIR__), io)
    else
        print_kv("BLP25", "not downloaded (run ./fetch_catalog.sh --full for the 2025 3.78M set)", io)
        s = sigma_index(load_catalog())
        save_index(s, SIG_CACHE)
        print_kv("full σ-index (BLP22 ∪ Gold ∪ paper)", string(length(s)), io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    novelty_report()
end
