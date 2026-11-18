# Catalog pages: the catalog home, one page per corpus (with the dynamic member view), the
# function list, and one page per curated function with alias pages for its names. Bulk
# corpus members get no static page: assets/portal/js/members.js reads them from the query
# database of the snapshot.

yesno(x) = x === missing || x === nothing ? "–" : Bool(x) ? "yes" : "no"
val(x) = x === missing || x === nothing ? "–" : string(x)

"""Curated functions with their properties, keys, signatures and LUT bytes."""
function catalog_functions(db; index_path = sigma_index_path())
    sig = Dict{Int,String}()
    if isfile(index_path)
        idx = SQLite.DB("file:" * index_path * "?mode=ro")
        for r in DBInterface.execute(idx, "SELECT member_idx, sigma_hash FROM ccz_sigma_index WHERE source = 'functions'")
            sig[Int(r.member_idx)] = lowercase(String(r.sigma_hash))
        end
        close(idx)
    end
    [Dict{String,Any}("id" => Int(r.id), "key" => FunctionKey(r.n, r.m, r.lut_sha256), "family" => String(r.family),
        "name" => coalesce(r.canonical_name, ""), "n" => Int(r.n), "m" => Int(r.m),
        "algebraic_degree" => r.algebraic_degree, "differential_uniformity" => r.differential_uniformity,
        "linearity" => r.linearity, "boomerang_uniformity" => r.boomerang_uniformity,
        "is_apn" => r.is_apn, "is_permutation" => r.is_permutation, "is_quadratic" => r.is_quadratic,
        "bib_key" => coalesce(r.bib_key, ""), "form" => coalesce(r.algebraic_form, ""), "notes" => coalesce(r.notes, ""),
        "contributor" => String(r.contributor), "added" => String(r.added_date),
        "sigma" => get(sig, Int(r.id), ""), "source_repo" => String(r.source_repo))
     for r in DBInterface.execute(db, "SELECT * FROM functions ORDER BY n, family, canonical_name")]
end

"""
Facts from the query database for the static pages (empty without it): the corpus members of
each curated key, and the number of corpus members per signature, by corpus.
"""
function query_facts(query_db, fs)
    members = Dict{FunctionKey,Vector{Tuple{String,Int}}}()
    by_sigma = Dict{String,Vector{Tuple{String,Int}}}()
    query_db === nothing && return (; members, by_sigma)
    q = SQLite.DB("file:" * query_db * "?mode=ro")
    lut = DBInterface.prepare(q, "SELECT c.name, m.idx FROM members m JOIN corpora c ON c.id = m.corpus_id WHERE m.lut_sha256 = ?")
    sig = DBInterface.prepare(q, "SELECT c.name, count(*) AS k FROM members m JOIN corpora c ON c.id = m.corpus_id WHERE m.sigma = ? GROUP BY c.name")
    for f in fs
        rows = [(String(r.name), Int(r.idx)) for r in DBInterface.execute(lut, (hex2bytes(f["key"].lut_sha256),))]
        isempty(rows) || (members[f["key"]] = rows)
        s = f["sigma"]
        (isempty(s) || haskey(by_sigma, s)) && continue
        by_sigma[s] = [(String(r.name), Int(r.k)) for r in DBInterface.execute(sig, (hex2bytes(s),))]
    end
    close(q)
    (; members, by_sigma)
end

function_path(k::FunctionKey) = "catalog/functions/$(key_string(k))/index.html"
corpus_path(name) = "catalog/corpora/$(name)/index.html"
fname(f) = isempty(f["name"]) ? display_key(f["key"]) : f["name"]

"Link to a reference: its reproduction page when there is one, else its DOI or URL."
function ref_link(ref, root, repro_of; text = short_cite(ref))
    href = haskey(repro_of, ref["key"]) ? "$(root)reproductions/$(repro_of[ref["key"]]["id"])/" : ref["url"]
    isempty(href) ? esc(text) : "<a href=\"$(esc(href))\">$(esc(text))</a>"
end

"Characterization of a function in one sentence: \"An APN function from F_2^8 to F_2^8 of degree 2.\""
function characterization(f)
    kind = f["is_apn"] == 1 ? "An APN function" : "A function"
    deg = f["algebraic_degree"] === missing ? "" : " of algebraic degree $(f["algebraic_degree"])"
    perm = f["is_permutation"] == 1 ? "; it is a permutation" : ""
    "$kind from \$\\mathbb{F}_2^{$(f["n"])}\$ to \$\\mathbb{F}_2^{$(f["m"])}\$$deg$perm."
end

"Monomial x^u of the ANF in the variables x_0 … x_{n-1} (math indexing)."
monomial(u, n) = u == 0 ? "1" : join(["x$i" for i in 0:n-1 if (u >> i) & 1 == 1], "·")

"The ANF as lines `coefficient  monomial`; the coefficient is the output vector, in hex."
function anf_lines(F::SBox{N}) where {N}
    a = anf(F); w = cld(N, 4)
    ["0x" * string(a[u + 1]; base = 16, pad = w) * "  " * monomial(u, N) for u in 0:(1 << N) - 1 if a[u + 1] != 0]
end

const ANF_LINES_MAX = 300

"""Write the catalog home, the corpus pages, the function list and the function pages."""
function render_catalog_functions(model, out, db; query_db = nothing, versions = Dict{String,Any}[])
    text = catalog_text()
    fs = catalog_functions(db)
    corpora = sort(collect(values(model["corpora"])); by = c -> c["name"])
    gaps = catalog_text_gaps(text, unique(f["family"] for f in fs), [c["name"] for c in corpora])
    isempty(gaps) || error(join(gaps, "\n"))
    facts = query_facts(query_db, fs)
    refs = model["references"]
    repro_of = Dict(x["key"] => r for r in model["reproductions"] for x in r["publications"])
    upstreams = source_upstreams(); decls = corpus_declarations()
    snapshot = model["snapshot"]
    title(c) = text["corpora"][c]["title"]
    written = String[]
    page(path, t, body; crumbs) = push!(written, write_page(out, path, t,
        breadcrumbs(crumbs, root_prefix(path)) * Mustache.render(template("page"), Dict("title" => t, "body" => body)); nav = "catalog"))

    # Catalog home -------------------------------------------------------------------------
    root = root_prefix("catalog/index.html")
    total = sum(c["member_count"] for c in corpora)
    ns = sort(unique(f["n"] for f in fs))
    crows = join(["<tr><td><a href=\"corpora/$(c["name"])/\">$(esc(title(c["name"])))</a></td>" *
                  "<td>$(haskey(refs, c["bib_key"]) ? ref_link(refs[c["bib_key"]], root, repro_of) : "–")</td>" *
                  "<td>$(c["n"])</td><td class=\"num\">$(thousands(c["member_count"]))</td></tr>" for c in corpora])
    current = findfirst(v -> v["key"] == snapshot.prebuilt_key, versions)
    vrows = join(["<tr><td><a href=\"https://doi.org/$(v["doi"])\">$(esc(v["date"]))</a>$(i == current ? " (this site)" : "")</td>" *
                  "<td>$(isempty(v["key"]) ? "–" : short_hash(v["key"]; what = "the snapshot key"))</td>" *
                  "<td>$(v["query"] ? "yes" : "no")</td></tr>" for (i, v) in enumerate(versions)])
    body = """
        <p>The catalog holds vectorial Boolean functions from the literature and from published datasets:
        $(thousands(length(fs))) curated functions with their properties, and $(thousands(total)) functions in
        $(length(corpora)) corpora. A function is identified by its content key: \$n\$, \$m\$ and the SHA-256 of its lookup table.</p>
        <form class="search-main" action="functions/" method="get" role="search">
        <label>Find a function <input name="q" type="search" placeholder="Name or key, for example Gold" size="28"></label>
        <label>\$n\$ <select name="n"><option value="">any</option>$(join(["<option>$n</option>" for n in ns]))</select></label>
        <label>APN <select name="is_apn"><option value="">any</option><option value="1">yes</option><option value="0">no</option></select></label>
        <button type="submit">Search</button>
        </form>
        <p><a href="functions/">All $(thousands(length(fs))) curated functions</a></p>
        <h2 id="corpora">Corpora</h2>
        <p>A corpus is a published list of functions, kept in its original order. Each corpus page shows the members.</p>
        <div class="table-wrap"><table class="corpora"><thead><tr><th scope="col">Corpus</th><th scope="col">Publication</th>
        <th scope="col">\$n\$</th><th scope="col" class="num">Functions</th></tr></thead><tbody>$crows</tbody></table></div>
        <h2 id="snapshots">Versions</h2>
        <p>Each catalog snapshot is archived on Zenodo with its query database.
        <a href="https://doi.org/10.5281/zenodo.$(ZENODO_CONCEPT)">All versions</a> (concept DOI 10.5281/zenodo.$(ZENODO_CONCEPT)).
        A historical version holds the member order of its date.</p>
        $(isempty(versions) ? "" : "<div class=\"table-wrap\"><table class=\"versions\"><thead><tr><th scope=\"col\">Version</th><th scope=\"col\">Snapshot key</th><th scope=\"col\">Query database</th></tr></thead><tbody>$vrows</tbody></table></div>")
        <details class="technical"><summary>Technical identifiers of this snapshot</summary>
        <table class="properties">
        <tr><th scope="row">Snapshot key</th><td><code>$(snapshot.prebuilt_key)</code> $(copy_button(snapshot.prebuilt_key; what = "the snapshot key"))</td></tr>
        <tr><th scope="row">Inputs SHA-256</th><td><code>$(esc(snapshot.inputs_sha256))</code></td></tr>
        <tr><th scope="row">Implementation SHA-256</th><td><code>$(esc(snapshot.implementation_sha256))</code></td></tr>
        <tr><th scope="row">Machine-readable list</th><td><a href="snapshots.json">snapshots.json</a></td></tr>
        </table></details>
        """
    page("catalog/index.html", "Catalog", body; crumbs = [("Home", ""), ("Catalog", "")])
    write(joinpath(out, "catalog", "snapshots.json"), JSON.json(Dict("current" => snapshot.prebuilt_key,
        "concept_doi" => "10.5281/zenodo.$(ZENODO_CONCEPT)", "versions" => versions), 2))

    # Corpus pages -------------------------------------------------------------------------
    users(name) = [r for r in model["reproductions"] if any(c -> c["name"] == name, r["corpora"])]
    for c in corpora
        path = corpus_path(c["name"]); root = root_prefix(path)
        ref = get(refs, c["bib_key"], nothing)
        pub = ref === nothing ? "<p>The catalog names no publication for this corpus.</p>" :
            "<p>$(reference_html(ref))</p>" * (isempty(ref["doi_url"]) ? "" : "<p class=\"links\"><a href=\"$(esc(ref["doi_url"]))\">$(esc(ref["doi"]))</a></p>")
        rs = users(c["name"])
        repro = isempty(rs) ? "" : "<p>Reproduced in: " * join(["<a href=\"$(root)reproductions/$(r["id"])/\">$(esc(short_cite(r["ref"])))</a>" for r in rs], ", ") * ".</p>"
        tech = [("Corpus name", "<code>$(esc(c["name"]))</code> " * copy_button(c["name"]; what = "the corpus name")),
                ("Corpus digest", short_hash(c["digest"]; what = "the corpus digest")),
                ("Catalog snapshot", short_hash(snapshot.prebuilt_key; what = "the snapshot key")),
                ("Source string", "<code>$(esc(c["source_repo"]))</code>"),
                ("Member link", "<code>?digest=&lt;corpus digest&gt;&amp;idx=&lt;index&gt;</code>")]
        body = """
            <p class="lead">$(esc(text["corpora"][c["name"]]["summary"]))</p>
            <p>$(thousands(c["member_count"])) functions, \$n = $(c["n"])\$, \$m = $(c["m"])\$.</p>
            <h2>Publication</h2>$pub$repro
            <h2>Source</h2><p>$(corpus_source_html(c, get(decls, c["name"], Dict()), upstreams))</p>
            $(member_view(c, root, snapshot.prebuilt_key))
            <h2>Technical identifiers</h2>
            <table class="properties technical">$(join(["<tr><th scope=\"row\">$a</th><td>$b</td></tr>" for (a, b) in tech]))</table>
            <p class="note">A member index has a meaning only for one corpus digest. A permanent reference names both.</p>
            """
        page(path, title(c["name"]), body; crumbs = [("Home", ""), ("Catalog", "catalog/"), (title(c["name"]), "")])
    end

    # Function pages -----------------------------------------------------------------------
    by_sig = Dict{String,Vector{Any}}()
    foreach(f -> isempty(f["sigma"]) || push!(get!(by_sig, f["sigma"], []), f), fs)
    for f in fs
        k = f["key"]; path = function_path(k); root = root_prefix(path)
        F = load_sbox(db, f["id"])
        ref = get(refs, f["bib_key"], nothing)
        props = [("Differential uniformity", val(f["differential_uniformity"])), ("APN", yesno(f["is_apn"])),
                 ("Algebraic degree", val(f["algebraic_degree"])), ("Linearity", val(f["linearity"])),
                 ("Boomerang uniformity", val(f["boomerang_uniformity"])), ("Permutation", yesno(f["is_permutation"])),
                 ("Quadratic", yesno(f["is_quadratic"]))]
        lut = string.(Int.(F.lut))
        lutlines = join([join(lut[i:min(i + 15, end)], ", ") for i in 1:16:length(lut)], ",\n")
        anfl = anf_lines(F)
        anf_html = length(anfl) > ANF_LINES_MAX ?
            "<p>The ANF has $(thousands(length(anfl))) monomials. Compute it in Julia with <code>anf(F)</code>.</p>" :
            "<details><summary>Algebraic normal form ($(length(anfl)) monomials)</summary><pre>$(join(anfl, "\n"))</pre></details>"
        prov = Tuple{String,String}[]
        ref === nothing || push!(prov, ("Publication", reference_html(ref) * (haskey(repro_of, ref["key"]) ?
            " <a href=\"$(root)reproductions/$(repro_of[ref["key"]]["id"])/\">Reproduction</a>" :
            isempty(ref["url"]) ? "" : " <a href=\"$(esc(ref["url"]))\">Paper</a>")))
        push!(prov, ("Source", source_html(f["source_repo"], upstreams)))
        isempty(f["notes"]) || push!(prov, ("Notes", esc(f["notes"])))
        push!(prov, ("Added by", esc(f["contributor"]) * (isempty(f["added"]) ? "" : ", " * esc(f["added"]))))
        mem = get(facts.members, k, Tuple{String,Int}[])
        corp = query_db === nothing ? "<p>Corpus memberships need the query database at build time.</p>" :
            isempty(mem) ? "<p>This lookup table is in no corpus of the catalog.</p>" :
            "<ul>" * join(["<li><a href=\"$(root)catalog/corpora/$c/\">$(esc(title(c)))</a>, " *
                "<a href=\"$(root)catalog/corpora/$c/?digest=$(model["corpora"][c]["digest"])&amp;idx=$i\">member $(thousands(i))</a></li>"
                for (c, i) in mem]) * "</ul>"
        eq = if isempty(f["sigma"])
            "<p>This function has no signature in the index. The catalog records no equivalence relation for it.</p>"
        else
            same = [g for g in by_sig[f["sigma"]] if g["key"] != k]
            inc = get(facts.by_sigma, f["sigma"], Tuple{String,Int}[])
            """<p>Signature (a CCZ invariant): $(short_hash(f["sigma"]; what = "the signature")).</p>
            <ul>
            <li>Curated functions with the same signature: $(isempty(same) ? "none" :
                join(["<a href=\"$(root)catalog/functions/$(key_string(g["key"]))/\">$(esc(fname(g)))</a>" for g in same[1:min(end, 10)]], ", ") *
                (length(same) > 10 ? " and $(length(same) - 10) more" : "")).</li>
            <li>Corpus members with the same signature: $(query_db === nothing ? "not computed" : isempty(inc) ? "none" :
                join(["$(thousands(n)) in <a href=\"$(root)catalog/corpora/$c/?sigma=$(f["sigma"])\">$(esc(title(c)))</a>" for (c, n) in inc], ", ")).</li>
            </ul>
            <p class="note">An equal signature is an invariant match: it does not prove equivalence. For quadratic APN
            functions, a different signature proves CCZ-inequivalence. The catalog holds no verified equivalence certificate for this function.</p>"""
        end
        cmd = """using VBF, VBFCatalog
            db = load_catalog()
            h = "$(k.lut_sha256)"   # LUT SHA-256
            F = load_sbox(db, find_function(db; lut_sha256 = h).id)
            differential_uniformity(F), algebraic_degree(F)"""
        tech = [("Function key", "<code>$(key_string(k))</code> " * copy_button(key_string(k); what = "the function key")),
                ("LUT SHA-256", "<code>$(k.lut_sha256)</code>"),
                ("Signature", isempty(f["sigma"]) ? "–" : "<code>$(f["sigma"])</code>"),
                ("Catalog row", "$(f["id"]) (changes between snapshots; do not use it as a reference)")]
        names = isempty(f["name"]) ? "" : "<p class=\"note\">Name in the catalog: <code>$(esc(f["name"]))</code>. Link by name: " *
            "<a href=\"$(root)catalog/names/$(f["name"])/\">catalog/names/$(esc(f["name"]))/</a>.</p>"
        body = """
            <p class="lead">$(characterization(f))</p>
            <p>Family: <a href="$(root)catalog/functions/?family=$(esc(f["family"]))">$(esc(text["families"][f["family"]]))</a>.
            $(isempty(f["form"]) ? "" : "Definition: $(esc(f["form"])).")</p>
            $names
            <h2>Properties</h2>
            <table class="properties">$(join(["<tr><th scope=\"row\">$a</th><td>$b</td></tr>" for (a, b) in
                vcat([("Dimensions", "\$n = $(f["n"])\$, \$m = $(f["m"])\$")], props)]))</table>
            <h2>Representations</h2>
            <details><summary>Lookup table ($(thousands(length(lut))) values, input order)</summary>
            <p>$(copy_button("[" * join(lut, ", ") * "]"; what = "the lookup table")) Copy as a Julia vector.</p>
            <pre>$lutlines</pre></details>
            $anf_html
            <p class="note">The ANF lists each monomial with its coefficient, the output vector in hex (bit \$i\$ is coordinate \$i\$).</p>
            <h2>Provenance</h2>
            <table class="properties">$(join(["<tr><th scope=\"row\">$a</th><td>$b</td></tr>" for (a, b) in prov]))</table>
            <h2>Corpora</h2>$corp
            <p class="note">Membership means the same lookup table. EA or CCZ equivalence is a separate relation.</p>
            <h2>Equivalence relations</h2>$eq
            <h2>Local commands</h2>
            <p>Load the function by its content key in Julia: $(copy_button(cmd; what = "the Julia commands"))</p>
            <pre>$(esc(cmd))</pre>
            <h2>Technical identifiers</h2>
            <table class="properties technical">$(join(["<tr><th scope=\"row\">$a</th><td>$b</td></tr>" for (a, b) in tech]))</table>
            """
        page(path, fname(f), body; crumbs = [("Home", ""), ("Catalog", "catalog/"), ("Functions", "catalog/functions/"), (fname(f), "")])
        if !isempty(f["name"])
            npath = "catalog/names/$(f["name"])/index.html"
            mkpath(dirname(joinpath(out, npath)))
            write(joinpath(out, npath), Mustache.render(template("redirect"),
                Dict("target" => root_prefix(npath) * "catalog/functions/$(key_string(k))/")))
            push!(written, joinpath(out, npath))
        end
    end

    # Function list: a static table (it works without JavaScript); portal.js filters, sorts and
    # pages it, and keeps the state in the URL.
    path = "catalog/functions/index.html"; root = root_prefix(path)
    cols = [("name", "Name"), ("n", "\$n\$"), ("m", "\$m\$"), ("is_apn", "APN"), ("algebraic_degree", "Degree"),
            ("differential_uniformity", "Diff. unif."), ("linearity", "Linearity"), ("ref", "Reference")]
    head = "<tr>" * join(["<th scope=\"col\" data-col=\"$c\"><button type=\"button\" class=\"sort\">$l</button></th>" for (c, l) in cols]) * "</tr>"
    sortval(x) = x === missing ? "" : string(x)
    trs = join([begin
        ref = get(refs, f["bib_key"], nothing)
        cite = ref === nothing ? "" : short_cite(ref)
        string("<tr data-q=\"$(esc(lowercase(f["name"] * " " * key_string(f["key"]))))\" data-n=\"$(f["n"])\" data-m=\"$(f["m"])\" ",
            "data-family=\"$(esc(f["family"]))\" data-is_apn=\"$(sortval(f["is_apn"]))\" data-is_permutation=\"$(sortval(f["is_permutation"]))\" ",
            "data-algebraic_degree=\"$(sortval(f["algebraic_degree"]))\" data-differential_uniformity=\"$(sortval(f["differential_uniformity"]))\" ",
            "data-linearity=\"$(sortval(f["linearity"]))\" data-bib_key=\"$(esc(f["bib_key"]))\" data-name=\"$(esc(lowercase(fname(f))))\" data-ref=\"$(esc(cite))\">",
            "<td data-label=\"Name\"><a href=\"$(key_string(f["key"]))/\">$(esc(fname(f)))</a></td>",
            "<td data-label=\"n\">$(f["n"])</td><td data-label=\"m\">$(f["m"])</td><td data-label=\"APN\">$(yesno(f["is_apn"]))</td>",
            "<td data-label=\"Degree\">$(val(f["algebraic_degree"]))</td><td data-label=\"Diff. unif.\">$(val(f["differential_uniformity"]))</td>",
            "<td data-label=\"Linearity\">$(val(f["linearity"]))</td>",
            "<td data-label=\"Reference\">$(ref === nothing ? "–" : ref_link(ref, root, repro_of))</td></tr>")
    end for f in fs])
    opts(xs) = join(["<option value=\"$(esc(v))\">$(esc(l))</option>" for (v, l) in xs])
    bibs = sort(unique([(f["bib_key"], short_cite(refs[f["bib_key"]])) for f in fs if haskey(refs, f["bib_key"])]); by = last)
    num(field) = [(string(x), string(x)) for x in sort(unique(f[field] for f in fs if f[field] !== missing))]
    form = """
        <form class="filters" id="function-filters" role="search" aria-label="Filters">
        <label>Name or key <input name="q" type="search" size="18"></label>
        <label>\$n\$ <select name="n"><option value="">any</option>$(opts(num("n")))</select></label>
        <label>\$m\$ <select name="m"><option value="">any</option>$(opts(num("m")))</select></label>
        <label>Family <select name="family"><option value="">any</option>$(opts(sort([(x, text["families"][x]) for x in unique(f["family"] for f in fs)]; by = last)))</select></label>
        <label>APN <select name="is_apn"><option value="">any</option><option value="1">yes</option><option value="0">no</option></select></label>
        <label>Permutation <select name="is_permutation"><option value="">any</option><option value="1">yes</option><option value="0">no</option></select></label>
        <label>Degree <select name="algebraic_degree"><option value="">any</option>$(opts(num("algebraic_degree")))</select></label>
        <label>Diff. unif. <select name="differential_uniformity"><option value="">any</option>$(opts(num("differential_uniformity")))</select></label>
        <label>Reference <select name="bib_key"><option value="">any</option>$(opts(bibs))</select></label>
        <button type="reset" class="reset">Clear</button>
        </form>
        <p id="function-count" aria-live="polite">$(thousands(length(fs))) functions</p>
        """
    body = """
        <p>The curated functions of the catalog: named functions from the literature, known families and class
        representatives. The <a href="../#corpora">corpora</a> hold the other functions. Select a column title to sort.</p>
        $form<div class="table-wrap"><table class="functions" id="function-table"><thead>$head</thead><tbody>$trs</tbody></table></div>
        <nav class="pager" id="function-pager" aria-label="Pages"></nav>
        """
    page(path, "Functions", body; crumbs = [("Home", ""), ("Catalog", "catalog/"), ("Functions", "")])
    written
end

"""The member view of a corpus page: search, list and member detail, read by members.js."""
member_view(c, root, key) = """
    <h2 id="members">Members</h2>
    <section id="member-view" data-db="$(root)catalog/data/$(key)/query.sqlite" data-corpus="$(esc(c["name"]))"
             data-digest="$(esc(c["digest"]))" data-root="$(root)" data-count="$(c["member_count"])">
    <form class="filters" role="search">
    <label>Search by <select name="by"><option value="idx">index</option><option value="key">function key or LUT SHA-256</option>
      <option value="sigma">signature</option></select></label>
    <label>Value <input name="value" size="24" required></label>
    <button type="submit">Show</button>
    </form>
    <div class="member-result" aria-live="polite"><p>The member list needs JavaScript.</p></div>
    <noscript>In Julia: <code>corpus_function(load_catalog(), "$(esc(c["name"]))", i)</code>.</noscript>
    </section>
    <script type="module" src="$(root)assets/portal/js/members.js"></script>
    """
