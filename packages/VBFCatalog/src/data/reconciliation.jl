"""
Reconciliation across multiple S-box/APN databases.

The BFA catalog's `reconciliation_disagreements` table records every
case where the same abstract function appears differently across the
upstream sources we cross-check against ([sboxU](@cite sboxU),
[Xanadu's apn-ccz-graph-framework](@cite XanaduAPNCCZGraph),
[`APN-Repository`](@cite AndersenAPNRepository), …). This module is the
read/write API over that table; the actual import scripts live under
`data-build/import_*_apn.jl`.

# Disagreement kinds (the `kind` column)
- `"only_in_some"`         — function present in some sources, absent from others (`present_in` / `absent_from` columns list which).
- `"differential_uniformity_disagree"` — sources report different DUs for the same function.
- `"ccz_equivalence_disagree"`         — one source claims `f ~ g` (CCZ), another disagrees.
- `"odds_disagree"`                    — APN-Repository's ODDS value differs from BFA's recomputed value.

# Public surface
- [`list_reconciliation_disagreements`](@ref)
- [`count_reconciliation_disagreements`](@ref)
- [`reconciliation_summary`](@ref)
- [`record_disagreement!`](@ref)
- [`merge_source_repo!`](@ref) — append a source tag to a `functions.source_repo` row.
"""

import SQLite
import DBInterface

# ----------------------------------------------------------------------------
# Read API
# ----------------------------------------------------------------------------

const _RECON_COLUMNS = (:id, :n, :function_id, :lut_sha256,
                        :present_in, :absent_from, :kind,
                        :resolution, :resolver, :resolved_date)

const _RECON_SELECT =
    "id, n, function_id, lut_sha256, present_in, absent_from, kind, " *
    "resolution, resolver, resolved_date"

function _row_to_disagreement(r)
    NamedTuple{_RECON_COLUMNS}((
        Int(r.id),
        Int(r.n),
        r.function_id === missing ? nothing : Int(r.function_id),
        r.lut_sha256  === missing ? nothing : String(r.lut_sha256),
        String(r.present_in),
        String(r.absent_from),
        String(r.kind),
        r.resolution === missing ? nothing : String(r.resolution),
        r.resolver === missing ? nothing : String(r.resolver),
        r.resolved_date === missing ? nothing : String(r.resolved_date),
    ))
end

function _disagreement_where(; n = nothing, kind = nothing, resolved = nothing,
                              present_in = nothing, absent_from = nothing)
    clauses = String[]
    n !== nothing && push!(clauses, "n = $(Int(n))")
    kind !== nothing && push!(clauses, "kind = " * _sql_quote(String(kind)))
    if resolved !== nothing
        resolved ? push!(clauses, "resolution IS NOT NULL") :
                   push!(clauses, "resolution IS NULL")
    end
    present_in !== nothing &&
        push!(clauses, "present_in LIKE " * _sql_quote("%" * String(present_in) * "%"))
    absent_from !== nothing &&
        push!(clauses, "absent_from LIKE " * _sql_quote("%" * String(absent_from) * "%"))
    isempty(clauses) ? "" : " WHERE " * join(clauses, " AND ")
end

"""
    list_reconciliation_disagreements(db; n, kind, resolved, present_in, absent_from, limit)
        -> Vector{NamedTuple}

Filtered list. Every keyword optional. `present_in` / `absent_from` are
substring matches against the pipe-list columns (so passing
`present_in = "sboxu"` selects every row whose `present_in` contains
that string).

# Examples
```julia
db = load_catalog()
list_reconciliation_disagreements(db; n = 8, kind = "only_in_some")
list_reconciliation_disagreements(db; absent_from = "bfa", resolved = false)
```
"""
function list_reconciliation_disagreements(db::SQLite.DB;
                                           n = nothing,
                                           kind = nothing,
                                           resolved = nothing,
                                           present_in = nothing,
                                           absent_from = nothing,
                                           limit::Union{Nothing, Integer} = nothing)
    where = _disagreement_where(; n, kind, resolved, present_in, absent_from)
    tail  = " ORDER BY id"
    limit !== nothing && (tail *= " LIMIT $(Int(limit))")
    sql = "SELECT " * _RECON_SELECT * " FROM reconciliation_disagreements" * where * tail
    out = NamedTuple[]
    for r in DBInterface.execute(db, sql)
        push!(out, _row_to_disagreement(r))
    end
    out
end

"""
    count_reconciliation_disagreements(db; ...) -> Int

Fast `COUNT(*)` under the same filters as [`list_reconciliation_disagreements`](@ref).
"""
function count_reconciliation_disagreements(db::SQLite.DB; kwargs...)
    where = _disagreement_where(; kwargs...)
    sql = "SELECT COUNT(*) AS c FROM reconciliation_disagreements" * where
    for r in DBInterface.execute(db, sql)
        return Int(r.c)
    end
    0
end

"""
    reconciliation_summary(db) -> Vector{NamedTuple{(:n, :kind, :count), Tuple{Int, String, Int}}}

Aggregated view: how many disagreement rows of each `(n, kind)` pair
exist? Useful for a one-glance health check before the report goes out.

# Examples
```julia
for row in reconciliation_summary(db)
    @info "disagreement" n=row.n kind=row.kind count=row.count
end
```
"""
function reconciliation_summary(db::SQLite.DB)
    sql = "SELECT n, kind, COUNT(*) AS c " *
          "FROM reconciliation_disagreements " *
          "GROUP BY n, kind ORDER BY n, kind"
    out = NamedTuple{(:n, :kind, :count), Tuple{Int, String, Int}}[]
    for r in DBInterface.execute(db, sql)
        push!(out, (n = Int(r.n), kind = String(r.kind), count = Int(r.c)))
    end
    out
end

# ----------------------------------------------------------------------------
# Multi-source views: who agrees with whom
# ----------------------------------------------------------------------------

"""
    KNOWN_SOURCES :: NTuple{4, String}

Source-repo prefixes the catalog can carry: `"bfa"`, `"sboxu"`,
`"xanadu"`, `"apnrepo"`. Used by [`reconciliation_by_source`](@ref)
and [`functions_by_source`](@ref) for tally queries.
"""
const KNOWN_SOURCES = ("bfa", "sboxu", "xanadu", "apnrepo")

"""
    reconciliation_by_source(db) -> Vector{NamedTuple{(:source, :count), Tuple{String, Int}}}

How many reconciliation rows mention each upstream in their
`present_in` pipe-list. A single row contributes to *each* source it
mentions, so the counts can sum to more than the total row count
when cross-source matches exist.
"""
function reconciliation_by_source(db::SQLite.DB)
    out = NamedTuple{(:source, :count), Tuple{String, Int}}[]
    for source in KNOWN_SOURCES
        c = count_reconciliation_disagreements(db; present_in = source)
        push!(out, (source = source, count = c))
    end
    out
end

"""
    functions_by_source(db) -> Vector{NamedTuple{(:source, :count), Tuple{String, Int}}}

Same shape as [`reconciliation_by_source`](@ref), but counts rows in
the *functions* table (i.e., LUTs the catalog stores in full). A
function row with `source_repo = "bfa@…|xanadu@…"` contributes to
both `bfa` and `xanadu`.
"""
function functions_by_source(db::SQLite.DB)
    out = NamedTuple{(:source, :count), Tuple{String, Int}}[]
    for source in KNOWN_SOURCES
        sql = "SELECT COUNT(*) AS c FROM functions WHERE source_repo LIKE " *
              _sql_quote("%" * source * "%")
        c = 0
        for r in DBInterface.execute(db, sql)
            c = Int(r.c)
        end
        push!(out, (source = source, count = c))
    end
    out
end

"""
    cross_source_matches(db; min_sources = 2) -> Vector{NamedTuple}

Reconciliation rows whose `present_in` pipe-list mentions at least
`min_sources` distinct upstream sources. Returns
`(id, n, lut_sha256, present_in, sources_count)` tuples sorted by
`sources_count` descending, then `id` ascending — i.e., the strongest
cross-source agreements come first. Useful for picking high-confidence
APN representatives across databases.
"""
function cross_source_matches(db::SQLite.DB; min_sources::Integer = 2)
    rows = NamedTuple{(:id, :n, :lut_sha256, :present_in, :sources_count),
                      Tuple{Int, Int, String, String, Int}}[]
    sql = "SELECT id, n, lut_sha256, present_in FROM reconciliation_disagreements " *
          "WHERE present_in LIKE '%|%'"     # quick filter: must contain a pipe
    for r in DBInterface.execute(db, sql)
        present = String(r.present_in)
        sources = unique([split(p, '@')[1] for p in split(present, '|')])
        if length(sources) ≥ Int(min_sources)
            push!(rows, (
                id = Int(r.id),
                n = Int(r.n),
                lut_sha256 = r.lut_sha256 === missing ? "" : String(r.lut_sha256),
                present_in = present,
                sources_count = length(sources),
            ))
        end
    end
    sort!(rows; by = r -> (-r.sources_count, r.id))
    rows
end

"""
    multi_source_functions(db; min_sources = 2) -> Vector{NamedTuple}

Function rows whose `source_repo` pipe-list mentions at least
`min_sources` upstream sources. Returns
`(id, n, canonical_name, source_repo, sources_count)`. These are the
"in-catalog" cross-source matches — LUTs we hold in full *and* know
exist in at least one upstream.
"""
function multi_source_functions(db::SQLite.DB; min_sources::Integer = 2)
    rows = NamedTuple{(:id, :n, :canonical_name, :source_repo, :sources_count),
                      Tuple{Int, Int, Union{String, Nothing}, String, Int}}[]
    sql = "SELECT id, n, canonical_name, source_repo FROM functions " *
          "WHERE source_repo LIKE '%|%'"
    for r in DBInterface.execute(db, sql)
        repo = String(r.source_repo)
        sources = unique([split(p, '@')[1] for p in split(repo, '|')])
        if length(sources) ≥ Int(min_sources)
            push!(rows, (
                id = Int(r.id),
                n = Int(r.n),
                canonical_name = r.canonical_name === missing ? nothing : String(r.canonical_name),
                source_repo = repo,
                sources_count = length(sources),
            ))
        end
    end
    sort!(rows; by = r -> (-r.sources_count, r.id))
    rows
end

# ----------------------------------------------------------------------------
# Write API
# ----------------------------------------------------------------------------

"""
    record_disagreement!(db; n, present_in, absent_from, kind,
                         function_id = nothing,
                         resolution = nothing,
                         resolver = nothing,
                         resolved_date = nothing) -> Int

Insert a reconciliation row. Returns the new `id`. `present_in` and
`absent_from` are pipe-separated source-repo lists (e.g.,
`"sboxu@828b8ba|xanadu@xxxxxxx"`).
"""
function record_disagreement!(db::SQLite.DB;
                              n::Integer,
                              present_in::AbstractString,
                              absent_from::AbstractString,
                              kind::AbstractString,
                              function_id::Union{Nothing, Integer} = nothing,
                              lut_sha256::Union{Nothing, AbstractString} = nothing,
                              resolution::Union{Nothing, AbstractString} = nothing,
                              resolver::Union{Nothing, AbstractString} = nothing,
                              resolved_date::Union{Nothing, AbstractString} = nothing)
    fid = function_id === nothing ? "NULL" : string(Int(function_id))
    sha = lut_sha256 === nothing ? "NULL" : _sql_quote(String(lut_sha256))
    res = resolution === nothing ? "NULL" : _sql_quote(String(resolution))
    rsr = resolver === nothing ? "NULL" : _sql_quote(String(resolver))
    rdt = resolved_date === nothing ? "NULL" : _sql_quote(String(resolved_date))
    SQLite.execute(db, string(
        "INSERT INTO reconciliation_disagreements ",
        "(n, function_id, lut_sha256, present_in, absent_from, kind, ",
        " resolution, resolver, resolved_date) VALUES (",
        Int(n), ", ",
        fid, ", ",
        sha, ", ",
        _sql_quote(String(present_in)), ", ",
        _sql_quote(String(absent_from)), ", ",
        _sql_quote(String(kind)), ", ",
        res, ", ",
        rsr, ", ",
        rdt, ")"))
    id = 0
    for r in DBInterface.execute(db, "SELECT last_insert_rowid() AS id")
        id = Int(r.id)
    end
    id
end

"""
    merge_source_repo!(db, function_id::Integer, added_source::AbstractString) -> String

Append `added_source` to the `functions.source_repo` pipe-list for
`function_id` if it is not already present. Returns the new merged
value. Used by the importers to mark "this LUT was also found in
sboxU at SHA X".
"""
function merge_source_repo!(db::SQLite.DB, function_id::Integer, added_source::AbstractString)
    cur = ""
    for r in DBInterface.execute(db,
            "SELECT source_repo FROM functions WHERE id = $(Int(function_id)) LIMIT 1")
        cur = String(r.source_repo)
    end
    parts = split(cur, '|')
    added = String(added_source)
    added in parts && return cur
    new_val = isempty(cur) ? added : cur * "|" * added
    SQLite.execute(db, "UPDATE functions SET source_repo = " *
                       _sql_quote(new_val) *
                       " WHERE id = $(Int(function_id))")
    new_val
end
