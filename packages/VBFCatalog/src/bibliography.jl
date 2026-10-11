"""
Bibliography loader for the workspace's shared `packages/VBFCatalog/src/data/bibliography.bib`.

A minimal BibTeX parser that handles the subset BFA needs:

- one `@type{key, field = {value}, ...}` block per entry
- field values either braced `{...}` (with correct nested-brace tracking)
  or quoted `"..."`
- line-leading `%` comments are skipped
- field concatenation with `#` and `@string` macros are *not* supported

# Public surface
- [`BibEntry`](@ref)        — struct returned for each parsed entry
- [`load_bibliography`](@ref) — read + parse the bundled .bib file
- [`parse_bibtex`](@ref)    — parse a BibTeX string directly
- [`bibliography_path`](@ref)
"""

# Public type

"""
    BibEntry(bib_key, entry_type, fields)

A parsed BibTeX entry. `fields` is a `Dict{String, String}` keyed by
lowercased field names; values are the raw inner string (whitespace
preserved, surrounding braces / quotes stripped).

Use `entry["title"]` or `get(entry, "doi", "")` to access fields.
"""
struct BibEntry
    bib_key::String
    entry_type::String     # e.g. "inproceedings", "article", "misc"
    fields::Dict{String,String}
end

Base.getindex(e::BibEntry, field::AbstractString) =
    e.fields[lowercase(String(field))]
Base.get(e::BibEntry, field::AbstractString, default) =
    get(e.fields, lowercase(String(field)), default)
Base.haskey(e::BibEntry, field::AbstractString) =
    haskey(e.fields, lowercase(String(field)))

function Base.show(io::IO, e::BibEntry)
    print(
        io,
        "BibEntry(",
        repr(e.bib_key),
        ", @",
        e.entry_type,
        ", ",
        length(e.fields),
        " fields)",
    )
end

# Bibliography path + loader

"""
    bibliography_path() -> String

Default location of the shared `packages/VBFCatalog/src/data/bibliography.bib`.
"""
bibliography_path() =
    joinpath(catalog_source_dir(), "bibliography.bib")

"""
    load_bibliography([path]) -> Vector{BibEntry}

Read and parse the bundled bibliography file (or the file at `path`).
"""
function load_bibliography(path::AbstractString = bibliography_path())
    isfile(path) || throw(ArgumentError("BFA: bibliography not found at $path"))
    parse_bibtex(read(path, String))
end

# Parser

const _BIBTEX_KEY_CHARS = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-:./+")

"""
    parse_bibtex(content::AbstractString) -> Vector{BibEntry}

Parse the supported BibTeX subset directly from `content`. Top-level
`%` comments are stripped. Empty input yields `BibEntry[]`.
"""
function parse_bibtex(content::AbstractString)
    out = BibEntry[]
    chars = collect(content)
    n = length(chars)
    i = 1
    while i ≤ n
        c = chars[i]
        if c == '%'
            # comment to end of line
            while i ≤ n && chars[i] != '\n'
                i += 1
            end
            continue
        elseif c == '@'
            entry, i = _parse_entry(chars, i + 1)
            entry === nothing || push!(out, entry)
            continue
        else
            i += 1
        end
    end
    out
end

function _parse_entry(chars::Vector{Char}, i::Int)
    n = length(chars)
    # read entry type
    type_start = i
    while i ≤ n && isletter(chars[i])
        i += 1
    end
    i > type_start || return (nothing, i)
    entry_type = lowercase(String(chars[type_start:(i-1)]))
    i = _skip_ws(chars, i)
    (i > n || chars[i] != '{') && return (nothing, i)
    i += 1                                    # consume {
    i = _skip_ws(chars, i)
    # read key (up to first comma)
    key_start = i
    while i ≤ n && chars[i] != ',' && chars[i] != '}'
        i += 1
    end
    i > n && return (nothing, i)
    key = strip(String(chars[key_start:(i-1)]))
    if chars[i] == '}'                        # entry with no fields
        return (BibEntry(String(key), entry_type, Dict{String,String}()), i + 1)
    end
    i += 1                                    # consume comma
    fields = Dict{String,String}()
    while true
        i = _skip_ws(chars, i)
        i > n && break
        if chars[i] == '}'
            i += 1
            break
        end
        # read field name
        field_start = i
        while i ≤ n && (chars[i] in _BIBTEX_KEY_CHARS)
            i += 1
        end
        field_name = lowercase(String(chars[field_start:(i-1)]))
        i = _skip_ws(chars, i)
        (i > n || chars[i] != '=') && error(
            "parse_bibtex: expected '=' after field name $(repr(field_name)) in entry $(repr(key))",
        )
        i += 1                                # consume =
        i = _skip_ws(chars, i)
        value, i = _read_value(chars, i, key, field_name)
        fields[field_name] = value
        i = _skip_ws(chars, i)
        i ≤ n && chars[i] == ',' && (i += 1)
    end
    (BibEntry(String(key), entry_type, fields), i)
end

function _skip_ws(chars::Vector{Char}, i::Int)
    n = length(chars)
    while i ≤ n && isspace(chars[i])
        i += 1
    end
    i
end

function _read_value(
    chars::Vector{Char},
    i::Int,
    key::AbstractString,
    field::AbstractString,
)
    n = length(chars)
    i > n && error("parse_bibtex: EOF reading $field in $(repr(key))")
    c = chars[i]
    if c == '{'
        # nested-brace tracking; inner braces are kept verbatim in the value
        depth = 1
        i += 1
        start = i
        while i ≤ n && depth > 0
            ci = chars[i]
            if ci == '{'
                depth += 1
            elseif ci == '}'
                depth -= 1
                depth == 0 && return (String(chars[start:(i-1)]), i + 1)
            end
            i += 1
        end
        error(
            "parse_bibtex: unterminated braced value for $field in $(repr(key))",
        )
    elseif c == '"'
        i += 1
        start = i
        while i ≤ n && chars[i] != '"'
            i += 1
        end
        i > n && error(
            "parse_bibtex: unterminated quoted value for $field in $(repr(key))",
        )
        return (String(chars[start:(i-1)]), i + 1)
    else
        # bare value (number or word)
        start = i
        while i ≤ n && !isspace(chars[i]) && chars[i] != ',' && chars[i] != '}'
            i += 1
        end
        return (strip(String(chars[start:(i-1)])), i)
    end
end
