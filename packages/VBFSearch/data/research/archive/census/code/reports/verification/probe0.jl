using VBFCatalog
const DBI = VBFCatalog.DBInterface; const SQLite = VBFCatalog.SQLite
idx = VBFCatalog._open_sigma_index()
for r in DBI.execute(idx, "SELECT name, sql FROM sqlite_master"); println(r.name, " :: ", r.sql); end
for r in DBI.execute(idx, "SELECT source, n, COUNT(*) c, COUNT(DISTINCT member_idx) d, MIN(member_idx) mn, MAX(member_idx) mx FROM ccz_sigma_index GROUP BY source, n"); println(join([r.source, r.n, r.c, r.d, r.mn, r.mx], " | ")); end
for r in DBI.execute(idx, "SELECT * FROM sigma_coverage"); println("cov ", r.source, " ", r.n, " ", r.indexed); end
for r in DBI.execute(idx, "SELECT COUNT(DISTINCT sigma_hash) c FROM ccz_sigma_index WHERE n=8"); println("n8 distinct ", r.c); end
cat = VBFCatalog.load_catalog()
for r in DBI.execute(cat, "SELECT name,n,member_count,modulus,encoding,bytes_per_member FROM bulk_corpora"); println(join([r.name,r.n,r.member_count,r.modulus,r.encoding,r.bytes_per_member], " | ")); end
for r in DBI.execute(cat, "SELECT n, is_apn, is_quadratic, COUNT(*) c FROM functions GROUP BY n,is_apn,is_quadratic"); println("fn ", r.n, " apn=", r.is_apn, " q=", r.is_quadratic, " ", r.c); end
for r in DBI.execute(cat, "SELECT id, family, canonical_name, algebraic_degree, algebraic_form FROM functions WHERE n=8 AND is_apn=1 AND is_quadratic=0"); println("nonquad ", r.id, " | ", r.family, " | ", r.canonical_name, " | deg ", r.algebraic_degree, " | ", r.algebraic_form); end
