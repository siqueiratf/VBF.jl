using VBFCatalog, VBFSearch

db=load_catalog()
try
    println(populate_ccz_equivalence_classes!(db))
finally
    close(db)
end
