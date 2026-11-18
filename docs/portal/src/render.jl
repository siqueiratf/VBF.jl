# HTML rendering of the portal pages from the model (templates in docs/portal/templates).
# Every internal link is relative to the page, so the site works under any base path
# (for example /VBF.jl/ on GitHub Pages) and from a local folder.

const TEMPLATES = joinpath(@__DIR__, "..", "templates")
template(name) = Mustache.load(joinpath(TEMPLATES, name * ".html"))

"Escape text for HTML."
esc(s) = replace(string(s), "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")

"Prefix from a page path (\"reproductions/x/index.html\") to the site root (\"../../\")."
root_prefix(path) = (d = count(==('/'), path); d == 0 ? "./" : "../"^d)

"Reference in the list format: authors. year. title. venue."
reference_html(r) = string("<span class=\"authors-sc\">", esc(r["author_line"]), "</span>. ", r["year"], ". ", esc(r["title"]), ". <i>",
    isempty(r["venue"]) ? "" : esc(r["venue"]), "</i>.")

const VERIFICATION_TEXT = Dict(
    "computational-check" => "Computational check for the stated scope; not a general proof.",
    "replication" => "The published experiment, run again.",
    "transcription" => "Published values, transcribed and checked for consistency; not recomputed.")

"""
The meta line above a reference, as in ReScience: DOI | Paper | Code | Data | Catalog | BibTeX.
Paper and Code are small solid tags; absent items are left out, never shown empty.
"""
function linkline(r, root)
    ref = r["ref"]; items = String[]
    a(url, text; tag = false) = "<a href=\"$(esc(url))\"$(tag ? " class=\"tag\"" : "")>$(esc(text))</a>"
    isempty(ref["doi"]) || push!(items, a(ref["doi_url"], ref["doi"]))
    paper = isempty(ref["url"]) ? ref["doi_url"] : ref["url"]
    isempty(paper) || push!(items, a(paper, "Paper"; tag = true))
    foreach(c -> push!(items, a(c, "Code"; tag = true)), r["code"])
    for d in r["data"]
        isempty(d["url"]) || push!(items, a(d["url"], "Data"))
    end
    isempty(r["corpora"]) || push!(items, a(root * "catalog/corpora/" * first(r["corpora"])["name"] * "/", "Catalog"))
    isempty(ref["bibtex"]) || push!(items, "<details class=\"bibtex\"><summary>BibTeX</summary><pre>$(esc(ref["bibtex"]))</pre></details>")
    # A div, not a p: a p cannot hold the <details> of the BibTeX toggle.
    "<div class=\"links\">" * join(items, "<span class=\"sep\">|</span>") * "</div>"
end

"""One sentence about one evidence record, for one claim."""
function evidence_text(rec, claim_id)
    prov = rec["provenance"]
    date = first(get(prov, "created_utc", "unknown date"), 10)
    commit = first(get(prov, "commit", ""), 7)
    where = haskey(get(prov, "ci", Dict()), "run_id") ? "CI run $(prov["ci"]["run_id"])" : "local run"
    if rec["kind"] == "regression"
        files = [t for t in get(rec, "testsets", []) if claim_id in get(t, "claims", [])]
        outcome = isempty(files) ? rec["outcome"] :
            any(t -> t["outcome"] == "error", files) ? "error" : any(t -> t["outcome"] == "failed", files) ? "failed" : "passed"
        what = "Regression test " * outcome * " (" * join([t["file"] for t in files], ", ") * ")"
    else
        what = "Reproduction run " * rec["outcome"] * " (" * rec["command"] * ")"
    end
    state = !rec["valid"] ? "Invalid record: " * join(rec["problems"], "; ") * "." :
            rec["current"] ? "Current for this build." :
            "Historical: made at commit $commit; changed since: " * join(rec["changed"], ", ") * "."
    "$what, $where, commit $commit, $date. $state"
end

"""Render one page into `out/path` with the base layout."""
function write_page(out, path, title, content; nav = "", home = false)
    root = root_prefix(path)
    view = Dict("title" => title, "root" => root, "content" => content,
                "snapshot_key" => SNAPSHOT_KEY[], "snapshot_short" => first(SNAPSHOT_KEY[], 12),
                "nav_" * nav => true, "home" => home)
    file = joinpath(out, path)
    mkpath(dirname(file))
    write(file, Mustache.render(template("base"), view))
    file
end

const SNAPSHOT_KEY = Ref("")

"""Text of `site.md` (Markdown) as HTML, or empty when the paper has none."""
function site_text(repro)
    f = joinpath(ROOT, repro["path"], "site.md")
    isfile(f) ? Markdown.html(Markdown.parse(read(f, String))) : ""
end

"""
    render_portal(model, out) -> Vector{String}

Write Home, Reproductions, the reproduction pages, the catalog pages of S3 and About into
`out`. Returns the written page paths.
"""
function render_portal(model, out)
    SNAPSHOT_KEY[] = model["snapshot"].prebuilt_key
    written = String[]
    repros = model["reproductions"]
    item(r, root) = Dict("id" => r["id"], "reference" => reference_html(r["ref"]), "linkline" => linkline(r, root))

    latest = sort(repros; by = r -> r["updated"], rev = true)[1:min(3, end)]
    push!(written, write_page(out, "index.html", "Home",
        Mustache.render(template("home"), Dict("root" => "./", "latest" => [item(r, "./") for r in latest])); home = true))

    root = root_prefix("reproductions/index.html")
    years = [Dict("year" => y, "items" => [item(r, root) for r in repros if r["year"] == y])
             for y in unique(r["year"] for r in repros)]
    push!(written, write_page(out, "reproductions/index.html", "Reproductions",
        Mustache.render(template("reproductions"), Dict("root" => root, "count" => length(repros), "years" => years));
        nav = "reproductions"))

    for r in repros
        path = "reproductions/$(r["id"])/index.html"; root = root_prefix(path)
        claims = [merge(c, Dict(
            "verification_text" => get(VERIFICATION_TEXT, c["verification"], c["verification"]),
            "evidence_items" => [Dict("text" => evidence_text(e, c["id"])) for e in c["evidence"]],
            "api_text" => join(get(c, "api", String[]), ", "))) for c in r["claims"]]
        view = merge(r["ref"], Dict("root" => root, "linkline" => linkline(r, root), "claims" => claims,
            "has_claims" => r["has_claims"], "other_files" => r["other_files"],
            "other_files_any" => !isempty(r["other_files"]), "corpora" => r["corpora"],
            "corpora_any" => !isempty(r["corpora"]), "site_text" => site_text(r),
            "url" => r["url"], "path" => r["path"]))
        push!(written, write_page(out, path, r["ref"]["title"], Mustache.render(template("reproduction"), view);
            nav = "reproductions"))
    end

    # Catalog pages of S3: the corpora and the publications that cite them. S4 adds the query layer.
    corpora = sort(collect(values(model["corpora"])); by = c -> c["name"])
    users(name) = [r for r in repros if any(c -> c["name"] == name, r["corpora"])]
    body = "<p>Snapshot <code>$(esc(model["snapshot"].prebuilt_key))</code>.</p>" *
        "<p><a href=\"functions/\">Curated functions</a>: the named functions of the catalog, with their properties.</p>" *
        "<h2>Corpora</h2><ul>" *
        join(["<li><a href=\"corpora/$(c["name"])/\">$(esc(c["name"]))</a>: $(c["member_count"]) functions, n = $(c["n"])</li>" for c in corpora]) * "</ul>"
    push!(written, write_page(out, "catalog/index.html", "Catalog",
        Mustache.render(template("page"), Dict("title" => "Catalog", "body" => body)); nav = "catalog"))
    for c in corpora
        path = "catalog/corpora/$(c["name"])/index.html"; root = root_prefix(path)
        pubs = join(["<li><a href=\"$(root)reproductions/$(r["id"])/\">$(reference_html(r["ref"]))</a></li>" for r in users(c["name"])])
        body = "<table class=\"properties\">" *
               "<tr><th scope=\"row\">Functions</th><td>$(c["member_count"])</td></tr>" *
               "<tr><th scope=\"row\">Dimensions</th><td>\$n = $(c["n"])\$, \$m = $(c["m"])\$</td></tr>" *
               "<tr><th scope=\"row\">Corpus digest</th><td><code>$(esc(c["digest"]))</code></td></tr>" *
               "<tr><th scope=\"row\">Source</th><td><code>$(esc(c["source_repo"]))</code></td></tr></table>" *
               (isempty(pubs) ? "" : "<h2>Publications</h2><ol>$pubs</ol>") *
               member_view(c, root, model["snapshot"].prebuilt_key)
        push!(written, write_page(out, path, c["name"],
            Mustache.render(template("page"), Dict("title" => c["name"], "body" => body)); nav = "catalog"))
    end

    about = """
        <p>VBF.jl is developed by Tiago Faustino de Siqueira and Gustavo Zambonin
        (<a href="https://orcid.org/0000-0002-6962-9347">ORCID</a>), Universidade Federal de Santa Catarina.</p>
        <p>Cite the software with <a href="https://github.com/siqueiratf/VBF.jl/blob/main/CITATION.cff">CITATION.cff</a>,
        and the prebuilt catalog data with <a href="https://doi.org/10.5281/zenodo.24297661">doi:10.5281/zenodo.24297661</a>.
        The code is under the MIT license. The design follows <a href="https://rescience.github.io/">ReScience C</a>.</p>
        """
    push!(written, write_page(out, "about/index.html", "About",
        Mustache.render(template("page"), Dict("title" => "About", "body" => about)); nav = "about"))
    written
end

"""Member view of a corpus page: a form, read by assets/portal/js/members.js."""
member_view(c, root, key) = """
    <h2 id="members">Members</h2>
    <section id="member-view" data-db="$(root)catalog/data/$(key)/query.sqlite" data-corpus="$(esc(c["name"]))"
             data-digest="$(esc(c["digest"]))" data-root="$(root)">
    <form><label>Member index <input name="idx" type="number" min="1" max="$(c["member_count"])" required></label>
    <button type="submit">Show</button></form>
    <div class="member-result" aria-live="polite"></div>
    <noscript>The member view needs JavaScript. In Julia: corpus_function(load_catalog(), "$(esc(c["name"]))", i).</noscript>
    </section>
    <script type="module" src="$(root)assets/portal/js/members.js"></script>
    """

"""
    write_redirects(out, legacy) -> Vector{String}

For each path of the previous site that the new build does not serve, write a redirect page.
`generated/<paper-id>/` goes to `reproductions/<paper-id>/`. Returns the paths with no target.
"""
function write_redirects(out, legacy_file = joinpath(@__DIR__, "..", "legacy_urls.txt"))
    missing_ = String[]
    for line in eachline(legacy_file)
        p = strip(line)
        (isempty(p) || startswith(p, "#")) && continue
        isfile(joinpath(out, p, "index.html")) && continue
        m = match(r"^generated/(\d{6}-[a-z0-9-]+)/$", p)
        target = m === nothing ? nothing : "reproductions/$(m[1])/"
        if target === nothing || !isfile(joinpath(out, target, "index.html"))
            push!(missing_, p); continue
        end
        rel = root_prefix(p * "index.html") * target
        mkpath(joinpath(out, p))
        write(joinpath(out, p, "index.html"), Mustache.render(template("redirect"), Dict("target" => rel)))
    end
    missing_
end
