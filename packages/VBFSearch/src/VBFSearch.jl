"""
Reproducible APN experiments consuming VBF mathematics and VBFCatalog references.

The current drivers search restricted constructions of quadratic (8,8)-APNs.
Experiment completion and reference absence always have an explicit finite scope.
"""
module VBFSearch
using VBF, VBFCatalog, SHA, TOML, Dates, Random, SQLite, DBInterface

include("evidence.jl")
include("store.jl")
include("inputs.jl")
using .DiscoveryEvidence, .DiscoveryStore, .DiscoveryInputs
const Fourier = VBF.QuadraticExtensions
const BOOT_IMPLEMENTATION = Ref{Dict{String,String}}()

include("config.jl")
include("drivers.jl")
include("run.jl")
include("audit.jl")
include("classify.jl")
include("status.jl")
include("operations.jl")
include("cli.jl")

export SearchConfig, search, resume, status, stop!, audit, validate, report,
       candidate_properties, compare, classify, classify_snapshot, open_reference,
       close_reference, verify_comparison, verify_ccz_witness, verify_ea_witness,
       verify_certificate, main

function __init__()
    # Compute at process initialization, never bake a source identity into a cache.
    BOOT_IMPLEMENTATION[] = implementation_fingerprint()
end

end
