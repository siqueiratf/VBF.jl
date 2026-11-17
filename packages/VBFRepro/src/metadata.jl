# Reproduction metadata (`paper.toml`, schema vbf-paper-1): discovery of candidate claims,
# the scaffold that writes them, and the checks that need only the paper folder.
# Cross-checks against the bibliography, the catalog and the Library live in docs/portal.
#
# Discovered data are candidates. A claim is a result of the publication only after a
# person sets `review = "done"`; the scaffold never does that.

const PAPER_SCHEMA = "vbf-paper-1"
const PAPER_FILE = "paper.toml"
const PUBLICATION_ROLES = ("primary", "dataset", "related")
const VERIFICATIONS = ("computational-check", "replication", "transcription")
const COMPLETENESS = ("complete", "partial", "not-reproduced")
const REVIEW = ("pending", "done")
const CLAIM_KEYS = ("id", "label", "summary", "files", "targets", "tests", "verification",
                    "completeness", "scope", "functions", "api", "review", "note")
const TOP_KEYS = ("schema", "code", "corpora", "functions", "publications", "claims", "unassigned")
# Make targets that run tools, not results of the publication.
const TOOL_TARGETS = ("help", "test", "report", "clean_results", "instantiate", "default", "clean", "all")
# Files that support the claims; they are never claims themselves.
const SUPPORT_FILES = ("helpers.jl", "report.jl")
const RESULT_WORDS = "Theorem|Lemma|Proposition|Corollary|Table|Figure|Algorithm|Example|" *
                     "Definition|Remark|Conjecture|Construction|Observation|Fact|Claim|Equation|Eq\\."
const RESULT_RE = Regex("\\b($RESULT_WORDS)\\s+([0-9]+(?:\\.[0-9]+)*[a-z]?)")

"""Path of the `paper.toml` of a reproduction."""
paper_metadata_path(id::AbstractString; root=papers_root()) = joinpath(paper_path(id; root), PAPER_FILE)

"""Stable claim ID of a result label: \"Lemma 4.6\" → \"lemma4_6\"."""
claim_id(label::AbstractString) = replace(lowercase(replace(label, r"\s+" => "")), "." => "_")

"""Make targets with their help text (from `  name   text` lines of the help target)."""
function makefile_targets(path)
    text = read(joinpath(path, "Makefile"), String)
    rules = String[m[1] for m in eachmatch(r"^([A-Za-z0-9_]+):(?!=)"m, text)]
    help = Dict{String,String}()
    for m in eachmatch(r"@echo\s+['\"]\s+([A-Za-z0-9_]+)\s{2,}(.*?)['\"]\s*$"m, text)
        m[1] in rules && (help[m[1]] = strip(m[2]))
    end
    (; rules = unique(rules), help)
end

"""Header fields of a claim file: the `# Implements`, `# Section:` and `# VBF API used:` lines."""
function file_header(file)
    lines = collect(Iterators.take(eachline(file), 40))
    field(prefix) = (for l in lines; startswith(l, prefix) && return strip(l[length(prefix)+1:end]); end; "")
    implements = field("# Implements")
    api_text = field("# VBF API used:")
    api = startswith(lowercase(api_text), "none") || isempty(api_text) ? String[] :
        [strip(a) for a in split(replace(api_text, r"\(.*?\)" => ""), r"[,;]") if occursin(r"^[A-Za-z_][A-Za-z0-9_!]*$", strip(a))]
    (; implements, section = field("# Section:"), api)
end

"""Result label suggested by a file or target name: \"table4_1\" → \"Table 4.1\", else `nothing`."""
function stem_label(stem::AbstractString)
    m = match(Regex("^($(lowercase(RESULT_WORDS)))([0-9]+(?:_[0-9]+)*[a-z]?)\$"), stem)
    m === nothing ? nothing : string(uppercasefirst(m[1]), " ", replace(m[2], "_" => "."))
end

"""Result labels named in a text, in order, without repetition: [\"Lemma 4.6\", …]."""
result_labels(text) = unique([string(m[1] == "Eq." ? "Equation" : m[1], " ", m[2]) for m in eachmatch(RESULT_RE, text)])

"""
    discover_candidates(id) -> (claims, unassigned)

Candidate claims from the file headers, the Makefile help and the tests. One candidate per
result label; a file that names several results adds itself to each. Files and targets that
name no result are returned in `unassigned` for review. Nothing here is a reviewed claim.
"""
function discover_candidates(id::AbstractString; root=papers_root())
    path = paper_path(id; root)
    make = makefile_targets(path)
    claims = Dict{String,Dict{String,Any}}()
    order = String[]
    unassigned = String[]
    add!(label, file, target) = begin
        cid = claim_id(label)
        c = get!(claims, cid) do
            push!(order, cid)
            Dict{String,Any}("id" => cid, "label" => label, "files" => String[], "targets" => String[],
                             "tests" => String[], "api" => String[], "review" => "pending")
        end
        file === nothing || file in c["files"] || push!(c["files"], file)
        if target !== nothing && !(target in c["targets"])
            push!(c["targets"], target)
            test = joinpath("test", "test_$target.jl")
            isfile(joinpath(path, test)) && !(test in c["tests"]) && push!(c["tests"], test)
            haskey(make.help, target) && !haskey(c, "summary") && (c["summary"] = make.help[target])
        end
        c
    end
    files = sort([f for f in readdir(path) if endswith(f, ".jl") && !(f in SUPPORT_FILES)])
    for f in files
        stem = splitext(f)[1]
        target = stem in make.rules ? stem : nothing
        h = file_header(joinpath(path, f))
        labels = result_labels(h.implements)
        isempty(labels) && target !== nothing && (labels = result_labels(get(make.help, target, "")))
        fromstem = stem_label(stem)
        fromstem === nothing || fromstem in labels || push!(labels, fromstem)
        if isempty(labels)
            push!(unassigned, f)
            continue
        end
        for label in labels
            c = add!(label, f, target)
            append!(c["api"], setdiff(h.api, c["api"]))
        end
    end
    # Targets whose help names results but which have no file of their own name.
    for t in make.rules
        (t in TOOL_TARGETS || isfile(joinpath(path, "$t.jl"))) && continue
        labels = result_labels(get(make.help, t, ""))
        isempty(labels) ? push!(unassigned, "target:$t") : foreach(l -> add!(l, nothing, t), labels)
    end
    ([claims[c] for c in order], unassigned)
end

_toml_value(v::AbstractString) = repr(String(v))
_toml_value(v::AbstractVector) = "[" * join(_toml_value.(v), ", ") * "]"
_toml_value(v) = string(v)

"""Write `paper.toml` text with the schema's key order and short comments."""
function render_paper_metadata(meta::AbstractDict)
    io = IOBuffer()
    println(io, "# Portal metadata of this reproduction (schema $PAPER_SCHEMA).")
    println(io, "# `bin/vbfrepro scaffold` writes candidates with review = \"pending\"; a person reviews")
    println(io, "# each claim against the paper and the code, then sets review = \"done\".")
    println(io, "schema = ", _toml_value(PAPER_SCHEMA))
    for k in ("code", "corpora", "functions", "unassigned")
        haskey(meta, k) && println(io, k, " = ", _toml_value(meta[k]))
    end
    for p in get(meta, "publications", [])
        println(io, "\n[[publications]]")
        for k in ("key", "role", "note")
            haskey(p, k) && println(io, k, " = ", _toml_value(p[k]))
        end
    end
    for c in get(meta, "claims", [])
        println(io, "\n[[claims]]")
        for k in CLAIM_KEYS
            haskey(c, k) && println(io, k, " = ", _toml_value(c[k]))
        end
    end
    String(take!(io))
end

"""
    scaffold_paper(id; update=false) -> path

Write `paper.toml` with the discovered candidates. An existing file is never replaced:
with `update=true`, candidates whose ID is not yet in the file are appended as pending,
and the unassigned list is refreshed; reviewed entries are not changed.
"""
function scaffold_paper(id::AbstractString; root=papers_root(), update::Bool=false)
    file = paper_metadata_path(id; root)
    claims, unassigned = discover_candidates(id; root)
    if isfile(file)
        update || throw(ArgumentError("$file exists; use --update to add new candidates"))
        meta = TOML.parsefile(file)
        known = Set(c["id"] for c in get(meta, "claims", []))
        meta["claims"] = vcat(get(meta, "claims", []), [c for c in claims if !(c["id"] in known)])
        meta["unassigned"] = unassigned
    else
        key = isfile(publications_path()) ? get(TOML.parsefile(publications_path()), String(id), nothing) : nothing
        meta = Dict{String,Any}("code" => String[], "corpora" => String[], "functions" => String[],
            "unassigned" => unassigned, "claims" => claims,
            "publications" => key === nothing ? [] : [Dict("key" => key, "role" => "primary")])
    end
    write(file, render_paper_metadata(meta))
    file
end

"""Read and return `paper.toml`, or `nothing` when the reproduction has none."""
function load_paper_metadata(id::AbstractString; root=papers_root())
    file = paper_metadata_path(id; root)
    isfile(file) ? TOML.parsefile(file) : nothing
end

"""
    check_paper_metadata(id) -> (errors, review)

Checks that need only the paper folder. `errors` break the schema or point to missing
files, targets or tests; `review` lists what a person must still decide.
"""
function check_paper_metadata(id::AbstractString; root=papers_root())
    errors = String[]; review = String[]
    path = paper_path(id; root)
    meta = load_paper_metadata(id; root)
    meta === nothing && return (["$id: no $PAPER_FILE (run bin/vbfrepro scaffold $id)"], review)
    get(meta, "schema", nothing) == PAPER_SCHEMA || push!(errors, "$id: schema must be \"$PAPER_SCHEMA\"")
    for k in keys(meta)
        k in TOP_KEYS || push!(errors, "$id: unknown key '$k'")
    end
    pubs = get(meta, "publications", [])
    count(p -> get(p, "role", "") == "primary", pubs) >= 1 || push!(errors, "$id: no publication with role \"primary\"")
    for p in pubs
        haskey(p, "key") || push!(errors, "$id: a publication has no key")
        get(p, "role", "") in PUBLICATION_ROLES || push!(errors, "$id: publication role must be one of $(join(PUBLICATION_ROLES, ", "))")
    end
    make = makefile_targets(path)
    seen = Set{String}()
    for c in get(meta, "claims", [])
        cid = get(c, "id", "")
        tag = "$id/$cid"
        occursin(r"^[a-z0-9_]+$", cid) || push!(errors, "$tag: claim id must match [a-z0-9_]+")
        cid in seen && push!(errors, "$tag: duplicate claim id")
        push!(seen, cid)
        for k in keys(c)
            k in CLAIM_KEYS || push!(errors, "$tag: unknown claim key '$k'")
        end
        get(c, "review", "") in REVIEW || push!(errors, "$tag: review must be pending or done")
        for f in get(c, "files", [])
            isfile(joinpath(path, f)) || push!(errors, "$tag: missing file $f")
        end
        for t in get(c, "targets", [])
            t in make.rules || push!(errors, "$tag: no Make target '$t'")
        end
        for t in get(c, "tests", [])
            isfile(joinpath(path, t)) || push!(errors, "$tag: missing test $t")
        end
        if get(c, "review", "") == "done"
            for k in ("label", "summary", "verification", "completeness", "scope")
                haskey(c, k) || push!(errors, "$tag: a reviewed claim needs '$k'")
            end
            get(c, "verification", VERIFICATIONS[1]) in VERIFICATIONS || push!(errors, "$tag: verification must be one of $(join(VERIFICATIONS, ", "))")
            get(c, "completeness", COMPLETENESS[1]) in COMPLETENESS || push!(errors, "$tag: completeness must be one of $(join(COMPLETENESS, ", "))")
            isempty(get(c, "files", [])) && isempty(get(c, "targets", [])) && push!(errors, "$tag: a reviewed claim needs a file or a target")
        else
            push!(review, "$tag: candidate, not reviewed")
        end
    end
    claimed = Set(f for c in get(meta, "claims", []) for f in get(c, "files", []))
    for f in readdir(path)
        endswith(f, ".jl") && !(f in SUPPORT_FILES) && !(f in claimed) &&
            push!(review, "$id: $f is in no claim")
    end
    for f in get(meta, "unassigned", [])
        push!(review, "$id: unassigned $f (no result named in its header or help)")
    end
    key = isfile(publications_path()) ? get(TOML.parsefile(publications_path()), String(id), nothing) : nothing
    primary = [p["key"] for p in pubs if get(p, "role", "") == "primary" && haskey(p, "key")]
    key === nothing || key in primary ||
        push!(review, "$id: publications.toml maps to $key, but the primary publication is $(join(primary, ", "))")
    (errors, review)
end
