#!/usr/bin/env julia
#=
Render the manuscript figures and LaTeX tables from `packages/VBFPaper/doc/generated/reproductions/*.csv`.

Run from the repository root:
  julia --startup-file=no --project=packages/VBFPaper packages/VBFPaper/src/analysis/reproductions/figures.jl OUTPUT [INPUT]

OUTPUT is the directory the thesis reads; INPUT defaults to `packages/VBFPaper/doc/generated/reproductions`.
This script reads the CSVs that `packages/VBFPaper/src/analysis/reproductions/metrics.jl` produced and writes only
into OUTPUT. It reads saved measurements and opens no database. Figures retain the units
and evidence levels recorded in those input tables.

The invariant figure uses batch processing time per evaluated member and pair
separation from the same sample. Historical calibration costs are not plotted
as timings of unevaluated dimensions.
=#
ENV["GKSwstype"] = "100"
using CSV, DataFrames, Plots, Printf, Statistics, Dates, VBFPaper

const INVARIANT_POPULATION = "corpus_beierle2025_n8"

"""Escape a value for LaTeX, keeping underscores breakable inside \\texttt."""
tex(s) = replace(string(s), "_" => "\\_\\allowbreak{}", "%" => "\\%", "&" => "\\&", "#" => "\\#")
"""Portuguese thousands separator for an integer count."""
countpt(x) = replace(string(x), r"(\d)(?=(\d{3})+$)" => s"\1.")
"""Portuguese decimal comma, with a fixed number of digits."""
decimalpt(x, digits=2) = replace(@sprintf("%.*f", digits, x), "." => ",")
"""Three significant digits in math mode; missing stays a dash."""
number(x) = ismissing(x) ? "---" : replace(@sprintf("%.3g", x), r"e([+-]?\d+)" => s"\\mathrm{e}{\1}")

read_metric(dir, name) = CSV.read(joinpath(dir, name * ".csv"), DataFrame)

const INVARIANT_PT = Dict("sigma_signature" => "assinatura σ",
    "od_differential_spectrum" => "esp. dif. da ortoderivada",
    "od_walsh_spectrum" => "esp. Walsh da ortoderivada",
    "apn_ea_mugshot" => "mugshot APN-EA", "pi_multiset" => "multiconjunto Π",
    "component_degree_spectrum" => "graus das componentes",
    "differential_spectrum" => "espectro diferencial", "absolute_walsh_spectrum" => "espectro de Walsh",
    "gamma_rank" => "Gamma-rank", "delta_rank" => "Delta-rank")

"""Plot batch time per sampled member with pair-separation percentages.

Batch time includes invariant evaluation, key conversion and grouping; it is
not the API microbenchmark median. Only complete, error-free batches are shown.
"""
function figure_invariant_power(inv, out)
    here = filter(r -> r.population == INVARIANT_POPULATION, inv)
    rows = filter(r -> r.status == "measured" && !ismissing(r.measured_seconds) &&
        r.evaluated == r.population_size && r.errors == 0 && r.undefined == 0, here)
    isempty(rows) && error("No complete invariant rows for $INVARIANT_POPULATION")
    rows.batch_seconds_per_member = rows.measured_seconds ./ rows.evaluated
    all(>(0), rows.batch_seconds_per_member) || error("Non-positive batch timing")
    sort!(rows, :batch_seconds_per_member)
    refused = filter(r -> r.status == "not_applicable", here)
    plt = plot(; xscale=:log10, legend=false,
        yticks=(1:nrow(rows), [get(INVARIANT_PT,r.invariant,r.invariant) for r in eachrow(rows)]),
        xlabel="Tempo do lote por membro (ms, escala logarítmica)",
        ylims=(0.4,nrow(rows)+0.6), size=(950,420),
        margin=6Plots.PlotMeasures.mm, fontfamily="DejaVu Sans",
        guidefontsize=11, tickfontsize=10,
        xlims=(minimum(rows.batch_seconds_per_member)*700, maximum(rows.batch_seconds_per_member)*1800))
    for (i,r) in enumerate(eachrow(rows))
        colour = r.pair_separation_rate == 0 ? :gray55 : :steelblue
        scatter!(plt,[1000r.batch_seconds_per_member],[i];color=colour,markersize=6)
        annotate!(plt,1200r.batch_seconds_per_member,i,
            Plots.text(decimalpt(100r.pair_separation_rate,2)*"%",10,:left))
    end
    CSV.write(joinpath(out,"invariant_plot_data.csv"), rows)
    savefig(plt,joinpath(out,"fig_invariant_power.pdf"))
    rows, refused
end

"""Members against provably distinct signatures, for every stored source."""
function table_corpus_sigma(sig, out)
    df = sort(filter(r -> r.source != "functions", sig), :member_count, rev = true)
    open(joinpath(out, "tab_corpus_sigma.tex"), "w") do io
        println(io, raw"\begin{tabular}{lrrr}\toprule")
        println(io, raw"Corpus & Membros & Assinaturas $\sigma$ & Membros por assinatura \\ \midrule")
        for r in eachrow(df)
            println(io, "\\texttt{", tex(r.source), "} & ", countpt(r.member_count), " & ",
                countpt(r.distinct_signatures), " & ", decimalpt(r.rows_per_signature, 2), ROW)
        end
        println(io, raw"\bottomrule\end{tabular}")
    end
    df
end

"""Curated entries and corpus signatures for each construction method group."""
function table_method_dimension(met, out)
    df = filter(r -> r.curated_functions > 0 || r.corpus_members > 0, met)
    sort!(df, [:method_group, :n])
    open(joinpath(out, "tab_method_dimension.tex"), "w") do io
        println(io, raw"\begin{tabular}{llrrrr}\toprule")
        println(io, raw"Grupo & $n$ & Entradas & Quadráticas & Membros & Assinaturas $\sigma$ \\ \midrule")
        previous = ""
        for r in eachrow(df)
            group = r.method_group == previous ? "" : r.method_group
            previous = r.method_group
            println(io, group, " & ", r.n, " & ", countpt(r.curated_functions), " & ",
                countpt(r.curated_quadratic), " & ", countpt(r.corpus_members), " & ",
                countpt(r.distinct_signatures), ROW)
        end
        println(io, raw"\bottomrule\end{tabular}")
    end
    df
end

const AUDIT_CATEGORY = Dict('A' => "construções quadráticas",
    'B' => "buscas computacionais exaustivas", 'C' => "classificação por equivalência",
    'D' => "instâncias esporádicas e estudos de caso")
const GRADE_TEX = Dict("f" => "\\gf", "h" => "\\gh", "o" => "\\go")
const AXES = ["r1", "r2", "r3", "r4"]

"""LaTeX row terminator; a raw string would swallow one backslash here."""
const ROW = " \\\\"

"""Re-emit the curated audit table, so its aggregates cannot drift from it.

The grades are the author's reading, kept verbatim; this only renders them, and
every aggregate in the text is computed from the same rows.
"""
const table_audit=VBFPaper.write_audit_table

"""Grade counts per axis, and per axis within each methodological category."""
function table_bfa4r_aggregate(aud, out)
    open(joinpath(out, "tab_bfa4r_aggregate.tex"), "w") do io
        println(io, raw"\begin{tabular}{llrrr}\toprule")
        println(io, raw"Eixo & Categoria & Completo & Parcial & Ausente \\ \midrule")
        for a in AXES
            println(io, "\\textbf{", uppercase(a), "} & todas & ",
                count(==("f"), string.(aud[!, a])), " & ", count(==("h"), string.(aud[!, a])),
                " & ", count(==("o"), string.(aud[!, a])), ROW)
            for c in sort(unique(string.(aud.category)))
                sub = filter(r -> string(r.category) == c, aud)
                println(io, " & ", AUDIT_CATEGORY[first(c)], " & ", count(==("f"), string.(sub[!, a])),
                    " & ", count(==("h"), string.(sub[!, a])), " & ",
                    count(==("o"), string.(sub[!, a])), ROW)
            end
            a == last(AXES) || println(io, raw"\midrule")
        end
        println(io, raw"\bottomrule\end{tabular}")
    end
end

"""Share of each grade per axis across four publication periods."""
function figure_bfa4r_year(aud, out)
    edges = [(0, 2010, "até 2010"), (2011, 2015, "2011--2015"),
             (2016, 2020, "2016--2020"), (2021, 2100, "2021--2025")]
    buckets = [filter(r -> lo <= r.year <= hi, aud) for (lo, hi, _) in edges]
    plots = []
    for a in AXES
        shares = [isempty(b) ? 0.0 : 100count(==("f"), string.(b[!, a])) / nrow(b) for b in buckets]
        push!(plots, (uppercase(a), shares))
    end
    plt = plot(; xticks = (1:length(edges), [l for (_, _, l) in edges]),
        ylabel = "Artigos com nota completa (por cento)", ylims = (-4, 104),
        legend = :topleft, size = (900, 420), margin = 6Plots.PlotMeasures.mm,
        fontfamily = "DejaVu Sans", guidefontsize = 10, tickfontsize = 9, legendfontsize = 9)
    for (name, shares) in plots
        plot!(plt, 1:length(edges), shares; marker = :circle, linewidth = 2, label = name)
    end
    annotate!(plt, 1:length(edges), fill(-1.0, length(edges)),
        [Plots.text("n=$(nrow(b))", 8, :top, :center) for b in buckets])
    savefig(plt, joinpath(out, "fig_bfa4r_year.pdf"))
    edges, buckets
end

"""Macros for every number the prose states, so no figure is quoted by hand."""
function facts(out; papers, kwargs...)
    values = Dict{String,Any}("AnPapers"=>nrow(papers),
        "AnYearMin"=>minimum(papers.year), "AnYearMax"=>maximum(papers.year))
    merge!(values, Dict(String(k)=>v for (k,v) in kwargs))
    open(joinpath(out,"facts_analysis.tex"),"w") do io
        println(io,"% Generated from current inventory and measured results.")
        for key in sort(collect(keys(values)))
            println(io,"\\newcommand{\\",key,"}{",values[key],"}")
        end
    end
    values
end

function main(args)
    isempty(args) && error("Usage: figures.jl OUTPUT [INPUT]")
    out = abspath(args[1]); mkpath(out)
    input = length(args) >= 2 ? abspath(args[2]) : joinpath(@__DIR__, "..", "..", "..", "..", "..", "packages","VBFRepro","src","results", "analysis", "reproductions")
    papers = read_metric(input, "papers")
    inv = read_metric(input, "invariant_power")
    sig = read_metric(input, "corpus_sigma")
    met = read_metric(input, "method_by_dimension")
    aud = CSV.read(joinpath(@__DIR__, "curated_bfa4r.csv"), DataFrame)

    default(fontfamily = "DejaVu Sans")
    table_audit(eachrow(aud), out)
    table_bfa4r_aggregate(aud, out)
    _, buckets = figure_bfa4r_year(aud, out)
    measured, refused = figure_invariant_power(inv, out)
    corpora = table_corpus_sigma(sig, out)
    table_method_dimension(met, out)

    cheapest = measured[argmin(measured.batch_seconds_per_member), :]
    strongest = measured[argmax(measured.pair_separation_rate), :]
    useless = filter(r -> r.pair_separation_rate == 0, measured)
    dearest = isempty(useless) ? missing : useless[argmax(useless.batch_seconds_per_member), :]
    biggest = corpora[argmax(corpora.member_count), :]
    densest = corpora[argmax(corpora.rows_per_signature), :]
    facts(out; papers,
        AnInvPopulation = tex(INVARIANT_POPULATION),
        AnInvSample = measured[1, :population_size],
        AnInvCheapest = get(INVARIANT_PT, cheapest.invariant, cheapest.invariant),
        AnInvCheapestMs = decimalpt(1000cheapest.batch_seconds_per_member, 3),
        AnInvCheapestSep = decimalpt(100cheapest.pair_separation_rate, 2),
        AnInvStrongestSep = decimalpt(100strongest.pair_separation_rate, 2),
        AnInvDearestUseless = ismissing(dearest) ? "---" : get(INVARIANT_PT, dearest.invariant, dearest.invariant),
        AnInvDearestUselessMs = ismissing(dearest) ? "---" : decimalpt(1000dearest.batch_seconds_per_member, 1),
        AnInvRefused = join([get(INVARIANT_PT, r.invariant, r.invariant) for r in eachrow(refused)], " e "),
        AnCorpusBiggest = countpt(biggest.member_count),
        AnCorpusBiggestSigma = countpt(biggest.distinct_signatures),
        AnCorpusDensest = tex(densest.source),
        AnCorpusDensestMembers = countpt(densest.member_count),
        AnCorpusDensestSigma = countpt(densest.distinct_signatures),
        AnCorpusDensestRatio = countpt(round(Int, densest.rows_per_signature)),
        AnAudited = nrow(aud),
        AnAuditedOut = nrow(papers) - nrow(aud),
        AnAuditRoneFull = count(==("f"), string.(aud.r1)),
        AnAuditRtwoFull = count(==("f"), string.(aud.r2)),
        AnAuditRthreeFull = count(==("f"), string.(aud.r3)),
        AnAuditRthreeOpen = count(==("o"), string.(aud.r3)),
        AnAuditRfourFull = count(==("f"), string.(aud.r4)),
        AnAuditRfourOpen = count(==("o"), string.(aud.r4)),
        AnAuditRtwoOpen = count(==("o"), string.(aud.r2)),
        AnAuditRecentArtifact = count(r -> r.year >= 2021 && string(r.r3) != "o",
            eachrow(aud)),
        AnAuditRecent = count(r -> r.year >= 2021, eachrow(aud)),
        AnAuditOldArtifact = count(r -> r.year <= 2015 && string(r.r3) != "o",
            eachrow(aud)),
        AnAuditOld = count(r -> r.year <= 2015, eachrow(aud)),
        AnAuditCatSearch = count(r -> string(r.category) == "B", eachrow(aud)),
        AnAuditCatBuild = count(r -> string(r.category) == "A", eachrow(aud)),
        AnAuditCatSearchRone = count(r -> string(r.category) == "B" && string(r.r1) == "f",
            eachrow(aud)),
        AnAuditCatBuildRone = count(r -> string(r.category) == "A" && string(r.r1) == "f",
            eachrow(aud)),
        AnAuditCatSearchArtifact = count(r -> string(r.category) == "B" && string(r.r3) != "o",
            eachrow(aud)),
        AnAuditArtifact = count(r -> string(r.r3) != "o", eachrow(aud)),
        AnInventory = nrow(papers))
    println("figures: OK; ",nrow(papers)," papers; ",nrow(measured),
        " invariants measured in ",INVARIANT_POPULATION)

end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main(ARGS)
