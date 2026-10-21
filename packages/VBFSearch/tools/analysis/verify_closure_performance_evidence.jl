"""Verify fixed-work performance evidence against an archived identity manifest.

Usage: julia --project=FROZEN/docs/inspector verify_closure_performance_evidence.jl PROOF.json IDENTITY.toml OUTPUT.json
Reads source metadata only; no search database is opened or upgraded.
"""
module VerifyClosurePerformanceEvidence
using VBFSearch, JSON3, TOML, SHA

length(ARGS)==3 || error("expected proof, identity manifest, and output paths")
proof_path,identity_path,output_path=abspath.(ARGS)
identity=TOML.parsefile(identity_path)
implementation=VBFSearch.code_identity()
changed=sort!([path for path in union(keys(identity["implementation"]),keys(implementation))
    if get(identity["implementation"],path,nothing)!=get(implementation,path,nothing)])
result=VBFSearch._closure_performance_evidence(proof_path,identity,implementation,changed)
receipt=Dict("validated"=>true,"production_database_opened"=>false,"upgrade_performed"=>false,
    "proof"=>proof_path,"identity_manifest"=>identity_path,
    "identity_manifest_sha256"=>bytes2hex(sha256(read(identity_path))),
    "implementation"=>implementation,"julia"=>string(VERSION),"changed"=>changed,"result"=>result,
    "tool_sha256"=>bytes2hex(sha256(read(@__FILE__))))
open(output_path,"w") do io
    JSON3.pretty(io,receipt)
end
println(JSON3.write(Dict("validated"=>true,"changed_paths"=>length(changed),
    "proof_sha256"=>result["sha256"],"production_database_opened"=>false,"upgrade_performed"=>false)))
end
