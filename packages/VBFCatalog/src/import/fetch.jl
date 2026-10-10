using VBFCatalog, SHA, TOML, Dates
include("load_sources.jl")

"""Fetch an original dataset into the catalog's local source cache.

Repository revisions and standalone checksums are declared in sources.toml.
Downloads resume through .partial files; checked originals are then installed.
"""
function fetch_source(name)
    src = _bfa_source_config(name)
    get(src,"builtin",false) && return nothing
    if !haskey(src,"download")
        return with_source(name) do root
            println(name, ": ", root)
            root
        end
    end
    root = _bfa_source_root(src); mkpath(root)
    path = joinpath(root,src["check_path"])
    if !isfile(path)
        compressed = path * ".gz"
        if !isfile(compressed)
            partial = compressed * ".partial"
            run(`curl --fail --location --retry 5 --continue-at - --output $partial $(src["download"])`)
            mv(partial,compressed)
        end
        partial = path * ".partial"
        open(partial,"w") do io
            run(pipeline(`gzip -dc $compressed`;stdout=io))
        end
        verify_original(partial,src)
        mv(partial,path)
    end
    verify_original(path,src)
    provenance=Dict("source"=>name,"download"=>src["download"],"fetched_utc"=>string(now(UTC)),
        "sha256"=>bytes2hex(open(SHA.sha256,path)),"bytes"=>filesize(path))
    open(io->TOML.print(io,provenance;sorted=true),joinpath(root,"provenance.toml"),"w")
    println(name, ": ",root)
    root
end

function verify_original(path,src)
    filesize(path)==src["published_bytes"] || error("original size mismatch")
    first(split(readchomp(`md5sum $path`)))==src["published_md5"] || error("original checksum mismatch")
end

function main(args)
    names=isempty(args) ? [s["name"] for s in TOML.parsefile(_SOURCES_TOML)["source"]
        if haskey(s,"upstream") || haskey(s,"download")] : args
    foreach(fetch_source, unique(names))
end
abspath(PROGRAM_FILE)==(@__FILE__) && main(ARGS)
