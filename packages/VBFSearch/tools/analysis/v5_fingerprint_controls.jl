"""
Replay positive controls on actual V5 spaces before using invariant buckets.

Each input space is conjugated by independently generated invertible input
maps using VBF APIs. The known map is replayed and both fingerprints must be
identical. This audits invariance on the campaign's high-bent-count spaces;
it does not estimate the frequency of equivalent spaces in the population.

Run with --project=docs/inspector:
  v5_fingerprint_controls.jl SAMPLE_JSON OUTPUT_JSON [CONJUGATES_PER_SPACE]
"""
module V5FingerprintControls
using VBF, JSON3, SHA, Random, Dates

"""Check real-data conjugates and retain explicit positive-map certificates."""
function fingerprint_controls(input,output;conjugates=2,seed=20261018)
    conjugates>0 || throw(ArgumentError("conjugates must be positive"))
    abspath(input)==abspath(output) && error("input and output must differ")
    raw=read(input)
    samples=JSON3.read(String(copy(raw)))
    G=VBF.QuadraticExtensions.geometry(8)
    rng=Xoshiro(seed)
    rows=Dict{String,Any}[]
    started=time()
    for sample in samples
        V=UInt32.(sample.forms)
        original=quadratic_space_fingerprint(G,V)
        for trial in 1:conjugates
            A=random_linear_permutation(rng,Val(8))
            W=transform_quadratic_space(G,V,A.cols)
            verify_quadratic_space_transporter(G,V,W,A.cols) ||
                error("generated positive transporter did not replay")
            transformed=quadratic_space_fingerprint(G,W)
            transformed==original || error("fingerprint failed a known equivalence")
            push!(rows,Dict("source_job_id"=>sample.job_id,"b5"=>sample.b5,
                "origin"=>sample.origin,"trial"=>trial,"input_columns"=>Int.(A.cols),
                "source_forms"=>Int.(V),"target_forms"=>Int.(W),
                "fingerprint"=>original,"transporter_replayed"=>true))
        end
    end
    sha256(read(input))==sha256(raw) || error("input changed during controls")
    report=Dict("schema"=>"vbfsearch-real-v5-fingerprint-controls-v1",
        "complete"=>true,"created_utc"=>string(now(UTC))*"Z",
        "sample_path"=>abspath(input),"sample_sha256"=>bytes2hex(sha256(raw)),
        "tool_sha256"=>bytes2hex(open(sha256,@__FILE__)),
        "fingerprint_source_sha256"=>bytes2hex(open(sha256,
            joinpath(pkgdir(VBF),"src/constructions/quadratic_space_fingerprint.jl"))),
        "julia_version"=>string(VERSION),"seed"=>seed,
        "source_spaces"=>length(samples),"conjugates_per_space"=>conjugates,
        "verified_controls"=>length(rows),"elapsed_seconds"=>time()-started,
        "records"=>rows)
    mkpath(dirname(abspath(output)))
    open(output*".tmp","w") do io; JSON3.pretty(io,report); end
    mv(output*".tmp",output;force=true)
    println(JSON3.write(Dict(k=>report[k] for k in
        ("complete","source_spaces","verified_controls","elapsed_seconds"))))
    report
end
end

if abspath(PROGRAM_FILE)==(@__FILE__)
    2<=length(ARGS)<=3 || error("SAMPLE_JSON OUTPUT_JSON [CONJUGATES_PER_SPACE]")
    V5FingerprintControls.fingerprint_controls(ARGS[1],ARGS[2];
        conjugates=length(ARGS)==3 ? parse(Int,ARGS[3]) : 2)
end
