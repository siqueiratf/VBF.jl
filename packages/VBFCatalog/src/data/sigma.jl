"""
σ-signature CCZ classification and novelty oracle.

The **ortho-derivative signature** of a quadratic APN function `F` is
`σ(F) = (diff-spectrum(π_F), abs-Walsh-spectrum(π_F))`, where `π_F` is the
ortho-derivative (`VBF.ortho_derivative`). By Yoshiara (CCZ = EA for quadratic
APN) together with the Canteaut–Couvreur–Perrin invariant, a signature mismatch
`σ(F) ≠ σ(G)` *certifies* `F` and `G` are CCZ-inequivalent. So σ is a sound,
fast filter for "is this function new?": absence of its σ from the catalog is a
rigorous proof of a new CCZ class.

This module hashes σ to a hex string and maintains `ccz_sigma_index` — a σ index
over every `is_quadratic` APN `functions` row *and* every bulk-corpus member —
backing [`is_novel`](@ref) / [`classify_ccz`](@ref). It also populates
`equivalence_classes` (kind `"CCZ"`) for the `functions`-table reps.
"""

import SQLite
import DBInterface
import SHA

# --- the invariant ----------------------------------------------------------

"""
    sigma_key(F::SBox) -> Tuple

CCZ-invariant ortho-derivative signature: `(sorted_pairs(diff-spectrum(π_F)),
sorted_pairs(abs-Walsh-spectrum(π_F)))`. `F` must be a quadratic APN function.
"""
function sigma_key(F::SBox)
    pi = ortho_derivative(F)
    pi === nothing && error("sigma_key: ortho_derivative undefined (F not APN?)")
    (sorted_pairs(differential_spectrum(pi)), sorted_pairs(absolute_walsh_spectrum(pi)))
end

"""
    sigma_hash(F::SBox) -> String

Stable hex digest (SHA-256 of `string(sigma_key(F))`) usable as a content key.
Equal hash ⇔ equal σ; different hash ⇒ provably CCZ-inequivalent.
"""
sigma_hash(F::SBox) = bytes2hex(SHA.sha256(string(sigma_key(F))))

# --- side store -------------------------------------------------------------
# The σ index is large (one row per catalogued function — millions) and fully
# regenerable from the corpora + functions table, so — like the bulk-corpus LUT
# stores — it is kept OUT of the committed main catalog in its own side store
# under corpora/, never committed (see .gitignore). Build it with
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

Path to the σ-index side store `corpora/ccz_sigma_index.sqlite` (regenerable, not
committed).
"""
sigma_index_path() = joinpath(_corpora_dir(), "ccz_sigma_index.sqlite")

function _open_sigma_index(; create::Bool = false)
    p = sigma_index_path()
    if !isfile(p) && !create
        error("σ-index side store not found at $p; build it with build_sigma_index!(load_catalog())")
    end
    create && mkpath(_corpora_dir())
    s = SQLite.DB(p)
    if create
        SQLite.execute(s, _SIGMA_INDEX_DDL)
        SQLite.execute(s, _SIGMA_COVERAGE_DDL)
    end
    s
end

# Sources that were deliberately NOT indexed and that could hold an n-bit match.
# An index built before sigma_coverage existed has no such table; those builds
# always covered everything (the defaults index the functions table and every
# corpus), so treat a missing table as "no gaps".
function _sigma_gaps(idx::SQLite.DB, n::Integer)
    has_table = false
    for _ in DBInterface.execute(idx,
            "SELECT name FROM sqlite_master WHERE type='table' AND name='sigma_coverage'")
        has_table = true
    end
    has_table || return String[]
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
    let absent = filter(nm -> !isfile(corpus_store_path(nm)), names)
        if !isempty(absent)
            @warn "σ-index: side store absent; corpus NOT indexed (its dimension " *
                  "will refuse a novelty lookup)" corpora = absent
            names = filter(nm -> isfile(corpus_store_path(nm)), names)
        end
    end
    for name in names
        info = corpus_info(db, name)
        info === nothing && continue
        n = Int(info.n); mod = Int(info.modulus)
        powtab = monomial_power_table(n, mod)
        store = SQLite.DB(corpus_store_path(name))
        try
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
            for r in DBInterface.execute(store, "SELECT idx, coeffs FROM members ORDER BY idx")
                push!(batch_idx, Int(r.idx)); push!(batch_co, Vector{UInt8}(r.coeffs))
                length(batch_idx) >= batch && flush_batch()
            end
            flush_batch()
        finally
            close(store)
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

# --- equivalence_classes population (functions-table reps) ------------------

"""
    populate_ccz_equivalence_classes!(db) -> Int

Record the CCZ classes of the `is_quadratic` APN `functions` rows into
`equivalence_classes` (kind `"CCZ"`, `canonical_id` = lowest member id) with all
members in `class_members` (strategy `"ortho-derivative-sigma-confirmed"`).
Returns the number of classes written.

σ is used to **bucket**, not to decide. A σ collision does not imply
CCZ-equivalence — Gold `x³`/`x⁵` over `F₂⁵` and `x³`/`x⁹` over `F₂⁷` each share a
σ while being CCZ-inequivalent — so a σ bucket may need splitting. The complete
decision for quadratic APN is `VBF.ea_mappings_from_ortho_derivative` (non-empty
iff EA-equivalent; EA = CCZ here by Yoshiara), but *confirming* an equivalent
n=8 pair with it costs ~5 minutes, and the catalog has dozens of such pairs.

The known σ-collisions of CCZ-**inequivalent** functions are the Gold-exponent
pairs at **odd** n, where the EA test is cheap; at n=8 those pairs have distinct
σ, and σ is the complete invariant the literature uses to enumerate n=8
quadratic APN. So this function **EA-confirms buckets at n ≤ 7** (splitting the
real collisions) and **σ-groups n ≥ 8** directly, recording the two provenances
in `class_members.strategy`:

  * `"ortho-derivative-sigma-confirmed"` — EA-confirmed (n ≤ 7).
  * `"ortho-derivative-sigma"` — σ-grouped, not yet EA-confirmed (n ≥ 8). A
    native confirmation tool can upgrade these; the label keeps the provenance
    honest meanwhile.

Buckets of size 1 need no work: σ-mismatch against everything else is already a
certificate. Grouping on σ alone at *all* n (as an earlier version did) silently
merged the odd-n Gold pairs into single classes.
"""
function populate_ccz_equivalence_classes!(db::SQLite.DB)
    SQLite.execute(db, "DELETE FROM class_members WHERE strategy IN (" *
        _sql_quote(_SIGMA_STRATEGY) * ", " * _sql_quote(_SIGMA_STRATEGY_CONFIRMED) * ")")
    SQLite.execute(db, "DELETE FROM equivalence_classes WHERE kind = 'CCZ'")

    # 1) bucket by (n, σ) — a necessary condition, cheap
    buckets = Dict{Tuple{Int,String},Vector{Int}}()
    sboxes = Dict{Int,Any}()
    for r in DBInterface.execute(
        db, "SELECT id, n, lut_blob FROM functions WHERE is_apn = 1 AND is_quadratic = 1")
        id = Int(r.id); n = Int(r.n)
        s = _sbox_from_blob(Vector{UInt8}(r.lut_blob), n)
        sboxes[id] = s
        push!(get!(buckets, (n, sigma_hash(s)), Int[]), id)
    end

    # 2) split each multi-member bucket into true CCZ classes.
    #    The EA decision dominates the cost: finding the maps for an *equivalent*
    #    n=8 pair takes ~4 minutes. Classifying a bucket sequentially (compare each
    #    member against the running class reps) serialises those calls on one
    #    thread, so a single big n=8 bucket becomes a ~40-min long pole no matter
    #    how the buckets are scheduled across cores.
    #
    #    Instead, flatten EVERY within-bucket pair (i<j) across ALL buckets into
    #    one pool of independent comparisons and run them together. EA-equivalence
    #    is transitive within a σ-bucket, so the true partition is the connected
    #    components of the "equivalent" graph (union-find) — which the full set of
    #    pairwise answers determines exactly. A heavy bucket's pairs now interleave
    #    with every other bucket's, so no bucket serialises; wall-time is bounded by
    #    (total_pairs / cores) × per-comparison, not by the largest bucket. Singletons
    #    need no comparison (σ-mismatch against everything else already certifies the
    #    class). DB writes stay on this thread — SQLite is not reentrant here.
    #    Round-based rep comparison, minimal calls, maximally parallel. In each
    #    round every still-unassigned member of every bucket is compared against
    #    its bucket's current representative — these are all INDEPENDENT, so they
    #    flatten across buckets into one pool run in parallel. Members equivalent
    #    to the rep join its class; the rest go to the next round under a new rep.
    #    A single-class bucket resolves in ONE round of (k-1) comparisons; only a
    #    genuinely splitting bucket (the Gold pairs) needs a second round. This
    #    does the *minimum* number of the ~4-min n=8 EA calls (k-1, not the
    #    k(k-1)/2 of all-pairs) and runs them all at once. Singletons need no call
    #    (σ-mismatch against everything else already certifies the class). DB
    #    writes stay on this thread — SQLite is not reentrant here.
    # Cost split by dimension. The EA decision is fast to REFUTE (~1 s) but slow
    # to CONFIRM an equivalent pair (~5 min at n=8, and Γ-rank is guarded above
    # n=7). The only known σ-collisions of CCZ-INEQUIVALENT functions are the
    # Gold-exponent pairs at odd n (x³/x⁵ at n=5, x³/x⁹ at n=7) — where the EA
    # test is cheap. At n=8 those same Gold pairs have DISTINCT σ, and σ is the
    # complete invariant the literature uses to enumerate n=8 quadratic APN
    # (Beierle–Leander). So: EA-confirm the cheap small buckets (n ≤ CONFIRM_MAX,
    # catching the real splits), and σ-group the rest, recorded under the
    # *unconfirmed* strategy label so the provenance is honest and the C
    # confirmation tool can upgrade them later.
    CONFIRM_MAX = 7
    bkeys = collect(keys(buckets))
    confirm_idx = [bi for (bi, (n, _)) in enumerate(bkeys) if n <= CONFIRM_MAX]
    sigmagroup_idx = [bi for (bi, (n, _)) in enumerate(bkeys) if n > CONFIRM_MAX]
    classes_of = [Vector{Vector{Int}}() for _ in bkeys]   # finalized classes per bucket
    strat_of = fill(_SIGMA_STRATEGY_CONFIRMED, length(bkeys))
    # σ-group the large-dimension buckets outright (one class each), unconfirmed label
    for bi in sigmagroup_idx
        classes_of[bi] = [sort(buckets[bkeys[bi]])]
        strat_of[bi] = _SIGMA_STRATEGY
    end
    # EA-confirm only the small buckets
    pending = [bi in confirm_idx ? sort(buckets[bkeys[bi]]) : Int[] for bi in eachindex(bkeys)]
    while any(!isempty, pending)
        # finalize singletons; collect (bucket, member) comparison jobs vs pending[bi][1]
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
        # Confirming an *equivalent* n=8 pair via ea_mappings is ~5 min and
        # allocates heavily, so running too many at once GC-thrashes (an 80-min
        # blow-up at 16-wide). Byte-identical LUTs are equivalent for free — take
        # that shortcut first — and cap the residual ea_mappings concurrency so
        # each runs at native speed.
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
    for (bi, (n, h)) in enumerate(bkeys)
        for cls in splits[bi]
            canon = cls[1]
            SQLite.execute(db, string(
                "INSERT INTO equivalence_classes (kind, n, canonical_id, discriminator) VALUES (",
                "'CCZ', ", n, ", ", canon, ", ", _sql_quote(h), ")"))
            cid = 0
            for rr in DBInterface.execute(db, "SELECT last_insert_rowid() id"); cid = Int(rr.id); end
            for fid in cls
                SQLite.execute(db, string(
                    "INSERT INTO class_members (class_id, function_id, strategy) VALUES (",
                    cid, ", ", fid, ", ", _sql_quote(strat_of[bi]), ")"))
            end
            nclasses += 1
        end
    end
    nclasses
end
