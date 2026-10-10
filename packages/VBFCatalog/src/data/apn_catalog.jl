"""
APN-function catalog loader.

Reads every `src/entries/apn_catalog/n*_apn.toml` and exposes the
per-dimension lists. Mirrors [`literature.jl`](@ref) but for
APN-specific entries.

# Public surface
- [`apn_catalog_names`](@ref)      — every loadable name.
- [`apn_catalog_metadata`](@ref)   — full TOML record.
- [`load_apn_function`](@ref)      — `SBox` constructed from the catalog.
"""

import TOML

const _APN_CACHE = Ref{Union{Dict{String,Any},Nothing}}(nothing)

_apn_catalog_dir() =
    normpath(joinpath(@__DIR__, "..", "entries", "apn_catalog"))

function _load_apn_raw()
    cache = _APN_CACHE[]
    cache === nothing || return cache
    dir = _apn_catalog_dir()
    isdir(dir) || error("BFA: APN catalog directory not found at $dir")
    by_name = Dict{String,Any}()
    for fname in sort(readdir(dir))
        endswith(fname, "_apn.toml") || continue
        data = TOML.parsefile(joinpath(dir, fname))
        haskey(data, "apn_functions") || continue
        for entry in data["apn_functions"]
            name = entry["name"]::String
            haskey(by_name, name) && error(
                "BFA: duplicate APN catalog name $(repr(name)) (in $fname)",
            )
            # Materialise monomial-form LUTs so callers see a uniform field.
            _materialise_monomial_lut!(entry, fname)
            by_name[name] = entry
        end
    end
    _APN_CACHE[] = by_name
    by_name
end

"""
    _materialise_monomial_lut!(entry::Dict, fname::AbstractString)

If `entry` declares a `monomial_exponent` and no explicit `lut`, compute
`x ↦ x^d` over `GF(2^n)` using either the explicit `modulus` field or
[`primitive_polynomial`](@ref VBF.primitive_polynomial), and inject the
resulting LUT in place. Internal. Throws if `n` is outside the table
and no modulus is specified.
"""
function _materialise_monomial_lut!(entry::Dict, fname::AbstractString)
    haskey(entry, "lut") && return entry
    haskey(entry, "monomial_exponent") || return entry
    n = entry["n"]::Int
    d = Int(entry["monomial_exponent"])
    modulus = if haskey(entry, "modulus")
        Int(entry["modulus"])
    else
        try
            primitive_polynomial(n)
        catch
            error(
                "BFA: monomial-form entry $(repr(entry["name"])) in $fname needs an explicit `modulus`: no canonical primitive polynomial is shipped for n=$n",
            )
        end
    end
    entry["lut"] = gf_monomial_lut(n, d; modulus = modulus)
    entry
end

"""
    apn_catalog_names() -> Vector{String}

Sorted list of every name accepted by [`load_apn_function`](@ref).
"""
apn_catalog_names() = sort!(collect(keys(_load_apn_raw())))

"""
    apn_catalog_metadata(name) -> Dict

Full TOML record. Throws `ArgumentError` if `name` is unknown.
"""
function apn_catalog_metadata(name::AbstractString)
    cache = _load_apn_raw()
    haskey(cache, String(name)) || throw(
        ArgumentError(
            "no APN catalog entry named $(repr(String(name))) — try apn_catalog_names()",
        ),
    )
    cache[String(name)]
end

"""
    load_apn_function(name) -> SBox

Construct the APN `SBox` `name`. The differential uniformity is recomputed on
load and the call throws `ArgumentError` if it is not 2 (i.e., the entry
mis-claims APN). Use [`apn_catalog_names`](@ref) for the accepted names.

# Examples
```jldoctest
julia> using VBF, VBFCatalog

julia> g = load_apn_function("n5_Gold_x3");

julia> differential_uniformity(g)
2

julia> inputbits(g)
5
```
"""
function load_apn_function(name::AbstractString)
    entry = apn_catalog_metadata(name)
    n = entry["n"]::Int
    m = entry["m"]::Int
    n == m || throw(
        ArgumentError(
            "load_apn_function: n=$n ≠ m=$m for $(repr(String(name)))",
        ),
    )
    s = SBox{n}(convert(Vector{Int}, entry["lut"]))
    du = differential_uniformity(s)
    du == 2 || throw(
        ArgumentError(
            "load_apn_function: $(repr(String(name))) is not APN " *
            "(differential_uniformity = $du, expected 2)",
        ),
    )
    s
end
