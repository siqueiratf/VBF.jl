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
    create && SQLite.execute(s, _SIGMA_INDEX_DDL)
    s
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
"""
function classify_ccz(F::SBox; index::SQLite.DB = _open_sigma_index())
    h = sigma_hash(F)
    for r in DBInterface.execute(
        index,
        "SELECT source, member_idx FROM ccz_sigma_index WHERE sigma_hash = " *
        _sql_quote(h) * " LIMIT 1",
    )
        return (:sigma_match, String(r.source), Int(r.member_idx))
    end
    (:new, nothing, nothing)
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
is_novel(F::SBox; index::SQLite.DB = _open_sigma_index()) = classify_ccz(F; index = index)[1] === :new

# --- equivalence_classes population (functions-table reps) ------------------

"""
    populate_ccz_equivalence_classes!(db) -> Int

Record the CCZ classes of the `is_quadratic` APN `functions` rows into
`equivalence_classes` (kind `"CCZ"`, `canonical_id` = lowest member id) with all
members in `class_members` (strategy `"ortho-derivative-sigma-confirmed"`).
Returns the number of classes written.

σ is used to **bucket**, not to decide. A σ collision does not imply
CCZ-equivalence — Gold `x³`/`x⁹` over `F₂⁷` and `x³`/`x⁵` over `F₂⁵` each share a
σ while being CCZ-inequivalent — so every bucket with more than one member is
split by the complete decision for quadratic APN
(`VBF.ea_mappings_from_ortho_derivative` is non-empty iff EA-equivalent; EA = CCZ
here by Yoshiara). Buckets of size 1 need no confirmation: σ-mismatch against
everything else is already a certificate.

Grouping on σ alone (as this did before) silently merged those Gold pairs into
single classes.
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
    #    The buckets are independent and the EA decision dominates the cost
    #    (finding the maps for an equivalent n=8 pair takes minutes, while
    #    refuting one is instant), so confirm them in parallel. Singletons need
    #    no confirmation: a σ-mismatch against everything else already certifies
    #    the class. DB writes stay on this thread — SQLite is not reentrant here.
    bkeys = collect(keys(buckets))
    splits = Vector{Vector{Vector{Int}}}(undef, length(bkeys))
    Threads.@threads for bi in eachindex(bkeys)
        ids = sort(buckets[bkeys[bi]])
        if length(ids) == 1
            splits[bi] = [ids]
            continue
        end
        classes = Vector{Int}[]
        for id in ids
            placed = false
            for cls in classes
                if !isempty(ea_mappings_from_ortho_derivative(sboxes[id], sboxes[cls[1]]))
                    push!(cls, id)
                    placed = true
                    break
                end
            end
            placed || push!(classes, [id])
        end
        splits[bi] = classes
    end

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
                    cid, ", ", fid, ", ", _sql_quote(_SIGMA_STRATEGY_CONFIRMED), ")"))
            end
            nclasses += 1
        end
    end
    nclasses
end
