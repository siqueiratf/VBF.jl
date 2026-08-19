#!/usr/bin/env julia
#
# Sync the declarative `APN` family from data-raw/apn_catalog/ into an EXISTING
# BFA_catalog.sqlite, in place.
#
# WHY THIS EXISTS
#
# `build_catalog.jl` calls `create_catalog()`, which recreates the database from
# scratch and then chains the importers listed in `sources.toml`. Three of those
# importers (`simonberg`, `xanadu`, `apn_repo`) declare no `upstream` URL, so
# without `BFA_THESIS_PATH` / `BFA_XANADU_PATH` / `BFA_APN_REPO_PATH` pointing at
# local checkouts they are skipped with a warning; `known_families` and
# `known_sporadic` are Makefile targets that `sources.toml` never lists, so a
# rebuild never runs them at all. On a clone without those checkouts a full
# rebuild therefore DROPS the CCZ-rep-GF4, known-family and known-sporadic rows
# and still fails the gate.
#
# That left the catalog in a state where a data-raw correction could not be
# carried into the DB by any sanctioned command. This script closes that hole
# for the one family that data-raw actually owns.
#
# WHAT IT DOES AND DOES NOT DO
#
# Touches rows with `family = 'APN'` and nothing else. Inserts declared entries
# that are absent, updates entries whose stored fields drifted from the TOML,
# and deletes `APN` rows no longer declared. Every function is re-verified APN by
# `load_apn_function` before it is written, exactly as `build_catalog.jl` does.
# Derived columns are recomputed here, never copied from the old row.
#
# It is NOT a substitute for a full rebuild. It does not touch the bibliography,
# the literature S-boxes, or any importer-backed family. Run the full rebuild
# once the external sources are available.
#
# Usage:
#   julia --project=packages/VBFCatalog/data-build packages/VBFCatalog/data-build/sync_apn_family.jl
#   ... --dry-run    report what would change and write nothing
#
# Then run the gate, which is what actually certifies the result:
#   make -C packages/VBFCatalog/data-build check

using VBF
using VBFCatalog
import SQLite
import DBInterface
import Dates

const DRY_RUN = "--dry-run" in ARGS

_today_utc() = string(Dates.now(Dates.UTC)) * "Z"

function _git_sha()
    try
        return readchomp(`git -C $(pkgdir(VBF)) rev-parse --short HEAD`)
    catch
        return "unknown"
    end
end

"""
Every column `insert_apn_functions!` in build_catalog.jl writes, recomputed from
the catalog entry rather than read back from the database.
"""
function _row_values(name::AbstractString)
    meta = apn_catalog_metadata(name)
    s = load_apn_function(name)          # re-verifies differential_uniformity == 2
    is_perm = is_permutation(s)
    algdeg = algebraic_degree(s)
    (; name,
       n = inputbits(s),
       m = inputbits(s),
       lut_sha256 = VBFCatalog.lut_sha256_hex(s),
       lut_blob = VBFCatalog.canonical_lut_bytes(s),
       algebraic_form = get(meta, "algebraic_form", nothing),
       algebraic_degree = algdeg,
       differential_uniformity = Int(differential_uniformity(s)),
       linearity = Int(linearity(s)),
       boomerang_uniformity = is_perm ? Int(boomerang_uniformity(s)) : nothing,
       is_permutation = Int(is_perm),
       is_quadratic = Int(algdeg ≤ 2),
       bib_key = meta["bib_key"],
       notes = meta["description"])
end

_q(x) = x === nothing ? "NULL" : VBFCatalog._sql_quote(x)
_blob(b) = "X'" * bytes2hex(b) * "'"

function main()
    db_path = VBFCatalog.catalog_path()
    isfile(db_path) || error("no catalog at $db_path — run the full build first")
    db = SQLite.DB(db_path)

    # Materialise: an SQLite.Row is a cursor view and is invalid once the
    # cursor advances, so the fields must be copied out here.
    stored = Dict{String,NamedTuple}()
    for r in DBInterface.execute(db, string(
            "SELECT canonical_name, n, m, lut_sha256, bib_key, is_permutation, ",
            "algebraic_form, notes FROM functions WHERE family = 'APN'"))
        stored[String(r.canonical_name)] = (
            n = Int(r.n), m = Int(r.m),
            lut_sha256 = String(r.lut_sha256),
            bib_key = coalesce(r.bib_key, ""),
            is_permutation = Int(r.is_permutation),
            algebraic_form = coalesce(r.algebraic_form, ""),
            notes = coalesce(r.notes, ""))
    end
    declared = apn_catalog_names()

    source_repo = "bfa@" * _git_sha()
    today = _today_utc()
    inserts = String[]
    updates = String[]

    for name in declared
        v = _row_values(name)
        r = get(stored, name, nothing)
        if r === nothing
            push!(inserts, name)
            DRY_RUN && continue
            SQLite.execute(db, string(
                "INSERT INTO functions (",
                "family, n, m, lut_sha256, lut_blob, algebraic_form, ",
                "algebraic_degree, differential_uniformity, linearity, boomerang_uniformity, ",
                "is_apn, is_permutation, is_quadratic, canonical_name, bib_key, ",
                "source_repo, contributor, added_date, notes) VALUES (",
                _q("APN"), ", ", v.n, ", ", v.m, ", ",
                _q(v.lut_sha256), ", ", _blob(v.lut_blob), ", ", _q(v.algebraic_form), ", ",
                v.algebraic_degree, ", ", v.differential_uniformity, ", ", v.linearity, ", ",
                v.boomerang_uniformity === nothing ? "NULL" : string(v.boomerang_uniformity), ", ",
                Int(v.differential_uniformity == 2), ", ",
                v.is_permutation, ", ", v.is_quadratic, ", ",
                _q(v.name), ", ", _q(v.bib_key), ", ",
                _q(source_repo), ", ", _q("BFA APN catalog sync (automated)"), ", ",
                _q(today), ", ", _q(v.notes), ")"))
        else
            drift = String[]
            r.lut_sha256 == v.lut_sha256 || push!(drift, "lut")
            r.bib_key == v.bib_key || push!(drift, "bib_key")
            r.n == v.n && r.m == v.m || push!(drift, "n/m")
            r.is_permutation == v.is_permutation || push!(drift, "is_permutation")
            r.notes == v.notes || push!(drift, "notes")
            r.algebraic_form == something(v.algebraic_form, "") ||
                push!(drift, "algebraic_form")
            isempty(drift) && continue
            push!(updates, "$name ($(join(drift, ", ")))")
            DRY_RUN && continue
            SQLite.execute(db, string(
                "UPDATE functions SET ",
                "n = ", v.n, ", m = ", v.m, ", ",
                "lut_sha256 = ", _q(v.lut_sha256), ", lut_blob = ", _blob(v.lut_blob), ", ",
                "algebraic_form = ", _q(v.algebraic_form), ", ",
                "algebraic_degree = ", v.algebraic_degree, ", ",
                "differential_uniformity = ", v.differential_uniformity, ", ",
                "linearity = ", v.linearity, ", ",
                "boomerang_uniformity = ",
                v.boomerang_uniformity === nothing ? "NULL" : string(v.boomerang_uniformity), ", ",
                "is_apn = ", Int(v.differential_uniformity == 2), ", ",
                "is_permutation = ", v.is_permutation, ", ",
                "is_quadratic = ", v.is_quadratic, ", ",
                "bib_key = ", _q(v.bib_key), ", ",
                "notes = ", _q(v.notes),
                " WHERE family = 'APN' AND canonical_name = ", _q(name)))
        end
    end

    orphans = sort(collect(setdiff(keys(stored), declared)))
    if !isempty(orphans) && !DRY_RUN
        for name in orphans
            SQLite.execute(db,
                "DELETE FROM functions WHERE family = 'APN' AND canonical_name = " * _q(name))
        end
    end

    close(db)

    prefix = DRY_RUN ? "would " : ""
    @info "APN family sync complete" declared = length(declared) inserted = length(inserts) updated = length(updates) deleted = length(orphans)
    isempty(inserts) || println("  $(prefix)insert: ", join(inserts, ", "))
    isempty(updates) || println("  $(prefix)update: ", join(updates, "; "))
    isempty(orphans) || println("  $(prefix)delete: ", join(orphans, ", "))
    if isempty(inserts) && isempty(updates) && isempty(orphans)
        println("  the catalog already agrees with data-raw/apn_catalog/")
    end
end

isinteractive() || main()
