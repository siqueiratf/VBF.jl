# The site model: one structure built from the sources of truth, which the templates read.
#
#   references    bibliography.bib (title, authors, venue, year, DOI, URL, raw BibTeX)
#   reproductions paper folders + paper.toml (reviewed claims only become claims)
#   commands      derived from the claim's targets and parameters (bin/vbfrepro run ...)
#   evidence      record.toml files (CI regression records, archived reproduction records),
#                 with compatibility computed against this checkout
#   corpora       catalog bulk_corpora: declared in paper.toml, or citing a publication

const REPO_URL = "https://github.com/siqueiratf/VBF.jl"
const BLOB = REPO_URL * "/blob/main/"
const ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))

# TeX accents as Unicode combining marks: \"o, \"{o} and {\"o} become ö.
const TEX_ACCENTS = Dict('"' => '\u0308', '\'' => '\u0301', '`' => '\u0300', '^' => '\u0302', '~' => '\u0303',
                         '=' => '\u0304', '.' => '\u0307', 'c' => '\u0327', 'v' => '\u030c', 'u' => '\u0306', 'H' => '\u030b')
tex_accents(s) = Base.Unicode.normalize(replace(s, r"\\([\"'`^~=.]|[cvuH](?=[{\s]))\s*\{?([A-Za-z])\}?" =>
    m -> (c = match(r"\\([\"'`^~=.]|[cvuH])\s*\{?([A-Za-z])", m); string(c[2], TEX_ACCENTS[c[1][1]]))), :NFC)
"Plain text of a BibTeX field: no protecting braces, en dash for `--`."
clean_tex(s) = replace(replace(tex_accents(strip(String(s))), r"[{}]" => ""), "--" => "–", r"\s+" => " ")

"Raw BibTeX entries of a .bib file, by key (for the BibTeX toggle)."
function raw_bibtex(path)
    text = read(path, String)
    out = Dict{String,String}()
    for m in eachmatch(r"@\w+\s*\{\s*([^,\s]+)\s*,"m, text)
        depth = 0; i = m.offset
        while i <= lastindex(text)          # step by character: titles and names contain UTF-8
            c = text[i]
            c == '{' && (depth += 1)
            if c == '}'
                depth -= 1
                depth == 0 && (out[m[1]] = text[m.offset:i]; break)
            end
            i = nextind(text, i)
        end
    end
    out
end

"Initials plus last name: \"Yves Edel\" → \"Y. Edel\"."
short_name(first, last) = isempty(strip(first)) ? clean_tex(last) :
    join([string(p[1], ".") for p in split(clean_tex(first), r"[\s-]+") if !isempty(p)], " ") * " " * clean_tex(last)

function join_names(names)
    length(names) <= 2 ? join(names, " and ") : join(names[1:end-1], ", ") * ", and " * names[end]
end

"""All references of `bibliography.bib`, by key."""
function load_references(path = joinpath(ROOT, "packages", "VBFCatalog", "src", "data", "bibliography.bib"))
    bib = Bibliography.import_bibtex(path)
    raw = raw_bibtex(path)
    refs = Dict{String,Dict{String,Any}}()
    for (k, e) in bib
        venue = clean_tex(e.in.journal)
        isempty(venue) && (venue = clean_tex(e.booktitle))
        isempty(venue) && (venue = clean_tex(e.access.howpublished))
        isempty(venue) && (venue = clean_tex(e.in.publisher))
        vol = clean_tex(e.in.volume); num = clean_tex(e.in.number); pages = clean_tex(e.in.pages)
        # A preprint number that repeats the publisher ("arXiv" + "arXiv:2601.11247") is the venue.
        !isempty(venue) && startswith(num, venue) && (venue = num; num = "")
        detail = string(isempty(vol) ? "" : " $vol", isempty(num) ? "" : (isempty(vol) ? " $num" : "($num)"),
                        isempty(pages) ? "" : ", $pages")
        authors = [short_name(a.first, a.last) for a in e.authors]
        doi = strip(e.access.doi); url = strip(e.access.url)
        refs[k] = Dict{String,Any}("key" => k, "title" => clean_tex(e.title), "authors" => authors,
            "author_line" => join_names(authors), "year" => String(e.date.year),
            "venue" => venue * detail, "doi" => doi, "doi_url" => isempty(doi) ? "" : "https://doi.org/$doi",
            "url" => isempty(url) ? (isempty(doi) ? "" : "https://doi.org/$doi") : url,
            "bibtex" => get(raw, k, ""))
    end
    refs
end

"Commands that reproduce a claim: one per target, with the claim's parameters."
claim_commands(id, c) = ["bin/vbfrepro run $id --target $t" *
    join([" --param $k=$v" for (k, v) in sort!(collect(get(c, "parameters", Dict())))]) for t in get(c, "targets", [])]

"""Evidence records under the given folders, grouped by paper, with compatibility."""
function load_evidence(dirs)
    by_paper = Dict{String,Vector{Dict{String,Any}}}()
    current = Dict{Any,Dict{String,String}}()     # (paper, parameters) => fingerprint, computed once
    for base in dirs
        isdir(base) || continue
        for (d, _, files) in walkdir(base), f in files
            f == "record.toml" || continue
            r = TOML.parsefile(joinpath(d, f))
            problems = VBFRepro.validate_evidence(r; dir = d)
            key = (r["paper"], get(r, "parameters", Dict()))
            changed = String[]
            if isempty(problems) && isdir(joinpath(VBFRepro.papers_root(), r["paper"]))
                fp = get!(() -> VBFRepro.evidence_fingerprint(r["paper"]; parameters = key[2]), current, key)
                changed = sort!([k for k in union(keys(fp), keys(r["fingerprint"])) if get(fp, k, "") != get(r["fingerprint"], k, "")])
            end
            r["valid"] = isempty(problems)
            r["problems"] = problems
            r["changed"] = changed
            r["current"] = isempty(problems) && isempty(changed)
            r["source_dir"] = d
            push!(get!(by_paper, r["paper"], Dict{String,Any}[]), r)
        end
    end
    for v in values(by_paper)
        sort!(v; by = r -> get(r["provenance"], "created_utc", ""), rev = true)
    end
    by_paper
end

"""
    build_model(db; evidence_dirs) -> Dict

Everything the templates need. Only reviewed claims (review = "done") become claims; a paper
without them shows its implementation files and their commands, with no claim of
reproduction.
"""
function build_model(db; evidence_dirs = [joinpath(dirname(VBFRepro.papers_root()), "evidence")])
    refs = load_references()
    corpora = Dict(String(r.name) => Dict{String,Any}("name" => String(r.name), "bib_key" => coalesce(r.bib_key, ""),
        "member_count" => r.member_count, "n" => r.n, "m" => r.m, "digest" => String(r.store_sha256),
        "source_repo" => String(r.source_repo)) for r in DBInterface.execute(db, "SELECT * FROM bulk_corpora"))
    evidence = load_evidence(evidence_dirs)
    pubs_toml = TOML.parsefile(VBFRepro.publications_path())
    repros = Dict{String,Any}[]
    errors = String[]
    for p in VBFRepro.discover_papers()
        meta = VBFRepro.load_paper_metadata(p.id)
        rel = relpath(p.path, ROOT)
        publications = meta === nothing ?
            [Dict("key" => pubs_toml[p.id], "role" => "primary")] : get(meta, "publications", [])
        primary = only(x["key"] for x in publications if x["role"] == "primary")
        if !haskey(refs, primary)
            push!(errors, "$(p.id): publication $primary is not in bibliography.bib")
            continue
        end
        ref = refs[primary]
        recs = get(evidence, p.id, Dict{String,Any}[])
        claims = Dict{String,Any}[]
        for c in (meta === nothing ? [] : get(meta, "claims", []))
            get(c, "review", "") == "done" || continue
            cev = [r for r in recs if c["id"] in get(r, "claims", [])]
            push!(claims, merge(Dict{String,Any}(c), Dict{String,Any}(
                "anchor" => c["id"],
                "commands" => claim_commands(p.id, c),
                "file_links" => [Dict("name" => f, "url" => BLOB * rel * "/" * f) for f in get(c, "files", [])],
                "evidence" => cev)))
        end
        declared = meta === nothing ? String[] : get(meta, "corpora", String[])
        keys_ = [x["key"] for x in publications]
        pcorp = sort(unique(vcat(declared, [n for (n, c) in corpora if c["bib_key"] in keys_])))
        data = [refs[x["key"]] for x in publications if x["role"] == "dataset" && haskey(refs, x["key"])]
        reviewed_files = Set(f for c in claims for f in get(c, "files", []))
        files = [Dict("name" => f, "url" => BLOB * rel * "/" * f,
                      "command" => (stem = splitext(f)[1]; stem in VBFRepro.makefile_targets(p.path).rules ?
                                    "bin/vbfrepro run $(p.id) --target $stem" : ""))
                 for f in sort(readdir(p.path)) if endswith(f, ".jl") && !(f in reviewed_files) &&
                     !(f in ("helpers.jl", "report.jl", "evidence_runner.jl"))]
        updated = try readchomp(`git -C $ROOT log -1 --format=%cs -- $rel`) catch; "" end
        push!(repros, Dict{String,Any}("id" => p.id, "path" => rel, "url" => BLOB * rel,
            "ref" => ref, "publications" => publications, "claims" => claims, "has_claims" => !isempty(claims),
            "other_files" => files, "corpora" => [corpora[n] for n in pcorp if haskey(corpora, n)],
            "data" => data, "code" => meta === nothing ? String[] : get(meta, "code", String[]),
            "evidence" => recs, "updated" => updated,
            "year" => ref["year"]))
    end
    sort!(repros; by = r -> (r["year"], r["id"]), rev = true)
    Dict{String,Any}("references" => refs, "reproductions" => repros, "corpora" => corpora,
                     "snapshot" => catalog_snapshot(db), "errors" => errors)
end
