#!/usr/bin/env julia
#
# packages/VBFPaper/src/analysis/reproductions/metrics.jl — build the metric tables that the paper analyses.
#
#   julia --project=. packages/VBFPaper/src/analysis/reproductions/metrics.jl                 # every section
#   julia --project=. packages/VBFPaper/src/analysis/reproductions/metrics.jl --only=corpus   # one section
#   julia --project=. packages/VBFPaper/src/analysis/reproductions/metrics.jl --sample=1024 --budget-seconds=300
#   julia --project=. packages/VBFPaper/src/analysis/reproductions/metrics.jl --list          # print the sections
#
# The script reads the repository and writes only into packages/VBFPaper/doc/generated/reproductions/. It
# changes no database, it touches no file under packages/ or papers/, and it
# runs no git command.
#
# `packages/VBFPaper/src/analysis/reproductions/METRICS.md` defines every table and says why it is in the paper.
# `packages/VBFPaper/src/analysis/reproductions/taxonomy.toml` holds the classification that no other file states in
# a machine-readable form.
#
# THE OUTPUT FORMAT. Every CSV holds data only: one header line of column names,
# then one line for each row. There is no comment line, so pandas, R or a
# spreadsheet reads it with no filter. The provenance of every file goes into
# packages/VBFPaper/doc/generated/reproductions/PROVENANCE.md instead.
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
using VBF, VBFCatalog, VBFRepro, CSV, DataFrames

const SQLite = VBFCatalog.SQLite

const HERE     = @__DIR__
const ROOT     = VBFRepro.repo_root()
const OUT      = get(ENV, "VBF_PAPER_OUTPUT", joinpath(ROOT, "packages/VBFPaper/doc/generated/reproductions"))
const TAXONOMY = joinpath(HERE, "taxonomy.toml")

const BFA4R        = get(ENV, "VBF_PAPER_GRADES", joinpath(OUT, "bfa4r_grades.csv"))
const BENCHMARKS   = get(ENV, "VBF_PAPER_LEGACY_BENCHMARKS", joinpath(ROOT, "packages/VBFPaper/bench/data/archive/generated/benchmarks.csv"))
const CATALOG_DB = catalog_path()
const SIGMA_DB = sigma_index_path()

const SECTIONS = ["papers", "catalog", "corpus", "invariants"]

# ── command line ────────────────────────────────────────────────────────────

const HELP = """
packages/VBFPaper/src/analysis/reproductions/metrics.jl — build the metric tables that the paper analyses.

usage: julia --project=. packages/VBFPaper/src/analysis/reproductions/metrics.jl [options]

  --only=NAME           run one section; repeat the flag for more
                        ($(join(SECTIONS, ", ")))
  --sample=N            functions per population in `invariants` (default 128)
  --seed=N              the seed of that sample (default 20260901)
  --budget-seconds=X    wall-clock ceiling for one (invariant, population) pair
                        in `invariants` (default 15). The worst case of the
                        whole section is invariants x populations x this value.
  --list                print the sections and the tables, build none
  -h, --help            print this text

See packages/VBFPaper/src/analysis/reproductions/METRICS.md.
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

"""Write a derived table with standard CSV quoting; provenance is recorded separately."""
function write_csv(name::AbstractString,header::Vector{String},rows)
    all(r->length(r)==length(header),rows) || error("row/header width mismatch in $name")
    mkpath(OUT);path=joinpath(OUT,name)
    CSV.write(path,DataFrame([Any[r[i] for r in rows] for i in eachindex(header)],Symbol.(header)))
    push!(WRITTEN,(name,length(rows),length(header)))
    path
end

const WRITTEN = Tuple{String,Int,Int}[]

# ── the shared sources ──────────────────────────────────────────────────────

const TAX = TOML.parsefile(TAXONOMY)

function read_csv(path)
    isfile(path) || return (String[],Vector{String}[])
    rows=CSV.File(path;types=String,stringtype=String,missingstring=nothing)
    (String.(propertynames(rows)),[String.(collect(r)) for r in rows])
end

# ── section: papers ─────────────────────────────────────────────────────────

function section_papers()
    println("[papers] discovering runnable reproductions")
    db = load_catalog(CATALOG_DB)
    try
        functions=Dict{String,Int}();corpora=Dict{String,Int}()
        for r in list_functions(db;is_apn=true)
            r.bib_key===nothing && continue
            functions[r.bib_key]=get(functions,r.bib_key,0)+1
        end
        for name in list_corpora(db)
            r=corpus_info(db,name);r.bib_key===missing && continue
            k=String(r.bib_key);corpora[k]=get(corpora,k,0)+Int(r.member_count)
        end
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
            key = something(paper_bib_key(paper.id), "")
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
        haskey(bg, k) || error("packages/VBFPaper/src/analysis/reproductions/taxonomy.toml has no bib_group for $k")
        return bg[k]
    end
    f = String(family)
    haskey(fg, f) || error("packages/VBFPaper/src/analysis/reproductions/taxonomy.toml has no family_group for $f")
    return fg[f]
end

function catalog_inputs()
    db=load_catalog(CATALOG_DB)
    try
        (;functions=list_functions(db;is_apn=true),corpora=[corpus_info(db,name) for name in list_corpora(db)])
    finally
        SQLite.close(db)
    end
end

function section_catalog()
    inputs=catalog_inputs();taxc=TAX["corpus"]
    stats=isfile(SIGMA_DB) ? signature_summary(;path=SIGMA_DB) : nothing
    stats===nothing && @warn "no signature index; signature counts remain missing" path=SIGMA_DB
    groups=sort!(unique(vcat([row_group(r.bib_key,r.family) for r in inputs.functions],
        [String(taxc[r.name]["group"]) for r in inputs.corpora])))
    dims=sort!(unique(vcat([r.n for r in inputs.functions],[Int(r.n) for r in inputs.corpora])))
    rows=Vector{Any}[]
    for g in groups,n in dims
        functions=filter(r->r.n==n && row_group(r.bib_key,r.family)==g,inputs.functions)
        corpora=filter(r->r.n==n && taxc[r.name]["group"]==g,inputs.corpora)
        sources=stats===nothing ? String[] : [String(r.source) for r in stats.sources if r.n==n && taxc[r.source]["group"]==g]
        signatures=stats===nothing ? "" : signature_count(;path=SIGMA_DB,n,sources)
        isempty(functions) && isempty(corpora) && isempty(sources) && continue
        push!(rows,Any[g,n,length(functions),count(r->r.is_quadratic,functions),sum(Int(r.member_count) for r in corpora;init=0),signatures])
    end
    write_csv("method_by_dimension.csv",["method_group","n","curated_functions","curated_quadratic","corpus_members","distinct_signatures"],rows)
    indexed=stats===nothing ? Dict() : Dict(Int(r.n)=>r for r in stats.dimensions)
    erows=Vector{Any}[]
    for n in sort!(unique(vcat(dims,collect(keys(indexed)))))
        fs=filter(r->r.n==n,inputs.functions);cs=filter(r->r.n==n,inputs.corpora);r=get(indexed,n,nothing)
        push!(erows,Any[n,length(fs),count(r->r.is_quadratic,fs),length(cs),sum(Int(r.member_count) for r in cs;init=0),
            r===nothing ? "" : r.distinct_signatures,r===nothing ? "" : r.indexed_sources,!isempty(cs)])
    end
    write_csv("evidence_depth.csv",["n","curated_functions","curated_quadratic","corpora","corpus_members","distinct_signatures","indexed_sources","bulk_corpus_exists"],erows)
end

function section_corpus()
    inputs=catalog_inputs();stats=signature_summary(;path=SIGMA_DB);taxc=TAX["corpus"]
    members=Dict((String(r.name),Int(r.n))=>Int(r.member_count) for r in inputs.corpora)
    for n in unique(r.n for r in inputs.functions)
        members[("functions",n)]=count(r->r.n==n,inputs.functions)
    end
    classes=Dict((String(r.source),Int(r.n))=>Int(r.distinct_signatures) for r in stats.sources)
    rows=Vector{Any}[]
    for r in stats.sources
        src=String(r.source);n=Int(r.n);c=Int(r.distinct_signatures);t=taxc[src]
        push!(rows,Any[src,t["group"],n,get(members,(src,n),r.indexed_rows),r.indexed_rows,c,
            round(r.indexed_rows/max(c,1);digits=2),r.unique_signatures,r.shared_signatures,t["note"]])
    end
    write_csv("corpus_sigma.csv",["source","method_group","n","member_count","indexed_rows","distinct_signatures","rows_per_signature","unique_signatures","shared_signatures","note"],rows)
    orows=Vector{Any}[]
    for r in stats.overlaps
        sa=String(r.source_a);sb=String(r.source_b);n=Int(r.n);c=Int(r.shared_signatures);na=classes[(sa,n)];nb=classes[(sb,n)]
        push!(orows,Any[sa,sb,n,na,nb,c,round(c/max(na,1);digits=4),round(c/max(nb,1);digits=4),taxc[sa]["note"],taxc[sb]["note"]])
    end
    write_csv("corpus_overlap.csv",["source_a","source_b","n","signatures_a","signatures_b","shared_signatures","fraction_a","fraction_b","note_a","note_b"],orows)
end

# ── section: invariants ─────────────────────────────────────────────────────
#
# The only section that computes. It applies each invariant to each population
# and reports what the invariant separates, next to what it costs. The cost
# comes from packages/VBFPaper/bench/data/archive/generated/benchmarks.csv, so the two datasets agree.

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
    db = load_catalog(CATALOG_DB)

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
    functions=filter(r->r.is_quadratic,list_functions(db;is_apn=true))
    for n in sort!(unique(r.n for r in functions))
        ids=[r.id for r in functions if r.n==n]
        length(ids)>=4 || continue
        length(ids)>OPTS.sample && (ids=ids[Random.randperm(rng,length(ids))[1:OPTS.sample]])
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

    for r in sort!([corpus_info(db,name) for name in list_corpora(db)];by=r->r.member_count)
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
    paths=[@__FILE__,TAXONOMY,CATALOG_DB,SIGMA_DB,BFA4R,BENCHMARKS,
        VBFRepro.publications_path(),
        joinpath(ROOT,"Project.toml"),joinpath(ROOT,"Manifest.toml")]
    for package in (VBF,VBFCatalog,VBFRepro), (dir,_,files) in walkdir(joinpath(pkgdir(package),"src"))
        append!(paths,[joinpath(dir,f) for f in files if endswith(f,".jl")])
    end
    inputs=Dict(relpath(p,ROOT)=>bytes2hex(open(sha256,p)) for p in paths if isfile(p))
    if "invariants" in ran
        db=load_catalog(CATALOG_DB)
        try
            for name in list_corpora(db)
                path=corpus_store_path(name)
                isfile(path) && (inputs[relpath(path,ROOT)]=bytes2hex(open(sha256,path)))
            end
        finally
            SQLite.close(db)
        end
    end
    # Each table retains its own execution record when another section runs later.
    for (name,nrows,ncols) in WRITTEN
        path=joinpath(OUT,name)
        metadata=Dict("generated_utc"=>string(now(UTC)),"julia_version"=>string(VERSION),
            "sections"=>ran,"sample"=>OPTS.sample,"seed"=>OPTS.seed,"budget_seconds"=>OPTS.budget,
            "wall_seconds"=>wall,"rows"=>nrows,"columns"=>ncols,
            "output_sha256"=>bytes2hex(open(sha256,path)),"inputs_sha256"=>inputs)
        open(io->TOML.print(io,metadata;sorted=true),path*".toml","w")
    end
    open(joinpath(OUT, "PROVENANCE.md"), "w") do io
        println(io, "# Provenance of `packages/VBFPaper/doc/generated/reproductions/`\n")
        println(io, "Do not edit these files. Rebuild them with `make -C packages/VBFPaper all`.")
        println(io, "`packages/VBFPaper/src/analysis/reproductions/METRICS.md` says what each table is for.\n")
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
