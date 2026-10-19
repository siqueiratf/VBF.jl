"""Bounded paired benchmark of exact odd-five filtering beyond native DU7."""
module OddFlatCircuitBenchmark
using VBF, JSON3, SHA, Statistics, Dates
include("odd_flat_circuit_prototype.jl")
const P=OddFlatCircuitPrototype
const Q=VBF.QuadraticExtensions

function parity(a,b)
    for name in (:Ss,:nX,:nX_used,:next_x,:du_reject,:nT,:key,:capped,:skipped)
        getproperty(a,name)==getproperty(b,name) || error("odd-circuit parity failed: $name")
    end
    a.ncand>=b.ncand || error("filter introduced a new candidate")
    true
end

function main(args)
    2<=length(args)<=3 || error("expected kernel-benchmark.json output.json [repeats=3]")
    document=JSON3.read(read(args[1],String),Dict{String,Any})
    repeats=length(args)==3 ? parse(Int,args[3]) : 3
    G=Q.geometry(8);work=Q.V5Work(23);rank_table=Q.PolarRankTable(G)
    beta=Q.BETA8;records=Dict{String,Any}[];start=time_ns()
    for job in document["jobs"]
        (time_ns()-start)*1e-9>120.0 && break
        V=UInt32.(job["forms"]);need=Int(job["need"])
        reference=Q.v5_extensions(G,V,need,work;beta,max_kernel=23,du7_filter=:bitsets,rank_table)
        clone=P.circuit_v5_extensions(G,V,need,work;beta,max_kernel=23,
            du7_filter=:bitsets,rank_table,circuit_filter=false)
        parity(reference,clone);reference.ncand==clone.ncand || error("disabled clone changed work")
        stats=P.CircuitStats()
        filtered=P.circuit_v5_extensions(G,V,need,work;beta,max_kernel=23,
            du7_filter=:bitsets,rank_table,circuit_stats=stats)
        parity(reference,filtered)
        native_seconds=Float64[];filtered_seconds=Float64[];preparation_seconds=Float64[]
        for repetition in 1:repeats
            if isodd(repetition)
                push!(native_seconds,@elapsed Q.v5_extensions(G,V,need,work;
                    beta,max_kernel=23,du7_filter=:bitsets,rank_table))
            end
            timed_stats=P.CircuitStats()
            push!(filtered_seconds,@elapsed P.circuit_v5_extensions(G,V,need,work;
                beta,max_kernel=23,du7_filter=:bitsets,rank_table,circuit_stats=timed_stats))
            push!(preparation_seconds,timed_stats.preparation_seconds)
            if iseven(repetition)
                push!(native_seconds,@elapsed Q.v5_extensions(G,V,need,work;
                    beta,max_kernel=23,du7_filter=:bitsets,rank_table))
            end
        end
        push!(records,Dict("parent_id"=>job["parent_id"],"forms"=>job["forms"],
            "need"=>need,"b5"=>job["b5"],"nX"=>reference.nX,
            "native_ncand"=>reference.ncand,"filtered_ncand"=>filtered.ncand,
            "candidate_system_reduction"=>1-filtered.ncand/max(reference.ncand,1),
            "positions_tested"=>stats.positions_tested,"positions_rejected"=>stats.positions_rejected,
            "circuit_count"=>stats.circuit_count,"discovery_complete"=>stats.discovery_complete,
            "states_bytes"=>stats.states_bytes,"discovery_seconds"=>stats.discovery_seconds,
            "preparation_seconds"=>preparation_seconds,
            "native_seconds"=>native_seconds,"filtered_seconds"=>filtered_seconds,
            "native_median_seconds"=>median(native_seconds),
            "filtered_median_seconds"=>median(filtered_seconds),
            "median_speedup"=>median(native_seconds)/median(filtered_seconds),
            "all_output_and_coverage_fields_match"=>true,
            "completion_spaces"=>length(reference.Ss)))
        println(JSON3.write(last(records)))
    end
    outdir=dirname(args[2]);mkpath(outdir)
    write(joinpath(outdir,"native-v5-body-used.jl"),P.SOURCE_BODY)
    report=Dict("schema"=>"odd-flat-circuit-benchmark-v1",
        "source"=>abspath(args[1]),"source_sha256"=>bytes2hex(open(sha256,args[1])),
        "tool_sha256"=>bytes2hex(open(sha256,@__FILE__)),
        "prototype_sha256"=>bytes2hex(open(sha256,joinpath(@__DIR__,"odd_flat_circuit_prototype.jl"))),
        "native_source_sha256"=>P.SOURCE_SHA256,"repeats"=>repeats,
        "created_utc"=>string(Dates.now(Dates.UTC)),"elapsed_seconds"=>(time_ns()-start)*1e-9,
        "scope"=>"Four descriptive full V5 jobs, includes circuit discovery/state preparation; no campaign writes",
        "complete"=>length(records)==length(document["jobs"]),"jobs"=>records)
    open(args[2],"w") do io;JSON3.pretty(io,report);end
end
end
if abspath(PROGRAM_FILE)==(@__FILE__)
    OddFlatCircuitBenchmark.main(ARGS)
end
