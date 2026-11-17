# Catalog and corpus snapshots: the identifiers that make references permanent.
#
# Catalog snapshot = the prebuilt key (VBFCatalog._prebuilt_key): the same key names a
# Zenodo version of the prebuilt data. Corpus snapshot = `bulk_corpora.store_sha256`, the
# digest of the packed members in index order; member indices keep their meaning only
# for one corpus digest.

"""The snapshot of the local catalog."""
struct CatalogSnapshot
    prebuilt_key::String                    # full 64 hex
    inputs_sha256::String
    implementation_sha256::String
    corpora::Dict{String,String}            # corpus name => store_sha256 (full)
    zenodo_doi::Union{Nothing,String}       # DOI of the Zenodo version, when installed from it
end

"""Read the snapshot of the local catalog (and its Zenodo DOI if `prebuilt.toml` exists)."""
function catalog_snapshot(db)
    meta = only(NamedTuple(r) for r in DBInterface.execute(db, "SELECT * FROM schema_meta"))
    corpora = Dict(String(r.name) => lowercase(String(r.store_sha256))
                   for r in DBInterface.execute(db, "SELECT name, store_sha256 FROM bulk_corpora"))
    marker = joinpath(catalog_data_dir(), "prebuilt.toml")
    doi = isfile(marker) ? get(TOML.parsefile(marker), "doi", nothing) : nothing
    CatalogSnapshot(VBFCatalog._prebuilt_key(), meta.inputs_sha256, meta.implementation_sha256, corpora, doi)
end

"""
    resolve_member(ref, snapshot) -> Symbol

`:current` when the reference's corpus digest is the corpus digest of `snapshot`;
`:historical` when the corpus exists with another digest (the index may name another member);
`:unknown` when the corpus is not in the snapshot.
"""
function resolve_member(ref::MemberRef, s::CatalogSnapshot)
    d = get(s.corpora, ref.corpus, nothing)
    d === nothing ? :unknown : d == ref.digest ? :current : :historical
end

"""A member reference against the current snapshot of a corpus."""
current_member(s::CatalogSnapshot, corpus::AbstractString, idx::Integer) =
    MemberRef(corpus, s.corpora[corpus], idx)
