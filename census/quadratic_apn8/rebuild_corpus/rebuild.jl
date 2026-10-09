"""
Rebuild the quadratic (8,8)-APN comparison baseline in a separate directory.

    julia --project=. -t 16 rebuild.jl stored|raw|compare [--outdir DIR] [--limit N]

`stored` reconstructs every registered n=8 corpus and quadratic-APN catalog
row. `raw` reads pinned public source files fetched by fetch.jl, including the
published list and the older public binary search dump. `compare` compares
the fresh stored signatures with the old index and with fresh raw signatures.
Only decoding uses VBF; verification/signature computation is independent.
Checkpoints bind inputs and computation code by SHA-256. --limit runs have
incomplete coverage and must use a separate output directory.
"""
const REBUILD_USAGE = nothing
using VBF, VBFCatalog, SHA, TOML, Dates, Printf
const SQL = VBFCatalog.SQLite
const DBI = VBFCatalog.DBInterface
const REPO = normpath(joinpath(@__DIR__, "../../.."))
const DEFAULT_OUTPUT = joinpath(REPO, "census/quadratic_apn8/results/signature_rebuild")
include("signature.jl")
using .IndependentSignature
module RawReaders
include("../crosscheck_raw/crosscheck.jl")
end

"""Open an existing SQLite input read-only; never create an absent source."""
function readonly(path)
    isfile(path) || error("missing input: $path")
    SQL.DB("file:" * abspath(path) * "?mode=ro")
end

"""Stream a SHA-256 digest without reading the whole source into memory."""
filehash(path) = bytes2hex(open(SHA.sha256, path))

"""Extract literal LUTs without executing upstream Python/Sage source."""
function literal_luts(path)
    luts = Vector{UInt8}[]
    for m in eachmatch(r"\[((?:\s*(?:0[xX][0-9a-fA-F]+|\d+)\s*,?\s*)+)\]", read(path, String))
        nums = [startswith(lowercase(strip(s)), "0x") ? parse(Int, strip(s)[3:end]; base=16) :
                parse(Int, strip(s)) for s in split(m.captures[1], ','; keepempty=false)]
        length(nums) == 256 || continue
        all(x -> 0 <= x <= 255, nums) || error("out-of-range LUT in $path")
        push!(luts, UInt8.(nums))
    end
    isempty(luts) && error("no 256-entry LUTs found in $path")
    luts
end

"""Extract balanced poly_to_lut arguments from Edel–Pott's source routine."""
function edelpott_luts(path)
    text = read(path, String)
    start = findfirst("def all_quadratic_polynomials", text)
    start === nothing && error("missing Edel–Pott routine")
    stop = findnext("\ndef ", text, last(start)+1)
    body = text[first(start):(stop === nothing ? lastindex(text) : first(stop)-1)]
    expressions = String[]
    pos = firstindex(body)
    while (hit = findnext("poly_to_lut(", body, pos)) !== nothing
        firstchar = last(hit)+1
        pos = firstchar; depth = 1
        while depth > 0
            body[pos] == '(' && (depth += 1)
            body[pos] == ')' && (depth -= 1)
            pos += 1
        end
        expr = body[firstchar:pos-2]
        while (m = match(r"sum\(X\*\*\((\d+)\*2\*\*i\) for i in range\(0, ?N\)\)", expr)) !== nothing
            k = parse(Int, m.captures[1])
            expr = replace(expr, m.match => "(" * join(["X**$(k*(1<<i))" for i in 0:7], " + ") * ")")
        end
        push!(expressions, replace(expr, r"\+\s*\+" => "+"))
    end
    length(expressions) == 22 || error("expected 22 Edel–Pott expressions")
    [UInt8.(polynomial_to_lut(expr, 8, conway_polynomial(8))) for expr in expressions]
end

"""The input descriptions, including original-file provenance and expected counts."""
function inputs(mode, outdir)
    catpath = VBFCatalog.catalog_path()
    cat = readonly(catpath)
    descriptions = NamedTuple[]
    try
        if mode == "stored"
            push!(descriptions, (; name="stored_functions", kind=:functions, paths=[catpath],
                expected=Int(first(DBI.execute(cat, "SELECT COUNT(*) c FROM functions WHERE n=8 AND is_apn=1 AND is_quadratic=1")).c),
                corpus="functions", modulus=0, url="catalog LUT rows", descriptor_sha=""))
            for name in VBFCatalog.list_corpora(cat)
                info = VBFCatalog.corpus_info(cat, name)
                Int(info.n) == Int(info.m) == 8 || error("unsupported corpus dimension: $name")
                info.encoding == "quadratic-coeffs-v1" || error("unsupported encoding")
                push!(descriptions, (; name="stored_" * name, kind=:store,
                    paths=[VBFCatalog.corpus_store_path(name)], expected=Int(info.member_count),
                    corpus=name, modulus=Int(info.modulus), url=String(info.source_repo),
                    descriptor_sha=String(info.store_sha256)))
            end
        elseif mode == "raw"
            sources = joinpath(outdir, "sources")
            apndb = joinpath(sources, "sboxU/sboxU/scripts/apnDB")
            for (corpus, file, kind) in [
                ("edelpott2009_n8", "eightBitAPN.py", :edelpott),
                ("wengtangong2013_n8", "eightBitAPN.py", :literals),
                ("yuwangli2014_qam_n8", "firstQAM.py", :literals),
                ("beierleleander2022_n8", "BeierleLeander.py", :literals),
                ("beierleleanderperrin2022_n8", "apn_8bit_BLP22.py", :literals),
                ("yuperrin2022_qam_n8", "secondQAM.py", :literals)]
                push!(descriptions, (; name="raw_"*corpus, kind, paths=[joinpath(apndb, file)],
                    expected=0, corpus, modulus=conway_polynomial(8),
                    url="https://github.com/lpp-crypto/sboxU/blob/7066b825c979ceefa901e7be3b2afcc63f587bcf/sboxU/scripts/apnDB/"*file,
                    descriptor_sha=""))
            end
            push!(descriptions, (; name="raw_simonberg_gf4_n8", kind=:polynomials,
                paths=[joinpath(sources, "thesis/rep$i.txt") for i in 1:27], expected=196863,
                corpus="simonberg_gf4_n8", modulus=conway_polynomial(8),
                url="https://github.com/Simon-Berg/thesis/tree/c13952d2458cb692171816b483f4e8ac0c62455a", descriptor_sha=""))
            push!(descriptions, (; name="raw_beierle2025_n8", kind=:stream,
                paths=[joinpath(sources, "new_apns.txt")], expected=3775599, corpus="beierle2025_n8", modulus=0,
                url="https://zenodo.org/records/16752428", descriptor_sha=""))
            push!(descriptions, (; name="raw_langevin_may2025", kind=:stream,
                paths=[joinpath(sources, "apn-11888039-may-2025-8.out")], expected=11888039,
                corpus="langevin_may2025", modulus=0, url="https://langevin.univ-tln.fr/data/apns/apn-11888039-may-2025-8.out", descriptor_sha=""))
            push!(descriptions, (; name="raw_taniguchi2019_n8", kind=:constructor,
                paths=[joinpath(REPO, "packages/VBF/src/constructions/taniguchi.jl")],
                expected=2, corpus="taniguchi2019_n8", modulus=0,
                url="Taniguchi Theorem 3; VBF constructor (no original LUT file)", descriptor_sha=""))
        else
            error("expected stored or raw")
        end
    finally
        close(cat)
    end
    mode == "stored" && sort!(descriptions; by=d -> d.expected)
    descriptions
end

"""Stream raw LUTs or compact encodings with stable input positions/member IDs."""
function records(desc, skip, batch)
    Channel{Vector{Tuple{Int,Vector{UInt8}}}}(2) do ch
        buf = Tuple{Int,Vector{UInt8}}[]
        emit(id, lut) = begin
            id <= skip && return
            push!(buf, (id, lut))
            if length(buf) >= batch
                put!(ch, copy(buf)); empty!(buf)
            end
        end
        if desc.kind in (:functions, :store)
            db = readonly(only(desc.paths))
            try
                if desc.kind == :functions
                    for r in DBI.execute(db, "SELECT id,lut_blob FROM functions WHERE n=8 AND is_apn=1 AND is_quadratic=1 AND id>$skip ORDER BY id")
                        emit(Int(r.id), Vector{UInt8}(r.lut_blob))
                    end
                else
                    counts = first(DBI.execute(db, "SELECT COUNT(*) c, MIN(idx) lo, MAX(idx) hi FROM members"))
                    (Int(counts.c) == desc.expected && Int(counts.lo) == 1 && Int(counts.hi) == desc.expected) ||
                        error("$(desc.name): incorrect count or noncontiguous member IDs")
                    for r in DBI.execute(db, "SELECT idx,coeffs FROM members WHERE idx>$skip ORDER BY idx")
                        emit(Int(r.idx), Vector{UInt8}(r.coeffs))
                    end
                end
            finally
                close(db)
            end
        elseif desc.kind == :stream
            path = only(desc.paths)
            id = skip
            stream = Channel{RawReaders.Batch}(2) do rawch
                RawReaders.produce!(rawch, path, RawReaders.fmt_of(path), skip, 0, batch)
            end
            for b in stream, j in eachindex(b.ids)
                id += 1
                b.ok[j] || error("malformed raw record $(b.ids[j]) in $path")
                emit(id, b.luts[j])
            end
        elseif desc.kind == :polynomials
            id = 0; powtab = monomial_power_table(8, desc.modulus)
            for path in desc.paths
                body = strip(read(path, String))
                startswith(body, "[") && endswith(body, "]") || error("malformed polynomial list: $path")
                for expr in split(body[2:end-1], ','; keepempty=false)
                    id += 1
                    id <= skip && continue
                    terms = polynomial_terms(strip(expr), 8, desc.modulus)
                    emit(id, UInt8.(terms_to_lut(terms, 8, desc.modulus; powtab)))
                end
            end
        else
            luts = desc.kind == :edelpott ? edelpott_luts(only(desc.paths)) :
                   desc.kind == :constructor ? [UInt8.(r.sbox.lut) for r in taniguchi_apn_representatives(4) if r.new] :
                   literal_luts(only(desc.paths))
            for (id, lut) in enumerate(luts)
                emit(id, lut)
            end
        end
        isempty(buf) || put!(ch, buf)
    end
end

"""Transactionally checkpoint recomputed signatures; refuse stale resumes."""
function input_identity(desc, limit)
    hashes = Dict(path => filehash(path) for path in desc.paths)
    provenance_hash = "not an original-file source"
    if startswith(desc.name, "raw_") && desc.kind != :constructor
        directory = dirname(first(desc.paths))
        while !isfile(joinpath(directory, "provenance.toml"))
            parent = dirname(directory)
            parent == directory && error("missing fetched-source provenance for $(desc.name)")
            directory = parent
        end
        provenance_path = joinpath(directory, "provenance.toml")
        provenance = TOML.parsefile(provenance_path)
        for (path, digest) in hashes
            relative = relpath(path, directory)
            haskey(provenance["files"], relative) || error("source absent from provenance: $path")
            provenance["files"][relative]["sha256"] == digest || error("source no longer matches fetch provenance: $path")
        end
        entries = Dict(relpath(path, directory) => provenance["files"][relpath(path, directory)] for path in desc.paths)
        provenance_hash = bytes2hex(SHA.sha256(sprint(io -> TOML.print(io, entries; sorted=true))))
    end
    codehash = bytes2hex(SHA.sha256(join(filehash.(
        [@__FILE__, joinpath(@__DIR__, "signature.jl"), joinpath(@__DIR__, "../crosscheck_raw/crosscheck.jl"),
         joinpath(REPO, "Manifest.toml"), joinpath(REPO, "packages/VBF/src/representations/univariate.jl")]))))
    identity = Dict("inputs"=>hashes, "code_sha256"=>codehash, "source_provenance_sha256"=>provenance_hash,
                    "julia_version"=>string(VERSION), "limit"=>limit,
                    "expected"=>desc.expected, "modulus"=>desc.modulus, "kind"=>string(desc.kind))
    identity
end

"""Transactionally checkpoint recomputed signatures; refuse stale resumes."""
function rebuild(desc, outdir; limit=0, batch=10000)
    identity = input_identity(desc, limit)
    hashes, codehash = identity["inputs"], identity["code_sha256"]
    path = joinpath(outdir, desc.name * ".sqlite")
    db = SQL.DB(path)
    try
        SQL.execute(db, "CREATE TABLE IF NOT EXISTS records(member_idx INTEGER PRIMARY KEY, sigma_hash TEXT NOT NULL, lut_sha256 TEXT NOT NULL)")
        SQL.execute(db, "CREATE TABLE IF NOT EXISTS excluded(member_idx INTEGER PRIMARY KEY, reason TEXT NOT NULL, lut_sha256 TEXT NOT NULL)")
        SQL.execute(db, "CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        identity_text = sprint(io -> TOML.print(io, identity; sorted=true))
        previous = [String(r.value) for r in DBI.execute(db, "SELECT value FROM metadata WHERE key='identity'")]
        if isempty(previous)
            DBI.execute(db, "INSERT INTO metadata VALUES('identity',?)", (identity_text,))
        else
            only(previous) == identity_text || error("input/code/limit changed; use a new outdir: $path")
        end
        completed = !isempty(collect(DBI.execute(db, "SELECT 1 FROM metadata WHERE key='complete' AND value='true'")))
        completed && (println(desc.name, ": already complete"); return)
        r = first(DBI.execute(db, "SELECT COUNT(*) c, COALESCE(MAX(member_idx),0) i FROM (SELECT member_idx FROM records UNION ALL SELECT member_idx FROM excluded)"))
        count, skip = Int(r.c), Int(r.i)
        w = [Workspace() for _ in 1:Threads.nthreads()]
        powtab = desc.kind == :store ? monomial_power_table(8, desc.modulus) : nothing
        stmt = DBI.prepare(db, "INSERT INTO records VALUES(?,?,?)")
        excluded_stmt = DBI.prepare(db, "INSERT INTO excluded VALUES(?,?,?)")
        t0 = time(); added = 0; exhausted = true
        channel = records(desc, skip, batch)
        try
            for rows in channel
                if limit > 0
                    allowed = limit-count
                    allowed <= 0 && (exhausted=false; break)
                    length(rows) > allowed && (resize!(rows, allowed); exhausted=false)
                end
                results = Vector{Tuple{Union{Nothing,String},String,String}}(undef, length(rows))
                Threads.@threads :static for worker in eachindex(w)
                    for j in worker:length(w):length(rows)
                        lut = desc.kind == :store ? UInt8.(decode_quadratic_lut(rows[j][2], 8, desc.modulus; powtab)) : rows[j][2]
                        h = nothing; reason = ""
                        try
                            h = bytes2hex(signature(w[worker], lut))
                        catch exception
                            message = sprint(showerror, exception)
                            # Upstream literal-LUT lists intentionally include nonquadratic
                            # functions. Record all such positions rather than silently filter.
                            if desc.kind == :literals && exception isa ErrorException &&
                                    (startswith(message, "degree ") || startswith(message, "not APN:"))
                                reason = message
                            else
                                error("$(desc.name) member $(rows[j][1]): $message")
                            end
                        end
                        results[j] = (h, bytes2hex(SHA.sha256(lut)), reason)
                    end
                end
                SQL.transaction(db) do
                    for j in eachindex(rows)
                        h, lutsha, reason = results[j]
                        if h === nothing
                            DBI.execute(excluded_stmt, (rows[j][1], reason, lutsha))
                        else
                            DBI.execute(stmt, (rows[j][1], h, lutsha))
                        end
                    end
                end
                count += length(rows); added += length(rows)
                @printf("%s: %d records; %.0f records/s\n", desc.name, count, added/max(time()-t0,0.001))
                flush(stdout)
                if limit > 0 && count >= limit
                    exhausted = false
                    break
                end
            end
        finally
            close(channel)
            DBI.close!(stmt)
            DBI.close!(excluded_stmt)
        end
        complete = exhausted && limit == 0 && (desc.expected == 0 || count == desc.expected)
        desc.expected > 0 && exhausted && limit == 0 && count != desc.expected &&
            error("$(desc.name): expected $(desc.expected), got $count")
        SQL.execute(db, "CREATE INDEX IF NOT EXISTS ix_sigma_hash ON records(sigma_hash)")
        SQL.execute(db, "CREATE INDEX IF NOT EXISTS ix_lut_sha256 ON records(lut_sha256)")
        excluded_count = Int(first(DBI.execute(db, "SELECT COUNT(*) c FROM excluded")).c)
        summary = Dict("source"=>desc.name, "records"=>count, "quadratic_apn_records"=>count-excluded_count,
            "excluded_records"=>excluded_count, "complete"=>complete,
            "expected_records"=>desc.expected, "input_sha256"=>hashes, "url"=>desc.url,
            "code_sha256"=>codehash, "seconds_this_run"=>time()-t0,
            "verification"=>"independent Mobius degree / polar rank / DDT / integer FWHT",
            "descriptor_sha256_matches"=>isempty(desc.descriptor_sha) ? "not applicable" : string(only(values(hashes)) == desc.descriptor_sha))
        summary_path = joinpath(outdir, desc.name * ".toml")
        open(io -> TOML.print(io, summary; sorted=true), summary_path * ".partial", "w")
        mv(summary_path * ".partial", summary_path; force=true)
        DBI.execute(db, "INSERT OR REPLACE INTO metadata VALUES('complete',?)", (string(complete),))
        println(desc.name, ": complete=", complete)
    finally
        close(db)
    end
end

"""Parse CLI options and run the selected rebuild stage."""
function main(args)
    isempty(args) && error("usage: rebuild.jl stored|raw|compare [--outdir DIR] [--limit N] [--source NAME]")
    mode = args[1]; outdir = DEFAULT_OUTPUT; limit = 0; selected = ""
    i = 2
    while i <= length(args)
        i < length(args) || error("missing option value")
        opt, val = args[i:i+1]
        opt == "--outdir" ? (outdir=abspath(val)) :
        opt == "--limit" ? (limit=parse(Int,val)) :
        opt == "--source" ? (selected=val) : error("unknown option $opt")
        i += 2
    end
    limit >= 0 || error("limit must be nonnegative")
    mkpath(outdir)
    mode == "compare" && return compare(outdir)
    descriptions = inputs(mode, outdir)
    isempty(selected) || (descriptions=filter(d -> d.name == selected, descriptions))
    isempty(descriptions) && error("no selected source")
    for desc in descriptions
        rebuild(desc, outdir; limit)
    end
end

include("compare.jl")
abspath(PROGRAM_FILE) == (@__FILE__) && main(ARGS)
