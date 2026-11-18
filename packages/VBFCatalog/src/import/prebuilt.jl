using VBFCatalog, SHA, TOML, Dates, JSON3, SQLite, DBInterface

"""Prebuilt catalog data on Zenodo.

The catalog, the Beierle et al. 2025 members and the signature index take hours to
build from the originals. CI publishes them as one Zenodo version per prebuilt key
(`VBFCatalog._prebuilt_key()`: the declarations and the VBF/VBFCatalog sources).
`fetch` installs the version whose key equals the key of this checkout.

    julia --project=. prebuilt.jl key
    julia --project=. prebuilt.jl fetch                # exit 1: no version for this checkout
    julia --project=. prebuilt.jl published            # exit 0: this key is on Zenodo
    julia --project=. prebuilt.jl publish [--draft] [--create]   # needs ZENODO_TOKEN

Publication is permanent. `--create` makes the first version of a new record;
without it, `publish` adds a version to `concept_recid` of prebuilt.toml.
`--draft` uploads the files and stops before the publication.
"""

const CONFIG = TOML.parsefile(joinpath(@__DIR__, "prebuilt.toml"))
const API = get(ENV, "ZENODO_API", CONFIG["api"])
const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const MANIFEST = "manifest.toml"
const QUERY = "query.sqlite"
"Path of the browser query database (built by docs/portal before the publication)."
query_path() = joinpath(catalog_data_dir(), QUERY)

"Installed path of each published file, in install order (the index last)."
data_files() = ["catalog.sqlite" => catalog_path(),
                "members.sqlite" => joinpath(catalog_data_dir(), "members.sqlite"),
                "ccz_sigma_index.sqlite" => sigma_index_path()]

filehash(path) = bytes2hex(open(SHA.sha256, path))
short(key) = key[1:12]

"""
Run curl and parse the JSON reply; `--fail-with-body` puts the Zenodo error in the exception.
With `gone_ok`, a 404 reply counts as success: curl retries a request after a server error,
and a DELETE that the first try completed then finds no file (seen on 2026-11-18).
"""
function zenodo(method, url; token = "", body = nothing, upload = nothing, gone_ok = false)
    cmd = `curl -sS --fail-with-body --retry 3 -X $method`
    isempty(token) || (cmd = `$cmd -H "Authorization: Bearer $token"`)
    body === nothing || (cmd = `$cmd -H "Content-Type: application/json" --data-binary $(JSON3.write(body))`)
    upload === nothing || (cmd = `$cmd -H "Content-Type: application/octet-stream" --upload-file $upload`)
    out = IOBuffer(); err = IOBuffer()
    ok = success(pipeline(`$cmd $url`; stdout = out, stderr = err))
    text = String(take!(out))
    message = String(take!(err))
    if !ok && gone_ok && occursin("error: 404", message)
        println("prebuilt: $method $url: already done (404)")
        return nothing
    end
    ok || error("Zenodo $method $url failed: ", message, text)
    isempty(strip(text)) ? nothing : JSON3.read(text)
end

"Published versions of the record, newest first (public search, no token: 25 hits per page)."
function versions(id = CONFIG["concept_recid"])
    hits = []
    isempty(id) && return hits
    for page in Iterators.countfrom(1)
        reply = zenodo("GET", "$API/records?q=conceptrecid:$id&all_versions=true&sort=mostrecent&size=25&page=$page")
        append!(hits, reply.hits.hits)
        (isempty(reply.hits.hits) || length(hits) >= reply.hits.total) && break
    end
    hits
end

"The published version of `key`, checked through its manifest, or `nothing`."
function find_version(key)
    for hit in versions()
        endswith(String(get(hit.metadata, :version, "")), short(key)) || continue
        files = Dict(String(f.key) => String(f.links.self) for f in hit.files)
        haskey(files, MANIFEST) || continue
        manifest = TOML.parse(read(download_text(files[MANIFEST]), String))
        manifest["key"] == key && return (; hit, files, manifest)
    end
    nothing
end

download_text(url) = IOBuffer(read(`curl -sS --fail --location --retry 3 $url`))

"Install the files of `key` into the catalog data directory. Return false if Zenodo has no such version."
function fetch_data(key)
    marker = joinpath(catalog_data_dir(), "prebuilt.toml")
    installed = isfile(marker) ? TOML.parsefile(marker)["key"] : ""
    if installed == key && all(isfile ∘ last, data_files())
        println("prebuilt: the data of key $(short(key)) is installed")
        return true
    end
    found = find_version(key)
    if found === nothing
        println(stderr, "prebuilt: Zenodo has no data for key $(short(key)) of this checkout")
        isempty(installed) || println(stderr, "prebuilt: the installed data has key $(short(installed)). ",
            "To build the data of this checkout, delete the *.sqlite files of $(catalog_data_dir()) ",
            "and run make -C docs data prebuilt=0")
        return false
    end
    doi = String(get(found.hit, :doi, ""))
    println("prebuilt: installing Zenodo version $(found.hit.metadata.version) (doi:$doi)")
    mkpath(catalog_data_dir())
    staged = String[]
    try
        for (name, target) in data_files()
            entry = found.manifest["files"][name]
            gz = target * ".gz.partial"; raw = target * ".partial"
            # A partial download resumes; a complete one with a wrong checksum is deleted.
            run(`curl --fail --location --retry 5 --continue-at - --output $gz $(found.files[name * ".gz"])`)
            filehash(gz) == entry["gz_sha256"] || (rm(gz); error("$name.gz: checksum mismatch, deleted"))
            push!(staged, raw)
            open(io -> run(pipeline(`gzip -dc $gz`; stdout = io)), raw, "w")
            filehash(raw) == entry["sha256"] || error("$name: checksum mismatch")
            rm(gz)
        end
    catch
        foreach(path -> rm(path; force = true), staged)
        rethrow()
    end
    # Install only after every file passed its check; the index gets the newest mtime.
    for ((_, target), raw) in zip(data_files(), staged)
        mv(raw, target; force = true); touch(target)
    end
    installed = merge(found.manifest, Dict("doi" => doi, "installed_utc" => string(now(UTC))))
    open(io -> TOML.print(io, installed; sorted = true), joinpath(catalog_data_dir(), "prebuilt.toml"), "w")
    println("prebuilt: installed $(join(first.(data_files()), ", ")) in $(catalog_data_dir())")
    true
end

"""
    fetch_query(key, dest) -> Bool

Download the browser query database of the Zenodo version of `key` to `dest` and check its
SHA-256. Returns false if Zenodo has no such version or the version has no query database.
"""
function fetch_query(key, dest)
    found = find_version(key)
    found === nothing && (println(stderr, "prebuilt: Zenodo has no data for key $(short(key))"); return false)
    entry = get(found.manifest["files"], QUERY, nothing)
    entry === nothing && (println(stderr, "prebuilt: this version has no $QUERY"); return false)
    if !(isfile(dest) && filehash(dest) == entry["sha256"])
        partial = dest * ".partial"
        run(`curl --fail --location --retry 5 --continue-at - --output $partial $(found.files[QUERY])`)
        filehash(partial) == entry["sha256"] || (rm(partial); error("$QUERY: checksum mismatch, deleted"))
        mv(partial, dest; force = true)
    end
    println("prebuilt: $QUERY of key $(short(key)) at $dest")
    true
end

"Manifest of the local files: the prebuilt key, the catalog digests and one entry per file."
function local_manifest(key, gz)
    db = load_catalog()
    meta = try only(NamedTuple(r) for r in DBInterface.execute(db, "SELECT * FROM schema_meta")) finally close(db) end
    commit = get(ENV, "GITHUB_SHA", readchomp(`git -C $ROOT rev-parse HEAD`))
    files = Dict{String,Any}(name => Dict("sha256" => filehash(path), "bytes" => filesize(path),
                              "gz_sha256" => filehash(gz[name]), "gz_bytes" => filesize(gz[name]))
                 for (name, path) in data_files())
    # The browser query database (docs/portal), uncompressed so that HTTP Range requests work.
    q = query_path()
    isfile(q) && (files[QUERY] = Dict("sha256" => filehash(q), "bytes" => filesize(q), "uncompressed" => true))
    Dict("key" => key, "commit" => commit, "julia" => string(VERSION),
         "schema_version" => meta.schema_version, "inputs_sha256" => meta.inputs_sha256,
         "implementation_sha256" => meta.implementation_sha256,
         "created_utc" => string(now(UTC)), "files" => files)
end

function metadata(version, manifest)
    software = JSON3.read(read(joinpath(ROOT, ".zenodo.json"), String))
    Dict("title" => CONFIG["title"], "upload_type" => "dataset", "version" => version,
        "creators" => software.creators, "license" => "cc-by-4.0", "access_right" => "open",
        "keywords" => ["APN functions", "vectorial Boolean functions", "CCZ equivalence", "SQLite"],
        "description" => """<p>Prebuilt SQLite files of the VBFCatalog package of
            <a href="https://github.com/siqueiratf/VBF.jl">VBF.jl</a>, commit
            <code>$(manifest["commit"])</code>. Use them instead of a rebuild from the original sources:
            run <code>make -C docs data</code> in a clone of the same commit.</p>
            <ul><li><code>catalog.sqlite</code>: the curated catalog of APN functions, S-boxes and corpora.</li>
            <li><code>members.sqlite</code>: the 3,775,599 quadratic APN functions of Beierle, Langevin,
            Leander, Polujan and Rasoolzadeh (2025), doi:10.5281/zenodo.16752428 (CC-BY-4.0), as 37-byte coefficients.</li>
            <li><code>ccz_sigma_index.sqlite</code>: the ortho-derivative signature index of the quadratic APN functions.</li></ul>
            <p><code>manifest.toml</code> gives the prebuilt key $(manifest["key"]) and the SHA-256 of each file.
            The sources of each corpus and their attributions are in the catalog tables
            <code>bulk_corpora</code> and <code>bibliography</code>.</p>""",
        "related_identifiers" => [
            Dict("identifier" => "10.5281/zenodo.16752428", "relation" => "isDerivedFrom", "scheme" => "doi"),
            Dict("identifier" => "https://github.com/siqueiratf/VBF.jl/tree/$(manifest["commit"])",
                 "relation" => "isSupplementTo", "scheme" => "url")])
end

function publish(key; draft = false, create = false)
    token = get(ENV, "ZENODO_TOKEN", "")
    isempty(token) && error("set ZENODO_TOKEN")
    concept = CONFIG["concept_recid"]
    create == isempty(concept) || error(create ? "prebuilt.toml already names a record; drop --create" :
        "prebuilt.toml has no concept_recid; use --create for the first version")
    found = find_version(key)
    found === nothing || (println("prebuilt: key $(short(key)) is already version $(found.hit.metadata.version)"); return)
    for (_, path) in data_files()
        isfile(path) || error("missing $path; run make -C docs data prebuilt=0")
    end
    work = mktempdir(catalog_data_dir())
    try
        gz = Dict{String,String}()
        for (name, path) in data_files()
            gz[name] = joinpath(work, name * ".gz")
            open(io -> run(pipeline(`gzip -c $path`; stdout = io)), gz[name], "w")
        end
        manifest = local_manifest(key, gz)
        version = Dates.format(now(UTC), "yyyy-mm-dd") * "+" * short(key)
        open(io -> TOML.print(io, manifest; sorted = true), joinpath(work, MANIFEST), "w")
        if create
            dep = zenodo("POST", "$API/deposit/depositions"; token, body = Dict())
        else
            latest = first(versions())
            draft_link = zenodo("POST", "$API/deposit/depositions/$(latest.id)/actions/newversion"; token).links.latest_draft
            dep = zenodo("GET", String(draft_link); token)
            # A new version starts with the files of the previous one.
            for f in dep.files
                zenodo("DELETE", "$API/deposit/depositions/$(dep.id)/files/$(f.id)"; token, gone_ok = true)
            end
            # A failed earlier run can leave this draft; it must hold no file before the upload.
            left = zenodo("GET", "$API/deposit/depositions/$(dep.id)"; token).files
            isempty(left) || error("the draft $(dep.id) still holds $(length(left)) files")
        end
        for name in [MANIFEST; [n * ".gz" for (n, _) in data_files()]]
            println("prebuilt: uploading $name")
            zenodo("PUT", "$(dep.links.bucket)/$name"; token, upload = joinpath(work, name))
        end
        if isfile(query_path())
            println("prebuilt: uploading $QUERY (uncompressed, for HTTP Range queries)")
            zenodo("PUT", "$(dep.links.bucket)/$QUERY"; token, upload = query_path())
        end
        zenodo("PUT", "$API/deposit/depositions/$(dep.id)"; token, body = Dict("metadata" => metadata(version, manifest)))
        if draft
            println("prebuilt: draft $(dep.links.html) is ready; publish or delete it on Zenodo")
            return
        end
        done = zenodo("POST", "$API/deposit/depositions/$(dep.id)/actions/publish"; token)
        println("prebuilt: published doi:$(done.doi) (version $version, concept_recid $(done.conceptrecid))")
        create && println("prebuilt: set concept_recid = \"$(done.conceptrecid)\" in prebuilt.toml and commit it")
    finally
        rm(work; recursive = true, force = true)
    end
end

function main(args)
    key = VBFCatalog._prebuilt_key()
    command = isempty(args) ? "key" : args[1]
    if command == "key"
        println(key)
    elseif command == "fetch"
        fetch_data(key) || exit(1)
    elseif command == "fetch-query"
        length(args) == 2 || error("usage: prebuilt.jl fetch-query DEST")
        fetch_query(key, args[2]) || exit(1)
    elseif command == "published"
        find_version(key) === nothing && exit(1)
    elseif command == "publish"
        publish(key; draft = "--draft" in args, create = "--create" in args)
    else
        error("unknown command $command (use key, fetch, fetch-query, published or publish)")
    end
end

abspath(PROGRAM_FILE) == (@__FILE__) && main(ARGS)
