"""
Literature S-box catalog.

Loads `src/entries/literature_sboxes.toml` and exposes its entries as
`SBox` instances.

# Functions
- [`load_literature_sbox`](@ref) — fetch an `SBox` by name.
- [`literature_sbox_names`](@ref) — list every loadable name.
- [`literature_sbox_metadata`](@ref) — fetch the full TOML record for one
  S-box (description, bib_key, source, is_permutation flag, …).
"""

import TOML

const _LITERATURE_CACHE = Ref{Union{Dict{String,Any},Nothing}}(nothing)

_literature_path() = normpath(
    joinpath(@__DIR__, "..", "entries", "literature_sboxes.toml"),
)

function _load_literature_raw()
    cache = _LITERATURE_CACHE[]
    cache === nothing || return cache
    path = _literature_path()
    isfile(path) || error(
        "BFA: literature_sboxes.toml not found at $path — was the package distributed without src/entries/?",
    )
    data = TOML.parsefile(path)
    haskey(data, "sboxes") || error("BFA: $path has no [[sboxes]] entries")
    by_name = Dict{String,Any}()
    for entry in data["sboxes"]
        name = entry["name"]::String
        haskey(by_name, name) &&
            error("BFA: duplicate literature S-box name $(repr(name))")
        by_name[name] = entry
    end
    _LITERATURE_CACHE[] = by_name
    by_name
end

"""
    literature_sbox_names() -> Vector{String}

Sorted list of every name accepted by [`load_literature_sbox`](@ref).
"""
literature_sbox_names() = sort!(collect(keys(_load_literature_raw())))

"""
    literature_sbox_metadata(name) -> Dict

Full TOML record (description, n, m, is_permutation, bib_key, source,
lut). Throws `ArgumentError` if `name` is unknown.
"""
function literature_sbox_metadata(name::AbstractString)
    cache = _load_literature_raw()
    haskey(cache, String(name)) || throw(
        ArgumentError(
            "no literature S-box named $(repr(String(name))) — try literature_sbox_names()",
        ),
    )
    cache[String(name)]
end

"""
    load_literature_sbox(name) -> SBox

Construct the literature S-box `name`. Only square (`n == m`) S-boxes
are supported in this loader; rectangular ones (e.g., DES) require the
not-yet-existent `RectSBox` type.

# Examples
```jldoctest
julia> using VBF

julia> aes = load_literature_sbox("AES");

julia> aes(0)
0x63

julia> aes(0xff)
0x16
```
"""
function load_literature_sbox(name::AbstractString)
    entry = literature_sbox_metadata(name)
    n = entry["n"]::Int
    m = entry["m"]::Int
    n == m || throw(
        ArgumentError(
            "load_literature_sbox: $(repr(String(name))) has n=$n ≠ m=$m; rectangular S-boxes need the RectSBox type (not yet implemented)",
        ),
    )
    SBox{n}(convert(Vector{Int}, entry["lut"]))
end
