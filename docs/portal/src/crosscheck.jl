# Checks of paper.toml that need the bibliography, the catalog or the VBF library.
# The paper-local checks are VBFRepro.check_paper_metadata; this file adds the rest.

"""Data that the cross-checks compare against: one load for all papers."""
struct CheckContext
    bib_keys::Set{String}
    corpora::Dict{String,NamedTuple}        # name => (bib_key, store_sha256)
    functions::CuratedFunctions
    vbf_names::Set{String}
end

function CheckContext(db)
    bib = Set(String(r.bib_key) for r in DBInterface.execute(db, "SELECT bib_key FROM bibliography"))
    corpora = Dict(String(r.name) => (bib_key = coalesce(r.bib_key, nothing), store_sha256 = String(r.store_sha256))
                   for r in DBInterface.execute(db, "SELECT name, bib_key, store_sha256 FROM bulk_corpora"))
    vbf = Set(string(s) for s in names(VBF; all = false))
    CheckContext(bib, corpora, curated_functions(db), vbf)
end

"""
    check_paper(id, ctx) -> (errors, review)

The VBFRepro checks plus the cross-checks: publication keys in the bibliography, declared
corpora in the catalog, declared functions resolvable to curated content keys. API names
that are not public VBF bindings, and catalog corpora that cite a publication of this paper
but are not declared, are review items.
"""
function check_paper(id::AbstractString, ctx::CheckContext)
    errors, review = check_paper_metadata(id)
    meta = load_paper_metadata(id)
    meta === nothing && return (errors, review)
    pubs = [p["key"] for p in get(meta, "publications", []) if haskey(p, "key")]
    for k in pubs
        k in ctx.bib_keys || push!(errors, "$id: publication $k is not in bibliography.bib")
    end
    declared = Set(get(meta, "corpora", String[]))
    for c in declared
        haskey(ctx.corpora, c) || push!(errors, "$id: corpus $c is not in the catalog")
    end
    for (name, c) in ctx.corpora
        c.bib_key !== nothing && c.bib_key in pubs && !(name in declared) &&
            push!(review, "$id: catalog corpus $name cites $(c.bib_key); declare it in corpora or explain")
    end
    refs = vcat(get(meta, "functions", String[]), [f for c in get(meta, "claims", []) for f in get(c, "functions", [])])
    for f in refs
        resolve_function(ctx.functions, f) === nothing && push!(errors, "$id: function $f is not a curated name or full key")
    end
    for c in get(meta, "claims", []), a in get(c, "api", [])
        a in ctx.vbf_names || push!(review, "$id/$(c["id"]): API name $a is not a public VBF binding")
    end
    (errors, review)
end
