"""Resolve public signature matches with bounded EA searches and explicit witnesses."""
const EQUIVALENCE_USAGE = nothing
include("check_candidates.jl")
include("../../../search/apn/verification/ea_witness.jl")
using .IndependentEAWitness

function matched_candidates(references, expected_hashes)
    rows = Dict{String,Any}[]
    for line in Iterators.drop(eachline(references), 1)
        c = split(line, '\t')
        push!(rows, Dict("sigma_hash"=>String(c[1]), "candidate_file"=>String(c[2]),
            "candidate_line"=>parse(Int,c[3]), "public_dump_first_record"=>parse(Int,c[4]),
            "public_dump_records_with_signature"=>parse(Int,c[5])))
    end
    length(Set(r["sigma_hash"] for r in rows)) == length(rows) || error("duplicate match rows")
    for path in unique(r["candidate_file"] for r in rows)
        filehash(path) == expected_hashes[path] || error("candidate input changed: $path")
        wanted = Dict(r["candidate_line"]=>r for r in rows if r["candidate_file"] == path)
        payloadcol = 0
        for (i,line) in enumerate(eachline(path))
            c = split(line, '\t')
            if i == 1
                col = findfirst(x -> x in ("coeffs", "lut", "lut_hex"), c)
                col === nothing && error("candidate payload header missing")
                payloadcol = col
            end
            haskey(wanted,i) || continue
            row = wanted[i]
            c[1] == row["sigma_hash"] || error("candidate reference changed")
            row["candidate_lut_hex"] = bytes2hex(candidate_lut(c[payloadcol]))
        end
    end
    all(haskey(r,"candidate_lut_hex") for r in rows) || error("candidate reference missing")
    rows
end

function public_lut(io, record)
    record > 0 || error("invalid public record number")
    seek(io, 64*(record-1))
    bytes = read(io,64)
    length(bytes) == 64 || error("public record beyond end of file")
    words = reinterpret(UInt64, bytes)
    RawReaders.lut_from_masks!(Vector{UInt8}(undef,256), ntuple(i->ltoh(words[i]),8))
end

function solve_pair(f, g; timeout_seconds, max_nodes)
    result = partition_refinement_equivalence(SBox{8,UInt8}(f), SBox{8,UInt8}(g);
        relation=:ea, timeout_seconds, max_nodes)
    if result isa Found
        map = only(search_solutions(result))
        cols = Int.(map.linear.cols)
        constant = Int(map.constant)
        verify_ea_witness(f,g,cols,constant) || error("solver returned invalid EA witness")
        return (; status="ea_equivalent", cols, constant, result)
    end
    status = result isa Exhausted ? "ea_inequivalent" : "inconclusive"
    (; status, cols=Int[], constant=0, result)
end

function save_equivalence_report(path, identity, rows, started)
    report = Dict{String,Any}("identity"=>identity, "started_utc"=>started,
        "updated_utc"=>string(now(UTC)), "checks"=>rows,
        "matched_candidates"=>length(rows),
        "ea_equivalent"=>count(r->get(r,"status","")=="ea_equivalent",rows),
        "ea_inequivalent_to_all_public_matches"=>count(r->get(r,"status","")=="ea_inequivalent",rows),
        "inconclusive"=>count(r->get(r,"status","")=="inconclusive",rows),
        "pending"=>count(r->!haskey(r,"status"),rows))
    report["complete"] = report["pending"] == report["inconclusive"] == 0
    tmp = path*".tmp"
    open(io->TOML.print(io,report;sorted=true),tmp,"w")
    mv(tmp,path;force=true)
    report
end

"""
Search every public representative with a candidate's matching signature until
one verifies EA-equivalent. A negative verdict requires exhaustion for every
representative; a budget hit remains inconclusive. Completed verdicts resume.
"""
function check_equivalence(outdir; timeout_seconds=60.0, max_nodes=1_000_000)
    started = string(now(UTC))
    references = joinpath(outdir,"search_public_matches.tsv")
    candidates = TOML.parsefile(joinpath(outdir,"candidate_comparison.toml"))
    rawreport = TOML.parsefile(joinpath(outdir,"raw_langevin_may2025.toml"))
    rawreport["complete"] || error("public corpus rebuild incomplete")
    rawpath = joinpath(outdir,"sources/apn-11888039-may-2025-8.out")
    filehash(rawpath) == rawreport["input_sha256"][rawpath] || error("public original changed")
    rows = matched_candidates(references,candidates["candidate_sha256"])
    length(rows) == candidates["original_status"]["search"]["matches"] || error("match coverage mismatch")
    # Pin the verifier, dependencies and the entire loaded VBF source tree.
    vbfpaths = sort(filter(p->endswith(p,".jl"),
        [joinpath(dir,f) for (dir,_,files) in walkdir(joinpath(REPO,"packages/VBF/src")) for f in files]))
    codepaths = vcat(vbfpaths, [(@__FILE__), joinpath(REPO,"search/apn/verification/ea_witness.jl"),
        joinpath(@__DIR__,"check_candidates.jl"),joinpath(REPO,"search/apn/verification/signature.jl"),
        joinpath(@__DIR__,"rebuild.jl"),joinpath(@__DIR__,"../crosscheck_raw/crosscheck.jl"),joinpath(REPO,"Manifest.toml")])
    codehashes = Dict(p=>filehash(p) for p in codepaths)
    identity = Dict("references_sha256"=>filehash(references),
        "candidate_report_sha256"=>filehash(joinpath(outdir,"candidate_comparison.toml")),
        "public_source_sha256"=>filehash(rawpath),
        "public_rebuild_sha256"=>filehash(joinpath(outdir,"raw_langevin_may2025.sqlite")),
        "code_sha256"=>codehashes, "julia_version"=>string(VERSION),
        "method"=>"native partition refinement EA; independent full-LUT graph witness verification")
    reportpath = joinpath(outdir,"equivalence_checks.toml")
    if isfile(reportpath)
        old = TOML.parsefile(reportpath)
        old["identity"] == identity || error("equivalence inputs/code changed; archive the old report first")
        verify_witness_report(reportpath)
        previous = Dict(r["sigma_hash"]=>r for r in old["checks"])
        for i in eachindex(rows)
            oldrow = previous[rows[i]["sigma_hash"]]
            get(oldrow,"status","") in ("ea_equivalent","ea_inequivalent") && (rows[i] = oldrow)
        end
        started = old["started_utc"]
    end
    db = readonly(joinpath(outdir,"raw_langevin_may2025.sqlite"))
    try
        open(rawpath) do io
            for (i,row) in enumerate(rows)
                get(row,"status","") in ("ea_equivalent","ea_inequivalent") && continue
                hash = row["sigma_hash"]
                f = hex2bytes(row["candidate_lut_hex"])
                bytes2hex(signature(Workspace(),f)) == hash || error("candidate signature mismatch")
                row["candidate_lut_sha256"] = bytes2hex(SHA.sha256(f))
                refs = [(Int(r.member_idx),String(r.lut_sha256)) for r in DBI.execute(db,
                    "SELECT member_idx,lut_sha256 FROM records WHERE sigma_hash=? ORDER BY member_idx",(hash,))]
                length(refs) == row["public_dump_records_with_signature"] || error("public reference count changed")
                first(refs)[1] == row["public_dump_first_record"] || error("first public reference changed")
                attempts = Dict{String,Any}[]
                row["status"] = "ea_inequivalent"
                for (record,digest) in refs
                    g = public_lut(io,record)
                    bytes2hex(SHA.sha256(g)) == digest || error("public record LUT digest mismatch")
                    bytes2hex(signature(Workspace(),g)) == hash || error("public signature mismatch")
                    elapsed = @elapsed solved = solve_pair(f,g;timeout_seconds,max_nodes)
                    attempt = Dict{String,Any}("public_record"=>record,"status"=>solved.status,
                        "elapsed_seconds"=>elapsed,"nodes_visited"=>nodes_visited(solved.result),
                        "timeout_seconds"=>timeout_seconds,"max_nodes"=>max_nodes)
                    solved.result isa BudgetHit && (attempt["budget_reason"] = string(solved.result.where_it_stopped.reason))
                    push!(attempts,attempt)
                    if solved.status == "ea_equivalent"
                        row["status"] = "ea_equivalent"
                        row["public_record"] = record
                        row["public_lut_hex"] = bytes2hex(g)
                        row["public_lut_sha256"] = digest
                        row["graph_map_columns"] = solved.cols
                        row["graph_map_constant"] = solved.constant
                        break
                    elseif solved.status == "inconclusive"
                        row["status"] = "inconclusive"
                    end
                end
                row["attempts"] = attempts
                save_equivalence_report(reportpath,identity,rows,started)
                println(i,"/",length(rows)," ",hash," ",row["status"]," (",sum(a["elapsed_seconds"] for a in attempts)," s)")
                flush(stdout)
            end
        end
    finally
        close(db)
    end
    all(filehash(p)==digest for (p,digest) in codehashes) || error("computation code changed during run")
    filehash(references) == identity["references_sha256"] || error("references changed during run")
    all(filehash(p)==digest for (p,digest) in candidates["candidate_sha256"]) || error("candidate inputs changed during run")
    final = save_equivalence_report(reportpath,identity,rows,started)
    verify_witness_report(reportpath)
    println("EA-equivalent: ",final["ea_equivalent"],"; inequivalent: ",final["ea_inequivalent_to_all_public_matches"],"; inconclusive: ",final["inconclusive"])
    final
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    length(ARGS) in 1:3 || error("usage: check_equivalence.jl OUTDIR [timeout_seconds] [max_nodes]")
    check_equivalence(abspath(ARGS[1]); timeout_seconds=length(ARGS)>=2 ? parse(Float64,ARGS[2]) : 60.0,
        max_nodes=length(ARGS)>=3 ? parse(Int,ARGS[3]) : 1_000_000)
end
