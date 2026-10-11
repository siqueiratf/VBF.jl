"""
σ-signature CCZ classification and novelty oracle.

The **ortho-derivative signature** of a quadratic APN function `F` is
`σ(F) = (diff-spectrum(π_F), abs-Walsh-spectrum(π_F))`, where `π_F` is the
ortho-derivative (`VBF.ortho_derivative`). By Yoshiara (CCZ = EA for quadratic
APN) together with the Canteaut–Couvreur–Perrin invariant, a signature mismatch
`σ(F) ≠ σ(G)` *certifies* `F` and `G` are CCZ-inequivalent. So σ is a sound
filter for catalog comparison: absence of its σ certifies inequivalence only
to the quadratic APNs represented by the documented index coverage. It does
not establish novelty throughout the literature.

This module hashes σ to a hex string and maintains `ccz_sigma_index` — a σ index
over every `is_quadratic` APN `functions` row *and* every bulk-corpus member —
backing [`is_novel`](@ref) / [`classify_ccz`](@ref). It also populates
`equivalence_classes` (kind `"CCZ"`) for the `functions`-table reps.
"""

import SQLite
import DBInterface

# Invariant keys and hashes are implemented and exported by VBF.

# --- side store -------------------------------------------------------------
# The σ index is large (one row per catalogued function — millions) and fully
# regenerable from the corpora + functions table, so — like the bulk-corpus LUT
# stores — it is kept OUT of the committed main catalog in its own side store
# under packages/VBFCatalog/data/, never committed (see .gitignore). Build it with
# `build_sigma_index!`; the oracle (`classify_ccz`/`is_novel`) reads it.

const _SIGMA_INDEX_DDL =
    "CREATE TABLE IF NOT EXISTS ccz_sigma_index " *
    "(sigma_hash TEXT NOT NULL, n INTEGER NOT NULL, source TEXT NOT NULL, member_idx INTEGER)"

# What the index actually covers. A σ-ABSENCE is only a novelty certificate
# against the functions that were indexed, so a PARTIAL index silently converts
# "known" into `:new` — the exact failure that put four withdrawn functions into
# this catalog (8022d09). The build therefore records every source it indexed and
# every source it SKIPPED, and the oracle refuses to answer at a dimension whose
# coverage has a hole rather than returning an uncertified `:new`.
# `n = -1` marks the functions table, which spans all dimensions.
const _SIGMA_COVERAGE_DDL =
    "CREATE TABLE IF NOT EXISTS sigma_coverage " *
    "(source TEXT NOT NULL, n INTEGER NOT NULL, indexed INTEGER NOT NULL)"

const _COVERAGE_ALL_N = -1

"""
    sigma_index_path() -> String

Path to the σ-index side store `packages/VBFCatalog/data/ccz_sigma_index.sqlite` (regenerable, not
committed).
"""
sigma_index_path() = joinpath(catalog_data_dir(), "ccz_sigma_index.sqlite")

"""Rebind curated signature rows after catalog IDs change during a rebuild.

Bulk signatures are retained. Compute all replacements before the transaction;
failure leaves the existing index untouched.
"""
function refresh_curated_sigma_index!(db::SQLite.DB;path=sigma_index_path())
    isfile(path) || return 0
    rows=[(sigma_hash(load_sbox(db,Int(r.id))),Int(r.n),Int(r.id)) for r in
        DBInterface.execute(db,"SELECT id,n FROM functions WHERE is_apn=1 AND is_quadratic=1 ORDER BY id")]
    idx=SQLite.DB(path)
    try
        SQLite.execute(idx,_SIGMA_COVERAGE_DDL)
        SQLite.transaction(idx) do
            SQLite.execute(idx,"DELETE FROM ccz_sigma_index WHERE source='functions'")
            SQLite.execute(idx,"DELETE FROM sigma_coverage WHERE source='functions'")
            for (hash,n,id) in rows
                SQLite.execute(idx,"INSERT INTO ccz_sigma_index VALUES(?,?,?,?)",(hash,n,"functions",id))
            end
            SQLite.execute(idx,"INSERT INTO sigma_coverage VALUES('functions',-1,1)")
        end
        length(rows)
    finally
        close(idx)
    end
end

function _open_sigma_index(; create::Bool = false)
    p = sigma_index_path()
    if !isfile(p) && !create
        error("σ-index side store not found at $p; build it with build_sigma_index!(load_catalog())")
    end
    create && mkpath(catalog_data_dir())
    s = SQLite.DB(p)
    if create
        SQLite.execute(s, _SIGMA_INDEX_DDL)
        SQLite.execute(s, _SIGMA_COVERAGE_DDL)
    end
    s
end

# Sources that were deliberately NOT indexed and that could hold an n-bit match.
# Missing coverage metadata is unknown coverage, never evidence of completeness.
function _sigma_gaps(idx::SQLite.DB, n::Integer)
    has_table = false
    for _ in DBInterface.execute(idx,
            "SELECT name FROM sqlite_master WHERE type='table' AND name='sigma_coverage'")
        has_table = true
    end
    has_table || return ["missing sigma_coverage metadata"]
    gaps = String[]
    for r in DBInterface.execute(idx, string(
            "SELECT source FROM sigma_coverage WHERE indexed = 0 AND n IN (",
            Int(n), ", ", _COVERAGE_ALL_N, ")"))
        push!(gaps, String(r.source))
    end
    gaps
end

# A corpus registered in the catalog AFTER the index was built has no
# sigma_coverage row at all, so it reads as neither indexed nor skipped and the
# oracle would answer `:new` without ever having seen its members. Pass the
# catalog to close that hole: a corpus the catalog knows and the coverage table
# does not is a gap, exactly like an explicitly skipped one.
function _sigma_unknown_corpora(idx::SQLite.DB, db::SQLite.DB, n::Integer)
    recorded = Set{String}()
    has_table = false
    for _ in DBInterface.execute(idx,
            "SELECT name FROM sqlite_master WHERE type='table' AND name='sigma_coverage'")
        has_table = true
    end
    has_table || return String[]
    for r in DBInterface.execute(idx, "SELECT source FROM sigma_coverage")
        push!(recorded, String(r.source))
    end
    out = String[]
    for name in list_corpora(db)
        name in recorded && continue
        info = corpus_info(db, name)
        info === nothing && continue
        Int(info.n) == Int(n) && push!(out, name)
    end
    out
end

function _assert_sigma_coverage(idx::SQLite.DB, n::Integer;
                                db::Union{Nothing,SQLite.DB} = nothing)
    gaps = _sigma_gaps(idx, n)
    db === nothing || append!(gaps, _sigma_unknown_corpora(idx, db, n))
    isempty(gaps) && return
    error("σ-index does not cover n=$n: the source(s) $(join(gaps, ", ")) were not " *
          "indexed, so a σ-absence at this dimension is NOT a novelty certificate. " *
          "Rebuild with build_sigma_index!(load_catalog()) to index them.")
end

# --- decoding helpers -------------------------------------------------------

# SBox from a `functions.lut_blob` (cld(n,8) LE bytes per entry, input order).
function _sbox_from_blob(blob::AbstractVector{UInt8}, n::Integer)
    nn = Int(n); bpe = cld(nn, 8); N = 1 << nn
    lut = Vector{Int}(undef, N)
    @inbounds for i in 1:N
        v = 0
        for b in 0:(bpe-1)
            v |= Int(blob[(i-1)*bpe+b+1]) << (8b)
        end
        lut[i] = v
    end
    SBox{nn}(lut)
end

# --- index build ------------------------------------------------------------

const _SIGMA_STRATEGY = "ortho-derivative-sigma"                     # legacy: σ-bucketed, unconfirmed
const _SIGMA_STRATEGY_CONFIRMED = "ortho-derivative-sigma-confirmed" # σ-bucketed, EA-confirmed

"""
    build_sigma_index!(db; rebuild=true) -> NamedTuple

(Re)build `ccz_sigma_index` over every `is_quadratic` APN `functions` row and
every bulk-corpus member (σ computed in parallel). Returns
`(; functions, corpus_members, total, distinct)`.

`corpora` / `include_functions` narrow the build; what was left out is recorded
in `sigma_coverage`, and [`classify_ccz`](@ref) then REFUSES to answer at a
dimension a skipped source could have matched, instead of returning an
uncertified `:new`. Every bulk corpus is n=8, so `corpora = String[]` yields an
index that is exactly as complete as the full one at every n ≠ 8 and costs
seconds instead of hours — that is what CI builds.
"""
function build_sigma_index!(
    db::SQLite.DB;
    rebuild::Bool = true,
    corpora = nothing,
    include_functions::Bool = true,
    batch::Int = 20_000,
)
    idx = _open_sigma_index(create = true)              # the regenerable side store
    rebuild && SQLite.execute(idx, "DROP INDEX IF EXISTS ix_sigma_hash")
    rebuild && SQLite.execute(idx, "DELETE FROM ccz_sigma_index")
    stmt = DBInterface.prepare(
        idx,
        "INSERT INTO ccz_sigma_index (sigma_hash, n, source, member_idx) VALUES (?,?,?,?)",
    )
    nfun = 0
    ncorp = 0

    # 1) functions-table quadratic APN rows
    rows = include_functions ? [(Int(r.id), Int(r.n), Vector{UInt8}(r.lut_blob)) for r in DBInterface.execute(
        db, "SELECT id, n, lut_blob FROM functions WHERE is_apn = 1 AND is_quadratic = 1")] : Tuple{Int,Int,Vector{UInt8}}[]
    if !isempty(rows)
        hashes = Vector{String}(undef, length(rows))
        Threads.@threads for i in eachindex(rows)
            id, n, blob = rows[i]
            hashes[i] = sigma_hash(_sbox_from_blob(blob, n))
        end
        SQLite.transaction(idx) do
            for (i, (id, n, _)) in enumerate(rows)
                DBInterface.execute(stmt, (hashes[i], n, "functions", id))
            end
        end
        nfun = length(rows)
    end

    # 2) bulk corpora (decode member -> σ), in batches to bound memory + GC churn.
    #    σ over millions allocates heavily; GC.gc() per batch avoids a GC death-spiral.
    names = corpora === nothing ? list_corpora(db) : collect(corpora)
    # A descriptor may name a side store this clone does not hold: the largest
    # corpora exceed GitHub's per-file limit and are regenerable, so they are
    # not committed. Drop such a corpus from `names` HERE, so it is recorded as
    # NOT indexed and the oracle refuses its dimension — the honest answer.
    # Opening a missing store would instead create an empty file and then throw
    # on `SELECT … FROM members`.
    let absent = filter(nm -> !isfile(corpus_store_path(db, nm)), names)
        if !isempty(absent)
            @warn "σ-index: side store absent; corpus NOT indexed (its dimension " *
                  "will refuse a novelty lookup)" corpora = absent
            names = filter(nm -> isfile(corpus_store_path(db, nm)), names)
        end
    end
    for name in names
        info = corpus_info(db, name)
        info === nothing && continue
        n = Int(info.n); mod = Int(info.modulus)
        powtab = monomial_power_table(n, mod)
        with_corpus_rows(db, name) do rows
            batch_idx = Int[]; batch_co = Vector{UInt8}[]
            flush_batch = function ()
                isempty(batch_idx) && return
                hs = Vector{Union{Nothing,String}}(nothing, length(batch_idx))
                Threads.@threads for j in eachindex(batch_idx)
                    try
                        lut = decode_quadratic_lut(batch_co[j], n, mod; powtab = powtab)
                        hs[j] = sigma_hash(SBox{n}(lut))
                    catch
                        hs[j] = nothing      # skip degenerate member (not quadratic APN)
                    end
                end
                SQLite.transaction(idx) do
                    for j in eachindex(batch_idx)
                        hs[j] === nothing && continue
                        DBInterface.execute(stmt, (hs[j], n, name, batch_idx[j]))
                        ncorp += 1
                    end
                end
                empty!(batch_idx); empty!(batch_co)
                GC.gc(false)
            end
            for r in rows
                push!(batch_idx, Int(r.idx)); push!(batch_co, Vector{UInt8}(r.coeffs))
                length(batch_idx) >= batch && flush_batch()
            end
            flush_batch()
        end
    end

    SQLite.execute(idx, "CREATE INDEX IF NOT EXISTS ix_sigma_hash ON ccz_sigma_index(sigma_hash)")

    # Record coverage: the functions table (all n) plus every corpus the catalog
    # knows about, flagged indexed or skipped. Read back by `_assert_sigma_coverage`.
    # `rebuild = false` keeps the rows an earlier build wrote, so its coverage
    # survives too — otherwise a narrow top-up would mark a source it did not
    # touch as skipped and the oracle would refuse a dimension it can in fact
    # answer. A rebuild wipes the rows, so only this run's scope counts.
    prev = Dict{String,Bool}()
    if !rebuild
        for r in DBInterface.execute(idx, "SELECT source, indexed FROM sigma_coverage")
            prev[String(r.source)] = Int(r.indexed) == 1
        end
    end
    covered(src, now) = now || get(prev, src, false)

    SQLite.execute(idx, "DELETE FROM sigma_coverage")
    SQLite.transaction(idx) do
        SQLite.execute(idx, string(
            "INSERT INTO sigma_coverage (source, n, indexed) VALUES (",
            _sql_quote("functions"), ", ", _COVERAGE_ALL_N, ", ",
            Int(covered("functions", include_functions)), ")"))
        for name in list_corpora(db)
            info = corpus_info(db, name)
            info === nothing && continue
            SQLite.execute(idx, string(
                "INSERT INTO sigma_coverage (source, n, indexed) VALUES (",
                _sql_quote(name), ", ", Int(info.n), ", ",
                Int(covered(name, name in names)), ")"))
        end
    end

    total = nfun + ncorp
    distinct = 0
    for r in DBInterface.execute(idx, "SELECT COUNT(DISTINCT sigma_hash) c FROM ccz_sigma_index")
        distinct = Int(r.c)
    end
    close(idx)
    (; functions = nfun, corpus_members = ncorp, total = total, distinct = distinct)
end

# --- novelty oracle ---------------------------------------------------------

"""
    classify_ccz(F::SBox; index) -> (status, source, member_idx)

Look up `σ(F)` in the `ccz_sigma_index` side store (see [`sigma_index_path`](@ref)).

The two verdicts are **not** symmetric, and the asymmetry is the whole point:

  * `(:new, nothing, nothing)` — σ is absent from the index. This is a **rigorous
    CCZ-inequivalence certificate** against every indexed function: σ is a
    CCZ-invariant, so a mismatch cannot be an artefact.
  * `(:sigma_match, source, member_idx)` — σ collides with that member. This is
    **NOT proof of equivalence**, only a candidate. σ is necessary, not
    sufficient: Gold `x³` and `x⁹` over `F₂⁷` share a σ (and a Γ-rank, and a
    Δ-rank) yet are CCZ-inequivalent, as do `x³` and `x⁵` over `F₂⁵`.

To settle a `:sigma_match`, confirm it against the candidate's LUT with the
complete decision for quadratic APN — `VBF.ea_mappings_from_ortho_derivative(F, G)`
is non-empty iff `F ~EA G`, and EA = CCZ for quadratic APN (Yoshiara).

The status was formerly `:known`, which invited callers to read a σ collision as
"already in the catalog" and silently discard a genuinely new class.

Throws if the index does not cover `F`'s dimension (see `sigma_coverage`): an
absence proves nothing against sources that were never indexed, so a partial
index must refuse rather than answer `:new`. By default the check also reads the
catalog, so a bulk corpus registered since the last index build counts as a gap
too — otherwise its members would read as `:new`. Pass `index` to supply your
own index (then no catalog is read unless you also pass `catalog`).
"""
function classify_ccz(F::SBox{N};
                      index::Union{Nothing,SQLite.DB} = nothing,
                      catalog::Union{Nothing,SQLite.DB} = nothing) where {N}
    # The default path opens BOTH side stores and cross-checks them, so a corpus
    # registered after the last index build is caught. An explicit `index`
    # (the tests build one in memory) is taken as the whole world unless the
    # caller also passes `catalog`.
    own_index = index === nothing
    idx = own_index ? _open_sigma_index() : index
    own_cat = own_index && catalog === nothing
    cat = own_cat ? load_catalog() : catalog
    try
        return _classify_ccz(F, idx, cat)
    finally
        own_index && close(idx)
        own_cat && cat !== nothing && close(cat)
    end
end

function _classify_ccz(F::SBox{N}, index::SQLite.DB,
                       catalog::Union{Nothing,SQLite.DB}) where {N}
    _assert_sigma_coverage(index, N; db = catalog)
    h = sigma_hash(F)
    q = DBInterface.execute(
        index,
        "SELECT source, member_idx FROM ccz_sigma_index WHERE sigma_hash = " *
        _sql_quote(h) * " LIMIT 1",
    )
    try
        for r in q
            return (:sigma_match, String(r.source), Int(r.member_idx))
        end
        (:new, nothing, nothing)
    finally
        DBInterface.close!(q)
    end
end

"""
    is_novel(F::SBox; index) -> Bool

`true` iff `σ(F)` is absent from the `ccz_sigma_index` side store — i.e. `F` is
CCZ-inequivalent to every indexed function (a new quadratic-APN CCZ class). This
direction is rigorous.

`false` means only "σ collides with something indexed" — **not** that `F` is
known. Confirm a collision before treating it as a duplicate; see
[`classify_ccz`](@ref).
"""
is_novel(F::SBox; index::Union{Nothing,SQLite.DB} = nothing,
         catalog::Union{Nothing,SQLite.DB} = nothing) =
    classify_ccz(F; index = index, catalog = catalog)[1] === :new

# Curated classes are derived evidence, outside the tracked catalog.
const _CURATED_CLASSES_DDL = (
    "CREATE TABLE IF NOT EXISTS equivalence_classes(id INTEGER PRIMARY KEY,kind TEXT NOT NULL,n INTEGER NOT NULL,canonical_id INTEGER NOT NULL,discriminator TEXT)",
    "CREATE TABLE IF NOT EXISTS class_members(class_id INTEGER NOT NULL,function_id INTEGER NOT NULL,strategy TEXT NOT NULL,PRIMARY KEY(class_id,function_id,strategy))",
    "CREATE TABLE IF NOT EXISTS curated_class_meta(inputs_sha256 TEXT NOT NULL,solver_sha256 TEXT NOT NULL)")

function _curated_inputs_digest(db)
    bytes2hex(SHA.sha256(join([string(row.id,':',row.n,':',row.lut_sha256) for row in
        DBInterface.execute(db,"SELECT id,n,lut_sha256 FROM functions WHERE is_apn=1 AND is_quadratic=1 ORDER BY id")],"\n")))
end

"""Path to regenerable curated class evidence."""
curated_classes_path() = joinpath(catalog_data_dir(),"curated_classes.sqlite")

"""Populate derived curated classes: EA-confirm n <= 7; label larger sigma buckets unconfirmed."""
function populate_ccz_equivalence_classes!(db::SQLite.DB;path=curated_classes_path())
    mkpath(dirname(path))
    idx=SQLite.DB(path)
    try
        for sql in _CURATED_CLASSES_DDL
            SQLite.execute(idx,sql)
        end

    buckets = Dict{Tuple{Int,String},Vector{Int}}()
    sboxes = Dict{Int,Any}()
    for r in DBInterface.execute(
        db, "SELECT id, n, lut_blob FROM functions WHERE is_apn = 1 AND is_quadratic = 1")
        id = Int(r.id); n = Int(r.n)
        s = _sbox_from_blob(Vector{UInt8}(r.lut_blob), n)
        sboxes[id] = s
        push!(get!(buckets, (n, sigma_hash(s)), Int[]), id)
    end

    CONFIRM_MAX = 7
    bkeys = sort!(collect(keys(buckets)))
    confirm_idx = [bi for (bi, (n, _)) in enumerate(bkeys) if n <= CONFIRM_MAX]
    sigmagroup_idx = [bi for (bi, (n, _)) in enumerate(bkeys) if n > CONFIRM_MAX]
    classes_of = [Vector{Vector{Int}}() for _ in bkeys]   # finalized classes per bucket
    strat_of = fill(_SIGMA_STRATEGY_CONFIRMED, length(bkeys))
    for bi in sigmagroup_idx
        classes_of[bi] = [sort(buckets[bkeys[bi]])]
        strat_of[bi] = _SIGMA_STRATEGY
    end
    pending = [bi in confirm_idx ? sort(buckets[bkeys[bi]]) : Int[] for bi in eachindex(bkeys)]
    while any(!isempty, pending)
        jobs = Tuple{Int,Int}[]
        for bi in eachindex(pending)
            p = pending[bi]
            if length(p) == 1
                push!(classes_of[bi], [p[1]]); empty!(pending[bi])
            elseif length(p) >= 2
                for m in @view p[2:end]; push!(jobs, (bi, m)); end
            end
        end
        isempty(jobs) && break
        reps = [pending[bi][1] for (bi, _) in jobs]          # snapshot reps before any mutation
        res = Vector{Bool}(undef, length(jobs))
        sem = Base.Semaphore(max(1, min(Threads.nthreads(), 6)))
        let tasks = map(eachindex(jobs)) do t
                m = jobs[t][2]; rep = reps[t]
                Threads.@spawn begin
                    sboxes[m].lut == sboxes[rep].lut && return true      # identical ⇒ equivalent
                    Base.acquire(sem)
                    try
                        !isempty(ea_mappings_from_ortho_derivative(sboxes[m], sboxes[rep]))
                    finally
                        Base.release(sem)
                    end
                end
            end
            for t in eachindex(tasks); res[t] = fetch(tasks[t]); end
        end
        matched = Dict{Int,Vector{Int}}(); unmatched = Dict{Int,Vector{Int}}()
        for (t, (bi, m)) in enumerate(jobs)
            push!(get!(res[t] ? matched : unmatched, bi, Int[]), m)
        end
        for bi in eachindex(pending)
            length(pending[bi]) >= 2 || continue
            rep = pending[bi][1]
            push!(classes_of[bi], sort(vcat([rep], get(matched, bi, Int[]))))
            pending[bi] = sort(get(unmatched, bi, Int[]))
        end
    end
    splits = classes_of

    nclasses = 0
    SQLite.transaction(idx) do
    SQLite.execute(idx, "DELETE FROM class_members WHERE strategy IN (" *
        _sql_quote(_SIGMA_STRATEGY) * ", " * _sql_quote(_SIGMA_STRATEGY_CONFIRMED) * ")")
    SQLite.execute(idx, "DELETE FROM equivalence_classes WHERE kind = 'CCZ'")

    for (bi, (n, h)) in enumerate(bkeys)
        for cls in splits[bi]
            canon = cls[1]
            SQLite.execute(idx, string(
                "INSERT INTO equivalence_classes (kind, n, canonical_id, discriminator) VALUES (",
                "'CCZ', ", n, ", ", canon, ", ", _sql_quote(h), ")"))
            cid = 0
            for rr in DBInterface.execute(idx, "SELECT last_insert_rowid() id"); cid = Int(rr.id); end
            for fid in cls
                SQLite.execute(idx, string(
                    "INSERT INTO class_members (class_id, function_id, strategy) VALUES (",
                    cid, ", ", fid, ", ", _sql_quote(strat_of[bi]), ")"))
            end
            nclasses += 1
        end
    end
    SQLite.execute(idx,"DELETE FROM curated_class_meta")
    SQLite.execute(idx,"INSERT INTO curated_class_meta VALUES(?,?)",(_curated_inputs_digest(db),equivalence_solver_fingerprint()))
    end
    nclasses
    finally
        close(idx)
    end
end

"""Read confirmed curated class representatives, refusing absent or stale evidence."""
function ccz_class_representatives(db::SQLite.DB;n::Integer,path=curated_classes_path())
    isfile(path) || error("missing class evidence; run make -C packages/VBFCatalog/src/import classes")
    idx=SQLite.DB("file:"*abspath(path)*"?mode=ro")
    try
        exists=only(Int(row.c) for row in DBInterface.execute(idx,"SELECT COUNT(*) c FROM sqlite_master WHERE name='curated_class_meta'"))
        exists==1 || error("missing class evidence; run the catalog classes command")
        rows=[NamedTuple(row) for row in DBInterface.execute(idx,"SELECT * FROM curated_class_meta")]
        length(rows)==1 || error("incomplete class evidence")
        meta=only(rows)
        meta.inputs_sha256==_curated_inputs_digest(db) && meta.solver_sha256==equivalence_solver_fingerprint() || error("stale class evidence; rebuild catalog classes")
        ids=[Int(row.canonical_id) for row in DBInterface.execute(idx,
            "SELECT e.canonical_id FROM equivalence_classes e WHERE e.n=? AND NOT EXISTS(SELECT 1 FROM class_members m WHERE m.class_id=e.id AND m.strategy!=?) ORDER BY e.canonical_id",
            (n,_SIGMA_STRATEGY_CONFIRMED))]
        n>7 && any(row->true,DBInterface.execute(db,"SELECT 1 FROM functions WHERE n=? AND is_apn=1 AND is_quadratic=1 LIMIT 1",(n,))) && error("large-dimension signature buckets are not confirmed classes")
        [(id=id,sbox=load_sbox(db,id)) for id in ids]
    finally
        close(idx)
    end
end
