# Implements 5.1 — CCZ equivalence; optional catalog comparison.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 5.1 — CCZ equivalence; optional catalog comparison
#
# Pseudocode:
#   1. Load the thirteen frozen APN-rep rows from the optional catalog layer.
#   2. Add Kim and verify fourteen APN inputs, thirteen quadratic.
# VBF API used: kim_apn, algebraic_degree, differential_uniformity

using VBF, VBFCatalog

"""Load fourteen known six-bit CCZ roots for GL Table 2 comparison."""
function gl_catalog_roots()
    db=load_catalog()
    rows=sort!(list_functions(db;n=6,is_apn=true,family="APN-rep");by=r->r.id)
    roots=[String(row.canonical_name)=>load_sbox(db,row.id) for row in rows]
    push!(roots,"Kim"=>kim_apn())
    length(roots)==14 && count(pair->algebraic_degree(last(pair))==2,roots)==13 ||
        error("catalog known-root input differs from GL’s fourteen classes")
    all(pair->differential_uniformity(last(pair))==2,roots) || error("catalog root is not APN")
    return roots
end
