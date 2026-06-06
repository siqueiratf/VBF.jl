include(joinpath(@__DIR__, "helpers.jl"))
using VBF
using VBFCatalog

const CORPUS_NAME = "yuperrin2022_qam_n8"
const EXPECTED_COUNT = 5412

# ── Load the Yu–Perrin 2022 QAM corpus from VBFCatalog and return basic info.
# Returns nothing if the corpus is unavailable.
function load_corpus_info()
    db = load_catalog()
    try
        info = corpus_info(db, CORPUS_NAME)
        info === nothing && return nothing
        n = corpus_length(db, CORPUS_NAME)
        (; name = CORPUS_NAME, count = n)
    finally
        close(db)
    end
end

# ── Sample `sample_size` functions from the corpus (deterministically, using
# `seed`) and validate that each is quadratic (degree 2) and APN (DU = 2) and
# that its derivative matrix is a QAM. Returns a named tuple with counts.
function validate_corpus_sample(;
    sample_size::Int = 50,
    seed::Int = 42,
)
    db = load_catalog()
    try
        n_total = corpus_length(db, CORPUS_NAME)
        n_total == 0 && return nothing

        # Deterministic, evenly-spaced sample indices across the corpus
        rng = let
            # Use a simple linear spacing seeded by seed
            step = max(1, n_total ÷ sample_size)
            start = mod(seed, step) + 1
            [min(n_total, start + (i - 1) * step) for i in 1:sample_size]
        end
        indices = unique(clamp.(rng, 1, n_total))
        actual_sample = length(indices)

        n_apn = 0
        n_deg2 = 0
        n_qam = 0
        for idx in indices
            F = corpus_function(db, CORPUS_NAME, idx)
            differential_uniformity(F) == 2 && (n_apn += 1)
            algebraic_degree(F) == 2 && (n_deg2 += 1)
            is_qam(quadratic_apn_matrix(F)) && (n_qam += 1)
        end

        (sample_size = actual_sample,
         all_apn = n_apn == actual_sample,
         all_deg2 = n_deg2 == actual_sample,
         all_qam = n_qam == actual_sample,
         n_apn, n_deg2, n_qam)
    finally
        close(db)
    end
end

function catalog_validation_report(;
    sample_size::Int = 50,
    seed::Int = 42,
    io::IO = stdout,
)
    print_section("Catalog Validation: $(CORPUS_NAME)", io)
    println(io, "  Source: VBFCatalog corpus \"$(CORPUS_NAME)\" (known, not freshly generated)")

    info = load_corpus_info()
    if info === nothing
        println(io, "  [SKIP] corpus unavailable")
        return (skipped = true, reason = "corpus unavailable")
    end

    count_ok = info.count == EXPECTED_COUNT
    print_kv("corpus member count", info.count, io)
    print_check("count == $(EXPECTED_COUNT) (paper expectation)", count_ok, io)

    v = validate_corpus_sample(; sample_size, seed)
    if v === nothing
        println(io, "  [SKIP] corpus empty, skipping sample validation")
        return (skipped = true, reason = "corpus empty", count = info.count, count_ok = count_ok)
    end

    println(io, "  Sample: $(v.sample_size) functions, seed=$(seed), evenly spaced")
    print_check("all sampled functions have differential uniformity 2 (APN)",
                v.all_apn, io)
    print_check("all sampled functions have algebraic degree 2 (quadratic)",
                v.all_deg2, io)
    print_check("all sampled functions have a valid QAM derivative matrix",
                v.all_qam, io)

    (
        skipped = false,
        corpus = CORPUS_NAME,
        count = info.count,
        count_ok = count_ok,
        sample_size = v.sample_size,
        seed = seed,
        all_apn = v.all_apn,
        all_deg2 = v.all_deg2,
        all_qam = v.all_qam,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    catalog_validation_report()
end
