#!/usr/bin/env julia
#
# Generate the BFA-4R table from the tracked sources.
#
# BFA-4R grades a PUBLICATION on the computational evidence it supplied. It is a
# different axis from the recomputation status in Table 1 of apn_catalog.tex,
# which grades what THIS work verified independently. The two must never be
# merged: a paper can supply exemplary evidence for a claim that recomputation
# then contradicts, and a paper can supply nothing for a claim that recomputation
# confirms. Keeping them apart is the point.
#
# UNIT OF ANALYSIS: one row = one publication. Not a family, not a construction,
# not a catalog entry, not a claim.
#
# HOW THE MARKS ARE PRODUCED — READ THIS BEFORE TRUSTING THEM
#
# Each mark is derived by a stated rule over tracked files. The rules are proxies
# for an expert reading, and they are printed with their raw evidence in the
# appendix so a reader can audit and override every cell. They are a first pass,
# not an oracle.
#
# One limitation dominates and is not fixable here: papers/<id>/input/*.tex are
# automated PDF-to-LaTeX conversions. `\begin{theorem}` occurs 0 times across all
# 42 papers and `\begin{algorithm}` 0 times, so the STRUCTURAL signal for R1 is
# destroyed by the conversion. R1 therefore uses a textual proxy (the word
# "algorithm", pseudocode step markers, "Input:"/"Output:"/"Require:"/"Ensure:")
# corroborated by the reproduction
# README, which is hand-written and records exactly what a reimplementer had to
# guess. `tabular` survives conversion (142 occurrences), so R2's table signal is
# sound. R3's URLs survive and are the most reliable of the four. R4 is the
# weakest: third-party confirmation is only partly observable from inside this
# repository.
#
# Usage:  julia --project=. packages/VBFWorkingPaper/src/analysis/reproductions/grades.jl
#         julia --project=. packages/VBFWorkingPaper/src/analysis/reproductions/grades.jl --report   (stdout only)

using VBFRepro, VBFCatalog, TOML
const ROOT = VBFRepro.repo_root()
const PAPERS = VBFRepro.papers_root()
const BIB = VBFCatalog.bibliography_path()
const OUT = get(ENV, "VBF_WORKING_PAPER_OUTPUT", joinpath(ROOT, "packages/VBFWorkingPaper/doc/generated/reproductions"))
const REPORT_ONLY = "--report" in ARGS

const TAXONOMY = TOML.parsefile(joinpath(@__DIR__, "taxonomy.toml"))["papers"]

# ---------------------------------------------------------------------------
# sources
# ---------------------------------------------------------------------------

struct Paper
    id::String
    year::Int
    dir::String
    bib_key::String
    tex::String        # concatenated paper source, "" when absent
    readme::String     # reproduction review, "" when absent
end

# ---------------------------------------------------------------------------
# evidence extraction
# ---------------------------------------------------------------------------

countmatches(re::Regex, s::AbstractString) = count(_ -> true, eachmatch(re, s))

const RE_PSEUDOCODE = r"(?i)(algorithm\b|pseudo-?code|\bstep +\d|\brepeat\b|\bwhile\b.{0,40}\bdo\b|for each)"
const RE_IO         = r"(?m)^[ \t]*(Input|Output|Require|Ensure)[ \t]*:"
const RE_PARAMS     = r"(?i)(primitive polynomial|irreducible polynomial|defining polynomial|modulus|generator of|search (bound|space|range)|running time|time complexity|complexity of|CPU|runtime|\bO\(|number of steps|hours|seconds)"
const RE_TABULAR    = r"\\begin\{tabular\}"
const RE_INVARIANT  = r"(?i)(\\Gamma[- ]?rank|\\Delta[- ]?rank|Gamma[- ]?rank|Delta[- ]?rank|ortho[- ]?derivative|Walsh spectrum|differential spectrum|extended Walsh|N_?F|nonlinearity|differential uniformity)"
const RE_ARCHIVE    = r"(?i)(zenodo|figshare|doi\.org/10\.5281|/releases/tag/|dryad)"
const RE_REPO       = r"(?i)(github\.com|gitlab\.|bitbucket\.|sourceforge)"
const RE_PROPRIETARY= r"(?i)(magma|maple|mathematica)"

# README "Paper Issues" phrasing that indicates the publication itself is
# underspecified for reimplementation.
const RE_UNDERSPEC = r"(?i)(underspecif|not specified|unspecified|does not (say|specify|state|give)|ambiguous|ambiguity|unclear|no explicit|had to (choose|guess|assume)|we assume|left implicit|not given in the paper|omits)"

"""Extract one `## <heading>` section from a README, case-insensitively."""
function section(readme::AbstractString, want::AbstractString)
    isempty(readme) && return ""
    lines = split(readme, '\n')
    out = String[]
    grabbing = false
    for l in lines
        if startswith(l, "## ")
            grabbing = occursin(lowercase(want), lowercase(l))
            continue
        end
        startswith(l, "# ") && (grabbing = false)
        grabbing && push!(out, l)
    end
    join(out, "\n")
end

struct Evidence
    pseudocode::Int
    io::Int
    params::Int
    tabular::Int
    invariant::Int
    archive::Int
    repo::Int
    proprietary::Int
    underspec::Int
    paper_issues::Int
    corroborators::Vector{String}   # other paper ids whose README names this one
    in_corpus::Bool                 # functions of this paper live in a bulk corpus
end

# ---------------------------------------------------------------------------
# the four rules
# ---------------------------------------------------------------------------

"""
R1 Methodological Disclosure — could the paper be reimplemented from its own text?

  full : a pseudocode or explicit-parameter signal is present AND the
         reproduction README records no underspecification issue.
  half : structure is present but the README records an underspecification
         issue, or only one of the two signals is present.
  open : neither signal, i.e. the method is described qualitatively only.
"""
function r1(e::Evidence)
    structured = (e.pseudocode ≥ 1 || e.io ≥ 1)
    if structured && e.params ≥ 1 && e.underspec == 0
        :full
    elseif !structured && e.params == 0
        :open
    else
        :half
    end
end

"""
R2 Numerical Verification Metadata — can the central claim be checked against
the paper's own reported outputs?

  full : at least 2 tabular environments AND at least 3 invariant mentions.
  half : some tabular or invariant evidence, but not both thresholds.
  open : no table and no invariant mention.
"""
function r2(e::Evidence)
    if e.tabular ≥ 2 && e.invariant ≥ 3
        :full
    elseif e.tabular ≥ 1 || e.invariant ≥ 1
        :half
    else
        :open
    end
end

"""
R3 Artifact Availability — is code or data shared in a form that survives?

  full : a persistent archive (Zenodo, figshare, a tagged release, a data DOI).
  half : a repository or proprietary-tool script only — transient host, no
         resolved dependencies, or Magma/Maple/Mathematica dependence.
  open : no computational artifact referenced.
"""
function r3(e::Evidence)
    if e.archive ≥ 1
        :full
    elseif e.repo ≥ 1 || e.proprietary ≥ 1
        :half
    else
        :open
    end
end

"""
R4 External Corroboration — has anyone outside the author team confirmed it?

  full : another reproduction in this collection names this paper AND its
         functions also appear in an independent corpus, i.e. two distinct
         outside signals.
  half : exactly one such signal — cross-referenced by another reproduction, or
         present in a community database, but not both.
  open : neither; validation is internal to the authors.

WEAKEST OF THE FOUR. "Outside the author team" is only partly observable from
inside this repository, and a shared author between two papers is not detected.
"""
function r4(e::Evidence)
    signals = (length(e.corroborators) ≥ 1) + e.in_corpus
    signals ≥ 2 ? :full : signals == 1 ? :half : :open
end

const MARK = Dict(:full => "\\gf", :half => "\\gh", :open => "\\go")

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

function build()
    # --- gather papers ------------------------------------------------------
    papers = Paper[]
    for paper in VBFRepro.discover_papers()
            id, pdir = paper.id, paper.path
            tex = ""
            indir = joinpath(pdir, "input")
            if isdir(indir)
                for f in sort(readdir(indir; join = true))
                    endswith(f, ".tex") || continue
                    tex *= "\n" * read(f, String)
                end
            end
            rp = joinpath(pdir, "README.md")
            readme = isfile(rp) ? read(rp, String) : ""
            key = something(VBFRepro.paper_bib_key(id), "")
            push!(papers, Paper(id, parse(Int,paper.year), pdir, key, tex, readme))
    end
    isempty(papers) && error("no papers found under $PAPERS")

    # --- bibliography keys that actually exist ------------------------------
    bibtext = read(BIB, String)
    bibkeys = Set(m.captures[1] for m in eachmatch(r"@\w+\{([^,]+),", bibtext))

    # --- corpora bib_keys (community-database inclusion, R4) ----------------
    corpus_keys = Set{String}()
    db = VBFCatalog.catalog_path()
    if isfile(db)
        catalog=load_catalog(db)
        try
            for name in list_corpora(catalog)
                k=corpus_info(catalog,name).bib_key
                k===missing || push!(corpus_keys,String(k))
            end
            for r in list_functions(catalog)
                r.family!="APN" && r.bib_key!==nothing && push!(corpus_keys,r.bib_key)
            end
        finally
            VBFCatalog.SQLite.close(catalog)
        end
    end

    # --- evidence -----------------------------------------------------------
    ids = Set(p.id for p in papers)
    ev = Dict{String,Evidence}()
    for p in papers
        issues = section(p.readme, "paper issues")
        corrob = String[]
        for q in papers
            q.id == p.id && continue
            # another reproduction's README or FINDINGS naming this paper
            if occursin(p.id, q.readme) || (!isempty(p.bib_key) && occursin(p.bib_key,q.readme))
                push!(corrob, q.id)
            end
        end
        ev[p.id] = Evidence(
            countmatches(RE_PSEUDOCODE, p.tex),
            countmatches(RE_IO, p.tex),
            countmatches(RE_PARAMS, p.tex),
            countmatches(RE_TABULAR, p.tex),
            countmatches(RE_INVARIANT, p.tex),
            countmatches(RE_ARCHIVE, p.tex),
            countmatches(RE_REPO, p.tex),
            countmatches(RE_PROPRIETARY, p.tex),
            countmatches(RE_UNDERSPEC, issues),
            count(l -> startswith(strip(l), "-"), split(issues, '\n')),
            sort(corrob),
            p.bib_key in corpus_keys,
        )
    end

    # --- emit ---------------------------------------------------------------
    mkpath(OUT)
    header = """
    % !!! GENERATED FILE — DO NOT EDIT !!!
    % Produced by packages/VBFWorkingPaper/src/analysis/reproductions/grades.jl from:
    %   packages/VBFRepro/src/<id>/input/*.tex     (the publication, PDF-converted)
    %   packages/VBFRepro/src/<id>/README.md       (the reproduction review)
    %   packages/VBFCatalog/data/bibliography.bib
    %   packages/VBFCatalog/data/catalog.sqlite  (bulk_corpora, functions)
    % Regenerate with:  julia --project=. packages/VBFWorkingPaper/src/analysis/reproductions/grades.jl
    """

    # Two side-by-side panels, so 42 rows fit one compact table rather than a page.
    ordered = sort(papers; by = x -> (x.year, x.id))
    n_full = Dict(:R1 => 0, :R2 => 0, :R3 => 0, :R4 => 0)
    cells = String[]
    for p in ordered
        e = ev[p.id]
        m = (r1(e), r2(e), r3(e), r4(e))
        for (k, v) in zip((:R1, :R2, :R3, :R4), m)
            v == :full && (n_full[k] += 1)
        end
        cite = (isempty(p.bib_key) || !(p.bib_key in bibkeys)) ?
               "\\textsuperscript{\\dag}" : "\\cite{$(p.bib_key)}"
        label = replace(p.id, "_" => "\\_")
        push!(cells, "\\texttt{\\scriptsize $label} & $cite & " *
                     join((MARK[x] for x in m), " & "))
    end
    half = cld(length(cells), 2)
    rows = IOBuffer()
    for i in 1:half
        left = cells[i]
        right = i + half ≤ length(cells) ? cells[i+half] : " & & & & & "
        println(rows, left, " & ", right, " \\\\")
    end

    facts = IOBuffer()
    println(facts, header)
    println(facts, "\\newcommand{\\bfaPapers}{$(length(papers))}")
    # TeX control-sequence names cannot contain digits, so R1..R4 are spelled out.
    WORD = Dict(:R1 => "Rone", :R2 => "Rtwo", :R3 => "Rthree", :R4 => "Rfour")
    for k in (:R1, :R2, :R3, :R4)
        println(facts, "\\newcommand{\\bfaFull$(WORD[k])}{$(n_full[k])}")
    end
    nobib = [p.id for p in papers if isempty(p.bib_key) || !(p.bib_key in bibkeys)]
    println(facts, "\\newcommand{\\bfaNoBib}{$(length(nobib))}")

    ap = IOBuffer()
    println(ap, header)
    for p in sort(papers; by = x -> (x.year, x.id))
        e = ev[p.id]
        label = replace(p.id, "_" => raw"\_")
        println(ap, "\\texttt{$label} & $(e.pseudocode) & $(e.io) & $(e.params) & ",
                "$(e.tabular) & $(e.invariant) & $(e.archive) & $(e.repo) & ",
                "$(e.proprietary) & $(e.underspec) & $(length(e.corroborators)) & ",
                (e.in_corpus ? "y" : "n"), " \\\\")
    end

    if REPORT_ONLY
        println(String(take!(facts)))
        println("--- rows ---"); println(String(take!(rows)))
        return
    end
    write(joinpath(OUT, "bfa4r_table.tex"), header * String(take!(rows)))
    write(joinpath(OUT, "bfa4r_facts.tex"), String(take!(facts)))
    write(joinpath(OUT, "bfa4r_evidence.tex"), String(take!(ap)))

    # The same grades as data. packages/VBFWorkingPaper/src/analysis/reproductions/metrics.jl joins this file to the
    # reproduction outcome of each paper, so the grade must come from here and
    # never from a second copy of the rules. The file holds data only: one
    # header line, then one row per paper, and no comment line.
    csv = IOBuffer()
    println(csv, "paper_id,year,bib_key,r1,r2,r3,r4,pseudocode,io,params,tabular,",
                 "invariant,archive,repo,proprietary,underspec,paper_issues,",
                 "corroborators,in_corpus")
    for p in ordered
        e = ev[p.id]
        println(csv, join((p.id, p.year, p.bib_key,
                           r1(e), r2(e), r3(e), r4(e),
                           e.pseudocode, e.io, e.params, e.tabular, e.invariant,
                           e.archive, e.repo, e.proprietary, e.underspec,
                           e.paper_issues, length(e.corroborators),
                           e.in_corpus ? 1 : 0), ","))
    end
    write(joinpath(OUT, "bfa4r_grades.csv"), String(take!(csv)))

    @info "BFA-4R generated" papers = length(papers) R1full = n_full[:R1] R2full = n_full[:R2] R3full = n_full[:R3] R4full = n_full[:R4] missing_bib = length(nobib)
    isempty(nobib) || println("  no usable bibliography key: ", join(nobib, ", "))
end

build()
