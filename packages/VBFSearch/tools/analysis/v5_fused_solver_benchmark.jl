"""Counterbalanced full-job comparison of native V5 and fused affine selection."""
module V5FusedSolverBenchmark
using VBF,VBFSearch,JSON3,SHA,Random,Statistics,Dates,Test
include("v5_fused_solver.jl")
include("v5_parent_provenance.jl")
const Q=VBF.QuadraticExtensions
const F=V5FusedSolver

"""Check solver parity on randomized affine systems, including contradictions."""
function check_solver(;seed=18105272,trials=2000)
    rng=Xoshiro(seed);checks=0
    for _ in 1:trials
        D=rand(rng,0:23);domain=UInt32(0):((UInt32(1)<<D)-UInt32(1))
        C=rand(rng,domain,rand(rng,0:100));t=rand(rng,domain)
        Z=filter(c->!Q.par(c&t),C)
        expected=isempty(Z) ? nothing : Q.solve_ones(Z,D)
        @test F.selected_ones(C,t,D)==expected
        checks+=1
    end
    checks
end

"""Use the previous frozen holdout job manifest to avoid new sample selection."""
function run(holdout,parents_file,output;limit=8)
    started=time();checks=check_solver()
    holdout_raw=JSON3.read(read(holdout,String));bytes=read(parents_file)
    bytes2hex(sha256(bytes))==holdout_raw["input_sha256"] || error("parent input changed")
    parents=JSON3.read(String(copy(bytes)))["parents"]
    receipt=JSON3.read(read(joinpath(dirname(parents_file),"provenance-validation.json"),String))
    receipt["complete"] && receipt["bindings"]["parents.json"]==bytes2hex(sha256(bytes)) || error("invalid receipt")
    byid=Dict(Int(p["parent_id"])=>p for p in parents)
    jobs=collect(Iterators.take(holdout_raw["records"],limit))
    G=Q.geometry(8);table=Q.PolarRankTable(G);wa=Q.V5Work(23);wb=Q.V5Work(23);wc=Q.V5Work(23)
    stable=(:Ss,:nX,:nX_used,:next_x,:du_reject,:nT,:key,:capped,:skipped,:ncand)
    records=Dict{String,Any}[]
    for (i,j) in enumerate(jobs)
        V=UInt32.(j["forms"]);need=Int(j["need"]);p=byid[Int(j["parent_id"])]
        parent=V5ParentProvenance.parent_component_space(hex2bytes(String(p["lut_hex"])))
        V5ParentProvenance.contained_five_space(parent,V) || error("incorrect parent association")
        if i==1
            Q.v5_extensions(G,V,need,wa;beta=Q.BETA8,max_x=8,max_kernel=23,du7_filter=:bitsets,rank_table=table)
            F.fused_v5_extensions(G,V,need,wb;beta=Q.BETA8,max_x=8,max_kernel=23,du7_filter=:bitsets,rank_table=table)
            F.control_v5_extensions(G,V,need,wc;beta=Q.BETA8,max_x=8,max_kernel=23,du7_filter=:bitsets,rank_table=table)
        end
        a=nothing;b=nothing;c=nothing;ta=nothing;tb=nothing;tc=nothing
        for which in (isodd(i) ? (:native,:fused,:control) : (:control,:fused,:native))
            if which===:native
                ta=@timed Q.v5_extensions(G,V,need,wa;beta=Q.BETA8,max_kernel=23,du7_filter=:bitsets,rank_table=table);a=ta.value
            elseif which===:control
                tc=@timed F.control_v5_extensions(G,V,need,wc;beta=Q.BETA8,max_kernel=23,du7_filter=:bitsets,rank_table=table);c=tc.value
            else
                tb=@timed F.fused_v5_extensions(G,V,need,wb;beta=Q.BETA8,max_kernel=23,du7_filter=:bitsets,rank_table=table);b=tb.value
            end
        end
        @test all(getproperty(a,k)==getproperty(b,k) for k in stable)
        @test all(getproperty(a,k)==getproperty(c,k) for k in stable)
        push!(records,Dict("parent_id"=>Int(j["parent_id"]),"forms"=>Int.(V),"need"=>need,
            "native_seconds"=>ta.time,"fused_seconds"=>tb.time,"control_seconds"=>tc.time,"speedup"=>ta.time/tb.time,"exact_parity"=>true,
            "native_bytes"=>ta.bytes,"fused_bytes"=>tb.bytes,"control_bytes"=>tc.bytes,
            "native_gc_seconds"=>ta.gctime,"fused_gc_seconds"=>tb.gctime,"control_gc_seconds"=>tc.gctime,
            "outputs"=>length(a.Ss),"candidates"=>a.ncand))
        println(JSON3.write(last(records)));flush(stdout)
    end
    report=Dict("schema"=>"vbfsearch-fused-affine-v5-benchmark-v1","created_utc"=>string(now(UTC))*"Z",
        "native_source_sha256"=>F.source_sha256,"tool_sha256"=>bytes2hex(open(sha256,@__FILE__)),
        "solver_sha256"=>VBFSearch.equivalence_solver_fingerprint(),"input_sha256"=>bytes2hex(sha256(bytes)),
        "randomized_solver_checks"=>checks,"elapsed_seconds"=>time()-started,"records"=>records,
        "paired_total_speedup"=>sum(r["native_seconds"] for r in records)/sum(r["fused_seconds"] for r in records),
        "control_total_speedup"=>sum(r["control_seconds"] for r in records)/sum(r["fused_seconds"] for r in records),
        "median_job_speedup"=>median(r["speedup"] for r in records))
    open(io->JSON3.pretty(io,report),output,"w");report
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && V5FusedSolverBenchmark.run(ARGS[1],ARGS[2],ARGS[3];limit=length(ARGS)>3 ? parse(Int,ARGS[4]) : 8)
