# Imports the curated quadratic-APN CCZ-class representatives shipped in
# sboxU's `scripts/apnDB/{reprs6,reprs7,reprs8,eightBitAPN}.py` as
# first-class BFA `functions` rows (not reconciliation rows — these are
# canonical representatives worth materialising).
#
# The files are heterogeneous (the upstream is disorganised):
#   - reprs6.py  : `ccz_class_representatives = [get_sbox(POLY|[LUT]), ...]`, n=6
#   - reprs7.py  : `[get_sbox(x) for x in [ [LUT], ... ]]`,                  n=7
#   - reprs8.py  : `... return [get_sbox(POLY), ...]`,                       n=8
#   - eightBitAPN: `... return [poly_to_lut(POLY), ...]`,                    n=8
#
# Polynomials are evaluated over GF(2ⁿ) with the Conway polynomial (what
# Sage's `GF(2**n)` uses, so `g`/`ksi` ↦ the element 2). Two n=8 entries
# written as Python generator expressions (`X**3 + sum(X**(9*2**i) ...)`)
# are skipped — the recursive-descent parser handles polynomials, not
# Python comprehensions. Every imported LUT is asserted APN.
#
# Dedup: a LUT whose (sha, n) already names a `functions` row merges the
# source tag into that row instead of inserting a duplicate.
#
# Usage (uses BFA_SBOXU_PATH or default ~/sboxU):
#     julia --project=. data-build/import_apn_reps.jl

using BFA
import SQLite
import DBInterface
import Dates

include(joinpath(@__DIR__, "_polynomial_parser.jl"))

const _REPS_SBOXU_PATHS = (
    get(ENV, "BFA_SBOXU_PATH", ""),
    "/home/zambonin/APN.jl/lpp-crypto@sboxU",   # current layout (2026-05-28)
    joinpath(homedir(), "APN.jl", "lpp-crypto@sboxU"),
    joinpath(homedir(), "sboxU"),               # legacy fallbacks
    "/home/zambonin/sboxU",
)

function _apndb_dir()
    for p in _REPS_SBOXU_PATHS
        isempty(p) && continue
        d = joinpath(p, "sboxU", "scripts", "apnDB")
        isdir(d) && return d
    end
    error("BFA: cannot find sboxU/sboxU/scripts/apnDB; set BFA_SBOXU_PATH")
end

function _sboxu_short_sha(path::AbstractString)
    try
        return readchomp(`git -C $path rev-parse --short HEAD`)
    catch
        return "unknown"
    end
end

# --- extraction -------------------------------------------------------------

# Substring inside the parentheses opened at `text[open]=='('`, tracking
# nesting so polynomial sub-expressions like `g**16*(X**18 + X**33)` and
# bracketed LUTs are returned whole.
function _balanced_paren_arg(text::AbstractString, open::Int)
    depth = 0
    i = open
    n = lastindex(text)
    start = 0
    while i ≤ n
        c = text[i]
        if c == '('
            depth += 1
            depth == 1 && (start = nextind(text, i))
        elseif c == ')'
            depth -= 1
            depth == 0 && return text[start:prevind(text, i)]
        end
        i = nextind(text, i)
    end
    error("unbalanced parenthesis starting at $open")
end

# Every argument of `wrapper(...)` in `text`, as raw strings.
function _wrapper_args(text::AbstractString, wrapper::AbstractString)
    args = String[]
    pat = wrapper * "("
    idx = firstindex(text)
    while true
        r = findnext(pat, text, idx)
        r === nothing && break
        open = last(r)                       # index of '('
        arg = _balanced_paren_arg(text, open)
        push!(args, String(strip(arg)))
        idx = nextind(text, open)
    end
    args
end

# Every `[ integer, integer, ... ]` literal in `text` (the raw LUTs).
function _int_list_luts(text::AbstractString)
    luts = Vector{Int}[]
    pat = r"\[((?:\s*(?:0[xX][0-9a-fA-F]+|\d+)\s*,?\s*)+)\]"
    for m in eachmatch(pat, text)
        body = strip(m.captures[1])
        nums = [_parse_int_lit(s) for s in split(body, r"\s*,\s*"; keepempty = false)]
        push!(luts, nums)
    end
    luts
end

_parse_int_lit(s::AbstractString) =
    (t = strip(s); (startswith(t, "0x") || startswith(t, "0X")) ?
        parse(Int, t[3:end]; base = 16) : parse(Int, t))

_is_lut_arg(arg::AbstractString) = startswith(strip(arg), "[")
_is_unparseable_poly(arg::AbstractString) = occursin("sum(", arg) || occursin(" for ", arg)

# Parsed representative: (n, lut, label, kind) where kind ∈ {:poly, :lut}.
const RepEntry = NamedTuple{(:n, :lut, :label), Tuple{Int, Vector{Int}, String}}

# Turn a polynomial-or-LUT argument into a LUT, or `nothing` if it should
# be skipped: a raw `[LUT]`, a polynomial in `X`, or `nothing` for a
# generator expression / a spurious match (e.g. the `p` parameter of the
# `def poly_to_lut(p):` definition, which contains no `X`).
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
          BFA._sql_quote(String(sha)) * " LIMIT 1"
    for r in DBInterface.execute(db, sql)
        return Int(r.id)
    end
    nothing
end

function _insert_function_row!(db::SQLite.DB, s::SBox{N, T};
                               canonical_name::AbstractString,
                               source_repo::AbstractString,
                               contributor::AbstractString,
                               added_date::AbstractString,
                               notes::AbstractString) where {N, T}
    is_perm = is_permutation(s)
    du = differential_uniformity(s)
    lin = linearity(s)
    algdeg = algebraic_degree(s)
    bu = is_perm ? boomerang_uniformity(s) : nothing
    blob_literal = "X'" * bytes2hex(BFA.canonical_lut_bytes(s)) * "'"
    bu_literal = bu === nothing ? "NULL" : string(Int(bu))
    sql = string(
        "INSERT INTO functions (",
        "family, n, m, lut_sha256, lut_blob, algebraic_form, ",
        "algebraic_degree, differential_uniformity, linearity, boomerang_uniformity, ",
        "is_apn, is_permutation, is_quadratic, canonical_name, bib_key, ",
        "source_repo, contributor, added_date, notes) VALUES (",
        BFA._sql_quote("APN-rep"), ", ", N, ", ", N, ", ",
        BFA._sql_quote(lut_sha256_hex(s)), ", ", blob_literal, ", NULL, ",
        algdeg, ", ", Int(du), ", ", Int(lin), ", ", bu_literal, ", ",
        Int(du == 2), ", ", Int(is_perm), ", ", Int(algdeg ≤ 2), ", ",
        BFA._sql_quote(canonical_name), ", NULL, ",
        BFA._sql_quote(source_repo), ", ",
        BFA._sql_quote(contributor), ", ",
        BFA._sql_quote(added_date), ", ",
        BFA._sql_quote(notes), ")")
    SQLite.execute(db, sql)
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
            # First-class BFA catalog row originating from sboxU: tag both
            # so the "in-catalog rows include bfa" invariant holds and the
            # upstream provenance is preserved.
            _insert_function_row!(db, s;
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

function main()
    dir = _apndb_dir()
    sboxu_root = dirname(dirname(dirname(dir)))
    sha = _sboxu_short_sha(sboxu_root)
    tag = "sboxu@" * sha
    bfa_sha = try
        readchomp(`git -C $(pkgdir(BFA)) rev-parse --short HEAD`)
    catch
        "unknown"
    end
    bfa_repo = "bfa@" * bfa_sha
    contributor = "BFA APN reps import (automated)"
    added = string(Dates.now(Dates.UTC)) * "Z"
    @info "sboxU APN-reps import" dir sha bfa_sha

    sources = [
        ("reprs6",      () -> _entries_from_get_sbox(joinpath(dir, "reprs6.py"), 6, "reprs6")),
        ("reprs7",      () -> _entries_from_lut_comprehension(joinpath(dir, "reprs7.py"), 7, "reprs7")),
        ("reprs8",      () -> _entries_from_get_sbox(joinpath(dir, "reprs8.py"), 8, "reprs8")),
        ("eightBitAPN", () -> _entries_from_poly_to_lut(joinpath(dir, "eightBitAPN.py"), 8, "eightBitAPN")),
    ]

    db = load_catalog()
    try
        for (label, gen) in sources
            entries = try
                gen()
            catch err
                @warn "skipping reps source" label exception = err
                continue
            end
            st = import_reps!(db, entries, tag, label;
                              bfa_repo = bfa_repo,
                              contributor = contributor, added_date = added)
            _human(stdout, st, label)
        end
    finally
        close(db)
    end
    return nothing
end

# Auto-run when included by build_catalog.jl (non-interactive). The
# BFA_REPS_NO_AUTORUN guard lets tests `include` this file for its
# extraction helpers without touching the catalog.
if !isinteractive() && get(ENV, "BFA_REPS_NO_AUTORUN", "0") != "1"
    main()
end
