#!/usr/bin/env julia
#
# packages/VBFRepro/analysis/reproductions/metrics.jl — build the metric tables that the paper analyses.
#
#   julia --project=. packages/VBFRepro/analysis/reproductions/metrics.jl                 # every section
#   julia --project=. packages/VBFRepro/analysis/reproductions/metrics.jl --only=corpus   # one section
#   julia --project=. packages/VBFRepro/analysis/reproductions/metrics.jl --sample=1024 --budget-seconds=300
#   julia --project=. packages/VBFRepro/analysis/reproductions/metrics.jl --list          # print the sections
#
# The script reads the repository and writes only into data/repro/analysis/reproductions/. It
# changes no database, it touches no file under packages/ or papers/, and it
# runs no git command.
#
# `packages/VBFRepro/analysis/reproductions/METRICS.md` defines every table and says why it is in the paper.
# `packages/VBFRepro/analysis/reproductions/taxonomy.toml` holds the classification that no other file states in
# a machine-readable form.
#
# THE OUTPUT FORMAT. Every CSV holds data only: one header line of column names,
# then one line for each row. There is no comment line, so pandas, R or a
# spreadsheet reads it with no filter. The provenance of every file goes into
# data/repro/analysis/reproductions/PROVENANCE.md instead.
#
# THE SECTIONS.
#   papers      current paper inventory and catalog contributions
#   catalog     where the APN functions are, by method and by dimension
#   corpus      what each published corpus carries, in sigma-class terms
#   invariants  the cost of each invariant against what it separates (SLOW)
#
# Only `invariants` computes anything. The other three sections read files and
# finish in seconds.

using Printf, TOML, Dates, Random, SHA
using VBF, VBFCatalog, VBFRepro

# The root project depends on VBFCatalog, which depends on SQLite. Reaching the
# driver through the package keeps the root Project.toml unchanged.
const SQLite = VBFCatalog.SQLite
const DBInterface = VBFCatalog.DBInterface

const HERE     = @__DIR__
const ROOT     = VBFRepro.repo_root()
const OUT      = get(ENV, "VBF_REPRO_ANALYSIS_OUTPUT", joinpath(ROOT, "data/repro/analysis/reproductions"))
const TAXONOMY = joinpath(HERE, "taxonomy.toml")

const BFA4R        = get(ENV, "VBF_REPRO_GRADES", joinpath(OUT, "bfa4r_grades.csv"))
const BENCHMARKS   = get(ENV, "VBF_REPRO_LEGACY_BENCHMARKS", joinpath(ROOT, "data/perf/archive/generated/benchmarks.csv"))
const CATALOG_DB   = joinpath(ROOT, "packages", "VBFCatalog", "BFA_catalog.sqlite")
const SIGMA_DB     = joinpath(ROOT, "packages", "VBFCatalog", "corpora",
                              "ccz_sigma_index.sqlite")

const SECTIONS = ["papers", "catalog", "corpus", "invariants"]

# ── command line ────────────────────────────────────────────────────────────

const HELP = """
packages/VBFRepro/analysis/reproductions/metrics.jl — build the metric tables that the paper analyses.

usage: julia --project=. packages/VBFRepro/analysis/reproductions/metrics.jl [options]

  --only=NAME           run one section; repeat the flag for more
                        ($(join(SECTIONS, ", ")))
  --sample=N            functions per population in `invariants` (default 128)
  --seed=N              the seed of that sample (default 20260901)
  --budget-seconds=X    wall-clock ceiling for one (invariant, population) pair
                        in `invariants` (default 15). The worst case of the
                        whole section is invariants x populations x this value.
  --list                print the sections and the tables, build none
  -h, --help            print this text

See packages/VBFRepro/analysis/reproductions/METRICS.md.
"""

function parse_args(argv)
    only = String[]
    sample = 128
    seed = 20260901
    budget = 15.0
    for a in argv
        if (m = match(r"^--only=([a-z]+)$", a)) !== nothing
            m.captures[1] in SECTIONS ||
                error("unknown section $(m.captures[1]); expected one of $(join(SECTIONS, ", "))")
            push!(only, m.captures[1])
        elseif (m = match(r"^--sample=(\d+)$", a)) !== nothing
            sample = parse(Int, m.captures[1])
        elseif (m = match(r"^--seed=(\d+)$", a)) !== nothing
            seed = parse(Int, m.captures[1])
        elseif (m = match(r"^--budget-seconds=([0-9.]+)$", a)) !== nothing
            budget = parse(Float64, m.captures[1])
        elseif a == "--list"
            for s in SECTIONS
                println(s)
            end
            exit(0)
        elseif a in ("-h", "--help")
            print(HELP); exit(0)
        else
            error("unknown argument: $a")
        end
    end
    return (only = isempty(only) ? SECTIONS : only, sample = sample,
            seed = seed, budget = budget)
end

const OPTS = parse_args(ARGS)

# ── the CSV writer ──────────────────────────────────────────────────────────

"Quote a field only when it holds a comma, a quotation mark or a newline."
function csv_field(v)::String
    s = v === nothing ? "" : v isa Bool ? (v ? "1" : "0") : string(v)
    if occursin(',', s) || occursin('"', s) || occursin('\n', s)
        return '"' * replace(s, '"' => "\"\"") * '"'
    end
    return s
end

"""
    write_csv(name, header, rows) -> String

Write one table into data/repro/analysis/reproductions/. The file holds the header line and
the rows, and nothing else. Provenance belongs in PROVENANCE.md.
"""
function write_csv(name::AbstractString, header::Vector{String}, rows)
    mkpath(OUT)
    path = joinpath(OUT, name)
    open(path, "w") do io
        println(io, join(header, ","))
        for r in rows
            length(r) == length(header) ||
                error("$name: a row has $(length(r)) fields and the header has $(length(header))")
            println(io, join(csv_field.(r), ","))
        end
    end
    push!(WRITTEN, (name, length(rows), length(header)))
    return path
end

const WRITTEN = Tuple{String,Int,Int}[]

# ── the shared sources ──────────────────────────────────────────────────────

const TAX = TOML.parsefile(TAXONOMY)

open_db(path) = isfile(path) ? SQLite.DB(path) : nothing

"""
    q(db, sql) -> Vector{NamedTuple}

Run one query and materialise every row. The driver gives a forward-only
cursor, so each row must become a NamedTuple inside the loop; a row that
outlives its iteration is invalid.
"""
function q(db, sql::AbstractString)
    db === nothing && return NamedTuple[]
    return [NamedTuple(r) for r in DBInterface.execute(db, sql)]
end

"""
    read_csv(path) -> (header, rows)

Read a CSV that this repository generated. It handles the quoted fields that
`write_csv` produces and nothing more.
"""
function read_csv(path::AbstractString)
    isfile(path) || return (String[], Vector{String}[])
    lines = readlines(path)
    isempty(lines) && return (String[], Vector{String}[])
    split_line = function (l)
        out = String[]; buf = IOBuffer(); inq = false; i = 1
        while i <= lastindex(l)
            c = l[i]
            if inq
                if c == '"'
                    if i < lastindex(l) && l[i+1] == '"'
                        print(buf, '"'); i += 1
                    else
                        inq = false
                    end
                else
                    print(buf, c)
                end
            elseif c == '"'
                inq = true
            elseif c == ','
                push!(out, String(take!(buf)))
            else
                print(buf, c)
            end
            i = nextind(l, i)
        end
        push!(out, String(take!(buf)))
        return out
    end
    header = split_line(lines[1])
    rows = [split_line(l) for l in lines[2:end] if !isempty(strip(l))]
    return (header, rows)
end

# ── section: papers ─────────────────────────────────────────────────────────

function section_papers()
    println("[papers] discovering runnable reproductions")
    db = load_catalog(CATALOG_DB)
    try
        functions = Dict(String(r.bib_key) => Int(r.c) for r in q(db,
            "SELECT bib_key, COUNT(*) c FROM functions WHERE is_apn=1 AND bib_key IS NOT NULL GROUP BY bib_key"))
        corpora = Dict(String(r.bib_key) => Int(r.c) for r in q(db,
            "SELECT bib_key, SUM(member_count) c FROM bulk_corpora WHERE bib_key IS NOT NULL GROUP BY bib_key"))
        header, records = read_csv(BFA4R)
        grades = Dict{String,Vector{String}}()
        if !isempty(header)
            positions = Dict(h => i for (i,h) in enumerate(header))
            for row in records
                grades[row[positions["paper_id"]]] = [row[positions[r]] for r in ("r1","r2","r3","r4")]
            end
        end
        rows = Vector{Any}[]
        for paper in discover_papers()
            classification = get(TAX["papers"], paper.id, Dict{String,Any}())
            key = get(classification, "catalog_bib_key", paper.id)
            test_files = sum(count(f -> endswith(f,".jl"), files)
                for name in ("test","tests") if isdir(joinpath(paper.path,name))
                for (_,_,files) in walkdir(joinpath(paper.path,name)); init=0)
            push!(rows, Any[paper.id,parse(Int,paper.year),get(classification,"topic","unclassified"),
                key,relpath(paper.path,ROOT),test_files,get(functions,key,0),get(corpora,key,0),
                get(grades,paper.id,["","","",""])...])
        end
        write_csv("papers.csv", ["paper_id","year","topic","catalog_bib_key","path",
            "test_files","catalog_functions","corpus_members","r1","r2","r3","r4"], rows)
    finally
        db === nothing || SQLite.close(db)
    end
end

# ── section: catalog ────────────────────────────────────────────────────────

"The construction group of one row of the functions table."
function row_group(bib_key, family)
    bg = TAX["bib_group"]; fg = TAX["family_group"]
    if bib_key !== missing && bib_key !== nothing && !isempty(String(bib_key))
        k = String(bib_key)
        haskey(bg, k) || error("packages/VBFRepro/analysis/reproductions/taxonomy.toml has no bib_group for $k")
        return bg[k]
    end
    f = String(family)
    haskey(fg, f) || error("packages/VBFRepro/analysis/reproductions/taxonomy.toml has no family_group for $f")
    return fg[f]
end

function section_catalog()
    println("[catalog] reading the catalog and the sigma index")
    db = open_db(CATALOG_DB)
    db === nothing && error("no catalog at $CATALOG_DB")
    sig = open_db(SIGMA_DB)
    sig === nothing && @warn "no sigma index; the sigma columns stay empty" path = SIGMA_DB

    # The sigma index covers QUADRATIC APN functions only, because the
    # ortho-derivative signature is defined for them. The quadratic count
    # therefore travels beside the total, or a reader compares a sigma-class
    # count against a denominator that sigma never saw.
    curated = Dict{Tuple{String,Int},Int}()
    curated_q = Dict{Tuple{String,Int},Int}()
    for r in q(db, "SELECT COALESCE(bib_key,'') bk, family, n, is_quadratic, COUNT(*) c " *
                   "FROM functions WHERE is_apn = 1 GROUP BY bk, family, n, is_quadratic")
        g = row_group(r.bk, r.family)
        k = (g, Int(r.n))
        curated[k] = get(curated, k, 0) + Int(r.c)
        Int(r.is_quadratic) == 1 && (curated_q[k] = get(curated_q, k, 0) + Int(r.c))
    end

    corpora = q(db, "SELECT name, n, member_count FROM bulk_corpora")
    taxc = TAX["corpus"]
    members = Dict{Tuple{String,Int},Int}()
    for r in corpora
        nm = String(r.name)
        haskey(taxc, nm) || error("packages/VBFRepro/analysis/reproductions/taxonomy.toml has no corpus entry for $nm")
        k = (String(taxc[nm]["group"]), Int(r.n))
        members[k] = get(members, k, 0) + Int(r.member_count)
    end

    # the sigma classes of each source, mapped to a group
    sigma_by_group = Dict{Tuple{String,Int},Int}()
    sigma_by_source = Dict{Tuple{String,Int},Int}()
    if sig !== nothing
        for r in q(sig, "SELECT source, n, COUNT(DISTINCT sigma_hash) c " *
                        "FROM ccz_sigma_index GROUP BY source, n")
            src = String(r.source)
            sigma_by_source[(src, Int(r.n))] = Int(r.c)
            haskey(taxc, src) || error("packages/VBFRepro/analysis/reproductions/taxonomy.toml has no corpus entry for $src")
            g = String(taxc[src]["group"])
            k = (g, Int(r.n))
            sigma_by_group[k] = get(sigma_by_group, k, 0) + Int(r.c)
        end
    end

    groups = sort(unique(vcat([k[1] for k in keys(curated)],
                              [k[1] for k in keys(members)])))
    dims = sort(unique(vcat([k[2] for k in keys(curated)],
                            [k[2] for k in keys(members)])))
    rows = Vector{Any}[]
    for g in groups, n in dims
        cu = get(curated, (g, n), 0)
        me = get(members, (g, n), 0)
        si = get(sigma_by_group, (g, n), 0)
        (cu == 0 && me == 0 && si == 0) && continue
        push!(rows, Any[g, n, cu, get(curated_q, (g, n), 0), me, si])
    end
    write_csv("method_by_dimension.csv",
              ["method_group", "n", "curated_functions", "curated_quadratic",
               "corpus_members", "corpus_sigma_classes"], rows)

    # evidence_depth.csv — the denominator of a novelty verdict at each n
    # The distinct count per dimension, and not the sum over the sources: some
    # sigma classes appear in more than one source.
    sigma_distinct = Dict{Int,Int}()
    if sig !== nothing
        for r in q(sig, "SELECT n, COUNT(DISTINCT sigma_hash) c FROM ccz_sigma_index GROUP BY n")
            sigma_distinct[Int(r.n)] = Int(r.c)
        end
    end
    erows = Vector{Any}[]
    for n in sort(unique(vcat(dims, [Int(r.n) for r in corpora], collect(keys(sigma_distinct)))))
        cu = sum(get(curated, (g, n), 0) for g in groups)
        cq = sum(get(curated_q, (g, n), 0) for g in groups)
        cs = [r for r in corpora if Int(r.n) == n]
        me = isempty(cs) ? 0 : sum(Int(r.member_count) for r in cs)
        si = get(sigma_distinct, n, 0)
        srcs = length(unique(s for ((s, m), _) in sigma_by_source if m == n))
        push!(erows, Any[n, cu, cq, length(cs), me, si, srcs, !isempty(cs)])
    end
    write_csv("evidence_depth.csv",
              ["n", "curated_functions", "curated_quadratic", "corpora",
               "corpus_members", "sigma_classes", "indexed_sources",
               "bulk_corpus_exists"], erows)

    SQLite.close(db)
    sig === nothing || SQLite.close(sig)
    return nothing
end

# ── section: corpus ─────────────────────────────────────────────────────────

function section_corpus()
    println("[corpus] measuring the sigma-class content of each source")
    sig = open_db(SIGMA_DB)
    sig === nothing && error("no sigma index at $SIGMA_DB; build it with build_sigma_index!")
    db = open_db(CATALOG_DB)
    taxc = TAX["corpus"]

    # The member count is per (source, n). The sigma index labels every curated
    # row with the source name "functions", and that source spans every
    # dimension, so its count must be per dimension as well.
    member_count = Dict{Tuple{String,Int},Int}()
    for r in q(db, "SELECT name, n, member_count FROM bulk_corpora")
        member_count[(String(r.name), Int(r.n))] = Int(r.member_count)
    end
    for r in q(db, "SELECT n, COUNT(*) c FROM functions WHERE is_apn = 1 GROUP BY n")
        member_count[("functions", Int(r.n))] = Int(r.c)
    end

    # Three temporary tables. `s` holds one row per (source, n, sigma). `m`
    # counts how many sources carry each sigma, so the shared classes are a
    # lookup and not a correlated scan over four million rows. The pairwise
    # join then runs over the shared classes only.
    DBInterface.execute(sig, "DROP TABLE IF EXISTS temp.s")
    DBInterface.execute(sig, "DROP TABLE IF EXISTS temp.m")
    DBInterface.execute(sig,
        "CREATE TEMP TABLE s AS SELECT DISTINCT source, n, sigma_hash FROM ccz_sigma_index")
    DBInterface.execute(sig, "CREATE INDEX temp.ix_s ON s(sigma_hash, n)")
    DBInterface.execute(sig,
        "CREATE TEMP TABLE m AS SELECT sigma_hash, n, COUNT(*) k FROM s GROUP BY sigma_hash, n")
    DBInterface.execute(sig, "CREATE INDEX temp.ix_m ON m(sigma_hash, n)")

    indexed = Dict{Tuple{String,Int},Int}()
    for r in q(sig, "SELECT source, n, COUNT(*) c FROM ccz_sigma_index GROUP BY source, n")
        indexed[(String(r.source), Int(r.n))] = Int(r.c)
    end
    classes = Dict{Tuple{String,Int},Int}()
    for r in q(sig, "SELECT source, n, COUNT(*) c FROM s GROUP BY source, n")
        classes[(String(r.source), Int(r.n))] = Int(r.c)
    end
    shared = Dict{Tuple{String,Int},Int}()
    for r in q(sig, "SELECT s.source src, s.n nn, COUNT(*) c FROM s JOIN m " *
                    "ON m.sigma_hash = s.sigma_hash AND m.n = s.n " *
                    "WHERE m.k > 1 GROUP BY s.source, s.n")
        shared[(String(r.src), Int(r.nn))] = Int(r.c)
    end

    rows = Vector{Any}[]
    for ((src, n), cls) in sort(collect(classes); by = x -> -x[2])
        haskey(taxc, src) || error("packages/VBFRepro/analysis/reproductions/taxonomy.toml has no corpus entry for $src")
        idx = indexed[(src, n)]
        sh = get(shared, (src, n), 0)
        mem = get(member_count, (src, n), idx)
        push!(rows, Any[src, String(taxc[src]["group"]), n, mem, idx, cls,
                        round(idx / max(cls, 1); digits = 2),
                        cls - sh, sh, String(taxc[src]["note"])])
    end
    write_csv("corpus_sigma.csv",
              ["source", "method_group", "n", "member_count", "indexed_rows",
               "sigma_classes", "rows_per_sigma_class", "unique_sigma_classes",
               "shared_sigma_classes", "note"], rows)

    orows = Vector{Any}[]
    for r in q(sig, "SELECT a.source sa, b.source sb, a.n nn, COUNT(*) c FROM s a " *
                    "JOIN s b ON a.sigma_hash = b.sigma_hash AND a.n = b.n " *
                    "AND a.source < b.source JOIN m ON m.sigma_hash = a.sigma_hash " *
                    "AND m.n = a.n AND m.k > 1 " *
                    "GROUP BY a.source, b.source, a.n ORDER BY c DESC")
        sa, sb, n, c = String(r.sa), String(r.sb), Int(r.nn), Int(r.c)
        na, nb = classes[(sa, n)], classes[(sb, n)]
        push!(orows, Any[sa, sb, n, na, nb, c,
                         round(c / max(na, 1); digits = 4),
                         round(c / max(nb, 1); digits = 4),
                         String(taxc[sa]["note"]), String(taxc[sb]["note"])])
    end
    write_csv("corpus_overlap.csv",
              ["source_a", "source_b", "n", "sigma_classes_a", "sigma_classes_b",
               "shared_sigma_classes", "share_of_a", "share_of_b",
               "note_a", "note_b"], orows)

    SQLite.close(sig)
    db === nothing || SQLite.close(db)
    return nothing
end

# ── section: invariants ─────────────────────────────────────────────────────
#
# The only section that computes. It applies each invariant to each population
# and reports what the invariant separates, next to what it costs. The cost
# comes from data/perf/archive/generated/benchmarks.csv, so the two datasets agree.

"Read the measured cost of one benchmark case at the nearest n at or below `n`."
function bench_cost(case::AbstractString, n::Int)
    h, rows = read_csv(BENCHMARKS)
    isempty(h) && return nothing
    gi = Dict(k => i for (i, k) in enumerate(h))
    best = nothing
    for r in rows
        (r[gi["group"]] * "/" * r[gi["case"]]) == case || continue
        rn = parse(Int, r[gi["n"]])
        rn == 0 && continue
        t = parse(Float64, r[gi["min_seconds"]])
        if best === nothing || abs(rn - n) < abs(best[1] - n)
            best = (rn, t)
        end
    end
    return best
end

"""
    bucket_key(v) -> String

A key that depends on the VALUE of an invariant and never on how it prints.

CAUTION: `string(v)` is wrong here. `apn_ea_mugshot` returns a struct whose
`show` method prints a summary — `APNEAMugshot{kind=quadratic, 2 components}` —
which is the same text for every quadratic APN function. A key built from that
text puts every function into one bucket and makes the invariant look useless.
This function walks the fields instead, and it sorts a dictionary, because two
equal dictionaries can iterate in different orders.
"""
function bucket_key(v)::String
    v === nothing && return "nothing"
    v isa AbstractString && return String(v)
    (v isa Number || v isa Symbol || v isa Char || v isa Bool) && return string(v)
    if v isa AbstractDict
        return "D(" * join(sort!([bucket_key(k) * "=>" * bucket_key(x) for (k, x) in v]), ",") * ")"
    end
    if v isa AbstractSet
        return "S(" * join(sort!([bucket_key(x) for x in v]), ",") * ")"
    end
    if v isa Tuple || v isa AbstractArray
        return "A(" * join((bucket_key(x) for x in v), ",") * ")"
    end
    T = typeof(v)
    if isstructtype(T) && !isempty(fieldnames(T))
        return string(nameof(T)) * "(" *
               join((bucket_key(getfield(v, f)) for f in fieldnames(T)), ",") * ")"
    end
    return string(v)
end

function section_invariants()
    db = open_db(CATALOG_DB)
    db === nothing && error("no catalog at $CATALOG_DB")

    # the invariants, from the taxonomy
    calls = Dict{String,Function}(
        "sigma_hash" => F -> sigma_hash(F),
        "od_diff"    => F -> (p = ortho_derivative(F);
                              p === nothing ? error("no ortho-derivative") :
                              sorted_pairs(differential_spectrum(p))),
        "od_walsh"   => F -> (p = ortho_derivative(F);
                              p === nothing ? error("no ortho-derivative") :
                              sorted_pairs(absolute_walsh_spectrum(p))),
        "apn_ea_mugshot"            => F -> apn_ea_mugshot(F),
        "pi_multiset"               => F -> pi_multiset(F, 0),
        "component_degree_spectrum" => F -> component_degree_spectrum(F),
        "differential_spectrum"     => F -> sorted_pairs(differential_spectrum(F)),
        "absolute_walsh_spectrum"   => F -> sorted_pairs(absolute_walsh_spectrum(F)),
        "gamma_rank"                => F -> gamma_rank(F),
        "delta_rank"                => F -> delta_rank(F))

    # the populations
    rng = Random.Xoshiro(OPTS.seed)
    pops = Tuple{String,Int,Vector{Any}}[]      # (name, n, functions)

    # QUADRATIC APN functions only. Three reasons, and they agree:
    #   1. the sigma signature is defined for them, so the sigma index covers
    #      exactly this population and the two datasets stay comparable;
    #   2. CCZ equivalence and EA equivalence coincide here (Yoshiara), so a
    #      separation statement means one thing and not two;
    #   3. the fallback path of apn_ea_mugshot, which a non-quadratic function
    #      takes, computes a thickness spectrum whose cost at n >= 10 is far
    #      above anything the benchmark suite measured.
    for r in q(db, "SELECT n, COUNT(*) c FROM functions " *
                   "WHERE is_apn = 1 AND is_quadratic = 1 GROUP BY n ORDER BY n")
        n, c = Int(r.n), Int(r.c)
        c >= 4 || continue
        ids = [Int(x.id) for x in q(db, "SELECT id FROM functions " *
                                        "WHERE is_apn = 1 AND is_quadratic = 1 AND n = $n ORDER BY id")]
        length(ids) > OPTS.sample && (ids = ids[Random.randperm(rng, length(ids))[1:OPTS.sample]])
        fs = Any[]
        for i in ids
            try
                push!(fs, load_sbox(db, i))
            catch err
                @warn "a catalog function did not load" id = i error = err
            end
        end
        isempty(fs) || push!(pops, ("catalog_n$n", n, fs))
    end

    for r in q(db, "SELECT name, n, member_count FROM bulk_corpora ORDER BY member_count")
        nm, n, mc = String(r.name), Int(r.n), Int(r.member_count)
        isfile(corpus_store_path(nm)) || continue
        k = min(OPTS.sample, mc)
        idx = mc <= k ? collect(1:mc) : sort(Random.randperm(rng, mc)[1:k])
        fs = Any[]
        for i in idx
            try
                push!(fs, corpus_function(db, nm, i))
            catch err
                @warn "a corpus member did not decode" corpus = nm index = i error = err
            end
        end
        isempty(fs) || push!(pops, ("corpus_" * nm, n, fs))
    end

    # `@printf` needs a literal format, so the message is one string.
    @printf("[invariants] %d populations, %d invariants, sample <= %d, budget %.0f s per pair; worst case %.0f min\n",
            length(pops), length(TAX["invariant"]), OPTS.sample, OPTS.budget,
            length(pops) * length(TAX["invariant"]) * OPTS.budget / 60)
    flush(stdout)

    rows = Vector{Any}[]
    for inv in TAX["invariant"]
        name = String(inv["name"])
        call = calls[String(inv["call"])]
        maxn = Int(inv["max_n"])
        bcase = String(inv["bench_case"])
        for (pname, n, fs) in pops
            N = length(fs)
            cost = bench_cost(bcase, n)
            secs = cost === nothing ? nothing : cost[2]
            if n > maxn
                push!(rows, Any[name, pname, n, N, "", "", "", "", "", "", "",
                                secs === nothing ? "" : secs, "",
                                "not_applicable", String(inv["note"])])
                continue
            end
            if secs !== nothing && secs * N > OPTS.budget
                push!(rows, Any[name, pname, n, N, "", "", "", "", "", "", "",
                                secs, round(secs * N; digits = 1),
                                "skipped_budget", String(inv["note"])])
                continue
            end
            # Three outcomes for one function: a value, an undefined result, or
            # an error. An undefined result must NOT become a bucket of its own,
            # or "the invariant does not apply here" would read as "every one of
            # these functions has the same invariant".
            keys_seen = Dict{String,Int}()
            errors = 0
            undefined = 0
            stopped = false
            t0 = time_ns()
            for F in fs
                if (time_ns() - t0)*1e-9 > OPTS.budget
                    stopped = true
                    break
                end
                try
                    v = call(F)
                    if v === nothing || v === missing
                        undefined += 1
                    else
                        k = bucket_key(v)
                        keys_seen[k] = get(keys_seen, k, 0) + 1
                    end
                catch
                    errors += 1
                end
            end
            el = (time_ns() - t0)*1e-9
            ev = sum(values(keys_seen); init = 0)
            counts = collect(values(keys_seen))
            distinct = length(counts)
            maxb = isempty(counts) ? 0 : maximum(counts)
            singles = count(==(1), counts)
            pairs_total = ev * (ev - 1) ÷ 2
            same = sum(c * (c - 1) ÷ 2 for c in counts; init = 0)
            sep = pairs_total == 0 ? "" : round(1 - same / pairs_total; digits = 6)
            push!(rows, Any[name, pname, n, N, ev, undefined, errors, distinct,
                            maxb, singles, sep, secs === nothing ? "" : secs,
                            el,
                            stopped ? "stopped_budget" : "measured",
                            String(inv["note"])])
            @printf("  %-26s %-34s n=%2d N=%4d distinct=%5s sep=%-8s %6.2f s\n",
                    name, pname, n, N, string(distinct), string(sep), el)
            flush(stdout)
        end
    end
    write_csv("invariant_power.csv",
              ["invariant", "population", "n", "population_size", "evaluated",
               "undefined", "errors", "distinct_values", "largest_bucket",
               "singleton_buckets", "pair_separation_rate",
               "bench_seconds_per_call", "measured_seconds", "status", "note"],
              rows)

    SQLite.close(db)
    return nothing
end

# ── provenance ──────────────────────────────────────────────────────────────

function write_provenance(ran::Vector{String}, wall::Float64)
    mkpath(OUT)
    open(joinpath(OUT, "PROVENANCE.md"), "w") do io
        println(io, "# Provenance of `data/repro/analysis/reproductions/`\n")
        println(io, "Do not edit these files. Rebuild them with `make -C packages/VBFRepro/analysis all`.")
        println(io, "`packages/VBFRepro/analysis/reproductions/METRICS.md` says what each table is for.\n")
        println(io, "| Field | Value |")
        println(io, "|---|---|")
        println(io, "| Generated (UTC) | ", Dates.format(now(UTC), "yyyy-mm-dd HH:MM"), " |")
        println(io, "| Julia | ", VERSION, " |")
        println(io, "| Sections | ", join(ran, ", "), " |")
        if "invariants" in ran
            println(io, "| Sample per population | ", OPTS.sample, " |")
            println(io, "| Sample seed | ", OPTS.seed, " |")
            println(io, "| Budget for one pair | ", OPTS.budget, " s |")
        end
        println(io, "| Wall time | ", round(wall; digits = 1), " s |")
        println(io, "\n## Sources\n")
        println(io, "Paper inventory comes from VBFRepro.discover_papers(); test-file counts are structural, not successful test executions.")
        for (label, path) in [("the metrics implementation", @__FILE__),
                              ("paper discovery", joinpath(ROOT,"packages","VBFRepro","src","VBFRepro.jl")),
                              ("the classification", TAXONOMY),
                              ("the evidence grades", BFA4R),
                              ("the measured costs", BENCHMARKS),
                              ("the catalog", CATALOG_DB),
                              ("the sigma index", SIGMA_DB)]
            st = isfile(path) ? Dates.format(Dates.unix2datetime(mtime(path)),
                                             "yyyy-mm-dd HH:MM") : "ABSENT"
            digest = isfile(path) ? open(io -> bytes2hex(sha256(io)),path) : "ABSENT"
            println(io, "- ", label, " — `", relpath(path, ROOT), "` (", st, "; SHA256 ",digest,")")
        end
        # Every CSV in the directory, and not only the ones that this run
        # wrote. A section that ran earlier must stay visible, with the date of
        # its own run, or the provenance would claim the directory is newer
        # than it is.
        fresh = Dict(n => (r, c) for (n, r, c) in WRITTEN)
        println(io, "\n## Files\n")
        println(io, "| File | Rows | Columns | Written | This run |")
        println(io, "|---|---|---|---|---|")
        for f in sort(filter(x -> endswith(x, ".csv"), readdir(OUT)))
            path = joinpath(OUT, f)
            lines = countlines(path)
            cols = length(split(first(eachline(path)), ','))
            when = Dates.format(Dates.unix2datetime(mtime(path)), "yyyy-mm-dd HH:MM")
            println(io, "| `", f, "` | ", max(lines - 1, 0), " | ", cols, " | ",
                    when, " | ", haskey(fresh, f) ? "yes" : "no", " |")
        end
        println(io, "\nEvery file above holds data only. No file carries a comment line.")
    end
end

# ── run ─────────────────────────────────────────────────────────────────────

const T0 = time()
for s in OPTS.only
    s == "papers"     && section_papers()
    s == "catalog"    && section_catalog()
    s == "corpus"     && section_corpus()
    s == "invariants" && section_invariants()
end
const WALL = time() - T0
write_provenance(collect(OPTS.only), WALL)

println()
println("wrote into ", relpath(OUT, ROOT), ":")
for (name, r, c) in sort(WRITTEN)
    @printf("  %-32s %5d rows  %2d columns\n", name, r, c)
end
@printf("done in %.1f s\n", WALL)
