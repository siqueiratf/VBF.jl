"""
CCZ-invariant fingerprint for fast novelty rejection of **non-quadratic** APN.

The σ signature ([`sigma_hash`](@ref)) needs the ortho-derivative and so only
applies to quadratic APN. This fingerprint is defined for any APN function via a
tuple of genuine CCZ-invariants, giving non-quadratic APN the same O(1)
mismatch-certifies-new filter σ gives quadratics.

Soundness ledger — every component is a CCZ-invariant, so a fingerprint mismatch
*certifies* CCZ-inequivalence (a rigorous "new" verdict); equal fingerprints are
necessary but not sufficient (a collision must be confirmed by a full CCZ check):

- differential spectrum (trivial {0,2} multiset for APN, but harmless)
- absolute-Walsh spectrum — the full LAT multiset over all masks, i.e. the
  weight distribution of the linear code `C_F`, which is CCZ-invariant
- Γ-rank, Δ-rank (Edel–Pott; feasible only for n ≤ 7)

EXCLUDED because they are EA-invariant (or weaker) but **not** CCZ-invariant:
algebraic degree and thickness (Kim, degree 2, and the Dillon permutation,
degree 4, are CCZ-equivalent), **and σ-multiplicities** (empirically differs on
the CCZ-equivalent pair Kim / Dillon-permutation, so it is not sound here). The
key is n-tiered and the tier is folded into the hash input so keys from
different tiers never compare equal:

- tier 1 (n ≤ 7): `(Γ-rank, Δ-rank, diff-spectrum, abs-Walsh)`
- tier 2 (n ≥ 8): `(diff-spectrum, abs-Walsh)`   — Γ/Δ-rank intractable; the
  code weight distribution (abs-Walsh) is the discriminator.
"""

"""
    ccz_fingerprint_key(F::SBox) -> Tuple

CCZ-invariant fingerprint tuple, n-tiered (see module docstring). `F` should be
APN. The leading `(N, tier)` makes keys from different dimensions/tiers
incomparable.
"""
function ccz_fingerprint_key(F::SBox{N,T}) where {N,T}
    ds = sorted_pairs(differential_spectrum(F))
    ws = sorted_pairs(absolute_walsh_spectrum(F))
    if N ≤ 7
        return (N, 1, gamma_rank(F), delta_rank(F), ds, ws)
    else
        return (N, 2, ds, ws)
    end
end

"""
    ccz_fingerprint_hash(F::SBox) -> String

Stable hex digest (SHA-256 of `string(ccz_fingerprint_key(F))`). Equal hash ⇔
equal fingerprint; different hash ⇒ provably CCZ-inequivalent.
"""
ccz_fingerprint_hash(F::SBox) = bytes2hex(SHA.sha256(string(ccz_fingerprint_key(F))))

# --- side store -------------------------------------------------------------
# Like the σ index, this is regenerable and kept out of the committed catalog in
# its own side store under corpora/ (gitignored). All bulk corpora are quadratic
# (degree 2), so only non-quadratic APN functions rows are indexed here.

const _CCZ_FP_INDEX_DDL =
    "CREATE TABLE IF NOT EXISTS ccz_fingerprint_index " *
    "(fp_hash TEXT NOT NULL, n INTEGER NOT NULL, tier INTEGER NOT NULL, " *
    "source TEXT NOT NULL, member_idx INTEGER)"

"""
    ccz_fingerprint_index_path() -> String

Path to the fingerprint side store `corpora/ccz_fingerprint_index.sqlite`
(regenerable, not committed).
"""
ccz_fingerprint_index_path() = joinpath(_corpora_dir(), "ccz_fingerprint_index.sqlite")

function _open_ccz_fingerprint_index(; create::Bool = false)
    p = ccz_fingerprint_index_path()
    if !isfile(p) && !create
        error("CCZ-fingerprint side store not found at $p; build it with " *
              "build_ccz_fingerprint_index!(load_catalog())")
    end
    create && mkpath(_corpora_dir())
    s = SQLite.DB(p)
    create && SQLite.execute(s, _CCZ_FP_INDEX_DDL)
    s
end

"""
    build_ccz_fingerprint_index!(db; rebuild=true) -> NamedTuple

(Re)build `ccz_fingerprint_index` over every non-quadratic APN `functions` row
(`is_apn = 1 AND is_quadratic = 0`); the bulk corpora are all quadratic and are
covered by the σ index instead. Returns `(; functions, distinct)`.
"""
function build_ccz_fingerprint_index!(db::SQLite.DB; rebuild::Bool = true)
    idx = _open_ccz_fingerprint_index(create = true)
    rebuild && SQLite.execute(idx, "DROP INDEX IF EXISTS ix_fp_hash")
    rebuild && SQLite.execute(idx, "DELETE FROM ccz_fingerprint_index")
    stmt = DBInterface.prepare(
        idx,
        "INSERT INTO ccz_fingerprint_index (fp_hash, n, tier, source, member_idx) VALUES (?,?,?,?,?)",
    )
    rows = [(Int(r.id), Int(r.n), Vector{UInt8}(r.lut_blob)) for r in DBInterface.execute(
        db, "SELECT id, n, lut_blob FROM functions WHERE is_apn = 1 AND is_quadratic = 0")]
    nfun = 0
    if !isempty(rows)
        hashes = Vector{String}(undef, length(rows))
        tiers = Vector{Int}(undef, length(rows))
        Threads.@threads for i in eachindex(rows)
            _, n, blob = rows[i]
            F = _sbox_from_blob(blob, n)
            hashes[i] = ccz_fingerprint_hash(F)
            tiers[i] = n ≤ 7 ? 1 : 2
        end
        SQLite.transaction(idx) do
            for (i, (id, n, _)) in enumerate(rows)
                DBInterface.execute(stmt, (hashes[i], n, tiers[i], "functions", id))
            end
        end
        nfun = length(rows)
    end
    SQLite.execute(idx,
        "CREATE INDEX IF NOT EXISTS ix_fp_hash ON ccz_fingerprint_index(fp_hash)")
    distinct = 0
    for r in DBInterface.execute(idx, "SELECT COUNT(DISTINCT fp_hash) c FROM ccz_fingerprint_index")
        distinct = Int(r.c)
    end
    close(idx)
    (; functions = nfun, distinct = distinct)
end

"""
    classify_ccz_fingerprint(F::SBox; index) -> (status, source, member_idx)

Look up `ccz_fingerprint_hash(F)` in the `ccz_fingerprint_index` side store.
Returns `(:known, source, member_idx)` for the first match, or
`(:new, nothing, nothing)` if the fingerprint is absent (a rigorous
CCZ-inequivalence certificate against every indexed non-quadratic APN). For
quadratic APN use [`classify_ccz`](@ref) (σ) instead.
"""
function classify_ccz_fingerprint(F::SBox; index::SQLite.DB = _open_ccz_fingerprint_index())
    h = ccz_fingerprint_hash(F)
    for r in DBInterface.execute(
        index,
        "SELECT source, member_idx FROM ccz_fingerprint_index WHERE fp_hash = " *
        _sql_quote(h) * " LIMIT 1",
    )
        return (:known, String(r.source), Int(r.member_idx))
    end
    (:new, nothing, nothing)
end

"""
    is_novel_fingerprint(F::SBox; index) -> Bool

`true` iff `ccz_fingerprint_hash(F)` is absent from `ccz_fingerprint_index` — a
new non-quadratic-APN CCZ class relative to the indexed catalog.
"""
is_novel_fingerprint(F::SBox; index::SQLite.DB = _open_ccz_fingerprint_index()) =
    classify_ccz_fingerprint(F; index = index)[1] === :new
