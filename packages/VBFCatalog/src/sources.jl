"""Load curated definitions through one parser; construct their functions with VBF."""

import TOML

const _SOURCE_ENTRIES = Dict{String,Dict{String,Any}}()

"""Read a named declaration set, checking names and caching by source path."""
function _source_entries(file, key)
    path = joinpath(catalog_source_dir(), file)
    get!(_SOURCE_ENTRIES, path) do
        entries = Dict{String,Any}()
        for entry in TOML.parsefile(path)[key]
            name = entry["name"]
            haskey(entries, name) && error("duplicate function name $name in $path")
            _materialise_monomial_lut!(entry, file)
            entries[name] = entry
        end
        entries
    end
end

"""Reconstruct a declared power function, preserving explicitly supplied LUTs."""
function _materialise_monomial_lut!(entry, file)
    haskey(entry, "lut") && return entry
    haskey(entry, "monomial_exponent") || return entry
    n = entry["n"]
    modulus = get(entry, "modulus", nothing)
    if modulus === nothing
        modulus = try
            primitive_polynomial(n)
        catch
            error("$(entry["name"]) in $file needs an explicit modulus for n=$n")
        end
    end
    entry["lut"] = gf_monomial_lut(n, entry["monomial_exponent"]; modulus)
    entry
end

"""Sorted names of curated APN definitions."""
apn_catalog_names() = sort!(collect(keys(_source_entries("apn.toml", "apn_functions"))))

"""Source declaration for a curated APN; unknown names raise ArgumentError."""
apn_catalog_metadata(name::AbstractString) = _source_metadata("apn.toml", "apn_functions", name)

"""Sorted names of literature S-boxes."""
literature_sbox_names() = sort!(collect(keys(_source_entries("literature_sboxes.toml", "sboxes"))))

"""Source declaration for a literature S-box; unknown names raise ArgumentError."""
literature_sbox_metadata(name::AbstractString) = _source_metadata("literature_sboxes.toml", "sboxes", name)

function _source_metadata(file, key, name)
    entries = _source_entries(file, key)
    haskey(entries, name) || throw(ArgumentError("unknown function $(repr(name)) in $file"))
    entries[name]
end

function _declared_sbox(entry)
    n, m = entry["n"], entry["m"]
    n == m || throw(ArgumentError("$(entry["name"]): rectangular n=$n, m=$m is unsupported"))
    SBox{n}(Int.(entry["lut"]))
end

"""Load a curated APN and verify its differential uniformity through VBF."""
function load_apn_function(name::AbstractString)
    F = _declared_sbox(apn_catalog_metadata(name))
    differential_uniformity(F) == 2 || throw(ArgumentError("$name is not APN"))
    F
end

"""Load a literature S-box from its source declaration."""
load_literature_sbox(name::AbstractString) = _declared_sbox(literature_sbox_metadata(name))
