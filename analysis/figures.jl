#!/usr/bin/env julia
"""
Render the manuscript figures and LaTeX tables from `analysis/generated/*.csv`.

Run from the repository root:
  julia --startup-file=no --project=bench/analysis analysis/figures.jl OUTPUT [INPUT]

OUTPUT is the directory the thesis reads; INPUT defaults to `analysis/generated`.
This script reads the CSVs that `analysis/metrics.jl` produced and writes only
into OUTPUT. It reads saved measurements and opens no database. Figures retain the units
and evidence levels recorded in those input tables.

The invariant figure uses batch processing time per evaluated member and pair
separation from the same sample. Historical calibration costs are not plotted
as timings of unevaluated dimensions.
"""
ENV["GKSwstype"] = "100"
using CSV, DataFrames, Plots, Printf, Statistics, Dates

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

const TOPIC_PT = Dict("construction" => "construção", "classification" => "classificação",
    "search" => "busca", "modification" => "modificação", "equivalence" => "equivalência",
    "four_uniform" => "4-uniforme", "theory" => "teoria")
const KIND_PT = Dict("wrong_value" => "valor incorreto", "wrong_condition" => "condição incorreta",
    "unsound_negative" => "negativa infundada", "sampling_not_exhaustion" => "amostra como exaustão",
    "internal_inconsistency" => "inconsistência interna", "scope_restriction" => "escopo restrito",
    "hard_limit" => "limite de recurso", "tool_limit" => "limite de ferramenta",
    "theory_limit" => "limite teórico", "unproved_premise" => "premissa não provada",
    "inferred" => "inferido")
const TIER_PT = Dict("readme_only" => "relato no README", "paper_confirmed" => "artigo",
    "code_confirmed" => "código", "recomputed" => "recomputação")
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

"""Reproduction outcome by topic, as counts of papers in each verdict class."""
function figure_reproduction_by_topic(rep, out)
    df = sort(rep, :papers, rev = true)
    classes = [(:papers_complete, "completa"), (:papers_mostly_complete, "majoritária"),
        (:papers_partial, "parcial"), (:papers_unstated, "não declarada")]
    labels = [get(TOPIC_PT, t, t) for t in df.topic]
    palette = [:seagreen, :steelblue, :goldenrod, :gray70]
    # Painter's algorithm: draw each cumulative total from the widest inward, so
    # the strip each pass leaves visible is exactly that class's own count.
    # Rows are sorted by count, so the top-right corner is the only region free
    # of bars; anywhere lower the legend would sit on top of the data.
    plt = plot(; orientation = :h, legend = :topright, yticks = (1:nrow(df), labels),
        xlabel = "Artigos", size = (900, 430), margin = 6Plots.PlotMeasures.mm,
        fontfamily = "DejaVu Sans", guidefontsize = 10, tickfontsize = 9, legendfontsize = 9)
    for k in length(classes):-1:1
        cumulative = sum(df[!, c] for (c, _) in classes[1:k])
        bar!(plt, 1:nrow(df), cumulative; orientation = :h, linewidth = 0,
            color = palette[k], label = classes[k][2], bar_width = 0.65)
    end
    savefig(plt, joinpath(out, "fig_reproduction_by_topic.pdf"))
    df
end

"""Defect kind against the weakest evidence that established it."""
function figure_defect_tier(def, out)
    tiers = ["readme_only", "code_confirmed", "recomputed"]
    kinds = unique(def.kind)
    order = sortperm([sum(filter(r -> r.kind == k && r.verification_tier == "recomputed", def).findings;
        init = 0) * 100 + sum(filter(r -> r.kind == k, def).findings) for k in kinds])
    kinds = kinds[order]
    grid = [sum(filter(r -> r.kind == k && r.verification_tier == t, def).findings; init = 0)
            for k in kinds, t in tiers]
    plt = heatmap(1:length(tiers), 1:length(kinds), Float64.(grid);
        xticks = (1:length(tiers), [TIER_PT[t] for t in tiers]),
        yticks = (1:length(kinds), [get(KIND_PT, k, k) for k in kinds]),
        color = cgrad(:Blues), colorbar_title = "ocorrências", legend = true,
        size = (760, 460), margin = 6Plots.PlotMeasures.mm, fontfamily = "DejaVu Sans",
        guidefontsize = 10, tickfontsize = 9,
        xlabel = "Nível de evidência registrado na revisão")
    for i in 1:length(kinds), j in 1:length(tiers)
        grid[i, j] == 0 && continue
        annotate!(plt, j, i, Plots.text(string(grid[i, j]), 9,
            grid[i, j] > maximum(grid) / 2 ? :white : :black, :center))
    end
    savefig(plt, joinpath(out, "fig_defect_tier.pdf"))
    kinds, tiers, grid
end

"""Members against provably distinct signatures, for every stored source."""
function table_corpus_sigma(sig, out)
    df = sort(filter(r -> r.source != "functions", sig), :member_count, rev = true)
    open(joinpath(out, "tab_corpus_sigma.tex"), "w") do io
        println(io, raw"\begin{tabular}{lrrr}\toprule")
        println(io, raw"Corpus & Membros & Assinaturas $\sigma$ & Membros por assinatura \\ \midrule")
        for r in eachrow(df)
            println(io, "\\texttt{", tex(r.source), "} & ", countpt(r.member_count), " & ",
                countpt(r.sigma_classes), " & ", decimalpt(r.rows_per_sigma_class, 2), ROW)
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
                countpt(r.corpus_sigma_classes), ROW)
        end
        println(io, raw"\bottomrule\end{tabular}")
    end
    df
end

"""Paper ids that the curated grades and the metric tables spell differently."""
const KEY_ALIAS = Dict("Yu_202211" => "Yu_202211d", "Calderini_202009a" => "Calderini_202009",
    "Yuyin_201307" => "Yuyin_201300", "Chase_202110a" => "Chase_202110")
normalise_key(k) = get(KEY_ALIAS, string(k), string(k))

"""Defects per paper against the evidence the publication supplied.

Built from the CURATED grades, not from the automatically derived ones. The two
disagree on most papers, and the thesis prints the curated table, so any
aggregate taken from the other source would contradict what the reader sees.
"""
function table_evidence_outcome(aud, papers, out)
    joined = leftjoin(transform(aud, :paper_key => ByRow(normalise_key) => :paper_id),
        select(papers, :paper_id, :findings_primary, :findings_high, :verdict_class);
        on = :paper_id)
    unmatched = count(ismissing, joined.findings_primary)
    unmatched == 0 || error("$unmatched curated papers do not join to papers.csv")
    rows = NamedTuple[]
    open(joinpath(out, "tab_evidence_outcome.tex"), "w") do io
        println(io, raw"\begin{tabular}{llrrrr}\toprule")
        println(io, raw"Eixo & Nota & Artigos & Ocorrências & Alta severidade & Ocorr./artigo \\ \midrule")
        for a in AXES
            for g in ("f", "h", "o")
                sub = filter(r -> string(r[a]) == g, joined)
                isempty(sub) && continue
                defects = sum(sub.findings_primary)
                entry = (axis = uppercase(a), grade = g, papers = nrow(sub),
                    findings = defects, high = sum(sub.findings_high),
                    per_paper = defects / nrow(sub))
                push!(rows, entry)
                println(io, g == "f" ? "\\textbf{" * uppercase(a) * "}" : "", " & ",
                    GRADE_PT[g], " & ", nrow(sub), " & ", defects, " & ",
                    sum(sub.findings_high), " & ", decimalpt(entry.per_paper, 2), ROW)
            end
            a == last(AXES) || println(io, raw"\midrule")
        end
        println(io, raw"\bottomrule\end{tabular}")
    end
    DataFrame(rows)
end

"""Reproduction outcome and defect load for each topic."""
function table_reproduction_by_topic(rep, out)
    df = sort(rep, :papers, rev = true)
    open(joinpath(out, "tab_reproduction_by_topic.tex"), "w") do io
        println(io, raw"\begin{tabular}{lrrrrr}\toprule")
        println(io, raw"Tema & Artigos & Completa & Ocorrências & Alta severidade & Recomputadas \\ \midrule")
        for r in eachrow(df)
            println(io, get(TOPIC_PT, r.topic, r.topic), " & ", r.papers, " & ",
                r.papers_complete, " & ", r.findings, " & ", r.findings_high, " & ",
                r.findings_recomputed, ROW)
        end
        println(io, raw"\bottomrule\end{tabular}")
    end
    df
end

const AUDIT_CATEGORY = Dict('A' => "construções quadráticas",
    'B' => "buscas computacionais exaustivas", 'C' => "classificação por equivalência",
    'D' => "instâncias esporádicas e estudos de caso")
const GRADE_TEX = Dict("f" => "\\gf", "h" => "\\gh", "o" => "\\go")
const GRADE_PT = Dict("f" => "completo", "h" => "parcial", "o" => "ausente")
const AXES = ["r1", "r2", "r3", "r4"]
"""Finding kinds that record an unverifiable claim rather than a divergence."""
const LIMIT_KINDS = ("tool_limit", "hard_limit", "theory_limit")
"""LaTeX row terminator; a raw string would swallow one backslash here."""
const ROW = " \\\\"

"""Re-emit the curated audit table, so its aggregates cannot drift from it.

The grades are the author's reading, kept verbatim; this only renders them, and
every aggregate in the text is computed from the same rows.
"""
function table_audit(aud, out)
    ordered = sort(collect(eachrow(aud)); by = r -> (string(r.category), -Int(r.year), -parse(Int, match(r"_(\d{4})(\d{2})", string(r.paper_key)).captures[2]), string(r.paper_key)))
    open(joinpath(out, "tab_audit.tex"), "w") do io
        println(io, raw"\begin{tabular}{@{}>{\raggedright\arraybackslash}p{5.5cm}cccc@{}}")
        println(io, raw"\toprule")
        println(io, raw"Referência & R1 & R2 & R3 & R4 \\ \midrule")
        for r in ordered
            println(io, "\\rowcolor{auditType", r.category, "}\\tabref{", r.paper_key, "} & ",
                join((GRADE_TEX[string(r[a])] for a in AXES), " & "), ROW)
        end
        println(io, raw"\bottomrule\end{tabular}")
    end
end

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
function facts(out; papers, findings, kwargs...)
    values = Dict{String,Any}(
        "AnPapers" => nrow(papers),
        "AnYearMin" => minimum(papers.year), "AnYearMax" => maximum(papers.year),
        "AnComplete" => count(==("complete"), papers.verdict_class),
        "AnMostly" => count(==("mostly_complete"), papers.verdict_class),
        "AnPartial" => count(==("partial"), papers.verdict_class),
        "AnUnstated" => count(==("unstated"), papers.verdict_class),
        "AnFindings" => nrow(findings),
        "AnFindingsHigh" => count(==("high"), findings.severity),
        "AnFindingsMedium" => count(==("medium"), findings.severity),
        "AnRecomputed" => count(==("recomputed"), findings.verification_tier),
        "AnCodeConfirmed" => count(==("code_confirmed"), findings.verification_tier),
        "AnReadmeOnly" => count(==("readme_only"), findings.verification_tier),
        "AnPapersWithFinding" => length(unique(findings.paper_id)),
        "AnUnsoundNegative" => count(==("unsound_negative"), findings.kind),
        "AnWrongValue" => count(==("wrong_value"), findings.kind),
        "AnCompleteRegion" => count(==("complete_within_region"), findings.method_completeness))
    merge!(values, Dict(String(k) => v for (k, v) in kwargs))
    open(joinpath(out, "facts_analysis.tex"), "w") do io
        println(io, "% Arquivo gerado por analysis/figures.jl. Não editar à mão.")
        for key in sort(collect(keys(values)))
            println(io, "\\newcommand{\\", key, "}{", values[key], "}")
        end
    end
    values
end

function main(args)
    isempty(args) && error("Usage: figures.jl OUTPUT [INPUT]")
    out = abspath(args[1]); mkpath(out)
    input = length(args) >= 2 ? abspath(args[2]) : joinpath(@__DIR__, "generated")
    papers = read_metric(input, "papers")
    findings = read_metric(input, "findings")
    inv = read_metric(input, "invariant_power")
    rep = read_metric(input, "reproduction_by_method")
    def = read_metric(input, "defect_kind_by_tier")
    sig = read_metric(input, "corpus_sigma")
    met = read_metric(input, "method_by_dimension")
    aud = CSV.read(joinpath(@__DIR__, "curated_bfa4r.csv"), DataFrame)

    default(fontfamily = "DejaVu Sans")
    table_audit(aud, out)
    table_bfa4r_aggregate(aud, out)
    _, buckets = figure_bfa4r_year(aud, out)
    measured, refused = figure_invariant_power(inv, out)
    figure_reproduction_by_topic(rep, out)
    kinds, tiers, grid = figure_defect_tier(def, out)
    corpora = table_corpus_sigma(sig, out)
    table_method_dimension(met, out)
    evidence = table_evidence_outcome(aud, papers, out)
    table_reproduction_by_topic(rep, out)

    cheapest = measured[argmin(measured.bench_seconds_per_call), :]
    strongest = measured[argmax(measured.pair_separation_rate), :]
    useless = filter(r -> r.pair_separation_rate == 0, measured)
    dearest = isempty(useless) ? missing : useless[argmax(useless.bench_seconds_per_call), :]
    biggest = corpora[argmax(corpora.member_count), :]
    densest = corpora[argmax(corpora.rows_per_sigma_class), :]
    facts(out; papers, findings,
        AnInvPopulation = tex(INVARIANT_POPULATION),
        AnInvSample = measured[1, :population_size],
        AnInvCheapest = get(INVARIANT_PT, cheapest.invariant, cheapest.invariant),
        AnInvCheapestMs = decimalpt(1000cheapest.bench_seconds_per_call, 3),
        AnInvCheapestSep = decimalpt(100cheapest.pair_separation_rate, 2),
        AnInvStrongestSep = decimalpt(100strongest.pair_separation_rate, 2),
        AnInvDearestUseless = ismissing(dearest) ? "---" : get(INVARIANT_PT, dearest.invariant, dearest.invariant),
        AnInvDearestUselessMs = ismissing(dearest) ? "---" : decimalpt(1000dearest.bench_seconds_per_call, 1),
        AnInvRefused = join([get(INVARIANT_PT, r.invariant, r.invariant) for r in eachrow(refused)], " e "),
        AnInvRefusedCost = isempty(refused) ? "---" : decimalpt(maximum(refused.bench_seconds_per_call), 2),
        AnCorpusBiggest = countpt(biggest.member_count),
        AnCorpusBiggestSigma = countpt(biggest.sigma_classes),
        AnCorpusDensest = tex(densest.source),
        AnCorpusDensestMembers = countpt(densest.member_count),
        AnCorpusDensestSigma = countpt(densest.sigma_classes),
        AnCorpusDensestRatio = countpt(round(Int, densest.rows_per_sigma_class)),
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
        AnFindingsWrongRecomputed = count(r -> r.kind == "wrong_value" &&
            r.verification_tier == "recomputed", eachrow(findings)),
        AnFindingsWrongRead = count(r -> r.kind == "wrong_value" &&
            r.verification_tier == "readme_only", eachrow(findings)),
        AnFindingsInternal = count(==("internal_inconsistency"), findings.kind),
        # A record whose kind is a limit is an unverified claim, not an
        # established divergence. The prose must never fold the two together.
        AnUnverified = count(in(LIMIT_KINDS), findings.kind),
        AnUnverifiedHigh = count(r -> r.kind in LIMIT_KINDS && r.severity == "high",
            eachrow(findings)),
        AnDefects = count(!in(LIMIT_KINDS), findings.kind),
        AnDefectsHigh = count(r -> !(r.kind in LIMIT_KINDS) && r.severity == "high",
            eachrow(findings)),
        AnWrongValueCode = count(r -> r.kind == "wrong_value" &&
            r.verification_tier == "code_confirmed", eachrow(findings)))
    println("figures: OK; ", nrow(papers), " artigos, ", nrow(findings), " ocorrências, ",
        nrow(measured), " invariantes medidos em ", INVARIANT_POPULATION)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main(ARGS)
