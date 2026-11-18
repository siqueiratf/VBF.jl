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

"""Outcome of a record for one claim: of the claim's test files (regression) or of the run."""
function claim_outcome(rec, claim_id)
    rec["kind"] == "reproduction" && return rec["outcome"]
    files = [t for t in get(rec, "testsets", []) if claim_id in get(t, "claims", [])]
    isempty(files) ? rec["outcome"] : any(t -> t["outcome"] == "error", files) ? "error" :
        any(t -> t["outcome"] == "failed", files) ? "failed" : "passed"
end

"""One evidence record for one claim, as a small table: what ran, how it ended, where, when."""
function evidence_table(rec, claim_id)
    prov = rec["provenance"]
    commit = get(prov, "commit", "")
    ci = get(prov, "ci", Dict())
    rows = Tuple{String,String}[]
    if rec["kind"] == "regression"
        files = [t["file"] for t in get(rec, "testsets", []) if claim_id in get(t, "claims", [])]
        push!(rows, ("Run", "Regression test" * (isempty(files) ? "" : " (" * esc(join(files, ", ")) * ")")))
    else
        push!(rows, ("Run", "Reproduction run"))
    end
    push!(rows, ("Outcome", esc(claim_outcome(rec, claim_id))))
    cmd = rec["kind"] == "regression" ? replace(rec["command"], " --evidence DIR" => "") : rec["command"]
    push!(rows, ("Command", "<code>$(esc(cmd))</code> " * copy_button(cmd)))
    isempty(commit) || push!(rows, ("Commit", "<a href=\"$(REPO_URL)/commit/$(commit)\"><code>$(first(commit, 7))</code></a>"))
    push!(rows, ("Date", esc(first(get(prov, "created_utc", ""), 10))))
    push!(rows, ("Where", haskey(ci, "run_id") ?
        "<a href=\"$(REPO_URL)/actions/runs/$(ci["run_id"])\">CI run $(esc(ci["run_id"]))</a>" : "Local run"))
    state = !rec["valid"] ? "Invalid record: " * esc(join(rec["problems"], "; ")) :
            rec["current"] ? "Current for this build" :
            "Historical: changed since the run: " * esc(join(rec["changed"], ", "))
    push!(rows, ("Compatibility", state))
    src = relpath(rec["source_dir"], ROOT)
    startswith(src, "packages/VBFRepro/evidence") &&
        push!(rows, ("Record", "<a href=\"$(BLOB)$(src)/record.toml\">record.toml</a>, <a href=\"$(BLOB)$(src)/$(rec["log"]["file"])\">output log</a>"))
    "<table class=\"evidence\">" * join(["<tr><th scope=\"row\">$a</th><td>$b</td></tr>" for (a, b) in rows]) * "</table>"
end

"""The Reproduction table: one row per reviewed claim and a full-width details row under it."""
function claims_section(r, root, lib)
    rows = String[]
    for c in r["claims"]
        targets = get(c, "targets", String[])
        commands = join(["<span class=\"cmd\"><code>$(esc(t))</code>" * copy_button(cmd; what = "the command of target $t") * "</span>"
                         for (t, cmd) in zip(targets, c["commands"])])
        files = join(["<a href=\"$(esc(f["url"]))\">$(esc(f["name"]))</a>" for f in c["file_links"]], "<br>")
        push!(rows, """<tr id="$(c["anchor"])" class="claim"><td><a href="#$(c["anchor"])">$(esc(c["label"]))</a></td>
            <td>$(esc(c["summary"]))</td><td>$files</td><td>$commands</td></tr>""")
        api = [haskey(lib, a) ? "<a href=\"$(root)$(lib[a])\"><code>$(esc(a))</code></a>" : "<code>$(esc(a))</code>"
               for a in get(c, "api", String[])]
        params = get(c, "parameters", Dict())
        dl = ["Verification" => get(VERIFICATION_TEXT, c["verification"], esc(c["verification"])),
              "Completeness" => esc(c["completeness"]), "Scope" => esc(c["scope"])]
        isempty(params) || push!(dl, "Parameters" => join(["<code>$(esc(k))=$(esc(v))</code>" for (k, v) in params], ", "))
        haskey(c, "note") && push!(dl, "Note" => esc(c["note"]))
        push!(dl, "Evidence" => isempty(c["evidence"]) ? "No recorded run yet. The command reproduces the result." :
                                join([evidence_table(e, c["id"]) for e in c["evidence"]]))
        isempty(api) || push!(dl, "Library functions" => join(api, ", "))
        push!(rows, """<tr class="claim-details-row"><td colspan="4"><details class="claim-details">
            <summary>Details of $(esc(c["label"]))</summary><dl>""" *
            join(["<dt>$k</dt><dd>$v</dd>" for (k, v) in dl]) * "</dl></details></td></tr>")
    end
    """<div class="table-wrap"><table class="claims"><colgroup><col class="c-result"><col class="c-desc"><col class="c-impl"><col class="c-cmd"></colgroup><thead><tr><th scope="col">Result</th><th scope="col">Description</th>
        <th scope="col">Implementation</th><th scope="col">Command</th></tr></thead><tbody>""" *
        join(rows, "\n") * "</tbody></table></div>"
end


const COPY_ICON = """<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><rect x="5" y="5" width="9" height="9" rx="1" fill="none" stroke="currentColor" stroke-width="1.3"/><path d="M3 11V3a1 1 0 0 1 1-1h7" fill="none" stroke="currentColor" stroke-width="1.3"/></svg>"""

"A copy button for `text`; `what` names it for screen readers."
copy_button(text; what = "the command") =
    "<button type=\"button\" class=\"copy\" data-command=\"$(esc(text))\" title=\"$(esc(text))\" aria-label=\"Copy $(esc(what)): $(esc(text))\">$COPY_ICON</button>"

"A long identifier shown short (12 characters), with a copy button for the full value."
short_hash(h; what = "the full identifier") =
    "<code class=\"hash\" title=\"$(esc(h))\">$(esc(first(h, 12)))…</code>" * copy_button(h; what)

"An integer with thousands separators: 3775599 → \"3,775,599\"."
thousands(n) = replace(string(n), r"(?<=\d)(?=(\d{3})+$)" => ",")

"Breadcrumbs: a list of (label, path from the site root); the last item is the current page."
function breadcrumbs(items, root)
    parts = [i == length(items) ? "<span aria-current=\"page\">$(esc(l))</span>" : "<a href=\"$(root)$(p)\">$(esc(l))</a>"
             for (i, (l, p)) in enumerate(items)]
    "<nav class=\"breadcrumbs\" aria-label=\"Breadcrumb\">" * join(parts, " <span class=\"sep\">/</span> ") * "</nav>"
end

"""
Library anchors from the Documenter build in `out`: VBF name => path of its API entry
(`api/<concept>/#VBF.name...`). Empty when Library is not built.
"""
function library_anchors(out)
    d = Dict{String,String}()
    api = joinpath(out, "api")
    isdir(api) || return d
    for (dir, _, files) in walkdir(api), f in files
        f == "index.html" || continue
        page = relpath(dir, out)
        for m in eachmatch(r"id=\"(VBF\.([A-Za-z_][A-Za-z0-9_!]*)[^\"]*)\"", read(joinpath(dir, f), String))
            get!(d, m[2], page * "/#" * m[1])
        end
    end
    d
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
    item(r, root) = Dict("id" => r["id"], "reference" => reference_html(r["ref"]), "linkline" => linkline(r, root),
        "search" => lowercase(r["ref"]["title"] * " " * join(r["ref"]["authors"], " ") * " " * r["ref"]["year"]))

    latest = sort(repros; by = r -> r["updated"], rev = true)[1:min(3, end)]
    push!(written, write_page(out, "index.html", "Home",
        Mustache.render(template("home"), Dict("root" => "./", "latest" => [item(r, "./") for r in latest])); home = true))

    root = root_prefix("reproductions/index.html")
    years = [(items = [item(r, root) for r in repros if r["year"] == y];
              Dict("year" => y, "items" => items, "n" => length(items), "one" => length(items) == 1))
             for y in unique(r["year"] for r in repros)]
    push!(written, write_page(out, "reproductions/index.html", "Reproductions",
        Mustache.render(template("reproductions"), Dict("root" => root, "count" => length(repros), "years" => years,
            "breadcrumbs" => breadcrumbs([("Home", ""), ("Reproductions", "")], root)));
        nav = "reproductions"))

    lib = library_anchors(out)
    for r in repros
        path = "reproductions/$(r["id"])/index.html"; root = root_prefix(path)
        view = merge(r["ref"], Dict("root" => root, "linkline" => linkline(r, root),
            "breadcrumbs" => breadcrumbs([("Home", ""), ("Reproductions", "reproductions/"), (r["ref"]["title"], "")], root),
            "claims_html" => r["has_claims"] ? claims_section(r, root, lib) : "",
            "has_claims" => r["has_claims"], "other_files" => [merge(f, Dict("copy" => isempty(f["command"]) ? "" :
                copy_button(f["command"]; what = "the command of $(f["name"])"))) for f in r["other_files"]],
            "other_files_any" => !isempty(r["other_files"]),
            "corpora" => [merge(c, Dict("count" => thousands(c["member_count"]))) for c in r["corpora"]],
            "corpora_any" => !isempty(r["corpora"]), "site_text" => site_text(r), "url" => r["url"]))
        push!(written, write_page(out, path, r["ref"]["title"], Mustache.render(template("reproduction"), view);
            nav = "reproductions"))
    end

    # Catalog pages of S3: the corpora and the publications that cite them. S4 adds the query layer.
    corpora = sort(collect(values(model["corpora"])); by = c -> c["name"])
    users(name) = [r for r in repros if any(c -> c["name"] == name, r["corpora"])]
    body =
        "<p><a href=\"functions/\">Curated functions</a>: the named functions of the catalog, with their properties.</p>" *
        "<h2>Corpora</h2><ul>" *
        join(["<li><a href=\"corpora/$(c["name"])/\">$(esc(c["name"]))</a>: $(thousands(c["member_count"])) functions, n = $(c["n"])</li>" for c in corpora]) * "</ul>" *
        "<h2 id=\"snapshots\">Snapshots</h2><p>This site shows the catalog snapshot " *
        short_hash(model["snapshot"].prebuilt_key; what = "the snapshot key") * ". Each snapshot, with its query database, " *
        "is archived on <a href=\"https://doi.org/10.5281/zenodo.24297661\">Zenodo</a>.</p>"
    push!(written, write_page(out, "catalog/index.html", "Catalog",
        Mustache.render(template("page"), Dict("title" => "Catalog", "body" => body)); nav = "catalog"))
    for c in corpora
        path = "catalog/corpora/$(c["name"])/index.html"; root = root_prefix(path)
        pubs = join(["<li><a href=\"$(root)reproductions/$(r["id"])/\">$(reference_html(r["ref"]))</a></li>" for r in users(c["name"])])
        body = "<table class=\"properties\">" *
               "<tr><th scope=\"row\">Functions</th><td>$(thousands(c["member_count"]))</td></tr>" *
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
