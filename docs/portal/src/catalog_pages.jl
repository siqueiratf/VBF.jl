# Static catalog pages: one page per curated function, alias pages for names, the corpus
# pages and the function list. Bulk corpus members get no static page (see members view).

"Display form of a hex digest: first 12 digits, full value in the title attribute."
short_hex(h) = "<code title=\"$(esc(h))\">$(esc(first(h, 12)))…</code>"

yesno(x) = x === missing || x === nothing ? "–" : Bool(x) ? "yes" : "no"
val(x) = x === missing || x === nothing ? "–" : string(x)

"""Curated functions with their properties, keys and signatures."""
function catalog_functions(db; index_path = sigma_index_path())
    sig = Dict{Int,String}()
    if isfile(index_path)
        idx = SQLite.DB("file:" * index_path * "?mode=ro")
        for r in DBInterface.execute(idx, "SELECT member_idx, sigma_hash FROM ccz_sigma_index WHERE source = 'functions'")
            sig[Int(r.member_idx)] = String(r.sigma_hash)
        end
        close(idx)
    end
    [Dict{String,Any}("id" => Int(r.id), "key" => FunctionKey(r.n, r.m, r.lut_sha256), "family" => String(r.family),
        "name" => coalesce(r.canonical_name, ""), "n" => Int(r.n), "m" => Int(r.m),
        "algebraic_degree" => r.algebraic_degree, "differential_uniformity" => r.differential_uniformity,
        "linearity" => r.linearity, "boomerang_uniformity" => r.boomerang_uniformity,
        "is_apn" => r.is_apn, "is_permutation" => r.is_permutation, "is_quadratic" => r.is_quadratic,
        "bib_key" => coalesce(r.bib_key, ""), "lut" => bytes2hex(Vector{UInt8}(r.lut_blob)),
        "sigma" => get(sig, Int(r.id), ""), "source_repo" => String(r.source_repo))
     for r in DBInterface.execute(db, "SELECT * FROM functions ORDER BY n, family, canonical_name")]
end

"""Corpus memberships of each curated key, from the query database (empty without it)."""
function memberships(query_db, keys)
    out = Dict{FunctionKey,Vector{Tuple{String,Int}}}()
    query_db === nothing && return out
    q = SQLite.DB("file:" * query_db * "?mode=ro")
    stmt = DBInterface.prepare(q, "SELECT c.name, m.idx FROM members m JOIN corpora c ON c.id = m.corpus_id WHERE m.lut_sha256 = ?")
    for k in keys
        rows = [(String(r.name), Int(r.idx)) for r in DBInterface.execute(stmt, (hex2bytes(k.lut_sha256),))]
        isempty(rows) || (out[k] = rows)
    end
    close(q)
    out
end

function_path(k::FunctionKey) = "catalog/functions/$(key_string(k))/index.html"

"""Write the function pages, the name pages and the function list. Returns the paths."""
function render_catalog_functions(model, out, db; query_db = nothing)
    fs = catalog_functions(db)
    members = memberships(query_db, [f["key"] for f in fs])
    refs = model["references"]
    repro_of = Dict(x["key"] => r for r in model["reproductions"] for x in r["publications"])
    written = String[]
    for f in fs
        k = f["key"]; path = function_path(k); root = root_prefix(path)
        ref = get(refs, f["bib_key"], nothing)
        origin = ref === nothing ? (isempty(f["source_repo"]) ? "–" : esc(f["source_repo"])) :
            (haskey(repro_of, f["bib_key"]) ?
                "<a href=\"$(root)reproductions/$(repro_of[f["bib_key"]]["id"])/\">$(reference_html(ref))</a>" :
                reference_html(ref))
        rows = [("Key", "<code>$(esc(key_string(k)))</code>"), ("Name", esc(f["name"])), ("Family", esc(f["family"])),
            ("Dimensions", "n = $(f["n"]), m = $(f["m"])"), ("APN", yesno(f["is_apn"])),
            ("Differential uniformity", val(f["differential_uniformity"])), ("Algebraic degree", val(f["algebraic_degree"])),
            ("Linearity", val(f["linearity"])), ("Boomerang uniformity", val(f["boomerang_uniformity"])),
            ("Permutation", yesno(f["is_permutation"])), ("Quadratic", yesno(f["is_quadratic"]))]
        isempty(f["sigma"]) || push!(rows, ("Signature", short_hex(f["sigma"])))
        box = "<table class=\"properties\">" * join(["<tr><th scope=\"row\">$a</th><td>$b</td></tr>" for (a, b) in rows]) * "</table>"
        mem = get(members, k, Tuple{String,Int}[])
        corp = query_db === nothing ? "<p>Corpus memberships are computed when the build has the query database.</p>" :
            isempty(mem) ? "<p>This concrete function is in no bulk corpus of the catalog.</p>" :
            "<ul>" * join(["<li><a href=\"$(root)catalog/corpora/$c/\">$c</a>, member $i</li>" for (c, i) in mem]) * "</ul>"
        lutline = join([f["lut"][i:min(i + 63, end)] for i in 1:64:length(f["lut"])], "\n")
        body = """
            $box
            <h2>Source</h2><p>$origin</p>
            <h2>Corpora</h2>$corp
            <p class="note">Corpus membership means the same concrete LUT. EA or CCZ equivalence is a separate relation and is not shown as identity.</p>
            <h2>Lookup table</h2>
            <details><summary>LUT ($(2^f["n"]) entries, canonical bytes, hex)</summary><pre>$(lutline)</pre></details>
            <h2>Local analysis</h2>
            <p>Load it in Julia, then test equivalence with another function:</p>
            <pre>using VBF, VBFCatalog
            db = load_catalog(); F = load_sbox(db, $(f["id"]))
            are_ccz_equivalent(F, G)   # G: the function to compare</pre>
            """
        push!(written, write_page(out, path, isempty(f["name"]) ? display_key(k) : f["name"],
            Mustache.render(template("page"), Dict("title" => isempty(f["name"]) ? display_key(k) : f["name"], "body" => body));
            nav = "catalog"))
        if !isempty(f["name"])
            npath = "catalog/names/$(f["name"])/index.html"
            mkpath(dirname(joinpath(out, npath)))
            write(joinpath(out, npath), Mustache.render(template("redirect"),
                Dict("target" => root_prefix(npath) * "catalog/functions/$(key_string(k))/")))
            push!(written, joinpath(out, npath))
        end
    end
    # Function list: a static table (works without JavaScript); the script filters it and keeps
    # the filters in the URL.
    path = "catalog/functions/index.html"; root = root_prefix(path)
    head = "<tr><th scope=\"col\">Name</th><th scope=\"col\">n</th><th scope=\"col\">m</th><th scope=\"col\">Family</th><th scope=\"col\">APN</th><th scope=\"col\">Degree</th><th scope=\"col\">Linearity</th><th scope=\"col\">Reference</th></tr>"
    trs = join([string("<tr data-n=\"$(f["n"])\" data-m=\"$(f["m"])\" data-family=\"$(esc(f["family"]))\" data-is_apn=\"$(val(f["is_apn"]))\" data-algebraic_degree=\"$(val(f["algebraic_degree"]))\" data-bib_key=\"$(esc(f["bib_key"]))\">",
        "<td><a href=\"$(key_string(f["key"]))/\">$(esc(isempty(f["name"]) ? display_key(f["key"]) : f["name"]))</a></td>",
        "<td>$(f["n"])</td><td>$(f["m"])</td><td>$(esc(f["family"]))</td><td>$(yesno(f["is_apn"]))</td>",
        "<td>$(val(f["algebraic_degree"]))</td><td>$(val(f["linearity"]))</td><td>$(esc(f["bib_key"]))</td></tr>") for f in fs])
    families = sort(unique(f["family"] for f in fs))
    form = """
        <form class="filters" id="function-filters" aria-label="Filters">
        <label>n <select name="n"><option value="">any</option>$(join(["<option>$n</option>" for n in sort(unique(f["n"] for f in fs))]))</select></label>
        <label>Family <select name="family"><option value="">any</option>$(join(["<option>$(esc(x))</option>" for x in families]))</select></label>
        <label>APN <select name="is_apn"><option value="">any</option><option value="1">yes</option><option value="0">no</option></select></label>
        <label>Degree <select name="algebraic_degree"><option value="">any</option>$(join(["<option>$d</option>" for d in sort(unique(val(f["algebraic_degree"]) for f in fs))]))</select></label>
        <label>Reference <input name="bib_key" size="16"></label>
        </form>
        <p id="function-count" aria-live="polite">$(length(fs)) functions</p>
        """
    body = form * "<div class=\"table-wrap\"><table class=\"functions\" id=\"function-table\"><thead>$head</thead><tbody>$trs</tbody></table></div>"
    push!(written, write_page(out, path, "Functions",
        Mustache.render(template("page"), Dict("title" => "Functions", "body" => body)); nav = "catalog"))
    written
end
