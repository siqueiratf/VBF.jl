"""
Reproducible APN experiments consuming VBF mathematics and VBFCatalog references.

The current drivers search restricted constructions of quadratic (8,8)-APNs.
Experiment completion and reference absence always have an explicit finite scope.
"""
module VBFSearch
using VBF, VBFCatalog, SHA, TOML, Dates, Random, SQLite, DBInterface, CSV, JSON3, CodecZstd

"""Local run and research evidence, overridable with VBF_SEARCH_DATA_DIR."""
search_data_dir() = abspath(get(ENV,"VBF_SEARCH_DATA_DIR",joinpath(pkgdir(VBFSearch),"data")))

include("power.jl")
include("reference/equivalence.jl")
include("reference/classes.jl")
include("reference/classification.jl")
include("reference/snapshot.jl")
include("evidence.jl")
include("store.jl")
include("inputs.jl")
using .DiscoveryEvidence, .DiscoveryStore, .DiscoveryInputs
const Fourier = VBF.QuadraticExtensions
const BOOT_IMPLEMENTATION = Ref{Dict{String,String}}()

include("v5_reuse.jl")

include("config.jl")
include("drivers.jl")
include("run.jl")
include("audit.jl")
include("classify.jl")
include("status.jl")
include("operations.jl")
include("catalog.jl")
include("report.jl")
include("closure_store.jl")
include("closure_normalized.jl")
include("closure_ledger_v2.jl")
include("closure_ledger.jl")
include("closure_segments.jl")
include("closure.jl")
include("closure_portable.jl")
include("closure_upgrade.jl")
include("closure_reduce.jl")
include("closure_algorithms.jl")
include("closure_equivalence_snapshots.jl")
include("closure_equivalence.jl")
include("cli.jl")

export AuditedAPNReference, open_apn_reference, close_apn_reference, open_catalog_reference,
       reference_metadata, reference_contains_signature, reference_exact_lut_match,
       equivalence_solver_fingerprint, check_equivalence!, list_equivalence_checks,
       verify_equivalence_check, equivalence_checks_path,
       deduplicate_signature_buckets!, classify_signature_buckets!, classification_summary,
       populate_ccz_equivalence_classes!, ccz_class_representatives, curated_classes_path,
       search_data_dir, equivalence_evidence, verify_graph_witness, SearchConfig, search, resume, status, stop!, audit, validate, report,
       report_snapshot, candidate_properties, compare, classify, classify_snapshot, open_reference,
       close_reference, verify_comparison, verify_ccz_witness, verify_ea_witness,
       verify_certificate, publish, main, closure_init, closure_run!, closure_snapshot, closure_progress, closure_stop!,
       closure_upgrade, closure_reduce, closure_relocate!, closure_export_checkpoint,
       closure_verify_checkpoint, closure_seal_segments!, closure_rehydrate_segments!,
       closure_verify_segments, closure_segment_artifacts, V5CompletionCache, cached_v5_extensions!

function __init__()
    # Compute at process initialization, never bake a source identity into a cache.
    BOOT_IMPLEMENTATION[] = implementation_fingerprint()
end

end
