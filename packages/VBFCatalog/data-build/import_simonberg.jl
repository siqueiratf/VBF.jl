# Imports Simon Berg's thesis data — "All CCZ classes of functions with
# coefficients in GF(2²) over GF(2⁸)" — into the BFA catalog.
#
# Layout: 27 files `rep1.txt … rep27.txt`, each a flat Sage/Magma list
# `[ poly, poly, … ]` of quadratic-APN polynomials over GF(2⁸) (generator
# `a`, coefficients in the GF(4) subgroup {1, a^85, a^170}, exponents < 256).
# All members of one file are CCZ-equivalent (one class per file, verified by
# distinct ortho-derivative differential+Walsh fingerprints across files); the
# 27 files are 27 distinct CCZ classes, with 2k–12k members each (~205k total).
#
# Ingestion policy (user decision, 2026-05-28): "representatives as rows +
# membership matches only".
#   - The first polynomial of each class is materialised as a first-class
#     `functions` row (family `CCZ-rep-GF4`), or, if its LUT already names a
#     row, its source tag is merged in.
#   - Every member's LUT SHA-256 is computed; a member that coincides with a
#     *pre-existing* catalog function (from any other source) has the Simon-Berg
#     source tag merged into that row. Non-matching members are counted (the
#     per-class member count is recorded in the representative row's notes) but
#     NOT stored as individual reconciliation rows.
#
# Polynomials are evaluated over GF(2⁸) with the Conway polynomial (matching
# Sage's `GF(2**8)`, so `a`/`ksi` ↦ the element 2). One-off developer step;
# BFA never depends on the thesis checkout at runtime.
#
# Usage (uses BFA_THESIS_PATH or the default APN.jl layout):
#     julia --project=. data-build/import_simonberg.jl

using VBF
using VBFCatalog
import SQLite
import DBInterface
import Dates


const _THESIS_PATHS = (
    get(ENV, "BFA_THESIS_PATH", ""),
    "/home/zambonin/APN.jl/Simon-Berg@thesis",
    joinpath(homedir(), "APN.jl", "Simon-Berg@thesis"),
)

function _thesis_dir()
    for p in _THESIS_PATHS
        isempty(p) && continue
        isfile(joinpath(p, "rep1.txt")) && return p
    end
    error("BFA: cannot find Simon-Berg@thesis; set BFA_THESIS_PATH")
end

function _thesis_short_sha(path::AbstractString)
    try
        return readchomp(`git -C $path rev-parse --short HEAD`)
    catch
        return "unknown"
    end
end

# --- parsing ----------------------------------------------------------------

# The polynomial strings of one `repN.txt`. The file is a single flat list
# `[ p1, p2, … ]` with no nested brackets, so top-level commas separate the
# polynomials.
function _class_polynomials(path::AbstractString)
    body = strip(read(path, String))
    (startswith(body, "[") && endswith(body, "]")) ||
        error("simonberg: $path is not a `[ … ]` list")
    body = strip(body[nextind(body, firstindex(body)):prevind(body, lastindex(body))])
    out = String[]
    for p in split(body, ','; keepempty = false)
        s = strip(replace(p, '\n' => ' '))
        isempty(s) || push!(out, s)
    end
    out
end

# --- catalog access ---------------------------------------------------------

# sha => row id for every existing `functions` row (snapshot before import).
function _existing_function_shas(db::SQLite.DB)
    d = Dict{String, Int}()
    for r in DBInterface.execute(db, "SELECT id, lut_sha256 FROM functions")
        d[String(r.lut_sha256)] = Int(r.id)
    end
    d
end

function _insert_ccz_rep_row!(db::SQLite.DB, s::SBox{N, T};
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
    blob_literal = "X'" * bytes2hex(VBFCatalog.canonical_lut_bytes(s)) * "'"
    bu_literal = bu === nothing ? "NULL" : string(Int(bu))
    sql = string(
        "INSERT INTO functions (",
        "family, n, m, lut_sha256, lut_blob, algebraic_form, ",
        "algebraic_degree, differential_uniformity, linearity, boomerang_uniformity, ",
        "is_apn, is_permutation, is_quadratic, canonical_name, bib_key, ",
        "source_repo, contributor, added_date, notes) VALUES (",
        VBFCatalog._sql_quote("CCZ-rep-GF4"), ", ", N, ", ", N, ", ",
        VBFCatalog._sql_quote(lut_sha256_hex(s)), ", ", blob_literal, ", NULL, ",
        algdeg, ", ", Int(du), ", ", Int(lin), ", ", bu_literal, ", ",
        Int(du == 2), ", ", Int(is_perm), ", ", Int(algdeg ≤ 2), ", ",
        VBFCatalog._sql_quote(canonical_name), ", NULL, ",
        VBFCatalog._sql_quote(source_repo), ", ",
        VBFCatalog._sql_quote(contributor), ", ",
        VBFCatalog._sql_quote(added_date), ", ",
        VBFCatalog._sql_quote(notes), ")")
    SQLite.execute(db, sql)
end

# --- import -----------------------------------------------------------------

struct ClassStats
    class::Int
    members::Int          # polynomials in the file
    rep_inserted::Bool    # representative added as a new row (vs merged)
    matched::Int          # members coinciding with a PRE-EXISTING catalog row
end

function _human(io::IO, st::ClassStats)
    println(io, "[simonberg:class $(st.class)] members=$(st.members) ",
                "rep=$(st.rep_inserted ? "inserted" : "merged") ",
                "matched_preexisting=$(st.matched)")
end

# Evaluate one polynomial string to an SBox{n}.
function _poly_sbox(expr::AbstractString, powtab::Vector{Vector{Int}}, n::Int, modulus::Int)
    terms = polynomial_terms(expr, n, modulus)
    SBox{n}(terms_to_lut(terms, n, modulus; powtab = powtab))
end

function import_one_class!(db::SQLite.DB, path::AbstractString, class::Int;
                           source_tag::AbstractString, bfa_repo::AbstractString,
                           contributor::AbstractString, added_date::AbstractString,
                           existing::Dict{String, Int}, powtab::Vector{Vector{Int}},
                           n::Int, modulus::Int)
    polys = _class_polynomials(path)
    isempty(polys) && error("simonberg: class $class has no polynomials")
    matched = 0
    merge_ids = Set{Int}()      # pre-existing rows to tag (dedup per id)

    # representative = first member; assert it is APN (a cheap validation that
    # the parser + Conway field reproduce a genuine quadratic-APN function).
    rep = _poly_sbox(polys[1], powtab, n, modulus)
    differential_uniformity(rep) == 2 || error("simonberg: class $class representative not APN")
    rep_sha = lut_sha256_hex(rep)
    rep_inserted = false
    if haskey(existing, rep_sha)
        push!(merge_ids, existing[rep_sha])      # rep already in catalog → tag it
    else
        _insert_ccz_rep_row!(db, rep;
            canonical_name = "SimonBerg_GF4_n8_class_$(class)",
            source_repo = bfa_repo * "|" * source_tag,
            contributor = contributor, added_date = added_date,
            notes = "Simon-Berg thesis: representative of CCZ class $(class) of " *
                    "GF(2²)-coefficient quadratic APN over GF(2⁸); $(length(polys)) members")
        rep_inserted = true
    end

    # every member: tag a PRE-EXISTING catalog row if its LUT coincides (the
    # "membership matches only" policy — non-matching members are counted, not
    # stored). Only the SHA is needed, so we skip a per-member APN check.
    for (k, p) in enumerate(polys)
        sha = k == 1 ? rep_sha : lut_sha256_hex(_poly_sbox(p, powtab, n, modulus))
        if haskey(existing, sha)
            push!(merge_ids, existing[sha])
            matched += 1
        end
    end

    for id in merge_ids
        merge_source_repo!(db, id, source_tag)
    end
    ClassStats(class, length(polys), rep_inserted, matched)
end

function main()
    dir = _thesis_dir()
    sha = _thesis_short_sha(dir)
    tag = "simonberg@" * sha
    bfa_sha = try
        readchomp(`git -C $(pkgdir(VBF)) rev-parse --short HEAD`)
    catch
        "unknown"
    end
    bfa_repo = "bfa@" * bfa_sha
    contributor = "BFA Simon-Berg import (automated)"
    added = string(Dates.now(Dates.UTC)) * "Z"
    n = 8
    modulus = conway_polynomial(n)
    @info "Simon-Berg thesis import" dir sha bfa_sha

    powtab = monomial_power_table(n, modulus)
    db = load_catalog()
    try
        existing = _existing_function_shas(db)
        total_members = total_matched = total_inserted = 0
        for class in 1:27
            path = joinpath(dir, "rep$(class).txt")
            isfile(path) || (@warn "skipping (missing)" path; continue)
            st = import_one_class!(db, path, class;
                source_tag = tag, bfa_repo = bfa_repo,
                contributor = contributor, added_date = added,
                existing = existing, powtab = powtab, n = n, modulus = modulus)
            _human(stdout, st)
            total_members += st.members
            total_matched += st.matched
            total_inserted += st.rep_inserted ? 1 : 0
        end
        println("[simonberg] TOTAL members=$(total_members) rep_rows_inserted=$(total_inserted) ",
                "member_matches_into_preexisting=$(total_matched)")
    finally
        close(db)
    end
    return nothing
end

# Auto-run when included by build_catalog.jl (non-interactive). The
# BFA_SIMONBERG_NO_AUTORUN guard lets tests `include` this file for its
# helpers without touching the catalog.
if !isinteractive() && get(ENV, "BFA_SIMONBERG_NO_AUTORUN", "0") != "1"
    main()
end
