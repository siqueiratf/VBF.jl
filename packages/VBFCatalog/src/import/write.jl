using VBF, VBFCatalog, DBInterface

"""Insert a normalized LUT and its VBF-computed properties into the catalog.

Converters supply source metadata; this is the only function-row insertion path.
SQLite enforces uniqueness and foreign keys. Invalid claimed APNs are rejected.
"""
function insert_function!(db, F; family, canonical_name, source_repo, contributor,
                          notes, added_date="", bib_key=nothing, algebraic_form=nothing,
                          require_apn=true)
    n=inputbits(F)
    du=Int(differential_uniformity(F)); degree=algebraic_degree(F)
    require_apn && du!=2 && error("non-APN source entry: $canonical_name")
    perm=is_permutation(F)
    DBInterface.execute(db,
        "INSERT INTO functions (family,n,m,lut_sha256,lut_blob,algebraic_form,algebraic_degree,differential_uniformity,linearity,boomerang_uniformity,is_apn,is_permutation,is_quadratic,canonical_name,bib_key,source_repo,contributor,added_date,notes) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (family,n,n,lut_sha256_hex(F),canonical_lut_bytes(F),algebraic_form,degree,du,
         Int(linearity(F)),perm ? Int(boomerang_uniformity(F)) : nothing,
         Int(du==2),Int(perm),Int(degree<=2),canonical_name,bib_key,source_repo,
         contributor,"",notes))
    nothing
end

"""Merge exact-LUT source tags in a stable order."""
function merge_source_repo!(db, function_id, added_source)
    current=only(String(row.source_repo) for row in DBInterface.execute(db,
        "SELECT source_repo FROM functions WHERE id=?",(function_id,)))
    tags=sort!(unique(vcat(split(current,'|'),[String(added_source)])))
    SQLite.execute(db,"UPDATE functions SET source_repo=? WHERE id=?",(join(tags,'|'),function_id))
    nothing
end
