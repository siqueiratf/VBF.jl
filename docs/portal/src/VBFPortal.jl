"""
Data model of the VBF.jl portal (Reproductions, Catalog, Library).

Stage S1: identity of functions and corpus members, catalog snapshots, equivalence
levels and the cross-checks of `paper.toml`. Rendering comes in later stages.
"""
module VBFPortal

using DBInterface, SHA, SQLite, TOML
using VBF
using VBFCatalog
using VBFCatalog: catalog_data_dir, canonical_lut_bytes
using VBFRepro: check_paper_metadata, load_paper_metadata, discover_papers

export FunctionKey, function_key, key_string, display_key, parse_key, MemberRef,
    CuratedFunctions, curated_functions, resolve_function,
    CatalogSnapshot, catalog_snapshot, resolve_member, current_member,
    EquivalenceRecord, EQUIVALENCE_LEVELS, proves_equivalence, proves_inequivalence,
    CheckContext, check_paper, check_all

include("identity.jl")
include("snapshots.jl")
include("equivalence.jl")
include("crosscheck.jl")

"""Check every paper that has a `paper.toml`; return (errors, review) over all of them."""
function check_all(db = load_catalog())
    ctx = CheckContext(db)
    errors = String[]; review = String[]
    for p in discover_papers()
        isfile(joinpath(p.path, "paper.toml")) || continue
        e, r = check_paper(p.id, ctx)
        append!(errors, e); append!(review, r)
    end
    (errors, review)
end

end
