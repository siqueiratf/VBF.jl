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

include(joinpath(@__DIR__, "library_pages.jl"))
api_pages = write_api_pages(joinpath(@__DIR__, "src"))
paper_pages, search_page = write_generated_pages(joinpath(@__DIR__, "src"))

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
