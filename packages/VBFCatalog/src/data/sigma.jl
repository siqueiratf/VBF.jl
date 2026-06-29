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

const _SIGMA_STRATEGY = "ortho-derivative-sigma"

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
    rebuild && SQLite.execute(db, "DELETE FROM ccz_sigma_index")
    stmt = DBInterface.prepare(
        db,
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
        SQLite.transaction(db) do
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
                SQLite.transaction(db) do
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

    total = nfun + ncorp
    distinct = 0
    for r in DBInterface.execute(db, "SELECT COUNT(DISTINCT sigma_hash) c FROM ccz_sigma_index")
        distinct = Int(r.c)
    end
    (; functions = nfun, corpus_members = ncorp, total = total, distinct = distinct)
end

# --- novelty oracle ---------------------------------------------------------

"""
    classify_ccz(F::SBox; db) -> (status, source, member_idx)

Look up `σ(F)` in `ccz_sigma_index`. Returns `(:known, source, member_idx)` for
the first catalog match, or `(:new, nothing, nothing)` if σ is absent (a rigorous
CCZ-inequivalence certificate against the entire indexed catalog).
"""
function classify_ccz(F::SBox; db::SQLite.DB = load_catalog())
    h = sigma_hash(F)
    for r in DBInterface.execute(
        db,
        "SELECT source, member_idx FROM ccz_sigma_index WHERE sigma_hash = " *
        _sql_quote(h) * " LIMIT 1",
    )
        return (:known, String(r.source), Int(r.member_idx))
    end
    (:new, nothing, nothing)
end

"""
    is_novel(F::SBox; db) -> Bool

`true` iff `σ(F)` is absent from `ccz_sigma_index` — i.e. `F` is CCZ-inequivalent
to every function in the indexed catalog (a new quadratic-APN CCZ class).
"""
is_novel(F::SBox; db::SQLite.DB = load_catalog()) = classify_ccz(F; db = db)[1] === :new

# --- equivalence_classes population (functions-table reps) ------------------

"""
    populate_ccz_equivalence_classes!(db) -> Int

Group every `is_quadratic` APN `functions` row by `σ` and record one
`equivalence_classes` row (kind `"CCZ"`, `discriminator` = σ-hash, `canonical_id`
= lowest member id) per class, with all members in `class_members`
(strategy `"ortho-derivative-sigma"`). Returns the number of classes written.
"""
function populate_ccz_equivalence_classes!(db::SQLite.DB)
    SQLite.execute(db, "DELETE FROM class_members WHERE strategy = " * _sql_quote(_SIGMA_STRATEGY))
    SQLite.execute(db, "DELETE FROM equivalence_classes WHERE kind = 'CCZ'")
    # group (n, sigma_hash) -> sorted member ids
    groups = Dict{Tuple{Int,String},Vector{Int}}()
    for r in DBInterface.execute(
        db, "SELECT id, n, lut_blob FROM functions WHERE is_apn = 1 AND is_quadratic = 1")
        id = Int(r.id); n = Int(r.n)
        h = sigma_hash(_sbox_from_blob(Vector{UInt8}(r.lut_blob), n))
        push!(get!(groups, (n, h), Int[]), id)
    end
    nclasses = 0
    for ((n, h), ids) in groups
        sort!(ids)
        canon = ids[1]
        SQLite.execute(db, string(
            "INSERT INTO equivalence_classes (kind, n, canonical_id, discriminator) VALUES (",
            "'CCZ', ", n, ", ", canon, ", ", _sql_quote(h), ")"))
        cid = 0
        for rr in DBInterface.execute(db, "SELECT last_insert_rowid() id"); cid = Int(rr.id); end
        for fid in ids
            SQLite.execute(db, string(
                "INSERT INTO class_members (class_id, function_id, strategy) VALUES (",
                cid, ", ", fid, ", ", _sql_quote(_SIGMA_STRATEGY), ")"))
        end
        nclasses += 1
    end
    nclasses
end
