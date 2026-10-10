"""
Fetch the pinned original quadratic (8,8)-APN inputs without changing the
catalog. Downloads are resumable and installed after checksum verification.
The authors' compressed mirror is accepted only if the decompressed file
matches the MD5 published by Zenodo (record 16752428). Source URLs, revisions,
sizes and SHA-256 digests are recorded in sources/provenance.toml.

    julia --project=. fetch.jl [OUTPUT_DIRECTORY]
"""
const FETCH_USAGE = nothing
using SHA, TOML, Dates
const FETCH_DEFAULT = normpath(joinpath(@__DIR__, "../../../../data/apn/rebuilds/original-source"))
const PINNED_REPOS = [
    ("sboxU", "https://github.com/lpp-crypto/sboxU.git", "7066b825c979ceefa901e7be3b2afcc63f587bcf"),
    ("thesis", "https://github.com/Simon-Berg/thesis.git", "c13952d2458cb692171816b483f4e8ac0c62455a")]

"""Download to a .partial file, resuming after interruption."""
function fetch_file(url, path)
    isfile(path) && return path
    partial = path * ".partial"
    run(`curl --fail --location --retry 5 --continue-at - --output $partial $url`)
    mv(partial, path)
    path
end

"""Fetch pinned inputs and save byte-level provenance."""
function fetch_inputs(outdir)
    sources = joinpath(abspath(outdir), "sources")
    mkpath(sources)
    provenance = Dict{String,Any}("fetched_utc"=>string(now(UTC)), "files"=>Dict{String,Any}(), "repositories"=>Dict{String,Any}())
    for (name, url, revision) in PINNED_REPOS
        path = joinpath(sources, name)
        files = name == "thesis" ? ["rep$i.txt" for i in 1:27] :
            ["sboxU/scripts/apnDB/" * f for f in
             ["eightBitAPN.py", "firstQAM.py", "BeierleLeander.py", "apn_8bit_BLP22.py", "secondQAM.py"]]
        mktempdir() do temp
            checkout = joinpath(temp, name)
            run(`git clone --quiet $url $checkout`)
            actual = readchomp(`git -C $checkout rev-parse $revision`)
            actual == revision || error("unexpected $name revision")
            for file in files
                target = joinpath(path, file)
                mkpath(dirname(target))
                open(target, "w") do io
                    run(pipeline(`git -C $checkout show $revision:$file`; stdout=io))
                end
                provenance["files"][name * "/" * file] = Dict{String,Any}("url"=>url, "revision"=>revision)
            end
        end
        provenance["repositories"][name] = Dict("url"=>url, "revision"=>revision)
    end
    published = joinpath(sources, "new_apns.txt")
    url = "https://langevin.univ-tln.fr/data/apns/new_apns.txt.gz"
    if !isfile(published) || filesize(published) != 3395265744
        compressed = fetch_file(url, published * ".gz")
        partial = published * ".partial"
        open(partial, "w") do io
            run(pipeline(`gzip -dc $compressed`; stdout=io))
        end
        # MD5 is the publisher's identifier; record SHA-256 as well below.
        first(split(readchomp(`md5sum $partial`))) == "dd6ae0655ba8a299a3d668cfc6cf10bf" ||
            error("mirror does not match Zenodo's published checksum")
        mv(partial, published; force=true)
    end
    first(split(readchomp(`md5sum $published`))) == "dd6ae0655ba8a299a3d668cfc6cf10bf" || error("published input checksum mismatch")
    provenance["files"]["new_apns.txt"] = Dict{String,Any}("url"=>url,
        "publication"=>"https://zenodo.org/records/16752428", "md5"=>"dd6ae0655ba8a299a3d668cfc6cf10bf")
    dumpurl = "https://langevin.univ-tln.fr/data/apns/apn-11888039-may-2025-8.out"
    dump = fetch_file(dumpurl, joinpath(sources, "apn-11888039-may-2025-8.out"))
    digest = bytes2hex(open(SHA.sha256, dump))
    digest == "daca5babcbb61c93c3d07e9236d65ed778db16e737e4a51e0fdd9022aa20760e" || error("public binary dump changed; inspect before updating its pin")
    provenance["files"][basename(dump)] = Dict{String,Any}("url"=>dumpurl)
    for (name, entry) in provenance["files"]
        path = joinpath(sources, name)
        entry["bytes"] = filesize(path)
        entry["sha256"] = bytes2hex(open(SHA.sha256, path))
    end
    open(io -> TOML.print(io, provenance; sorted=true), joinpath(sources, "provenance.toml"), "w")
    println("inputs fetched and checksummed: ", sources)
end

abspath(PROGRAM_FILE) == (@__FILE__) && fetch_inputs(isempty(ARGS) ? FETCH_DEFAULT : only(ARGS))
