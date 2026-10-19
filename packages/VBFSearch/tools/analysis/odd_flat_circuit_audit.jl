"""Exact odd-five-flat obstructions beyond pointwise DU7 pruning.

If distinct flats w1,...,w5 have xor zero, no linear functional v can take
value one on all five. Consequently V5+<x,t> has no APN completion whenever
both x and t annihilate their span. This is a replayable odd-dependence
certificate, not a hash or a sufficient APN test. Circuits with intersecting
input planes are already excluded by DU7, so this tool retains only disjoint
five-flat circuits when measuring additional work savings.

All geometry, RREF and extension decisions use existing VBF implementations.
The campaign is never opened for writing and no search is started.
"""
module OddFlatCircuitAudit
using VBF, JSON3, SHA, Dates
const Q=VBF.QuadraticExtensions

struct OddFiveCircuit
    flats::NTuple{5,UInt32}
    geometry_indices::NTuple{5,Int}
    basis::NTuple{4,UInt32}
end

"Read-only preparation of residual flats in the canonical V5 quotient."
function residual_flats(G,V)
    R,piv=Q.rref(UInt32.(V))
    _,mask=Q.pivots_masks(R,piv,G.N)
    C=UInt32[];indices=Int[]
    for (fi,w) in enumerate(G.flats)
        all(r->!Q.par(w&r),R) || continue
        push!(C,Q.pext(w,mask));push!(indices,fi)
    end
    (;C,indices,R,mask,D=G.N-length(R))
end

"Four machine words recording the three nonzero points of one input plane."
function point_mask(points)
    ntuple(k->foldl(|,(UInt64(1)<<(p&63) for p in points if (p>>6)+1==k);
        init=UInt64(0)),4)
end

"Verify disjoint input planes using the installed VBF flat incidences."
function pairwise_disjoint(masks,indices)
    seen=ntuple(_->UInt64(0),4)
    for index in indices
        m=masks[index]
        any(k->!iszero(seen[k]&m[k]),1:4) && return false
        seen=ntuple(k->seen[k]|m[k],4)
    end
    true
end

"Find exact five-element xor circuits by a pair/triple meet in the middle."
function odd_five_circuits(C,geometry_indices,G;
        maximum_circuits=100_000,max_seconds=30.0)
    length(C)==length(unique(C)) || throw(ArgumentError("flat coordinates must be distinct"))
    length(C)==length(geometry_indices) || throw(ArgumentError("flat incidence mismatch"))
    masks=[point_mask(G.flatpts[fi]) for fi in geometry_indices]
    pairs=Dict{UInt32,Vector{Tuple{Int,Int}}}()
    n=length(C);start=time_ns()
    for i in 1:n-1,j in i+1:n
        push!(get!(pairs,C[i]⊻C[j],Tuple{Int,Int}[]),(i,j))
    end
    circuits=OddFiveCircuit[];seen=Set{NTuple{4,UInt32}}()
    all_five=0;disjoint_five=0;complete=true
    for i in 1:n-4
        if (time_ns()-start)*1e-9>max_seconds
            complete=false;break
        end
        for j in i+1:n-3,k in j+1:n-2
            matches=get(pairs,C[i]⊻C[j]⊻C[k],nothing)
            matches===nothing && continue
            for (l,m) in matches
                k<l || continue
                all_five+=1
                indices=(i,j,k,l,m)
                pairwise_disjoint(masks,indices) || continue
                disjoint_five+=1
                flats=ntuple(a->C[indices[a]],5)
                iszero(reduce(⊻,flats)) || error("odd-circuit xor replay failed")
                rows=first(Q.rref(collect(flats)))
                length(rows)==4 || error("five distinct xor-zero vectors must have rank four")
                basis=Tuple(rows)
                basis in seen && continue
                push!(seen,basis)
                push!(circuits,OddFiveCircuit(flats,
                    ntuple(a->geometry_indices[indices[a]],5),basis))
                if length(circuits)>=maximum_circuits
                    complete=false;break
                end
            end
            complete || break
        end
        complete || break
    end
    (;circuits,all_five,disjoint_five,complete,seconds=(time_ns()-start)*1e-9)
end

"Return true only when the complete circuit is present in the residual system."
function rejects(circuit::OddFiveCircuit,x::UInt32,t::UInt32)
    all(w->!Q.par(w&x) && !Q.par(w&t),circuit.basis)
end

"A replayable JSON representation; quotient coordinates remain source-bound."
function circuit_record(circuit)
    Dict("flats"=>collect(circuit.flats),"geometry_indices"=>collect(circuit.geometry_indices),
        "basis"=>collect(circuit.basis))
end

function main(args)
    2<=length(args)<=3 || error("expected kernel-benchmark.json output.json [jobs=4]")
    document=JSON3.read(read(args[1],String),Dict{String,Any})
    jobs=document["jobs"];limit=length(args)==3 ? parse(Int,args[3]) : 4
    G=Q.geometry(8);results=Dict{String,Any}[]
    for job in jobs[1:min(length(jobs),limit)]
        f=residual_flats(G,job["forms"])
        audit=odd_five_circuits(f.C,f.indices,G)
        push!(results,Dict("parent_id"=>job["parent_id"],"forms"=>job["forms"],
            "b5"=>job["b5"],"flat_count"=>length(f.C),"all_five"=>audit.all_five,
            "disjoint_five"=>audit.disjoint_five,"distinct_spans"=>length(audit.circuits),
            "complete"=>audit.complete,"seconds"=>audit.seconds,
            "circuits"=>circuit_record.(audit.circuits)))
    end
    output=Dict("schema"=>"odd-flat-circuit-audit-v1","source"=>abspath(args[1]),
        "source_sha256"=>bytes2hex(open(sha256,args[1])),
        "tool_sha256"=>bytes2hex(open(sha256,@__FILE__)),
        "created_utc"=>string(Dates.now(Dates.UTC)),"jobs"=>results)
    mkpath(dirname(args[2]));open(args[2],"w") do io;JSON3.pretty(io,output);end
    for r in results;println(JSON3.write(Dict(k=>v for (k,v) in r if k!="circuits")));end
end
end

if abspath(PROGRAM_FILE)==(@__FILE__)
    OddFlatCircuitAudit.main(ARGS)
end
