"""Recheck saved LUT signatures and EA maps without loading VBF.

Usage: julia --startup-file=no verify_evidence.jl DOWNLOAD_DIRECTORY
The independent verifier uses only Julia's standard library. To recheck
original/baseline membership as well, rerun check_sources.jl.
"""
const VERIFY_LITERATURE_USAGE = nothing
using SHA, TOML
include("../../rebuild_corpus/signature.jl")
include("../../rebuild_corpus/ea_witness.jl")
using .IndependentSignature, .IndependentEAWitness

function verify_evidence(root)
    report = TOML.parsefile(joinpath(root,"checks.toml"))
    digest(path) = bytes2hex(open(SHA.sha256,path))
    for (file,key) in (("inputs.tsv","inputs_sha256"),("checks.tsv","checks_sha256"),
                       ("supplemental_luts.tsv","supplemental_luts_sha256"))
        digest(joinpath(root,file)) == report[key] || error("evidence file changed: $file")
    end
    checks = Dict{Tuple{String,String},Tuple{String,String}}()
    for line in Iterators.drop(eachline(joinpath(root,"checks.tsv")),1)
        c = split(line,'\t';keepempty=true)
        checks[(c[1],c[2])] = (c[3],c[4])
    end
    w = Workspace()
    for row in report["witnesses"]
        row["status"] == "ea_equivalent" || error("unresolved witness")
        f,g = hex2bytes(row["candidate_lut_hex"]),hex2bytes(row["public_lut_hex"])
        (bytes2hex(SHA.sha256(f)),row["sigma_hash"]) == checks[(row["source"],row["member"])] || error("witness refers to different input")
        bytes2hex(signature(w,f)) == bytes2hex(signature(w,g)) == row["sigma_hash"] || error("signature mismatch")
        verify_ea_witness(f,g,row["cols"],row["constant"]) || error("invalid EA map")
    end
    missing = 0
    for line in Iterators.drop(eachline(joinpath(root,"supplemental_luts.tsv")),1)
        hash,encoded = split(line,'\t')
        bytes2hex(signature(w,hex2bytes(encoded))) == hash || error("invalid supplement")
        missing += 1
    end
    missing == report["distinct_absent_signatures"] || error("supplement count differs")
    println("Verified ",length(report["witnesses"])," EA maps and ",missing," supplemental quadratic APN(s) without VBF")
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    length(ARGS) == 1 || error("expected evidence directory")
    verify_evidence(abspath(ARGS[1]))
end
