# Readable text and links of the catalog pages.
#
#   catalog.toml   site names of the families and the corpora (presentation text only)
#   sources.toml   the source declarations of VBFCatalog: upstream repositories, revisions and
#                  files, which turn a source string such as "sboxu@7066b82..." into a link
#   Zenodo         the versions of the prebuilt catalog data, one per catalog snapshot

const CATALOG_TEXT = joinpath(@__DIR__, "..", "catalog.toml")
const SOURCES_TOML = joinpath(ROOT, "packages", "VBFCatalog", "src", "data", "sources.toml")
const ZENODO_CONCEPT = "24297661"
const ZENODO_API = "https://zenodo.org/api/records"

"Site text of the catalog: `families` (family => label) and `corpora` (name => title, summary)."
catalog_text(path = CATALOG_TEXT) = TOML.parsefile(path)

"Missing entries of the site text: catalog families and corpora that `catalog.toml` does not name."
function catalog_text_gaps(text, families, corpora)
    vcat(["catalog.toml: no label for family $f" for f in families if !haskey(text["families"], f)],
         ["catalog.toml: no title for corpus $c" for c in corpora if !haskey(text["corpora"], c)])
end

"Upstream repositories by source name (lower case): name => (url, revision, path in the repository)."
function source_upstreams(path = SOURCES_TOML)
    d = Dict{String,NamedTuple{(:url, :revision, :dir),Tuple{String,String,String}}}()
    for s in get(TOML.parsefile(path), "source", [])
        haskey(s, "upstream") || continue
        url = replace(s["upstream"], r"\.git$" => "")
        # check_path starts with the cache folder ("sboxU/scripts/apnDB"); drop it.
        dir = join(split(get(s, "check_path", ""), '/')[2:end], '/')
        v = (url = url, revision = get(s, "revision", ""), dir = s["check_kind"] == "dir" ? dir : "")
        d[lowercase(s["name"])] = v
        d[lowercase(s["cache_name"])] = v
    end
    d
end

"Corpus declarations of sources.toml by corpus name (file, source, original SHA-256)."
corpus_declarations(path = SOURCES_TOML) =
    Dict(c["name"] => c for c in get(TOML.parsefile(path), "corpus", []))

"Owner and name of a repository URL: \"lpp-crypto/sboxU\"."
repo_name(url) = join(split(url, '/')[end-1:end], '/')

"""
    source_html(s, upstreams) -> String

Readable HTML of a catalog source string. The string is a `|`-list; each part is one of
`name@revision` (a declared upstream repository), `zenodo:<record>#sha256=...`, a URL, or text.
The link names the place, never the raw string.
"""
function source_html(s::AbstractString, upstreams)
    parts = String[]
    for p in strip.(split(s, '|'))
        isempty(p) && continue
        if (m = match(r"^zenodo:(\d+)", p)) !== nothing
            push!(parts, "<a href=\"https://doi.org/10.5281/zenodo.$(m[1])\">Zenodo record $(m[1])</a>")
        elseif (m = match(r"^(https?://([^/#]+)[^#]*)(#.*)?$", p)) !== nothing
            file = basename(m[1]); occursin(r"^\d*$", file) && (file = "")
            page = match(r"page=(\d+)", something(m[3], ""))
            text = m[2] * (isempty(file) || file == m[2] ? "" : ", $file") * (page === nothing ? "" : ", page $(page[1])")
            push!(parts, "<a href=\"$(esc(p))\">$(esc(text))</a>")
        elseif (m = match(r"^([A-Za-z0-9_]+)(?:@([0-9a-f]{7,40}))?$", p)) !== nothing && haskey(upstreams, lowercase(m[1]))
            u = upstreams[lowercase(m[1])]
            rev = something(m[2], u.revision)
            name = repo_name(u.url)
            push!(parts, "<a href=\"$(u.url)/tree/$(rev)\">$(esc(name))</a> (commit <code>$(first(rev, 7))</code>)")
        elseif p in ("VBF declarations", "VBF")
            push!(parts, "<a href=\"$(REPO_URL)/tree/main/packages/VBFCatalog/src/data\">VBF.jl declarations</a>")
        else
            push!(parts, esc(p))
        end
    end
    isempty(parts) ? "–" : join(parts, "; ")
end

"""
Readable HTML of the source of a corpus: the original file in its upstream repository, or
the catalog's source string. `decl` is the corpus declaration of sources.toml.
"""
function corpus_source_html(c, decl, upstreams)
    src = get(decl, "source", "")
    file = get(decl, "file", "")
    u = get(upstreams, lowercase(src), nothing)
    if !isempty(c["source_repo"]) && !occursin('@', c["source_repo"])
        return source_html(c["source_repo"], upstreams)          # a download, Zenodo record or URL
    elseif u !== nothing && !isempty(file) && !startswith(file, "luts/")
        path = isempty(u.dir) ? file : "$(u.dir)/$file"
        return "<a href=\"$(u.url)/blob/$(u.revision)/$(path)\"><code>$(esc(file))</code></a> in " *
               "<a href=\"$(u.url)/tree/$(u.revision)\">$(esc(repo_name(u.url)))</a> (commit <code>$(first(u.revision, 7))</code>)"
    end
    source_html(c["source_repo"], upstreams)
end

"""
    zenodo_versions(; concept, timeout) -> Vector{Dict}

The published versions of the prebuilt catalog data, newest first: version, date, DOI and
full prebuilt key (from each version's manifest.toml). Returns an empty list when Zenodo is
not reachable; the page then links to the concept record only.
"""
function zenodo_versions(; concept = ZENODO_CONCEPT, timeout = 30)
    get_text(url) = (io = IOBuffer(); run(pipeline(`curl -sS --fail --location --max-time $timeout $url`; stdout = io)); String(take!(io)))
    out = Dict{String,Any}[]
    try
        hits = []
        for page in Iterators.countfrom(1)            # 25 hits per page without a token
            reply = JSON.parse(get_text("$ZENODO_API?q=conceptrecid:$concept&all_versions=true&sort=mostrecent&size=25&page=$page"))
            append!(hits, reply["hits"]["hits"])
            (isempty(reply["hits"]["hits"]) || length(hits) >= reply["hits"]["total"]) && break
        end
        for hit in hits
            files = Dict(f["key"] => f["links"]["self"] for f in hit["files"])
            key = haskey(files, "manifest.toml") ? get(TOML.parse(get_text(files["manifest.toml"])), "key", "") : ""
            push!(out, Dict{String,Any}("version" => hit["metadata"]["version"], "date" => hit["metadata"]["publication_date"],
                "doi" => hit["doi"], "key" => key, "query" => haskey(files, "query.sqlite")))
        end
    catch e
        @warn "Zenodo versions are not available; the catalog page links to the concept record only" exception = e
        empty!(out)
    end
    out
end

"""Short citation of a reference: "Edel and Pott (2009)", "Beierle et al. (2025)"."""
function short_cite(ref)
    names = ref["lastnames"]
    who = isempty(names) ? ref["title"] : length(names) == 1 ? names[1] :
          length(names) == 2 ? "$(names[1]) and $(names[2])" : "$(names[1]) et al."
    "$who ($(ref["year"]))"
end
