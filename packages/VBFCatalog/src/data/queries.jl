"""
Catalog queries.

Thin functional layer over the SQLite catalog. Returns `NamedTuple` rows
(or `Nothing` for not-found) to avoid imposing a custom row type on the
caller; if you want an `SBox`, use [`load_sbox`](@ref).

Every helper opens its own iteration over the result set and copies row
values eagerly — never returns a `Vector{SQLite.Row}` (see the SQLite.jl
cursor caveat documented in `catalog.jl`).

# Public surface
- [`list_functions`](@ref)         — filtered list of catalog rows.
- [`find_function`](@ref)          — exactly one row by id or canonical_name.
- [`load_sbox`](@ref)              — materialise an `SBox` from a catalog row.
- [`count_functions`](@ref)        — fast count under the same filters.
"""

import SQLite
import DBInterface

# ---------------------------------------------------------------------------

const _FUNCTIONS_COLUMNS = (
    :id,
    :family,
    :n,
    :m,
    :lut_sha256,
    :algebraic_form,
    :algebraic_degree,
    :differential_uniformity,
    :linearity,
    :boomerang_uniformity,
    :is_apn,
    :is_permutation,
    :is_quadratic,
    :canonical_name,
    :bib_key,
    :source_repo,
    :contributor,
    :added_date,
    :notes,
)

const _FUNCTIONS_SELECT =
    "id, family, n, m, lut_sha256, algebraic_form, " *
    "algebraic_degree, differential_uniformity, linearity, boomerang_uniformity, " *
    "is_apn, is_permutation, is_quadratic, canonical_name, bib_key, " *
    "source_repo, contributor, added_date, notes"

function _row_to_namedtuple(r)
    NamedTuple{_FUNCTIONS_COLUMNS}((
        Int(r.id),
        String(r.family),
        Int(r.n),
        Int(r.m),
        String(r.lut_sha256),
        r.algebraic_form === missing ? nothing : String(r.algebraic_form),
        r.algebraic_degree === missing ? nothing : Int(r.algebraic_degree),
        r.differential_uniformity === missing ? nothing :
        Int(r.differential_uniformity),
        r.linearity === missing ? nothing : Int(r.linearity),
        r.boomerang_uniformity === missing ? nothing :
        Int(r.boomerang_uniformity),
        Bool(r.is_apn != 0),
        Bool(r.is_permutation != 0),
        Bool(r.is_quadratic != 0),
        r.canonical_name === missing ? nothing : String(r.canonical_name),
        r.bib_key === missing ? nothing : String(r.bib_key),
        String(r.source_repo),
        String(r.contributor),
        String(r.added_date),
        r.notes === missing ? nothing : String(r.notes),
    ))
end

function _where_clause(;
    family = nothing,
    n = nothing,
    is_apn = nothing,
    is_permutation = nothing,
    bib_key = nothing,
)
    clauses = String[]
    family !== nothing &&
        push!(clauses, "family = " * _sql_quote(String(family)))
    n !== nothing && push!(clauses, "n = " * string(Int(n)))
    is_apn !== nothing &&
        push!(clauses, "is_apn = " * string(Int(is_apn ? 1 : 0)))
    is_permutation !== nothing && push!(
        clauses,
        "is_permutation = " * string(Int(is_permutation ? 1 : 0)),
    )
    bib_key !== nothing &&
        push!(clauses, "bib_key = " * _sql_quote(String(bib_key)))
    isempty(clauses) ? "" : " WHERE " * join(clauses, " AND ")
end

"""
    list_functions(db; family, n, is_apn, is_permutation, bib_key, limit, offset)
        -> Vector{NamedTuple}

Filtered list of catalog rows. Every keyword is optional; pass `nothing`
(or omit) to skip the filter. Returns rows ordered by `id`.

# Examples
```julia
db = load_catalog()
list_functions(db; family = "Literature")           # all literature S-boxes
list_functions(db; n = 4)                           # every 4-bit entry
list_functions(db; is_apn = true)                   # APN-only
list_functions(db; bib_key = "AndersonBihamKnudsen1998Serpent")
```
"""
function list_functions(
    db::SQLite.DB;
    family = nothing,
    n = nothing,
    is_apn = nothing,
    is_permutation = nothing,
    bib_key = nothing,
    limit::Union{Nothing,Integer} = nothing,
    offset::Integer = 0,
)
    where = _where_clause(; family, n, is_apn, is_permutation, bib_key)
    tail = " ORDER BY id"
    limit !== nothing && (tail *= " LIMIT $(Int(limit)) OFFSET $(Int(offset))")
    sql = "SELECT " * _FUNCTIONS_SELECT * " FROM functions" * where * tail
    out = NamedTuple[]
    for r in DBInterface.execute(db, sql)
        push!(out, _row_to_namedtuple(r))
    end
    out
end

"""
    count_functions(db; family, n, is_apn, is_permutation, bib_key) -> Int

Number of catalog rows matching the same filters [`list_functions`](@ref) accepts.
"""
function count_functions(
    db::SQLite.DB;
    family = nothing,
    n = nothing,
    is_apn = nothing,
    is_permutation = nothing,
    bib_key = nothing,
)
    where = _where_clause(; family, n, is_apn, is_permutation, bib_key)
    sql = "SELECT COUNT(*) AS c FROM functions" * where
    for r in DBInterface.execute(db, sql)
        return Int(r.c)
    end
    0
end

"""
    find_function(db; id, canonical_name, lut_sha256) -> Union{NamedTuple, Nothing}

Exactly one row identified by any of `id`, `canonical_name`, or
`lut_sha256`. Exactly one of those keywords must be supplied. Returns
`nothing` if no row matches.
"""
function find_function(
    db::SQLite.DB;
    id = nothing,
    canonical_name = nothing,
    lut_sha256 = nothing,
)
    count(!=(nothing), (id, canonical_name, lut_sha256)) == 1 || throw(
        ArgumentError(
            "find_function: pass exactly one of id, canonical_name, lut_sha256",
        ),
    )
    where = if id !== nothing
        "id = " * string(Int(id))
    elseif canonical_name !== nothing
        "canonical_name = " * _sql_quote(String(canonical_name))
    else
        "lut_sha256 = " * _sql_quote(String(lut_sha256))
    end
    sql =
        "SELECT " *
        _FUNCTIONS_SELECT *
        " FROM functions WHERE " *
        where *
        " LIMIT 1"
    for r in DBInterface.execute(db, sql)
        return _row_to_namedtuple(r)
    end
    nothing
end

"""
    load_sbox(db, id::Integer) -> SBox
    load_sbox(db, canonical_name::AbstractString) -> SBox

Materialise the `SBox` from a catalog row by reconstructing the LUT
from the `lut_blob` column and the canonical byte layout
(`ceil(m/8)` LE bytes per entry).

Throws `ArgumentError` if no such row exists.
"""
function load_sbox(db::SQLite.DB, id::Integer)
    sql =
        "SELECT n, m, lut_blob FROM functions WHERE id = " *
        string(Int(id)) *
        " LIMIT 1"
    return _materialise_sbox(db, sql, "id = $id")
end

function load_sbox(db::SQLite.DB, canonical_name::AbstractString)
    sql =
        "SELECT n, m, lut_blob FROM functions WHERE canonical_name = " *
        _sql_quote(String(canonical_name)) *
        " LIMIT 1"
    return _materialise_sbox(
        db,
        sql,
        "canonical_name = $(repr(canonical_name))",
    )
end

function _materialise_sbox(db, sql, locator)
    for r in DBInterface.execute(db, sql)
        n = Int(r.n)
        m = Int(r.m)
        n == m || throw(
            ArgumentError(
                "load_sbox: catalog row has n=$n ≠ m=$m; rectangular S-boxes not yet supported",
            ),
        )
        bytes_per_entry = cld(n, 8)
        blob = Vector{UInt8}(r.lut_blob)
        len = 1 << n
        lut = Vector{Int}(undef, len)
        @inbounds for i = 1:len
            offset = (i - 1) * bytes_per_entry
            v = 0
            for b = 0:(bytes_per_entry-1)
                v |= Int(blob[offset+b+1]) << (8 * b)
            end
            lut[i] = v
        end
        return SBox{n}(lut)
    end
    throw(ArgumentError("load_sbox: no catalog row for $locator"))
end
