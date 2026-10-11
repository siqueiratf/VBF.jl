using VBF
using VBFCatalog
import SQLite
import DBInterface
import Dates

include("load_sources.jl")
include("write.jl")

include("readers.jl")
using .SourceReaders: _wrapper_args
const _int_list_luts=SourceReaders.parse_apn_lut_text

_is_lut_arg(arg::AbstractString) = startswith(strip(arg), "[")
_is_unparseable_poly(arg::AbstractString) = occursin("sum(", arg) || occursin(" for ", arg)

# Parsed representative: (n, lut, label, kind) where kind ∈ {:poly, :lut}.
const RepEntry = NamedTuple{(:n, :lut, :label), Tuple{Int, Vector{Int}, String}}

function _arg_to_lut(arg::AbstractString, n::Int)
    a = strip(arg)
    if _is_lut_arg(a)
        only_lut = _int_list_luts(a)
        isempty(only_lut) && return nothing
        return only_lut[1]
    end
    _is_unparseable_poly(a) && return nothing
    occursin('X', a) || return nothing        # not a polynomial (e.g. a def parameter)
    return polynomial_to_lut(a, n, conway_polynomial(n))
end

function _entries_from_get_sbox(path::AbstractString, n::Int, prefix::AbstractString)
    text = read(path, String)
    out = RepEntry[]
    for (k, arg) in enumerate(_wrapper_args(text, "get_sbox"))
        lut = _arg_to_lut(arg, n)
        lut === nothing && continue
        push!(out, (n = n, lut = lut, label = "$(prefix)_$(k - 1)"))
    end
    out
end

function _entries_from_poly_to_lut(path::AbstractString, n::Int, prefix::AbstractString)
    text = read(path, String)
    out = RepEntry[]
    for (k, arg) in enumerate(_wrapper_args(text, "poly_to_lut"))
        lut = _arg_to_lut(arg, n)
        lut === nothing && continue
        push!(out, (n = n, lut = lut, label = "$(prefix)_$(k - 1)"))
    end
    out
end

function _entries_from_lut_comprehension(path::AbstractString, n::Int, prefix::AbstractString)
    text = read(path, String)
    out = RepEntry[]
    for (k, lut) in enumerate(_int_list_luts(text))
        push!(out, (n = n, lut = lut, label = "$(prefix)_$(k - 1)"))
    end
    out
end

# --- insertion --------------------------------------------------------------

function _function_id_by_sha(db::SQLite.DB, sha::AbstractString)
    sql = "SELECT id FROM functions WHERE lut_sha256 = " *
          VBFCatalog._sql_quote(String(sha)) * " LIMIT 1"
    for r in DBInterface.execute(db, sql)
        return Int(r.id)
    end
    nothing
end

struct RepStats
    parsed::Int
    inserted::Int
    merged::Int
    not_apn::Int
end

function _human(io::IO, st::RepStats, label::AbstractString)
    println(io, "[reps:$label] parsed=$(st.parsed) inserted=$(st.inserted) ",
                "merged=$(st.merged) not_apn=$(st.not_apn)")
end

function import_reps!(db::SQLite.DB, entries::Vector{RepEntry}, source_tag::AbstractString,
                      label::AbstractString; bfa_repo::AbstractString,
                      contributor::AbstractString, added_date::AbstractString)
    parsed = inserted = merged = not_apn = 0
    for e in entries
        parsed += 1
        s = SBox{e.n}(e.lut)
        if differential_uniformity(s) != 2
            not_apn += 1
            continue
        end
        sha = lut_sha256_hex(s)
        fid = _function_id_by_sha(db, sha)
        if fid !== nothing
            merge_source_repo!(db, fid, source_tag)
            merged += 1
        else
            # First-class BFA catalog row originating from sboxU: tag both so the "in-catalog rows include bfa" invariant holds and the upstream provenance is preserved.
            insert_function!(db, s; family="APN-rep",
                canonical_name = e.label,
                source_repo = bfa_repo * "|" * source_tag,
                contributor = contributor,
                added_date = added_date,
                notes = "sboxU quadratic-APN CCZ-class representative ($label)")
            inserted += 1
        end
    end
    RepStats(parsed, inserted, merged, not_apn)
end

function _do_import(dir::AbstractString, sboxu_root::AbstractString)
    sha = source_revision(sboxu_root)
    tag = "sboxu@" * sha
    bfa_repo = "VBF"
    contributor = "BFA APN reps import (automated)"
    added = ""
    @info "sboxU APN-reps import" dir sha

    sources = [
        ("reprs6",      () -> _entries_from_get_sbox(joinpath(dir, "reprs6.py"), 6, "reprs6")),
        ("reprs7",      () -> _entries_from_lut_comprehension(joinpath(dir, "reprs7.py"), 7, "reprs7")),
        ("reprs8",      () -> _entries_from_get_sbox(joinpath(dir, "reprs8.py"), 8, "reprs8")),
        ("eightBitAPN", () -> _entries_from_poly_to_lut(joinpath(dir, "eightBitAPN.py"), 8, "eightBitAPN")),
    ]

    db = load_catalog()
    try
        for (label, gen) in sources
            entries = gen()
            st = import_reps!(db, entries, tag, label;
                              bfa_repo = bfa_repo,
                              contributor = contributor, added_date = added)
            _human(stdout, st, label)
        end
    finally
        close(db)
    end
end

function main()
    with_source("apn_reps") do sboxu_root
        dir = joinpath(sboxu_root, "sboxU", "scripts", "apnDB")
        _do_import(dir, sboxu_root)
    end
    return nothing
end

if abspath(PROGRAM_FILE)==(@__FILE__)
    main()
end
