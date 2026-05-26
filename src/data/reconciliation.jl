"""
Reconciliation across multiple S-box/APN databases.

The BFA catalog's `reconciliation_disagreements` table records every
case where the same abstract function appears differently across the
upstream sources we cross-check against (sboxU, Xanadu's
apn-ccz-graph-framework, `APN-Repository`, …). This module is the
read/write API over that table; the actual import scripts live under
`data-build/import_*_apn.jl`.

# Disagreement kinds (the `kind` column)
- `"only_in_some"`         — function present in some sources, absent from others (`present_in` / `absent_from` columns list which).
- `"differential_uniformity_disagree"` — sources report different DUs for the same function.
- `"ccz_equivalence_disagree"`         — one source claims `f ~ g` (CCZ), another disagrees. Reserved for Phase 8 when CCZ-equivalence tests land.
- `"odds_disagree"`                    — APN-Repository's ODDS value differs from BFA's recomputed value. Reserved for Phase 9.

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

const _RECON_COLUMNS = (:id, :n, :function_id, :present_in, :absent_from,
                        :kind, :resolution, :resolver, :resolved_date)

const _RECON_SELECT =
    "id, n, function_id, present_in, absent_from, kind, " *
    "resolution, resolver, resolved_date"

function _row_to_disagreement(r)
    NamedTuple{_RECON_COLUMNS}((
        Int(r.id),
        Int(r.n),
        r.function_id === missing ? nothing : Int(r.function_id),
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
                              resolution::Union{Nothing, AbstractString} = nothing,
                              resolver::Union{Nothing, AbstractString} = nothing,
                              resolved_date::Union{Nothing, AbstractString} = nothing)
    fid = function_id === nothing ? "NULL" : string(Int(function_id))
    res = resolution === nothing ? "NULL" : _sql_quote(String(resolution))
    rsr = resolver === nothing ? "NULL" : _sql_quote(String(resolver))
    rdt = resolved_date === nothing ? "NULL" : _sql_quote(String(resolved_date))
    SQLite.execute(db, string(
        "INSERT INTO reconciliation_disagreements ",
        "(n, function_id, present_in, absent_from, kind, resolution, resolver, resolved_date) ",
        "VALUES (",
        Int(n), ", ",
        fid, ", ",
        _sql_quote(String(present_in)), ", ",
        _sql_quote(String(absent_from)), ", ",
        _sql_quote(String(kind)), ", ",
        res, ", ",
        rsr, ", ",
        rdt, ")"))
    # last_insert_rowid via a separate query
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
