# packages/VBFCatalog/perf/suites/07_catalog.jl — the VBFCatalog data layer.
#
# CONTRACT (packages/VBF/perf/suites/01_representations.jl states it in full):
#   * The file defines exactly one function, `register!(reg)`.
#   * The function calls `benchmark!` once per case and measures nothing itself.
#   * `setup` is a zero-argument function that returns the payload. BenchmarkTools
#     does not time it. Put every allocation that the case does not measure here.
#   * `call` takes that payload and does the work that the case measures.
#   * `cost` is 1 (under about 0.1 s), 2 (under about 5 s) or 3 (minutes).
#   * `note` is one short phrase for the reader of the thesis table.
#
# THIS SUITE IS READ-ONLY.
# It calls no builder and no writer. It never calls `create_catalog`,
# `build_sigma_index!`, `build_corpus_store!`,
# `register_corpus!` or `populate_ccz_equivalence_classes!`. A write to `packages/VBFCatalog/` breaks the CI
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

    # The sigma index is a side store with no exported opener. Only the
    # setup uses this internal name; every
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
    benchmark!(reg; group = G, name = "load_catalog", n = 0, cost = 1,
           setup = () -> catalog_path(),
           call  = p -> (db = load_catalog(p); close(db)),
           note  = "open the committed catalog")

    benchmark!(reg; group = G, name = "canonical_lut_bytes", n = 12, cost = 1,
           setup = () -> gold_apn(12, 1),
           call  = F -> canonical_lut_bytes(F),
           note  = "canonical byte form")

    benchmark!(reg; group = G, name = "lut_sha256_hex", n = 8, cost = 1,
           setup = () -> gold_apn(8, 1),
           call  = F -> lut_sha256_hex(F),
           note  = "content key of an S-box")

    # ── queries against the functions table ─────────────────────────────────

    benchmark!(reg; group = G, name = "count_functions", n = 0, cost = 1,
           setup = () -> open_db(),
           call  = db -> count_functions(db),
           note  = "count every catalog row")

    benchmark!(reg; group = G, name = "list_functions", n = 0, cost = 1,
           setup = () -> open_db(),
           call  = db -> list_functions(db),
           note  = "read every catalog row")

    benchmark!(reg; group = G, name = "find_function_by_name", n = 8, cost = 1,
           setup = () -> open_db(),
           call  = db -> find_function(db; canonical_name = "n8_Gold_x3"),
           note  = "find one row by name")

    # The content-addressed path. The setup reads the hash once, so the timer
    # sees only the lookup.
    benchmark!(reg; group = G, name = "find_function_by_hash", n = 8, cost = 1,
           setup = () -> (db = open_db();
                          (db, find_function(db; canonical_name = "n8_Gold_x3").lut_sha256)),
           call  = p -> find_function(p[1]; lut_sha256 = p[2]),
           note  = "find one row by hash")

    benchmark!(reg; group = G, name = "load_sbox", n = 8, cost = 1,
           setup = () -> open_db(),
           call  = db -> load_sbox(db, "n8_Gold_x3"),
           note  = "materialise one catalog S-box")

    # ── declarative sources ─────────────────────────────────────────────────

    benchmark!(reg; group = G, name = "literature_sbox_names", n = 0, cost = 1,
           setup = () -> nothing,
           call  = _ -> literature_sbox_names(),
           note  = "list the literature names")

    benchmark!(reg; group = G, name = "load_literature_sbox", n = 8, cost = 1,
           setup = () -> "AES",
           call  = name -> load_literature_sbox(name),
           note  = "build the AES S-box")

    # The loader recomputes the differential uniformity on every call, so the
    # figure grows fast with n.
    benchmark!(reg; group = G, name = "load_apn_function", n = 8, cost = 1,
           setup = () -> "n8_Gold_x3",
           call  = name -> load_apn_function(name),
           note  = "build a catalog APN function")

    benchmark!(reg; group = G, name = "load_apn_function", n = 12, cost = 1,
           setup = () -> "n12_CalderiniLiVilla2023_F1",
           call  = name -> load_apn_function(name),
           note  = "build a catalog APN function")

    # ── bibliography ────────────────────────────────────────────────────────

    benchmark!(reg; group = G, name = "load_bibliography", n = 0, cost = 1,
           setup = () -> bibliography_path(),
           call  = p -> load_bibliography(p),
           note  = "read and parse the bibliography")

    benchmark!(reg; group = G, name = "parse_bibtex", n = 0, cost = 1,
           setup = () -> read(bibliography_path(), String),
           call  = text -> parse_bibtex(text),
           note  = "parse BibTeX text")

    # ── bulk corpora ────────────────────────────────────────────────────────

    benchmark!(reg; group = G, name = "list_corpora", n = 0, cost = 1,
           setup = () -> open_db(),
           call  = db -> list_corpora(db),
           note  = "list the bulk corpora")

    # The descriptor row lives in the committed catalog. The member count comes
    # from that row, so the call reads no member.
    if isfile(corpus_store_path(big_corpus))
        benchmark!(reg; group = G, name = "corpus_length", n = 8, cost = 1,
               setup = () -> (open_db(), big_corpus),
               call  = p -> corpus_length(p[1], p[2]),
               input_files=[corpus_store_path(big_corpus)],
               note  = "size of the largest corpus")

        benchmark!(reg; group = G, name = "corpus_coefficients", n = 8, cost = 1,
               setup = () -> (big_corpus, big_member),
               call  = p -> corpus_coefficients(p[1], p[2]),
               input_files=[corpus_store_path(big_corpus)],
               note  = "read one packed member")

        benchmark!(reg; group = G, name = "corpus_function", n = 8, cost = 1,
               setup = () -> (open_db(), big_corpus, big_member),
               call  = p -> corpus_function(p[1], p[2], p[3]),
               input_files=[corpus_store_path(big_corpus)],
               note  = "decode one corpus member")
    end

    # The expansion writes to a temporary file outside the repository. Both
    # corpora are small on purpose. Never expand `beierle2025_n8`.
    if isfile(corpus_store_path(small_corpus))
        benchmark!(reg; group = G, name = "materialize_corpus_luts", n = 8, cost = 1,
               setup = () -> (open_db(), small_corpus,
                              joinpath(mktempdir(), "luts.sqlite")),
               call  = p -> materialize_corpus_luts(p[1], p[2]; path = p[3]),
               teardown=p->rm(dirname(p[3]);recursive=true),
               input_files=[corpus_store_path(small_corpus)],
               note  = "expand 22 member LUTs")
    end

    if isfile(corpus_store_path(mid_corpus))
        benchmark!(reg; group = G, name = "materialize_corpus_luts_bulk", n = 8, cost = 2,
               setup = () -> (open_db(), mid_corpus,
                              joinpath(mktempdir(), "luts.sqlite")),
               call  = p -> materialize_corpus_luts(p[1], p[2]; path = p[3]),
               teardown=p->rm(dirname(p[3]);recursive=true),
               samples = 3,
               input_files=[corpus_store_path(mid_corpus)],
               note  = "expand 6368 member LUTs")
    end

    # ── the sigma signature and the novelty oracle ──────────────────────────

    if isfile(sigma_index_path())
        benchmark!(reg;group=G,name="sigma_index_lookup",n=8,
            setup=()->(open_index(),sigma_hash(gold_apn(8,1))),
            call=p->collect(DBInterface.execute(p[1],
                "SELECT source,member_idx FROM ccz_sigma_index WHERE sigma_hash=? LIMIT 1",(p[2],))),
            input_files=[sigma_index_path()],
            note="historical calibration raw signature lookup")
        # The index size depends on the locally rebuilt baseline. The lookup costs
        # microseconds, so the
        # figure is almost all signature cost.
        benchmark!(reg; group = G, name = "classify_ccz", n = 8, cost = 1,
               setup = () -> (gold_apn(8, 1), open_index()),
               call  = p -> classify_ccz(p[1]; index = p[2]),
               input_files=[sigma_index_path()],
               note  = "novelty query on the index")

        benchmark!(reg; group = G, name = "is_novel", n = 8, cost = 1,
               setup = () -> (gold_apn(8, 1), open_index()),
               call  = p -> is_novel(p[1]; index = p[2]),
               input_files=[sigma_index_path()],
               note  = "novelty verdict for one function")

    end

    return reg
end
