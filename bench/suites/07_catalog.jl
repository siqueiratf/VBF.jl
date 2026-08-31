# bench/suites/07_catalog.jl — the VBFCatalog data layer.
#
# CONTRACT (bench/suites/01_representations.jl states it in full):
#   * The file defines exactly one function, `register!(reg)`.
#   * The function calls `bench!` once per case and measures nothing itself.
#   * `setup` is a zero-argument function that returns the payload. The harness
#     does not time it. Put every allocation that the case does not measure here.
#   * `call` takes that payload and does the work that the case measures.
#   * `cost` is 1 (under about 0.1 s), 2 (under about 5 s) or 3 (minutes).
#   * `note` is one short phrase for the reader of the thesis table.
#
# THIS SUITE IS READ-ONLY.
# It calls no builder and no writer. It never calls `create_catalog`,
# `build_sigma_index!`, `build_ccz_fingerprint_index!`, `build_corpus_store!`,
# `register_corpus!`, `populate_ccz_equivalence_classes!`, `merge_source_repo!`
# or `record_disagreement!`. A write to `packages/VBFCatalog/` breaks the CI
# count gate that AGENTS.md describes.
#
# Three points for the reader of the table:
#   * The literature loader and the declarative APN loader keep a module-level
#     cache. The warm-up call fills that cache. Each figure is therefore the
#     warm cost of a repeat query, not the cost of the first read.
#   * `corpus_coefficients` and `corpus_function` open the side store on every
#     call. That cost belongs to the API, and the suite cannot remove it.
#   * A corpus side store is a large regenerable file. It can be absent from a
#     checkout. Each corpus case therefore tests the side store file first, and
#     the suite registers the case only when the file is present.

function register!(reg)
    G = "catalog"

    # One handle serves every read case. The suite opens it on the first setup
    # call, so `--list` opens no file at all. `setup` runs outside the timer.
    dbref = Ref{Any}(nothing)
    open_db() = (dbref[] === nothing && (dbref[] = load_catalog()); dbref[])

    # The sigma index is a side store with no exported opener. bench/calibrate.jl
    # opens it in the same way. Only the payload uses this internal name; every
    # measured call uses an exported name.
    idxref = Ref{Any}(nothing)
    open_index() =
        (idxref[] === nothing && (idxref[] = VBFCatalog._open_sigma_index()); idxref[])

    # Corpora. Keep the large one for single-member reads only. An expansion of
    # all 3775599 members would take hours and fill the disk.
    big_corpus   = "beierle2025_n8"                # 3775599 members
    mid_corpus   = "beierleleanderperrin2022_n8"   # 6368 members
    small_corpus = "edelpott2009_n8"               # 22 members
    big_member   = 1_234_567                       # a fixed index, for a repeatable read

    # ── open cost and content addressing ────────────────────────────────────

    # This is the only case that opens a file inside `call`, because the open is
    # the operation under test. The call closes the handle again.
    bench!(reg; group = G, name = "load_catalog", n = 0, cost = 1,
           setup = () -> catalog_path(),
           call  = p -> (db = load_catalog(p); close(db)),
           note  = "open the committed catalog")

    bench!(reg; group = G, name = "canonical_lut_bytes", n = 12, cost = 1,
           setup = () -> gold_apn(12, 1),
           call  = F -> canonical_lut_bytes(F),
           note  = "canonical byte form")

    bench!(reg; group = G, name = "lut_sha256_hex", n = 8, cost = 1,
           setup = () -> gold_apn(8, 1),
           call  = F -> lut_sha256_hex(F),
           note  = "content key of an S-box")

    # ── queries against the functions table ─────────────────────────────────

    bench!(reg; group = G, name = "count_functions", n = 0, cost = 1,
           setup = () -> open_db(),
           call  = db -> count_functions(db),
           note  = "count every catalog row")

    bench!(reg; group = G, name = "list_functions", n = 0, cost = 1,
           setup = () -> open_db(),
           call  = db -> list_functions(db),
           note  = "read every catalog row")

    bench!(reg; group = G, name = "find_function_by_name", n = 8, cost = 1,
           setup = () -> open_db(),
           call  = db -> find_function(db; canonical_name = "n8_Gold_x3"),
           note  = "find one row by name")

    # The content-addressed path. The setup reads the hash once, so the timer
    # sees only the lookup.
    bench!(reg; group = G, name = "find_function_by_hash", n = 8, cost = 1,
           setup = () -> (db = open_db();
                          (db, find_function(db; canonical_name = "n8_Gold_x3").lut_sha256)),
           call  = p -> find_function(p[1]; lut_sha256 = p[2]),
           note  = "find one row by hash")

    bench!(reg; group = G, name = "load_sbox", n = 8, cost = 1,
           setup = () -> open_db(),
           call  = db -> load_sbox(db, "n8_Gold_x3"),
           note  = "materialise one catalog S-box")

    # ── declarative sources ─────────────────────────────────────────────────

    bench!(reg; group = G, name = "literature_sbox_names", n = 0, cost = 1,
           setup = () -> nothing,
           call  = _ -> literature_sbox_names(),
           note  = "list the literature names")

    bench!(reg; group = G, name = "load_literature_sbox", n = 8, cost = 1,
           setup = () -> "AES",
           call  = name -> load_literature_sbox(name),
           note  = "build the AES S-box")

    # The loader recomputes the differential uniformity on every call, so the
    # figure grows fast with n.
    bench!(reg; group = G, name = "load_apn_function", n = 8, cost = 1,
           setup = () -> "n8_Gold_x3",
           call  = name -> load_apn_function(name),
           note  = "build a catalog APN function")

    bench!(reg; group = G, name = "load_apn_function", n = 12, cost = 1,
           setup = () -> "n12_CalderiniLiVilla2023_F1",
           call  = name -> load_apn_function(name),
           note  = "build a catalog APN function")

    # ── bibliography ────────────────────────────────────────────────────────

    bench!(reg; group = G, name = "load_bibliography", n = 0, cost = 1,
           setup = () -> bibliography_path(),
           call  = p -> load_bibliography(p),
           note  = "read and parse the bibliography")

    bench!(reg; group = G, name = "parse_bibtex", n = 0, cost = 1,
           setup = () -> read(bibliography_path(), String),
           call  = text -> parse_bibtex(text),
           note  = "parse BibTeX text")

    # ── bulk corpora ────────────────────────────────────────────────────────

    bench!(reg; group = G, name = "list_corpora", n = 0, cost = 1,
           setup = () -> open_db(),
           call  = db -> list_corpora(db),
           note  = "list the bulk corpora")

    # The descriptor row lives in the committed catalog. The member count comes
    # from that row, so the call reads no member.
    if isfile(corpus_store_path(big_corpus))
        bench!(reg; group = G, name = "corpus_length", n = 8, cost = 1,
               setup = () -> (open_db(), big_corpus),
               call  = p -> corpus_length(p[1], p[2]),
               note  = "size of the largest corpus")

        bench!(reg; group = G, name = "corpus_coefficients", n = 8, cost = 1,
               setup = () -> (big_corpus, big_member),
               call  = p -> corpus_coefficients(p[1], p[2]),
               note  = "read one packed member")

        bench!(reg; group = G, name = "corpus_function", n = 8, cost = 1,
               setup = () -> (open_db(), big_corpus, big_member),
               call  = p -> corpus_function(p[1], p[2], p[3]),
               note  = "decode one corpus member")
    end

    # The expansion writes to a temporary file outside the repository. Both
    # corpora are small on purpose. Never expand `beierle2025_n8`.
    if isfile(corpus_store_path(small_corpus))
        bench!(reg; group = G, name = "materialize_corpus_luts", n = 8, cost = 1,
               setup = () -> (open_db(), small_corpus,
                              joinpath(tempdir(), "vbf_bench_" * small_corpus * ".sqlite")),
               call  = p -> materialize_corpus_luts(p[1], p[2]; path = p[3]),
               note  = "expand 22 member LUTs")
    end

    if isfile(corpus_store_path(mid_corpus))
        bench!(reg; group = G, name = "materialize_corpus_luts_bulk", n = 8, cost = 2,
               setup = () -> (open_db(), mid_corpus,
                              joinpath(tempdir(), "vbf_bench_" * mid_corpus * ".sqlite")),
               call  = p -> materialize_corpus_luts(p[1], p[2]; path = p[3]),
               reps  = 3,
               note  = "expand 6368 member LUTs")
    end

    # ── the sigma signature and the novelty oracle ──────────────────────────

    for n in (8, 10)
        bench!(reg; group = G, name = "sigma_hash", n = n, cost = 1,
               setup = () -> gold_apn(n, 1),
               call  = F -> sigma_hash(F),
               note  = "ortho-derivative signature")
    end

    # The index holds 230404 rows. The lookup itself costs microseconds, so the
    # figure is almost all signature cost.
    bench!(reg; group = G, name = "classify_ccz", n = 8, cost = 1,
           setup = () -> (gold_apn(8, 1), open_index()),
           call  = p -> classify_ccz(p[1]; index = p[2]),
           note  = "novelty query on the index")

    bench!(reg; group = G, name = "is_novel", n = 8, cost = 1,
           setup = () -> (gold_apn(8, 1), open_index()),
           call  = p -> is_novel(p[1]; index = p[2]),
           note  = "novelty verdict for one function")

    # ── the CCZ fingerprint for non-quadratic APN ───────────────────────────

    # Tier 2 (n >= 8) uses the two spectra only, so it stays cheap.
    bench!(reg; group = G, name = "ccz_fingerprint_hash", n = 8, cost = 1,
           setup = () -> gold_apn(8, 1),
           call  = F -> ccz_fingerprint_hash(F),
           note  = "tier 2 CCZ fingerprint")

    # Tier 1 (n <= 7) adds the gamma-rank and the delta-rank. Those two ranks
    # dominate the cost, and the cost grows very fast with n: n = 7 needs more
    # than 5 s, which is why it is a level-3 case.
    bench!(reg; group = G, name = "ccz_fingerprint_key", n = 6, cost = 1,
           setup = () -> gold_apn(6, 1),
           call  = F -> ccz_fingerprint_key(F),
           note  = "tier 1 fingerprint with ranks")

    bench!(reg; group = G, name = "ccz_fingerprint_key", n = 7, cost = 3,
           setup = () -> gold_apn(7, 1),
           call  = F -> ccz_fingerprint_key(F),
           reps  = 3,
           note  = "tier 1 fingerprint with ranks")

    # The fingerprint index is a regenerable side store. A build is a write, so
    # this suite must not create it. Register the case only when it is present.
    if isfile(ccz_fingerprint_index_path())
        bench!(reg; group = G, name = "classify_ccz_fingerprint", n = 8, cost = 1,
               setup = () -> (gold_apn(8, 1), VBFCatalog._open_ccz_fingerprint_index()),
               call  = p -> classify_ccz_fingerprint(p[1]; index = p[2]),
               note  = "fingerprint query on the index")
    end

    # ── reconciliation views ────────────────────────────────────────────────

    bench!(reg; group = G, name = "reconciliation_summary", n = 0, cost = 1,
           setup = () -> open_db(),
           call  = db -> reconciliation_summary(db),
           note  = "tally of the disagreements")

    bench!(reg; group = G, name = "functions_by_source", n = 0, cost = 1,
           setup = () -> open_db(),
           call  = db -> functions_by_source(db),
           note  = "rows per upstream source")

    bench!(reg; group = G, name = "cross_source_matches", n = 0, cost = 1,
           setup = () -> open_db(),
           call  = db -> cross_source_matches(db),
           note  = "rows that two sources share")

    return reg
end
