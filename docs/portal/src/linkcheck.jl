# Static check of a built site: every relative link and asset must resolve to a file, and
# every #anchor must be an id in the target page. External links are not fetched.

const LINK_RE = r"\b(?:href|src)=\"([^\"]*)\""
const ID_RE = r"\bid=\"([^\"]+)\""

"Decode the HTML character references that may appear in an attribute, as a browser does."
function unescape_html(s)
    s = replace(s, r"&#x([0-9a-fA-F]+);" => m -> string(Char(parse(Int, m[4:end-1]; base = 16))))
    s = replace(s, r"&#([0-9]+);" => m -> string(Char(parse(Int, m[3:end-1]))))
    replace(s, "&quot;" => "\"", "&lt;" => "<", "&gt;" => ">", "&amp;" => "&")
end

"""
    check_links(site) -> Vector{String}

Problems found in the HTML files under `site`. A link may not start with `/`: an absolute path
breaks under a base path such as `/VBF.jl/`.
"""
function check_links(site)
    site = abspath(site)
    ids = Dict{String,Set{String}}()
    idset(f) = get!(() -> Set(unescape_html(m[1]) for m in eachmatch(ID_RE, read(f, String))), ids, f)
    problems = String[]
    for (d, _, files) in walkdir(site), f in files
        endswith(f, ".html") || continue
        page = joinpath(d, f)
        for m in eachmatch(LINK_RE, read(page, String))
            link = unescape_html(m[1])
            (isempty(link) || occursin(r"^(https?:|mailto:|data:|javascript:)", link)) && continue
            # Documenter loads these only on a multi-version deployment; they are optional.
            occursin(r"(^|/)(siteinfo|versions)\.js$", link) && continue
            where = relpath(page, site)
            startswith(link, "/") && (push!(problems, "$where: absolute link $link"); continue)
            path, anchor = occursin('#', link) ? split(link, '#'; limit = 2) : (link, "")
            path = split(path, '?')[1]
            target = isempty(path) ? page : normpath(joinpath(d, path))
            startswith(target, site) || (push!(problems, "$where: $link leaves the site"); continue)
            isdir(target) && (target = joinpath(target, "index.html"))
            if !isfile(target)
                push!(problems, "$where: missing $link")
            elseif !isempty(anchor) && endswith(target, ".html") && !(anchor in idset(target))
                push!(problems, "$where: no anchor #$anchor in $(relpath(target, site))")
            end
        end
    end
    problems
end
