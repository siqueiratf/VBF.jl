# Does the committed simonberg_gf4_n8 store hold the same CONTENT the catalog
# descriptor's store_sha256 was computed on? Re-create the store in /tmp with the
# exact statements of VBFCatalog.build_corpus_store! (same DDL, same inserts in
# idx order) under the current SQLite, and compare sha256 with the descriptor.
# Usage: julia --project=/home/ts/VBF.jl rebuild_store_sha.jl NAME
using VBFCatalog, SHA
const SQLite = VBFCatalog.SQLite; const DBI = VBFCatalog.DBInterface
name = ARGS[1]
cat = VBFCatalog.load_catalog(); info = VBFCatalog.corpus_info(cat, name)
src = SQLite.DB(VBFCatalog.corpus_store_path(name))
encs = [Vector{UInt8}(r.coeffs) for r in DBI.execute(src, "SELECT coeffs FROM members ORDER BY idx")]
close(src)
path = tempname() * ".sqlite"
store = SQLite.DB(path)
SQLite.execute(store, "CREATE TABLE members (idx INTEGER PRIMARY KEY, coeffs BLOB NOT NULL)")
SQLite.execute(store, "BEGIN")
for (i, e) in enumerate(encs)
    SQLite.execute(store, "INSERT INTO members (idx, coeffs) VALUES ($i, X'" * bytes2hex(e) * "')")
end
SQLite.execute(store, "COMMIT"); close(store)
sha = bytes2hex(SHA.sha256(read(path)))
println("$name: members=$(length(encs)) committed-file sha=$(bytes2hex(open(SHA.sha256, VBFCatalog.corpus_store_path(name))))")
println("$name: rebuilt-under-current-SQLite sha=$sha  descriptor sha=$(info.store_sha256)  equal=$(sha == info.store_sha256)")
rm(path)
