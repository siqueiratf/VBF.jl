"""Catalog paths, content addresses and read APIs; all mathematical work uses VBF."""

import SQLite, DBInterface, SHA

const SCHEMA_VERSION = 9

"""Tracked source inputs, overridable with BFA_SOURCE_DIR."""
catalog_source_dir() = abspath(get(ENV,"BFA_SOURCE_DIR",joinpath(pkgdir(VBFCatalog),"src","data")))

"""Generated catalog path; override with BFA_CATALOG_PATH."""
function catalog_path()
    override=get(ENV,"BFA_CATALOG_PATH","")
    isempty(override) ? joinpath(catalog_data_dir(),"catalog.sqlite") : normpath(override)
end

"""Actual database filename, including for read-only SQLite URI handles."""
function catalog_path(db::SQLite.DB)
    rows=DBInterface.execute(db,"PRAGMA database_list")
    try
        for row in rows
            row.name=="main" && return String(row.file)
        end
        error("catalog has no main database")
    finally
        DBInterface.close!(rows)
    end
end

"""Check whether a generated database exists; does not validate its schema."""
is_catalog_built(path::AbstractString=catalog_path()) = isfile(path) && filesize(path)>0

"""Canonical LUT bytes: ceil(n/8) little-endian bytes per output, in input order."""
function canonical_lut_bytes(s::SBox{N,T}) where {N,T}
    bytes_per_entry = cld(N, 8)
    n = 1 << N
    out = Vector{UInt8}(undef, n * bytes_per_entry)
    @inbounds for (i, v) in pairs(s.lut)
        offset = (i - 1) * bytes_per_entry
        vi = UInt(v)
        for b = 0:(bytes_per_entry-1)
            out[offset+b+1] = UInt8((vi >> (8 * b)) & 0xff)
        end
    end
    out
end

"""
    lut_sha256_hex(s::SBox) -> String

Lowercase hex string of `SHA.sha256(canonical_lut_bytes(s))`. The
catalog's UNIQUE constraint is on `(lut_sha256, n)` so this string is
the deduplication key.
"""
lut_sha256_hex(s::SBox) = bytes2hex(SHA.sha256(canonical_lut_bytes(s)))

"""Open a built catalog; reject missing files or incompatible schema versions."""
function load_catalog(path::AbstractString=catalog_path())
    isfile(path) || throw(ArgumentError("catalog missing at $path; run make -C $(joinpath(pkgdir(VBFCatalog),"src","import")) catalog"))
    db=SQLite.DB(path)
    try
        _verify_schema!(db,path)
    catch
        close(db)
        rethrow()
    end
    db
end

function _verify_schema!(db::SQLite.DB,path::AbstractString)
    rows=DBInterface.execute(db,"SELECT schema_version FROM schema_meta")
    versions=try
        [Int(row.schema_version) for row in rows]
    finally
        DBInterface.close!(rows)
    end
    versions==[SCHEMA_VERSION] || throw(ArgumentError("$path has incompatible or missing schema metadata; rebuild the catalog"))
    db
end

_sql_quote(value::AbstractString) = "'"*replace(value,"'"=>"''")*"'"

const _FUNCTIONS_COLUMNS = (:id, :family, :n, :m, :lut_sha256, :algebraic_form,
    :algebraic_degree, :differential_uniformity, :linearity, :boomerang_uniformity,
    :is_apn, :is_permutation, :is_quadratic, :canonical_name, :bib_key,
    :source_repo, :contributor, :added_date, :notes)
const _FUNCTIONS_SELECT = join(string.(_FUNCTIONS_COLUMNS), ",")

function _row_to_namedtuple(row)
    values = map(_FUNCTIONS_COLUMNS) do key
        value = getproperty(row, key)
        key in (:is_apn, :is_permutation, :is_quadratic) ? Bool(value) :
            ismissing(value) ? nothing : value
    end
    NamedTuple{_FUNCTIONS_COLUMNS}(values)
end

function _function_filters(; family=nothing, n=nothing, is_apn=nothing,
        is_permutation=nothing, bib_key=nothing)
    clauses, values = String[], Any[]
    for (key, value, type) in (("family",family,String), ("n",n,Int),
            ("is_apn",is_apn,Int), ("is_permutation",is_permutation,Int),
            ("bib_key",bib_key,String))
        value === nothing && continue
        push!(clauses, key*"=?"); push!(values, type(value))
    end
    (isempty(clauses) ? "" : " WHERE "*join(clauses," AND "), values)
end

"""List function metadata, filtered by family, dimension, APN/permutation flags or citation.

Rows follow increasing IDs; `limit` and `offset` optionally select a page.
Nullable fields return `nothing`, and property flags return Boolean values.
"""
function list_functions(db::SQLite.DB; limit::Union{Nothing,Integer}=nothing,
        offset::Integer=0, kwargs...)
    where, values = _function_filters(;kwargs...)
    tail = " ORDER BY id"
    if limit !== nothing
        tail *= " LIMIT ? OFFSET ?"; append!(values, [Int(limit),Int(offset)])
    end
    rows = DBInterface.execute(db, "SELECT "*_FUNCTIONS_SELECT*" FROM functions"*where*tail, values)
    try
        [_row_to_namedtuple(row) for row in rows]
    finally
        DBInterface.close!(rows)
    end
end

"""Count functions with the same filters as `list_functions`."""
function count_functions(db::SQLite.DB; kwargs...)
    where, values = _function_filters(;kwargs...)
    rows = DBInterface.execute(db, "SELECT COUNT(*) c FROM functions"*where, values)
    try
        only(Int(row.c) for row in rows)
    finally
        DBInterface.close!(rows)
    end
end

"""Find one function by exactly one of ID, canonical name or LUT SHA-256; return nothing if absent."""
function find_function(db::SQLite.DB; id=nothing, canonical_name=nothing, lut_sha256=nothing)
    keys = filter(pair->last(pair)!==nothing,
        ["id"=>id, "canonical_name"=>canonical_name, "lut_sha256"=>lut_sha256])
    length(keys)==1 || throw(ArgumentError("pass exactly one of id, canonical_name, lut_sha256"))
    key, value = only(keys)
    rows = DBInterface.execute(db,"SELECT "*_FUNCTIONS_SELECT*" FROM functions WHERE $key=? LIMIT 1",(value,))
    try
        for row in rows
            return _row_to_namedtuple(row)
        end
        nothing
    finally
        DBInterface.close!(rows)
    end
end

"""Load a square SBox by function ID or canonical name; absent records raise ArgumentError."""
function load_sbox(db::SQLite.DB, locator::Union{Integer,AbstractString})
    key = locator isa Integer ? "id" : "canonical_name"
    rows = DBInterface.execute(db,"SELECT n,m,lut_blob FROM functions WHERE $key=? LIMIT 1",(locator,))
    try
        for row in rows
            row.n==row.m || throw(ArgumentError("rectangular catalog functions are unsupported"))
            return _sbox_from_blob(Vector{UInt8}(row.lut_blob),Int(row.n))
        end
        throw(ArgumentError("no catalog function for $key=$(repr(locator))"))
    finally
        DBInterface.close!(rows)
    end
end

"""Decode canonical little-endian LUT bytes in input order."""
function _sbox_from_blob(blob::AbstractVector{UInt8}, n::Integer)
    width = cld(n,8)
    length(blob)==(1<<n)*width || error("invalid canonical LUT width")
    SBox{n}([sum(Int(blob[x*width+b+1]) << (8b) for b in 0:width-1) for x in 0:(1<<n)-1])
end
