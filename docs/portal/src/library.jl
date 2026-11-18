# The Library inside the portal. Documenter builds it (search, docstrings, mathematics,
# citations and its own navigation); this file then
#
#   - gives each Documenter page the portal header, footer and style sheet, and keeps only
#     the light theme (the portal has one colour scheme);
#   - adds the cross-references that the model knows and Documenter does not: under each
#     docstring, the reproduced claims that use the symbol, the catalog property that it
#     computes and the reproduced publications that it cites; on the References page, the
#     reproduction, the corpora and the citing symbols of each publication.
#
# The other direction (claims, function pages and publication pages to the Library) uses
# `library_anchors` and `library_citations` in render.jl and catalog_pages.jl.

const LIBRARY_MODULES = ("VBF", "VBFCatalog", "VBFRepro")

"""
Catalog properties and the Library symbol that computes each one: (symbol, label on the
function page, column of the function list or `nothing`).
"""
const CATALOG_PROPERTIES = [
    ("differential_uniformity", "Differential uniformity", "differential_uniformity"),
    ("is_apn", "APN", "is_apn"),
    ("algebraic_degree", "Algebraic degree", "algebraic_degree"),
    ("linearity", "Linearity", "linearity"),
    ("boomerang_uniformity", "Boomerang uniformity", nothing),
    ("is_permutation", "Permutation", "is_permutation"),
    ("anf", "Algebraic normal form", nothing),
    ("VBFCatalog.sigma_hash", "Signature", nothing),
]

"Pages of the Documenter build in `out` (the HTML files that hold `id=\"documenter\"`)."
function documenter_pages(out)
    pages = String[]
    for (dir, _, files) in walkdir(out), f in files
        endswith(f, ".html") || continue
        p = joinpath(dir, f)
        occursin("id=\"documenter\"", read(p, String)) && push!(pages, p)
    end
    pages
end

"Binding of a docstring id: \"VBF.algebraic_degree-Union{...}\" → \"VBF.algebraic_degree\"."
function docstring_binding(id)
    m = match(r"^((?:VBFCatalog|VBFRepro|VBF)\.[^-\s]+)", id)
    m === nothing ? nothing : String(m[1])
end

"The docstrings of a page: (binding, start of the summary tag, end of the docstring)."
function docstrings(html)
    out = Tuple{String,Int,Int}[]
    for m in eachmatch(r"<details class=\"docstring\"[^>]*><summary id=\"([^\"]+)\"", html)
        b = docstring_binding(unescape_html(m[1]))
        b === nothing && continue
        stop = findnext("</details>", html, m.offset)
        stop === nothing || push!(out, (b, m.offset, last(stop)))
    end
    out
end

"""
    library_citations(out) -> Dict{String,Vector{String}}

The bibliography keys that each Library symbol cites in its docstring ("VBF.delta_rank" =>
["Edel_200900"]), read from the citation links of the built API pages.
"""
function library_citations(out)
    d = Dict{String,Vector{String}}()
    api = joinpath(out, "api")
    isdir(api) || return d
    for (dir, _, files) in walkdir(api), f in files
        f == "index.html" || continue
        html = read(joinpath(dir, f), String)
        for (b, a, z) in docstrings(html)
            keys_ = [String(m[1]) for m in eachmatch(r"references/#([A-Za-z0-9_]+)\"", html[a:z])]
            isempty(keys_) || union!(get!(d, b, String[]), keys_)
        end
    end
    d
end

"Symbols by cited key: the inverse of `library_citations`."
function citing_symbols(cites)
    d = Dict{String,Vector{String}}()
    for (b, ks) in cites, k in ks
        push!(get!(d, k, String[]), b)
    end
    foreach(sort!, values(d))
    d
end

"Short display name of a binding: VBF names without the module, the others with it."
display_binding(b) = startswith(b, "VBF.") ? b[5:end] : b

"Library link of a binding from a page at `root`, or plain code when the Library has no entry."
lib_link(b, lib, root) = haskey(lib, b) ? "<a href=\"$(root)$(lib[b])\"><code>$(esc(display_binding(b)))</code></a>" :
                                         "<code>$(esc(display_binding(b)))</code>"

"Claims of the model that use each binding: \"VBF.delta_rank\" => [(reproduction, claim)]."
function claims_by_binding(model)
    d = Dict{String,Vector{Tuple{Any,Any}}}()
    for r in model["reproductions"], c in r["claims"], a in get(c, "api", String[])
        b = occursin('.', a) ? a : "VBF." * a
        push!(get!(d, b, Tuple{Any,Any}[]), (r, c))
    end
    d
end

"The portal header for a Library page (the same links as base.html, with Library current)."
library_header(root) = """
    <header class="site-header library">
      <a class="site-title" href="$(root)">VBF.jl</a>
      <button type="button" class="menu-toggle" aria-expanded="false" aria-controls="site-nav" aria-label="Menu">
        <svg viewBox="0 0 18 15" aria-hidden="true" focusable="false"><path d="M0 1.5h18M0 7.5h18M0 13.5h18" stroke="currentColor" stroke-width="2"/></svg>
      </button>
      <nav class="site-nav" id="site-nav" aria-label="Main">
        <a href="$(root)reproductions/">Reproductions</a>
        <a href="$(root)catalog/">Catalog</a>
        <a href="$(root)library/" aria-current="page">Library</a>
        <a href="$(root)about/">About</a>
      </nav>
    </header>"""

library_footer(root) = """
    <footer class="site-footer library">
      <a href="https://github.com/siqueiratf/VBF.jl">Sources</a> ·
      <a href="$(root)catalog/#snapshots">Catalog snapshot</a> ·
      Library built with <a href="https://github.com/JuliaDocs/Documenter.jl">Documenter.jl</a> ·
      Design after <a href="https://rescience.github.io/">ReScience C</a>
    </footer>"""

"""The cross-reference block under the docstring of `b` (empty when there is nothing to say)."""
function xref_block(b, root, model, claims, cites, repro_of, refs)
    items = String[]
    for (sym, label, col) in CATALOG_PROPERTIES
        (sym == b || "VBF." * sym == b) || continue
        push!(items, "Catalog: the property “$(esc(label))” of each <a href=\"$(root)catalog/functions/\">curated function</a>" *
            (col === nothing ? "." : "; <a href=\"$(root)catalog/functions/?sort=$(col)&amp;dir=asc\">the function list sorted by it</a>."))
    end
    cs = get(claims, b, [])
    isempty(cs) || push!(items, "Used in reproductions: " * join(["<a href=\"$(root)reproductions/$(r["id"])/#$(c["anchor"])\">" *
        "$(esc(short_cite(r["ref"]))), $(esc(c["label"]))</a>" for (r, c) in cs], "; ") * ".")
    reproduced = [k for k in get(cites, b, String[]) if haskey(repro_of, k) && haskey(refs, k)]
    isempty(reproduced) || push!(items, "Cited publications with a reproduction: " * join(["<a href=\"$(root)reproductions/$(repro_of[k]["id"])/\">" *
        "$(esc(short_cite(refs[k])))</a>" for k in reproduced], ", ") * ".")
    isempty(items) ? "" : "<div class=\"portal-xref\"><ul>" * join(["<li>$i</li>" for i in items]) * "</ul></div>"
end

"""
    decorate_library!(out, model) -> Int

Give each Documenter page in `out` the portal header, footer and style, keep the light theme
only, and add the cross-reference blocks. Returns the number of pages changed.
"""
function decorate_library!(out, model)
    lib = library_anchors(out)
    cites = library_citations(out)
    citing = citing_symbols(cites)
    claims = claims_by_binding(model)
    refs = model["references"]
    repro_of = Dict(x["key"] => r for r in model["reproductions"] for x in r["publications"])
    corpora_of = Dict{String,Vector{String}}()
    foreach(c -> isempty(c["bib_key"]) || push!(get!(corpora_of, c["bib_key"], String[]), c["name"]), values(model["corpora"]))
    pages = documenter_pages(out)
    for p in pages
        html = read(p, String)
        m = match(r"documenterBaseURL=\"([^\"]*)\"", html)
        root = m === nothing || m[1] == "." ? "./" : m[1] * "/"
        # One colour scheme: drop every theme but the primary light one (Documenter then
        # keeps the primary theme for any stored or system preference).
        html = replace(html, r"<link class=\"docs-theme-link\"[^>]*data-theme-name=\"(?!documenter-light\")[^\"]*\"[^>]*/>" => "")
        html = replace(html, r"<option value=\"(?!documenter-light\")[^\"]*\">[^<]*</option>" => "")
        html = replace(html, "</head>" => "<link rel=\"stylesheet\" type=\"text/css\" href=\"$(root)assets/portal/library.css\"/></head>"; count = 1)
        html = replace(html, r"<body([^>]*)>" => s -> s * library_header(root); count = 1)
        # The footer goes after the Documenter frame, at the end of the body.
        i = findlast("</body>", html)
        i === nothing || (html = html[1:first(i) - 1] * library_footer(root) *
            "<script defer src=\"$(root)assets/portal/portal.js\"></script>" * html[first(i):end])
        # Cross-references under the first docstring of each binding on the page.
        seen = Set{String}(); inserts = Tuple{Int,String}[]
        for (b, _, z) in docstrings(html)
            b in seen && continue
            push!(seen, b)
            block = xref_block(b, root, model, claims, cites, repro_of, refs)
            isempty(block) && continue
            close_section = findprev("</section>", html, z)
            close_section === nothing || push!(inserts, (first(close_section), block))
        end
        # References page: the reproduction, corpora and citing symbols of each entry.
        if occursin(r"/references/index\.html$", p)
            for m in eachmatch(r"<li><div id=\"([A-Za-z0-9_]+)\">", html)
                k = String(m[1])
                stop = findnext("</div></li>", html, m.offset)
                stop === nothing && continue
                links = String[]
                haskey(repro_of, k) && push!(links, "<a href=\"$(root)reproductions/$(repro_of[k]["id"])/\">Reproduction</a>")
                for c in get(corpora_of, k, String[])
                    push!(links, "<a href=\"$(root)catalog/corpora/$(c)/\">Catalog corpus <code>$(esc(c))</code></a>")
                end
                syms = get(citing, k, String[])
                isempty(syms) || push!(links, "Cited by " * join([lib_link(s, lib, root) for s in syms], ", "))
                isempty(links) || push!(inserts, (first(stop) + length("</div>"), "<div class=\"portal-xref ref\">" * join(links, " · ") * "</div>"))
            end
        end
        for (i, block) in sort(inserts; by = first, rev = true)
            html = html[1:prevind(html, i)] * block * html[i:end]
        end
        write(p, html)
    end
    length(pages)
end
