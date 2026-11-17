# Catalog proof of concept (stage S0): build the database variants that the browser
# measurements query. Read-only on the catalog; all output goes to OUT_DIR.
#
#   julia -t auto --project=packages/VBFCatalog/src/import docs/portal/poc/build_dbs.jl OUT_DIR
#
# Variants:
#   catalog_p{1024,4096}.sqlite  catalog.sqlite with that page size (VACUUM)
#   members_p{1024,4096}.sqlite  members.sqlite with that page size (VACUUM)
#   query_full_p{1024,4096}.sqlite   every member of every corpus with its full LUT
#                                    SHA-256 and its signature (sigma_hash), indexed
#   query_short_p4096.sqlite     the same with 16-byte hashes (size comparison only)
#   members_beierle2025_n8.bin   fixed-width baseline: 37 bytes per member, in idx order
using VBF, VBFCatalog, SQLite, DBInterface, SHA

const OUT = abspath(ARGS[1])
mkpath(OUT)

function vacuum_copy(src, dst, page_size)
    rm(dst; force = true)
    cp(src, dst)
    db = SQLite.DB(dst)
    SQLite.execute(db, "PRAGMA journal_mode = DELETE")
    SQLite.execute(db, "PRAGMA page_size = $page_size")
    SQLite.execute(db, "VACUUM")
    close(db)
    println(rpad(basename(dst), 34), filesize(dst) ÷ 2^20, " MiB")
end

"Every member of every corpus: (corpus, idx, coeffs, lut_sha256, sigma)."
function collect_members(db, sigma)
    rows = NamedTuple[]
    for name in list_corpora(db)
        info = corpus_info(db, name)
        n = Int(info.n); mod = Int(info.modulus)
        powtab = monomial_power_table(n, mod)
        sig = Dict{Int,Vector{UInt8}}()
        for r in DBInterface.execute(sigma, "SELECT member_idx, sigma_hash FROM ccz_sigma_index WHERE source = ?", (name,))
            sig[Int(r.member_idx)] = hex2bytes(r.sigma_hash)
        end
        idxs = Int[]; coeffs = Vector{UInt8}[]
        with_corpus_rows(db, name) do it
            for r in it
                push!(idxs, Int(r.idx)); push!(coeffs, Vector{UInt8}(r.coeffs))
            end
        end
        hashes = Vector{Vector{UInt8}}(undef, length(idxs))
        Threads.@threads for j in eachindex(idxs)
            lut = decode_quadratic_lut(coeffs[j], n, mod; powtab = powtab)
            hashes[j] = sha256(canonical_lut_bytes(SBox{n}(lut)))
        end
        for j in eachindex(idxs)
            push!(rows, (corpus = name, n = n, idx = idxs[j], coeffs = coeffs[j],
                         lut = hashes[j], sigma = get(sig, idxs[j], nothing)))
        end
        println(rpad(name, 30), length(idxs), " members, ", length(sig), " signatures")
    end
    rows
end

function write_query_db(path, db, members; hash_bytes = 32, page_size = 4096)
    rm(path; force = true)
    q = SQLite.DB(path)
    SQLite.execute(q, "PRAGMA page_size = $page_size")
    SQLite.execute(q, "PRAGMA journal_mode = DELETE")
    SQLite.execute(q, """CREATE TABLE corpora (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE,
        digest TEXT NOT NULL, n INTEGER NOT NULL, m INTEGER NOT NULL, member_count INTEGER NOT NULL, bib_key TEXT)""")
    SQLite.execute(q, """CREATE TABLE functions (id INTEGER PRIMARY KEY, n INTEGER NOT NULL, m INTEGER NOT NULL,
        lut_sha256 BLOB NOT NULL, family TEXT NOT NULL, canonical_name TEXT, algebraic_degree INTEGER,
        differential_uniformity INTEGER, linearity INTEGER, is_apn INTEGER, is_permutation INTEGER,
        is_quadratic INTEGER, bib_key TEXT)""")
    SQLite.execute(q, """CREATE TABLE members (corpus_id INTEGER NOT NULL, idx INTEGER NOT NULL,
        coeffs BLOB NOT NULL, lut_sha256 BLOB NOT NULL, sigma BLOB,
        PRIMARY KEY (corpus_id, idx)) WITHOUT ROWID""")
    ids = Dict{String,Int}()
    SQLite.transaction(q) do
        for (k, r) in enumerate(DBInterface.execute(db, "SELECT * FROM bulk_corpora ORDER BY name"))
            ids[String(r.name)] = k
            DBInterface.execute(q, "INSERT INTO corpora VALUES (?,?,?,?,?,?,?)",
                (k, r.name, r.store_sha256, r.n, r.m, r.member_count, r.bib_key))
        end
        for r in DBInterface.execute(db, "SELECT * FROM functions ORDER BY id")
            DBInterface.execute(q, "INSERT INTO functions VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (r.id, r.n, r.m, hex2bytes(r.lut_sha256)[1:hash_bytes], r.family, r.canonical_name,
                 r.algebraic_degree, r.differential_uniformity, r.linearity, r.is_apn,
                 r.is_permutation, r.is_quadratic, r.bib_key))
        end
        stmt = DBInterface.prepare(q, "INSERT INTO members VALUES (?,?,?,?,?)")
        for m in sort(members; by = m -> (ids[m.corpus], m.idx))
            DBInterface.execute(stmt, (ids[m.corpus], m.idx, m.coeffs, m.lut[1:hash_bytes],
                m.sigma === nothing ? missing : m.sigma[1:hash_bytes]))
        end
    end
    SQLite.execute(q, "CREATE INDEX members_lut ON members(lut_sha256)")
    SQLite.execute(q, "CREATE INDEX members_sigma ON members(sigma)")
    SQLite.execute(q, "CREATE INDEX functions_lut ON functions(lut_sha256)")
    SQLite.execute(q, "CREATE INDEX functions_filter ON functions(n, is_apn, family)")
    SQLite.execute(q, "ANALYZE")
    SQLite.execute(q, "VACUUM")
    close(q)
    println(rpad(basename(path), 34), filesize(path) ÷ 2^20, " MiB")
end

dir = catalog_data_dir()
for p in (1024, 4096)
    vacuum_copy(joinpath(dir, "catalog.sqlite"), joinpath(OUT, "catalog_p$p.sqlite"), p)
    vacuum_copy(joinpath(dir, "members.sqlite"), joinpath(OUT, "members_p$p.sqlite"), p)
end

db = load_catalog()
sigma = SQLite.DB("file:" * joinpath(dir, "ccz_sigma_index.sqlite") * "?mode=ro")
members = collect_members(db, sigma)
for p in (1024, 4096)
    write_query_db(joinpath(OUT, "query_full_p$p.sqlite"), db, members; page_size = p)
end
write_query_db(joinpath(OUT, "query_short_p4096.sqlite"), db, members; hash_bytes = 16)

open(joinpath(OUT, "members_beierle2025_n8.bin"), "w") do io
    for m in members
        m.corpus == "beierle2025_n8" && write(io, m.coeffs)
    end
end
println(rpad("members_beierle2025_n8.bin", 34), filesize(joinpath(OUT, "members_beierle2025_n8.bin")) ÷ 2^20, " MiB")

# Reference answers for the browser checks: one member, the curated function that occurs
# in the most corpus memberships, and the largest signature class.
open(joinpath(OUT, "expected.toml"), "w") do io
    b = findfirst(m -> m.corpus == "beierle2025_n8" && m.idx == 123456, members)
    count_by = (key) -> (d = Dict{Vector{UInt8},Int}(); for m in members; k = key(m); k === nothing || (d[k] = get(d, k, 0) + 1); end; d)
    luts = count_by(m -> m.lut)
    f = argmax(r -> get(luts, hex2bytes(r.lut_sha256), 0),
               [(canonical_name = String(r.canonical_name), lut_sha256 = String(r.lut_sha256))
                for r in DBInterface.execute(db, "SELECT canonical_name, lut_sha256 FROM functions")])
    sigmas = count_by(m -> m.sigma)
    s = argmax(k -> sigmas[k], collect(keys(sigmas)))
    println(io, "member_corpus = \"beierle2025_n8\"\nmember_idx = 123456")
    println(io, "member_coeffs = \"", bytes2hex(members[b].coeffs), "\"\nmember_lut = \"", bytes2hex(members[b].lut), "\"")
    println(io, "function_name = \"", f.canonical_name, "\"\nfunction_lut = \"", f.lut_sha256, "\"")
    println(io, "function_corpora = ", get(luts, hex2bytes(f.lut_sha256), 0))
    println(io, "sigma = \"", bytes2hex(s), "\"\nsigma_members = ", sigmas[s])
end
close(sigma); close(db)
