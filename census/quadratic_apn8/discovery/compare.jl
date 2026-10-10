"""Compare two explicit hexadecimal LUT/ANF payloads; save a portable graph witness or scoped negative."""
const COMPARE_USAGE=nothing
include("evidence.jl")
include("inputs.jl")
using .DiscoveryEvidence,.DiscoveryInputs,TOML
function compare_cli(args)
    cfg=Dict("candidate"=>"","target"=>"","relation"=>"ccz","seconds"=>"30","nodes"=>"1000000","out"=>"")
    iseven(length(args)) || error("use --name VALUE pairs")
    for i in 1:2:length(args)
        key=replace(args[i],r"^--"=>"");haskey(cfg,key) || error("unknown option $key")
        cfg[key]=args[i+1]
    end
    all(k->!isempty(cfg[k]),("candidate","target","out")) || error("--candidate HEX --target HEX --out FILE required")
    proof=compare(Existing.candidate_lut(cfg["candidate"]),Existing.candidate_lut(cfg["target"]);
        relation=Symbol(cfg["relation"]),timeout_seconds=parse(Float64,cfg["seconds"]),max_nodes=parse(Int,cfg["nodes"]))
    mkpath(dirname(abspath(cfg["out"])))
    open(io->TOML.print(io,proof;sorted=true),cfg["out"],"w")
    println(proof["status"])
    proof
end
abspath(PROGRAM_FILE)==(@__FILE__) && compare_cli(ARGS)
