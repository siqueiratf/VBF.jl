# Identity of concrete functions, names and corpus members.
#
# A function is its concrete LUT: (n, m, SHA-256 of VBFCatalog.canonical_lut_bytes). Names
# are aliases of a key. A corpus member is a position (corpus, corpus digest, index) that
# points to a key. EA/CCZ equivalence never merges keys (see equivalence.jl).

"""Content key of a concrete (n, m)-function. `lut_sha256` is the full lowercase hex digest."""
struct FunctionKey
    n::Int
    m::Int
    lut_sha256::String
    function FunctionKey(n::Integer, m::Integer, lut_sha256::AbstractString)
        h = lowercase(lut_sha256)
        occursin(r"^[0-9a-f]{64}$", h) || throw(ArgumentError("lut_sha256 must be 64 hex digits"))
        n > 0 && m > 0 || throw(ArgumentError("n and m must be positive"))
        new(n, m, h)
    end
end

"""Key of an `SBox{n}` with `m` output bits, from its canonical LUT bytes."""
function function_key(F::SBox{N}, m::Integer) where {N}
    FunctionKey(N, m, bytes2hex(sha256(canonical_lut_bytes(F))))
end

"""Permanent identifier: `<n>-<m>-<full sha256>`. Used in URLs and machine-readable data."""
key_string(k::FunctionKey) = "$(k.n)-$(k.m)-$(k.lut_sha256)"

"""Short form for display only: `<n>-<m>-<first 12 hex>`; never used to resolve."""
display_key(k::FunctionKey) = "$(k.n)-$(k.m)-$(k.lut_sha256[1:12])"

"""Parse a permanent identifier; a shortened hash is refused."""
function parse_key(s::AbstractString)
    m = match(r"^(\d+)-(\d+)-([0-9a-fA-F]{64})$", s)
    m === nothing && throw(ArgumentError("not a full function key: $s"))
    FunctionKey(parse(Int, m[1]), parse(Int, m[2]), m[3])
end

Base.show(io::IO, k::FunctionKey) = print(io, "FunctionKey(", key_string(k), ")")

"""
A position in a corpus snapshot. `digest` is the full `store_sha256` of the packed members,
so the index keeps its meaning only for that member order.
"""
struct MemberRef
    corpus::String
    digest::String
    idx::Int
    function MemberRef(corpus::AbstractString, digest::AbstractString, idx::Integer)
        d = lowercase(digest)
        occursin(r"^[0-9a-f]{64}$", d) || throw(ArgumentError("corpus digest must be 64 hex digits"))
        idx > 0 || throw(ArgumentError("member index must be positive"))
        new(corpus, d, idx)
    end
end

"""Catalog functions: key → row data, name → key."""
struct CuratedFunctions
    by_key::Dict{FunctionKey,NamedTuple}
    by_name::Dict{String,FunctionKey}
end

"""Read the curated `functions` table; names are aliases of content keys."""
function curated_functions(db)
    by_key = Dict{FunctionKey,NamedTuple}(); by_name = Dict{String,FunctionKey}()
    for r in DBInterface.execute(db, "SELECT id, family, n, m, lut_sha256, canonical_name, bib_key FROM functions")
        k = FunctionKey(r.n, r.m, r.lut_sha256)
        haskey(by_key, k) && error("two catalog rows with one content key: $(key_string(k))")
        by_key[k] = (; id = r.id, family = r.family, name = coalesce(r.canonical_name, nothing),
                       bib_key = coalesce(r.bib_key, nothing))
        if !ismissing(r.canonical_name)
            haskey(by_name, r.canonical_name) && error("catalog name used twice: $(r.canonical_name)")
            by_name[r.canonical_name] = k
        end
    end
    CuratedFunctions(by_key, by_name)
end

"""Resolve a name or a full key to a curated function key, or `nothing`."""
function resolve_function(cf::CuratedFunctions, ref::AbstractString)
    haskey(cf.by_name, ref) && return cf.by_name[ref]
    occursin(r"^\d+-\d+-[0-9a-fA-F]{64}$", ref) || return nothing
    k = parse_key(ref)
    haskey(cf.by_key, k) ? k : nothing
end
