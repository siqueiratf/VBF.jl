using VBF
using VBFCatalog
import SQLite
import DBInterface
import Dates
import TOML

const CATALOG_FILE = VBFCatalog.catalog_path()
const LITERATURE_PATH = normpath(joinpath(@__DIR__, "..", "data-raw", "literature_sboxes.toml"))
const APN_CATALOG_DIR = normpath(joinpath(@__DIR__, "..", "data-raw", "apn_catalog"))

include(joinpath(@__DIR__, "load_sources.jl"))

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

function _chain_external_imports()
    config = TOML.parsefile(joinpath(@__DIR__, "sources.toml"))
    for src in get(config, "source", [])
        importer = joinpath(@__DIR__, src["importer"])
        isfile(importer) || continue
        label    = get(src, "label", src["name"])
        env_var  = get(src, "env_var", "")
        env_val  = get(ENV, env_var, "")
        # Sources without an upstream URL are local-only: only include their
        # script when the env var already points to a valid path.  This avoids
        # loading optional heavy dependencies (e.g. Parquet2, JSON3) into
        # projects that don't have them just because the importer script exists.
        # Sources that declare an upstream can always be included because
        # with_source() will auto-clone when the env var is unset.
        if !haskey(src, "upstream") &&
           !_bfa_check_valid(env_val, src["check_path"], get(src, "check_kind", "dir"))
            @warn "BFA: skipping $label (source unavailable; set $env_var to enable)"
            continue
        end
        # Clear the no_autorun guard so main() fires when we include the script.
        # A previous include in this chain may have set it as a side-effect
        # (e.g. import_quadratic_apn_8bit.jl sets BFA_SBOXU_NO_AUTORUN=1 to
        # guard its own nested include of import_sboxu_apn.jl).
        no_autorun = get(src, "no_autorun", "")
        saved_guard = isempty(no_autorun) ? nothing : pop!(ENV, no_autorun, nothing)
        try
            @info "Chaining $label import" importer
            include(importer)
        catch err
            @warn "$label import failed; the catalog is still usable" exception=(err, catch_backtrace())
        finally
            isempty(no_autorun) || (saved_guard === nothing ?
                delete!(ENV, no_autorun) : setindex!(ENV, saved_guard, no_autorun))
        end
    end
end

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
    _chain_external_imports()
    final_size = filesize(CATALOG_FILE)
    if final_size > 0
        @info "Final catalog size" file_size_bytes=final_size
    end
end

isinteractive() || main()
