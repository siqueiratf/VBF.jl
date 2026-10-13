#=
Generate manuscript tables, figures, CSVs and provenance from saved measurements.
Run from the repository root:
  julia --startup-file=no --project=packages/VBFPaper packages/VBFPaper/src/analysis/performance/manuscript.jl OUTPUT [CONFIG] [DATABASE]
CONFIG defaults to manuscript.toml beside this script. Run IDs are explicit;
repetitions and input configurations are never pooled across invocations.
Corpus projections assume the measured Gold-input cost for every member,
sequentially, excluding loading and persistence. They are not full-corpus timings.
=#
ENV["GKSwstype"] = "100"
using VBF
include(joinpath(@__DIR__, "..", "..", "..", "bench", "analysis", "BenchAnalysis.jl"))
using .BenchAnalysis, DataFrames, CSV, TOML, Statistics, Printf, SHA, Dates, VBFRepro
using Plots

"""Escape identifiers for LaTeX tables, allowing breaks after underscores."""
tex(s) = replace(string(s), "_" => "\\_\\allowbreak{}", "#" => "\\#", "%" => "\\%", "&" => "\\&")
"""Format a measurement using three significant digits; missing remains a dash."""
number(x) = ismissing(x) ? "---" : replace(@sprintf("%.3g", x), r"e([+-]?\d+)" => s"\\mathrm{e}{\1}")
"""Format integer counts with Portuguese thousands separators."""
countpt(x) = replace(string(x), r"(\d)(?=(\d{3})+$)" => s"\1.")

"""Validate complete recorded repetitions and stable configuration within each case."""
function checked_summary(db, run)
    df = load_benchmarks(db; where="run_id = ?", params=(run,))
    isempty(df) && error("No measurements for run $run")
    meta = BenchAnalysis.query(db, raw"SELECT id, json_extract(parameters_json,'$.reps') expected, json_extract(parameters_json,'$.note') note FROM benchmark WHERE run_id = ?", (run,))
    df = leftjoin(df, meta; on=:id, validate=(true, true))
    for g in groupby(df, intersect(BenchAnalysis.GROUP_KEYS, propertynames(df)))
        length(unique(g.expected)) == 1 || error("Inconsistent repetition target")
        sort(g.repetition) == collect(1:first(g.expected)) || error("Incomplete case $(first(g.algorithm))")
        all(x -> isfinite(x) && x > 0, g.elapsed_seconds) || error("Invalid timing")
    end
    stats = runtime_statistics(df)
    extras = combine(groupby(df, BenchAnalysis.GROUP_KEYS), :elapsed_seconds => (x -> quantile(x, .25)) => :q25,
        :elapsed_seconds => (x -> quantile(x, .75)) => :q75,
        :id => minimum => :first_id, :id => maximum => :last_id, :note => first => :note)
    stats = leftjoin(stats, extras; on=BenchAnalysis.GROUP_KEYS, matchmissing=:equal, validate=(true,true))
    sort!(stats, [:algorithm, :n])
    df, stats
end

"""Write a page-breaking timing appendix without discarding provenance in CSV."""
function appendix(path, stats)
    open(path, "w") do io
        println(io, raw"\begin{longtable}{>{\raggedright\arraybackslash}p{7cm}rrrr}")
        println(io, raw"\caption{Tempos da execução selecionada da API pública.}\label{tab:bench-full}\\\\")
        header = raw"\toprule Operação & $n$ & mín. (s) & mediana (s) & reps. \\ \midrule"
        println(io, header, raw"\endfirsthead", '\n', header, raw"\endhead")
        println(io, raw"\bottomrule\endfoot")
        for r in eachrow(stats)
            println(io, "\\texttt{\\footnotesize ", tex(r.algorithm), "} & ", ismissing(r.n) ? "---" : r.n,
                " & \$", number(r.min), "\$ & \$", number(r.median), "\$ & ", r.n_observations, raw" \\\\")
        end
        println(io, raw"\end{longtable}")
    end
end

"""Produce a reproducible, read-only analysis snapshot for the thesis."""
function main(args)
    isempty(args) && error("Usage: manuscript.jl OUTPUT [CONFIG] [DATABASE]")
    out = abspath(args[1]); mkpath(out)
    config_path = length(args) >= 2 ? args[2] : joinpath(VBFRepro.repo_root(), "packages/VBFPaper/doc/performance/manuscript.toml")
    config = TOML.parsefile(config_path)
    db = length(args) >= 3 ? abspath(args[3]) : BenchAnalysis.RAW_DATABASE
    df, stats = checked_summary(db, config["core_run"])
    papers, paperstats = checked_summary(db, config["paper_run"])
    all(ismissing, df.paper_id) || error("Core run contains paper cases")
    all(!ismissing, papers.paper_id) || error("Paper run contains API cases")
    inventory = BenchAnalysis.query(db, "SELECT run_id, COALESCE(paper_id, 'API') suite, COUNT(*) repetitions, MIN(recorded_at) first_recorded_at, MAX(recorded_at) last_recorded_at FROM benchmark GROUP BY run_id, paper_id ORDER BY first_recorded_at")
    corpora = BenchAnalysis.query(db, "SELECT name, n, member_count, bytes_per_member, store_sha256 FROM bulk_corpora ORDER BY member_count")
    chosen = only(eachrow(filter(:name => ==(config["corpus"]), corpora)))
    total = sum(corpora.member_count)
    operations = ["spectra/ddt", "spectra/lat", "invariants/ortho_derivative", "invariants/sigma_multiplicities", "invariants/apn_ea_mugshot", "invariants/ortho_integral"]
    projected = filter(r -> !ismissing(r.n) && r.n == chosen.n && r.algorithm in operations, stats)
    nrow(projected) == length(operations) || error("Missing or ambiguous projection inputs")
    projected.members = fill(chosen.member_count, nrow(projected))
    for metric in (:min, :median, :q25, :q75)
        projected[!, Symbol(metric, :_hours)] = projected[!, metric] .* chosen.member_count ./ 3600
    end
    @assert all(isapprox.(projected.median_hours .* 3600, projected.median .* projected.members))
    catalog = filter(r -> r.algorithm in ["catalog/corpus_coefficients", "catalog/corpus_function", "catalog/corpus_length", "catalog/materialize_corpus_luts", "catalog/materialize_corpus_luts_bulk"], stats)
    for (name, data) in [("current_runtime",stats), ("current_papers",paperstats), ("current_corpora",corpora), ("current_projection",projected), ("current_catalog",catalog), ("current_runs",inventory)]
        CSV.write(joinpath(out, name * ".csv"), data)
    end
    source = BenchAnalysis.query(db, raw"SELECT DISTINCT json_extract(parameters_json,'$.provenance') provenance FROM benchmark WHERE run_id = ?", (config["core_run"],))
    write(joinpath(out,"current_run_provenance.json"), only(source.provenance))
    open(joinpath(out,"current_provenance.toml"), "w") do io
        TOML.print(io, Dict("generated_utc" => string(now(UTC)), "database" => abspath(db),
            "core_run" => config["core_run"], "paper_run" => config["paper_run"],
            "corpus" => config["corpus"], "corpus_store_sha256" => chosen.store_sha256,
            "script_sha256" => bytes2hex(sha256(read(@__FILE__))),
            "config_sha256" => bytes2hex(sha256(read(config_path))),
            "analysis_sha256" => bytes2hex(sha256(read(joinpath(@__DIR__, "..", "..", "..", "bench", "analysis", "BenchAnalysis.jl")))),
            "manifest_sha256" => bytes2hex(sha256(read(joinpath(@__DIR__, "..", "Manifest.toml")))),
            "snapshot_rows" => sum(inventory.repetitions),
            "snapshot_max_id" => only(BenchAnalysis.query(db,"SELECT MAX(id) id FROM benchmark").id),
            "projection_assumption" => "Gold input timing per member; serial; excludes I/O; quartiles describe repeated calls only"))
    end
    open(joinpath(out,"current_facts.tex"), "w") do io
        for (key, value) in ["CurrentCases" => nrow(stats), "CurrentReps" => countpt(nrow(df)),
            "CurrentMembers" => countpt(chosen.member_count), "CurrentTotalMembers" => countpt(total),
            "CurrentCorpusShare" => replace(@sprintf("%.2f",100chosen.member_count/total), "."=>","),
            "CurrentRawMB" => replace(@sprintf("%.1f",chosen.member_count*chosen.bytes_per_member/1e6),"."=>","),
            "CurrentLutMB" => replace(@sprintf("%.1f",chosen.member_count*2^chosen.n*cld(chosen.n,8)/1e6),"."=>",")]
            println(io, "\\newcommand{\\", key, "}{", value, "}")
        end
    end
    appendix(joinpath(out,"current_table.tex"), stats)
    open(joinpath(out,"current_projection_table.tex"), "w") do io
        println(io, raw"\begin{tabular}{lrrr}\toprule Operação & mediana (ms) & $Q_1$--$Q_3$ (ms) & projeção (h) \\ \midrule")
        for r in eachrow(projected)
            println(io,"\\texttt{",tex(split(r.algorithm,'/')[end]),"} & \$",number(1000r.median),"\$ & \$",number(1000r.q25),"\$--\$",number(1000r.q75),"\$ & \$",number(r.median_hours),"\$",raw" \\\\")
        end
        println(io,raw"\bottomrule\end{tabular}")
    end
    open(joinpath(out,"current_catalog_table.tex"),"w") do io
        println(io,raw"\begin{tabular}{lrr}\toprule Operação & mediana (ms) & reps. \\ \midrule")
        for r in eachrow(catalog)
            println(io,"\\texttt{",tex(split(r.algorithm,'/')[end]),"} & \$",number(1000r.median),"\$ & ",r.n_observations,raw" \\\\")
        end
        println(io,raw"\bottomrule\end{tabular}")
    end
    default(fontfamily="DejaVu Sans", guidefontsize=10, tickfontsize=9, legendfontsize=9)
    p = plot(xlabel="Dimensão n", ylabel="Mediana por chamada (s)", yscale=:log10,
        legend=:topleft, size=(850,480), margin=5Plots.PlotMeasures.mm)
    growth = filter(r -> r.algorithm in operations[1:5] &&
        (r.algorithm != "invariants/apn_ea_mugshot" || r.note == "quadratic path through pi_F"), stats)
    CSV.write(joinpath(out,"current_growth.csv"), growth)
    for op in operations[1:5]
        rows = filter(:algorithm => ==(op), growth)
        plot!(p, rows.n, rows.median; marker=:circle, label=split(op,'/')[end])
    end
    savefig(p,joinpath(out,"current_growth.pdf"))
    short = ["Edel–Pott 2009", "Weng–Tan–Gong 2013", "Yu–Wang–Li 2014", "Taniguchi 2019", "Beierle–Leander 2022", "Beierle–Leander–Perrin 2022", "Yu–Perrin 2022", "Simon–Berg", "Beierle et al. 2025"]
    names = Dict(["edelpott2009_n8","wengtangong2013_n8","yuwangli2014_qam_n8","taniguchi2019_n8","beierleleander2022_n8","beierleleanderperrin2022_n8","yuperrin2022_qam_n8","simonberg_gf4_n8","beierle2025_n8"] .=> short)
    labels = [get(names,r.name,r.name)*"  ("*countpt(r.member_count)*")" for r in eachrow(corpora)]
    p = scatter(corpora.member_count, 1:nrow(corpora); xscale=:log10,
        yticks=(1:nrow(corpora),labels), xlabel="Membros por corpus (escala logarítmica)",
        legend=false, size=(1000,500), left_margin=5Plots.PlotMeasures.mm,
        tickfontsize=12, guidefontsize=12, xticks=10.0 .^ (0:7), xlims=(1,1e7),
        bottom_margin=8Plots.PlotMeasures.mm, markersize=5)
    savefig(p,joinpath(out,"current_corpora.pdf"))
    println("manuscript-check: OK; $(nrow(stats)) API cases, $(nrow(df)) repetitions, $(chosen.member_count)/$total corpus members")
    show(stdout, select(projected,:algorithm,:median,:median_hours)); println()
    show(stdout, select(paperstats,:algorithm,:median,:n_observations)); println()
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main(ARGS)
