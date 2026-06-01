using VBF
using VBFCatalog
import SQLite
import DBInterface
import Dates

const CATALOG_FILE = VBFCatalog.catalog_path()
const LITERATURE_PATH = normpath(joinpath(@__DIR__, "..", "data-raw", "literature_sboxes.toml"))
const APN_CATALOG_DIR = normpath(joinpath(@__DIR__, "..", "data-raw", "apn_catalog"))

function _git_sha()
    try
        return readchomp(`git -C $(pkgdir(VBF)) rev-parse --short HEAD`)
    catch
        return "unknown"
    end
end

function _today_utc()
    string(Dates.now(Dates.UTC)) * "Z"
end

function _reconstruct_bibtex(entry::BibEntry)
    # round-trip the parsed entry back into a canonical BibTeX block, so the catalog's `bibtex` column is human-readable and tool-consumable (Mendeley/Zotero import, etc.)
    io = IOBuffer()
    print(io, "@", entry.entry_type, "{", entry.bib_key)
    for (k, v) in sort(collect(entry.fields); by = first)
        print(io, ",\n    ", k, " = {", v, "}")
    end
    print(io, "\n}")
    String(take!(io))
end

function insert_bibliography!(db::SQLite.DB)
    bib = load_bibliography()
    for entry in bib
        year = parse(Int, strip(get(entry, "year", "0")))
        authors = get(entry, "author", "")
        doi = get(entry, "doi", "")
        url = get(entry, "url", "")
        sql = string(
            "INSERT INTO bibliography (bib_key, bibtex, doi, url, year, authors) VALUES (",
            VBFCatalog._sql_quote(entry.bib_key), ", ",
            VBFCatalog._sql_quote(_reconstruct_bibtex(entry)), ", ",
            VBFCatalog._sql_quote(doi), ", ",
            VBFCatalog._sql_quote(url), ", ",
            year, ", ",
            VBFCatalog._sql_quote(authors), ")")
        SQLite.execute(db, sql)
    end
end

function insert_literature_sboxes!(db::SQLite.DB, contributor::AbstractString,
                                    source_repo::AbstractString)
    today = _today_utc()
    for name in literature_sbox_names()
        meta = literature_sbox_metadata(name)
        s = load_literature_sbox(name)
        n = inputbits(s)
        is_perm = is_permutation(s)

        # Compute statistics
        du = differential_uniformity(s)
        lin = linearity(s)
        algdeg = algebraic_degree(s)
        bu = is_perm ? boomerang_uniformity(s) : nothing
        is_quad = algdeg ≤ 2

        # BLOB serialisation + content hash
        bytes = VBFCatalog.canonical_lut_bytes(s)
        sha = VBFCatalog.lut_sha256_hex(s)

        # SQLite BLOB literal: X'...'  (uppercase hex preferred but we use lowercase)
        blob_literal = "X'" * bytes2hex(bytes) * "'"
        bu_literal = bu === nothing ? "NULL" : string(Int(bu))

        sql = string(
            "INSERT INTO functions (",
            "family, n, m, lut_sha256, lut_blob, algebraic_form, ",
            "algebraic_degree, differential_uniformity, linearity, boomerang_uniformity, ",
            "is_apn, is_permutation, is_quadratic, canonical_name, bib_key, ",
            "source_repo, contributor, added_date, notes) VALUES (",
            VBFCatalog._sql_quote("Literature"), ", ", n, ", ", n, ", ",
            VBFCatalog._sql_quote(sha), ", ", blob_literal, ", NULL, ",
            algdeg, ", ", Int(du), ", ", Int(lin), ", ", bu_literal, ", ",
            Int(du == 2), ", ",
            Int(is_perm), ", ",
            Int(is_quad), ", ",
            VBFCatalog._sql_quote(name), ", ",
            VBFCatalog._sql_quote(meta["bib_key"]), ", ",
            VBFCatalog._sql_quote(source_repo), ", ",
            VBFCatalog._sql_quote(contributor), ", ",
            VBFCatalog._sql_quote(today), ", ",
            VBFCatalog._sql_quote(meta["description"]), ")")
        SQLite.execute(db, sql)
    end
end

function insert_apn_functions!(db::SQLite.DB, contributor::AbstractString,
                                source_repo::AbstractString)
    today = _today_utc()
    for name in apn_catalog_names()
        meta = apn_catalog_metadata(name)
        s = load_apn_function(name)        # also verifies DU == 2
        n = inputbits(s)
        is_perm = is_permutation(s)

        du = differential_uniformity(s)
        lin = linearity(s)
        algdeg = algebraic_degree(s)
        bu = is_perm ? boomerang_uniformity(s) : nothing
        is_quad = algdeg ≤ 2

        bytes = VBFCatalog.canonical_lut_bytes(s)
        sha = VBFCatalog.lut_sha256_hex(s)

        blob_literal = "X'" * bytes2hex(bytes) * "'"
        bu_literal = bu === nothing ? "NULL" : string(Int(bu))
        algform_literal = haskey(meta, "algebraic_form") ?
            VBFCatalog._sql_quote(meta["algebraic_form"]) : "NULL"

        sql = string(
            "INSERT INTO functions (",
            "family, n, m, lut_sha256, lut_blob, algebraic_form, ",
            "algebraic_degree, differential_uniformity, linearity, boomerang_uniformity, ",
            "is_apn, is_permutation, is_quadratic, canonical_name, bib_key, ",
            "source_repo, contributor, added_date, notes) VALUES (",
            VBFCatalog._sql_quote("APN"), ", ", n, ", ", n, ", ",
            VBFCatalog._sql_quote(sha), ", ", blob_literal, ", ", algform_literal, ", ",
            algdeg, ", ", Int(du), ", ", Int(lin), ", ", bu_literal, ", ",
            Int(du == 2), ", ",
            Int(is_perm), ", ",
            Int(is_quad), ", ",
            VBFCatalog._sql_quote(name), ", ",
            VBFCatalog._sql_quote(meta["bib_key"]), ", ",
            VBFCatalog._sql_quote(source_repo), ", ",
            VBFCatalog._sql_quote(contributor), ", ",
            VBFCatalog._sql_quote(today), ", ",
            VBFCatalog._sql_quote(meta["description"]), ")")
        SQLite.execute(db, sql)
    end
end

"""
    _maybe_chain_sboxu_import()

Best-effort post-step. If `data-build/import_sboxu_apn.jl` is present
and sboxU is checked out at one of the well-known locations, run its
`main()` to populate `reconciliation_disagreements`. Failures are
warnings, not errors: the catalog is still usable without the import.
"""
function _maybe_chain_import(script_name::AbstractString, env_var::AbstractString,
                              default_paths::Tuple, label::AbstractString;
                              check::Function = isdir)
    importer = joinpath(@__DIR__, script_name)
    isfile(importer) || return
    candidates = (get(ENV, env_var, ""), default_paths...)
    any(c -> !isempty(c) && check(c), candidates) ||
        (@warn "skipping $label import (no checkout found); set $env_var to enable"; return)
    try
        @info "Chaining into $label import" importer
        include(importer)
    catch err
        @warn "$label import failed; the catalog is still usable" exception=(err, catch_backtrace())
    end
end

_maybe_chain_sboxu_import() =
    _maybe_chain_import("import_sboxu_apn.jl", "BFA_SBOXU_PATH",
        ("/home/zambonin/APN.jl/lpp-crypto@sboxU",
         joinpath(homedir(), "APN.jl", "lpp-crypto@sboxU"),
         joinpath(homedir(), "sboxU"), "/home/zambonin/sboxU"),
        "sboxU";
        check = p -> isdir(joinpath(p, "sboxU", "scripts", "apnDB")))

_maybe_chain_reps_import() =
    _maybe_chain_import("import_apn_reps.jl", "BFA_SBOXU_PATH",
        ("/home/zambonin/APN.jl/lpp-crypto@sboxU",
         joinpath(homedir(), "APN.jl", "lpp-crypto@sboxU"),
         joinpath(homedir(), "sboxU"), "/home/zambonin/sboxU"),
        "APN reps";
        check = p -> isdir(joinpath(p, "sboxU", "scripts", "apnDB")))

# Simon-Berg thesis: 27 CCZ classes of GF(2²)-coefficient quadratic APN over GF(2⁸). 27 class representatives → first-class rows; membership SHAs merged into matching rows only. Runs alongside the other rep/reconciliation chains.
_maybe_chain_simonberg_import() =
    _maybe_chain_import("import_simonberg.jl", "BFA_THESIS_PATH",
        ("/home/zambonin/APN.jl/Simon-Berg@thesis",
         joinpath(homedir(), "APN.jl", "Simon-Berg@thesis")),
        "Simon-Berg thesis";
        check = p -> isfile(joinpath(p, "rep1.txt")))

_maybe_chain_xanadu_import() =
    _maybe_chain_import("import_xanadu_apn.jl", "BFA_XANADU_PATH",
        ("/home/zambonin/APN.jl/Xanadu-ins@apn-ccz-graph-framework",
         joinpath(homedir(), "APN.jl", "Xanadu-ins@apn-ccz-graph-framework"),
         joinpath(homedir(), "sboxU", "apn-ccz-graph-framework"),
         "/home/zambonin/sboxU/apn-ccz-graph-framework"),
        "Xanadu";
        check = p -> isfile(joinpath(p, "list_of_APN_functions_for_different_n")))

_maybe_chain_apn_repo_import() =
    _maybe_chain_import("import_apn_repository.jl", "BFA_APN_REPO_PATH",
        ("/home/zambonin/APN.jl/cma029@APN-Repository",
         joinpath(homedir(), "APN.jl", "cma029@APN-Repository"),
         joinpath(homedir(), "sboxU", "APN-Repository"),
         "/home/zambonin/sboxU/APN-Repository"),
        "APN-Repository";
        check = p -> isdir(joinpath(p, "database", "apn")))

function main()
    sha = _git_sha()
    source_repo = "bfa@" * sha
    @info "Building BFA catalog" path=CATALOG_FILE source_repo
    db = create_catalog(CATALOG_FILE;
                         bfa_version = "0.1.0-DEV",
                         git_sha = sha)
    insert_bibliography!(db)
    insert_literature_sboxes!(db, "BFA literature import (automated)", source_repo)
    insert_apn_functions!(db, "BFA APN catalog import (automated)", source_repo)
    n_funcs = 0
    for r in DBInterface.execute(db, "SELECT COUNT(*) AS c FROM functions")
        n_funcs = r.c
    end
    @info "Catalog populated (BFA-only step)" functions=n_funcs file_size_bytes=filesize(CATALOG_FILE)
    close(db)
    _maybe_chain_reps_import()
    _maybe_chain_simonberg_import()
    _maybe_chain_sboxu_import()
    _maybe_chain_xanadu_import()
    _maybe_chain_apn_repo_import()
    final_size = filesize(CATALOG_FILE)
    if final_size > 0
        @info "Final catalog size" file_size_bytes=final_size
    end
end

isinteractive() || main()
