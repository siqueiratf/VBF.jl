# Pages of the documentation that are generated from the source tree and the READMEs.
# Shared by docs/make.jl (the current site) and docs/portal/build.jl (the new portal).

const VBF_SRC = normpath(joinpath(@__DIR__, "..", "packages", "VBF", "src"))
const REPO = "https://github.com/siqueiratf/VBF.jl/blob/main/"
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

"""
    write_api_pages(srcdir) -> Vector{String}

The API reference: one page per concept directory, generated from the source tree so it
never drifts. Each page is an `@autodocs` block over the `.jl` files of that directory.
Returns the page paths relative to `srcdir`.
"""
function write_api_pages(srcdir)
    api_dir = joinpath(srcdir, "api")
    isdir(api_dir) && rm(api_dir; recursive = true)
    mkpath(api_dir)
    api_pages = String[]
    for (dir, title) in CONCEPTS
        root = joinpath(VBF_SRC, dir)
        isdir(root) || continue
        files = String[]
        for (base, _, names) in walkdir(root), f in names
            endswith(f, ".jl") || continue
            push!(files, replace(relpath(joinpath(base, f), VBF_SRC), '\\' => '/'))
        end
        isempty(files) && continue
        sort!(files)
        open(joinpath(api_dir, dir * ".md"), "w") do io
            println(io, "# ", title, "\n")
            println(io, "```@autodocs")
            println(io, "Modules = [VBF]")
            println(io, "Pages = [", join(("\"" * f * "\"" for f in files), ", "), "]")
            println(io, "```")
        end
        push!(api_pages, "api/" * dir * ".md")
    end
    for (file, title, mod, pages) in (("module.md", "VBF module", "VBF", "Pages = [\"VBF.jl\"]\n"),
                                      ("catalog.md", "VBFCatalog", "VBFCatalog", ""),
                                      ("reproduction.md", "VBFRepro", "VBFRepro", ""))
        open(joinpath(api_dir, file), "w") do io
            print(io, "# ", title, "\n\n```@autodocs\nModules = [", mod, "]\n", pages, "```\n")
        end
    end
    vcat(["api/module.md"], api_pages, ["api/catalog.md", "api/reproduction.md"])
end

"""Copy a README into `srcdir`; rewrite its relative links to GitHub URLs."""
function readme_page(source, target, srcdir)
    repo_root = normpath(joinpath(@__DIR__, ".."))
    dir = relpath(dirname(source), repo_root)
    text = replace(read(source, String), r"\]\((?!https?:|mailto:|#)([^)\s]+)\)" =>
        s -> "](" * REPO * normpath(joinpath(dir, match(r"\]\((.*)\)", s)[1])) * ")")
    # "Edit on GitHub" opens the README, not the generated copy.
    write(target, "```@meta\nEditURL = \"" * REPO * relpath(source, repo_root) * "\"\n```\n\n" * text)
    relpath(target, srcdir)
end

"""
    write_generated_pages(srcdir; papers=true) -> (paper_pages, search_page)

The Searches page from the VBFSearch README and, with `papers`, one page per paper README.
"""
function write_generated_pages(srcdir; papers = true)
    generated = joinpath(srcdir, "generated")
    isdir(generated) && rm(generated; recursive = true)
    mkpath(generated)
    paper_pages = Pair{String,String}[]
    if papers
        for paper in VBFRepro.discover_papers()
            readme = joinpath(paper.path, "README.md")
            isfile(readme) || continue
            push!(paper_pages, paper.id => readme_page(readme, joinpath(generated, paper.id * ".md"), srcdir))
        end
    end
    search = readme_page(normpath(joinpath(@__DIR__, "..", "packages", "VBFSearch", "README.md")),
                         joinpath(generated, "search.md"), srcdir)
    (paper_pages, search)
end
