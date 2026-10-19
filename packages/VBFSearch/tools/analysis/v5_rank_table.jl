"""Isolated benchmark of ambient polar-rank lookup during V5 Fourier preparation.

The variant is generated from a pinned pre-table VBF routine, changing only the rank
evaluation to a checked UInt8 lookup. Neither package sources nor ledgers change.
Set `VBF_V5_BASELINE_SOURCE` and `VBF_V5_BASELINE_SHA256` when the native
routine already includes rank-table lookup.
"""
module V5RankTable
using VBF,VBFSearch,JSON3,SHA,Dates,Statistics
const Q=VBF.QuadraticExtensions
const SOURCE_FILE=get(ENV,"VBF_V5_BASELINE_SOURCE",joinpath(pkgdir(VBF),"src/constructions/quadratic_extensions.jl"))
const SOURCE=read(SOURCE_FILE,String)
if haskey(ENV,"VBF_V5_BASELINE_SOURCE")
    bytes2hex(SHA.sha256(SOURCE))==get(ENV,"VBF_V5_BASELINE_SHA256","") ||
        error("explicit rank-table baseline requires its exact VBF_V5_BASELINE_SHA256")
end
const ORIGINAL=let a=findfirst("function coset_bent_counts!",SOURCE), b=findfirst("\n# --- extensions through",SOURCE)
    SOURCE[first(a):first(b)-1]
end
const VARIANT=let text=ORIGINAL
    length(findall("beta::Vector{Int})",text))==1 || error("signature changed")
    length(findall("betap[(form_rank(G, y) >> 1)+1]",text))==1 || error("rank expression changed")
    text=replace(text,"function coset_bent_counts!"=>"function rank_table_coset_bent_counts!")
    text=replace(text,"beta::Vector{Int})"=>"beta::Vector{Int}, ranks::Vector{UInt8})")
    replace(text,"betap[(form_rank(G, y) >> 1)+1]"=>"betap[(Int(ranks[Int(y)+1]) >> 1)+1]")
end
Base.include_string(Q,VARIANT,"rank-table-variant.jl")

"Populate one read-only table with existing VBF polar-rank arithmetic."
function build_table(G)
    ranks=Vector{UInt8}(undef,1<<G.N);chunks=256;step=max(1,length(ranks)÷chunks)
    Threads.@threads for start in 0:step:length(ranks)-1
        for s in start:min(length(ranks)-1,start+step-1)
            @inbounds ranks[s+1]=UInt8(Q.form_rank(G,UInt32(s)))
        end
    end
    ranks
end

function benchmark(input,output;repeats=3)
    started=time();G=Q.geometry(8);t=time();ranks=build_table(G);build_seconds=time()-t
    jobs=JSON3.read(read(input,String))["jobs"];a=Int32[];b=Int32[];records=Dict{String,Any}[]
    for job in jobs
        V=UInt32.(job["forms"])
        original=Q.coset_bent_counts!(a,G,V,Q.BETA8)
        variant=Q.rank_table_coset_bent_counts!(b,G,V,Q.BETA8,ranks)
        a==b && original==variant || error("rank-table variant changes exact Fourier counts")
        ts=Float64[];vs=Float64[]
        for _ in 1:repeats
            t=time();Q.coset_bent_counts!(a,G,V,Q.BETA8);push!(ts,time()-t)
            t=time();Q.rank_table_coset_bent_counts!(b,G,V,Q.BETA8,ranks);push!(vs,time()-t)
            a==b || error("count buffer changed")
        end
        push!(records,Dict("parent_id"=>Int(job["parent_id"]),"b5"=>Int(job["b5"]),
            "original_seconds"=>ts,"table_seconds"=>vs,"speedup"=>median(ts)/median(vs),"all_count_entries_equal"=>true))
    end
    report=Dict("schema"=>"vbfsearch-ambient-rank-table-benchmark-v1","created_utc"=>string(now(UTC))*"Z",
        "input_sha256"=>bytes2hex(open(SHA.sha256,input)),"source_sha256"=>bytes2hex(SHA.sha256(SOURCE)),
        "variant_sha256"=>bytes2hex(SHA.sha256(VARIANT)),"table_bytes"=>length(ranks),
        "build_seconds"=>build_seconds,"elapsed_seconds"=>time()-started,"records"=>records,
        "scope"=>"Fourier bent-count preparation only; same exact count array, not a full-job or whole-campaign speedup")
    mkpath(dirname(output));open(io->JSON3.pretty(io,report),output,"w");report
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && V5RankTable.benchmark(ARGS[1],ARGS[2])
