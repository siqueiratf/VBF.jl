# Saved proposal witnesses are checked through VBF's graph APIs.
include(joinpath(@__DIR__, "..", "..", "..", "VBFSearch", "src", "verification", "ea_witness.jl"))
using .GraphWitnesses: verify_proposal_witnesses

if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==1 || error("usage: julia verify_proposal_witnesses.jl REPORT.toml")
    println(verify_proposal_witnesses(only(ARGS)))
end
