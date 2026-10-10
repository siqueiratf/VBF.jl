import SQLite
import DBInterface
import SHA
import TOML

"""A read-only, digest-bound snapshot of a documented quadratic (8,8)-APN corpus.

Absence separates a candidate only from the represented corpus; it does not
establish that the reference contains every APN construction in the literature.
Use the accessors rather than the internal SQLite connection.
"""
mutable struct AuditedAPNReference
    db::SQLite.DB
    statement::SQLite.Stmt
    metadata::Dict{String,Any}
    supplement::Dict{String,Vector{Vector{UInt8}}}
    closed::Bool
end

_reference_filehash(path) = bytes2hex(open(SHA.sha256, path))

function _reference_supplement_signature(lut)
    length(lut) == 256 || error("expected an eight-bit supplement LUT")
    F = SBox{8,UInt8}(lut)
    algebraic_degree(F) == 2 || error("supplement is not quadratic")
    sigma_hash(F) # ortho_derivative also checks the APN condition
end

"""
    open_apn_reference(dir; supplement_path="", supplement_signature=..., required_signatures=[])

Open the source-rebuilt `comparison.toml` / `fresh_union.sqlite` snapshot.
Require the quadratic (8,8)-APN scope, complete declared source provenance, a matching database digest, and
the recorded signature count. An optional TSV supplement (`sigma_hash`,
`lut_hex`) is verified before use. `supplement_signature(lut)` must validate
that the LUT is a quadratic (8,8)-APN and return its signature hash; the default
uses VBF, while an independent audit may supply a separate verifier.

Every `required_signatures` hash must occur in the rebuilt database itself.
Callers can therefore require representatives used in a mathematical coverage
argument without the supplement masking a missing reference entry. This is a
scope/provenance check, not an independent recomputation of database contents.
Close with [`close_apn_reference`](@ref), preferably inside `try` / `finally`.
"""
function open_apn_reference(dir; supplement_path::AbstractString="",
        supplement_signature=_reference_supplement_signature, required_signatures=String[])
    manifest_path = joinpath(dir, "comparison.toml")
    isfile(manifest_path) || error("missing source-rebuilt APN reference: $dir")
    manifest_bytes = read(manifest_path)
    manifest_digest = bytes2hex(SHA.sha256(manifest_bytes))
    manifest = TOML.parse(String(manifest_bytes))
    get(manifest, "provenance_complete", false) === true || error("incomplete original-source reference")
    get(manifest, "scope", nothing) == "quadratic (8,8)-APN" || error("unsupported reference scope")
    path = abspath(joinpath(dir, "fresh_union.sqlite"))
    isfile(path) || error("missing reference database")
    digest = _reference_filehash(path)
    digest == manifest["fresh_union_sha256"] || error("reference digest mismatch")
    supplement = Dict{String,Vector{Vector{UInt8}}}()
    if !isempty(supplement_path)
        isfile(supplement_path) || error("missing public supplement")
        # Bind the parsed supplement to the same bytes recorded in metadata.
        supplement_bytes = read(supplement_path)
        supplement_digest = bytes2hex(SHA.sha256(supplement_bytes))
        lines = split(String(supplement_bytes), '\n')
        split(strip(first(lines)), '\t') == ["sigma_hash", "lut_hex"] || error("invalid supplement header")
        for line in Iterators.drop(lines, 1)
            isempty(strip(line)) && continue
            cols = split(strip(line), '\t')
            length(cols) == 2 || error("invalid supplement row")
            lut = hex2bytes(cols[2])
            supplement_signature(lut) == cols[1] || error("invalid public supplement signature")
            # A signature need not identify an equivalence class or unique LUT.
            bucket = get!(supplement, String(cols[1]), Vector{UInt8}[])
            lut in bucket || push!(bucket, lut)
        end
    else
        supplement_digest = "none"
    end
    db = SQLite.DB("file:" * path * "?mode=ro")
    statement = nothing
    try
        count = only([Int(r.c) for r in DBInterface.execute(db, "SELECT COUNT(*) c FROM signatures")])
        count == manifest["fresh_union_distinct_signatures"] || error("reference count mismatch")
        statement = DBInterface.prepare(db, "SELECT 1 FROM signatures WHERE sigma_hash=? LIMIT 1")
        required = sort!(unique(String.(collect(required_signatures))))
        for hash in required
            isempty(collect(DBInterface.execute(statement, (hash,)))) &&
                error("reference omits required signature: $hash")
        end
        # Reject mutation while the connection was opened and checked.
        _reference_filehash(path) == digest || error("reference changed while opening")
        metadata = Dict{String,Any}("path"=>path, "sha256"=>digest,
            "manifest_sha256"=>manifest_digest, "signatures"=>count,
            "supplement_sha256"=>supplement_digest,
            "supplement_path"=>isempty(supplement_path) ? "none" : abspath(supplement_path),
            "scope"=>"source-rebuilt quadratic (8,8)-APN representatives plus specified public supplement",
            "required_signatures"=>required, "literature_complete"=>false)
        return AuditedAPNReference(db, statement, metadata, supplement, false)
    catch
        statement === nothing || DBInterface.close!(statement)
        SQLite.close(db)
        rethrow()
    end
end

"""Return a copy of the reference's provenance and explicitly limited scope."""
reference_metadata(r::AuditedAPNReference) = deepcopy(r.metadata)

"""Test signature membership, including the verified public supplement.

A match is a necessary filter, not proof of equivalence. Absence concerns only
the documented reference scope.
"""
function reference_contains_signature(r::AuditedAPNReference, hash::AbstractString)
    r.closed && error("APN reference is closed")
    haskey(r.supplement, hash) || !isempty(collect(DBInterface.execute(r.statement, (hash,))))
end

"""Whether the LUT equals the verified supplement entry for this signature."""
function reference_exact_lut_match(r::AuditedAPNReference, hash::AbstractString, lut)
    r.closed && error("APN reference is closed")
    haskey(r.supplement, hash) && any(==(lut), r.supplement[hash])
end

"""Close a reference and its prepared statement; repeated closure is harmless."""
function close_apn_reference(r::AuditedAPNReference)
    r.closed && return nothing
    DBInterface.close!(r.statement)
    SQLite.close(r.db)
    r.closed = true
    nothing
end
