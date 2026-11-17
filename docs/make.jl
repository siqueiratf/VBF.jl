using Documenter
using DocumenterCitations
using VBF
using VBFCatalog
using VBFRepro

# The References page renders the catalog's BibTeX file (the single source of truth for both the catalog provenance and the docs bibliography).
bib = CitationBibliography(
    VBFCatalog.bibliography_path();
    style = :authoryear,
)

# VBF docstrings draw examples from the catalog loaders (load_literature_sbox, load_apn_function, ...), so the doctest sandbox needs both modules in scope.
DocMeta.setdocmeta!(VBF, :DocTestSetup, :(using VBF, VBFCatalog); recursive = true)
DocMeta.setdocmeta!(VBFCatalog, :DocTestSetup, :(using VBF, VBFCatalog); recursive = true)

# The API reference is one page per concept directory, generated from the source tree so it never drifts: each page is an `@autodocs` block over the `.jl` files in that directory, picking up every docstring automatically.
const SRC = normpath(joinpath(@__DIR__, "..", "packages", "VBF", "src"))
const API_DIR = joinpath(@__DIR__, "src", "api")
isdir(API_DIR) && rm(API_DIR; recursive = true)
mkpath(API_DIR)

const CONCEPTS = [
    ("search",          "Search outcomes"),
    ("representations", "Representations"),
    ("linalg",          "Linear algebra"),
    ("spectra",         "Spectra"),
    ("invariants",      "Invariants"),
    ("equivalence",     "Equivalence"),
    ("constructions",   "Constructions"),
    ("random",          "Random objects"),
    ("io",              "Rendering"),
]

api_pages = String[]
for (dir, title) in CONCEPTS
    root = joinpath(SRC, dir)
    isdir(root) || continue
    files = String[]
    for (base, _, names) in walkdir(root), f in names
        endswith(f, ".jl") || continue
        push!(files, replace(relpath(joinpath(base, f), SRC), '\\' => '/'))
    end
    isempty(files) && continue
    sort!(files)
    page = joinpath(API_DIR, dir * ".md")
    open(page, "w") do io
        println(io, "# ", title, "\n")
        println(io, "```@autodocs")
        println(io, "Modules = [VBF]")
        println(io, "Pages = [", join(("\"" * f * "\"" for f in files), ", "), "]")
        println(io, "```")
    end
    push!(api_pages, "api/" * dir * ".md")
end

open(joinpath(API_DIR, "module.md"), "w") do io
    println(io, "# VBF module\n")
    println(io, "```@autodocs")
    println(io, "Modules = [VBF]")
    println(io, "Pages = [\"VBF.jl\"]")
    println(io, "```")
end
pushfirst!(api_pages, "api/module.md")

open(joinpath(API_DIR, "catalog.md"), "w") do io
    println(io, "# VBFCatalog\n")
    println(io, "```@autodocs")
    println(io, "Modules = [VBFCatalog]")
    println(io, "```")
end
push!(api_pages, "api/catalog.md")

open(joinpath(API_DIR, "reproduction.md"), "w") do io
    println(io, "# VBFRepro\n")
    println(io, "```@autodocs")
    println(io, "Modules = [VBFRepro]")
    println(io, "```")
end
push!(api_pages, "api/reproduction.md")

# One page per paper reproduction and one for the searches, generated from the READMEs so
# that the site never drifts from them. Relative links point to the files on GitHub.
const REPO = "https://github.com/siqueiratf/VBF.jl/blob/main/"
const GENERATED = joinpath(@__DIR__, "src", "generated")
isdir(GENERATED) && rm(GENERATED; recursive = true)
mkpath(GENERATED)

"""Copy a README into the site; rewrite its relative links to GitHub URLs."""
function readme_page(source, target)
    dir = relpath(dirname(source), normpath(joinpath(@__DIR__, "..")))
    text = replace(read(source, String), r"\]\((?!https?:|mailto:|#)([^)\s]+)\)" =>
        s -> "](" * REPO * normpath(joinpath(dir, match(r"\]\((.*)\)", s)[1])) * ")")
    # "Edit on GitHub" opens the README, not the generated copy.
    write(target, "```@meta\nEditURL = \"" * REPO * relpath(source, normpath(joinpath(@__DIR__, ".."))) * "\"\n```\n\n" * text)
    relpath(target, joinpath(@__DIR__, "src"))
end

paper_pages = Pair{String,String}[]
for paper in VBFRepro.discover_papers()
    readme = joinpath(paper.path, "README.md")
    isfile(readme) || continue
    push!(paper_pages, paper.id => readme_page(readme, joinpath(GENERATED, paper.id * ".md")))
end
search_page = readme_page(normpath(joinpath(@__DIR__, "..", "packages", "VBFSearch", "README.md")),
    joinpath(GENERATED, "search.md"))

makedocs(
    sitename = "VBF",
    authors = "Tiago Faustino de Siqueira, Gustavo Zambonin",
    modules = [VBF, VBFCatalog, VBFRepro],
    warnonly = true,
    # Run `DOCS_FIX=true julia --project=docs docs/make.jl` to rewrite drifted jldoctest blocks in the source to their actual output.
    doctest = get(ENV, "DOCS_FIX", "false") == "true" ? :fix : true,
    plugins = [bib],
    pages = [
        "Home" => "index.md",
        "Getting started" => "getting_started.md",
        "Command-line tools" => "cli.md",
        "Prebuilt catalog data" => "data.md",
        "APN inspector" => "inspector.md",
        "Paper reproductions" => ["Overview and performance" => "reproductions.md"; paper_pages],
        "Searches" => search_page,
        "2026/940 algorithm conformance" => "partition_refinement_conformance.md",
        "API reference" => api_pages,
        "References" => "references.md",
    ],
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        edit_link = "main",
        inventory_version = "0.1.0-DEV",
    ),
)

# CI publishes docs/build to GitHub Pages after each push to main (the docs-pages job of ci.yml).
