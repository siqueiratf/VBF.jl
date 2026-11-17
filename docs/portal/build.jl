# Build the portal: Library (Documenter) and the portal pages, in docs/portal/build/.
#
#   julia --project=docs/portal docs/portal/build.jl [--evidence DIR ...] [--skip-library]
#
# Until the switch of stage S5, the live site is still built by docs/make.jl. This build
# leaves docs/src unchanged: it copies it to a temporary folder, moves the Documenter home
# to library/ and the page "Overview and performance" to performance/, and drops the README
# copies of the papers (the portal has its own reproduction pages).
using Documenter, DocumenterCitations
using VBF, VBFCatalog, VBFRepro, VBFPortal

const DOCS = normpath(joinpath(@__DIR__, ".."))
const OUT = joinpath(@__DIR__, "build")
include(joinpath(DOCS, "library_pages.jl"))

args = copy(ARGS)
skip_library = "--skip-library" in args
evidence = [joinpath(dirname(VBFRepro.papers_root()), "evidence")]
for (i, a) in enumerate(args)
    a == "--evidence" && push!(evidence, abspath(args[i + 1]))
end
qi = findfirst(==("--query"), args)
query = qi === nothing ? nothing : abspath(args[qi + 1])

isdir(OUT) && rm(OUT; recursive = true)
mkpath(OUT)

if !skip_library
    # The copy stays inside the repository (ignored by git), so that Documenter can make its
    # source links; each copied page names its original in docs/src for "Edit on GitHub".
    src = joinpath(@__DIR__, "library-src")
    isdir(src) && rm(src; recursive = true)
    cp(joinpath(DOCS, "src"), src)
    # The closure-monitor pages work only behind docs/inspector/closure_monitor.jl (absolute
    # links to its own routes); no static page links to them, so the static build omits them.
    foreach(f -> startswith(f, "apn-closure") && rm(joinpath(src, "assets", f)), readdir(joinpath(src, "assets")))
    for (dir, _, files) in walkdir(src), f in files
        endswith(f, ".md") || continue
        p = joinpath(dir, f)
        original = "https://github.com/siqueiratf/VBF.jl/blob/main/docs/src/" * relpath(p, src)
        text = replace(read(p, String), "(reproductions.md)" => "(performance.md)", "(index.md)" => "(library.md)")
        write(p, "```@meta\nEditURL = \"$original\"\n```\n\n" * text)
    end
    mv(joinpath(src, "index.md"), joinpath(src, "library.md"))
    mv(joinpath(src, "reproductions.md"), joinpath(src, "performance.md"))
    api_pages = write_api_pages(src)
    _, search_page = write_generated_pages(src; papers = false)
    DocMeta.setdocmeta!(VBF, :DocTestSetup, :(using VBF, VBFCatalog); recursive = true)
    DocMeta.setdocmeta!(VBFCatalog, :DocTestSetup, :(using VBF, VBFCatalog); recursive = true)
    makedocs(
        source = src, build = OUT, root = DOCS,
        sitename = "VBF.jl Library",
        authors = "Tiago Faustino de Siqueira, Gustavo Zambonin",
        modules = [VBF, VBFCatalog, VBFRepro],
        warnonly = true,
        doctest = true,
        plugins = [CitationBibliography(VBFCatalog.bibliography_path(); style = :authoryear)],
        pages = [
            "Library" => "library.md",
            "Getting started" => "getting_started.md",
            "Command-line tools" => "cli.md",
            "Prebuilt catalog data" => "data.md",
            "APN inspector" => "inspector.md",
            "Performance" => "performance.md",
            "Searches" => search_page,
            "2026/940 algorithm conformance" => "partition_refinement_conformance.md",
            "API reference" => api_pages,
            "References" => "references.md",
        ],
        format = Documenter.HTML(; prettyurls = true, edit_link = "main", inventory_version = "0.1.0-DEV"),
    )
end

db = load_catalog()
model = build_model(db; evidence_dirs = evidence)
isfile(joinpath(@__DIR__, "assets", "js", "members.js")) ||
    error("the browser code is not bundled: run `npm ci && node build.mjs` in docs/portal/js")
mkpath(joinpath(OUT, "assets"))
cp(joinpath(@__DIR__, "assets"), joinpath(OUT, "assets", "portal"); force = true)   # beside Documenter's assets
# The query database of this snapshot, at catalog/data/<prebuilt key>/query.sqlite. A local
# build links to the file; --copy-query copies it (for a deployment).
if query !== nothing
    qdir = joinpath(OUT, "catalog", "data", model["snapshot"].prebuilt_key)
    mkpath(qdir)
    "--copy-query" in args ? cp(query, joinpath(qdir, "query.sqlite")) : symlink(query, joinpath(qdir, "query.sqlite"))
end
pages = render_portal(model, OUT)
append!(pages, render_catalog_functions(model, OUT, db; query_db = query))
unresolved = write_redirects(OUT)
problems = check_links(OUT)
close(db)

println("portal: $(length(pages)) pages, $(length(model["reproductions"])) reproductions")
isempty(unresolved) || println("legacy paths without a page or redirect:\n  ", join(unresolved, "\n  "))
isempty(problems) || println("link problems: ", length(problems), "\n  ", join(problems[1:min(end, 40)], "\n  "))
isempty(model["errors"]) || println("model errors:\n  ", join(model["errors"], "\n  "))
exit(isempty(unresolved) && isempty(problems) && isempty(model["errors"]) ? 0 : 1)
