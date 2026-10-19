"""Bounded tests of a three-dimensional singular-subspace obstruction.

If a codimension-two quadratic component space vanishes on Λ²H for dim H=3,
two additional Boolean coordinates cannot give an APN restriction H→F₂².
The certificate is the seven decomposable flats of Λ²H, replayed exactly.
This analysis prototype does not alter construction routines or campaign state.
"""
module U6Obstructions
using VBF, VBFSearch, JSON3, Random, SHA, Dates
include(joinpath(@__DIR__,"v5_parent_provenance.jl"))
const Q = VBF.QuadraticExtensions

"All decomposable flats orthogonal to the supplied component forms."
flat_indices(G, U) = [i for (i,w) in enumerate(G.flats) if all(q -> !Q.par(w&q), U)]

"Replay a totally singular input three-space against the original forms."
function verify_certificate(G, U, H)
    length(H)==3 && VBF.rank_f2(UInt16.(H);nbits=G.n)==3 || return false
    all(!Q.par(Q.wedge(G.pair,G.n,Int(H[i]),Int(H[j])) & q)
        for i in 1:3 for j in i+1:3 for q in U)
end

"Check the existing point-count obstruction, then look for a singular three-space."
function inspect(G, U, indices=flat_indices(G,U);prioritize_du=true)
    points=zeros(Int,1<<G.n); first_other=zeros(Int,1<<G.n); second_other=zeros(Int,1<<G.n)
    for fi in indices
        triple=G.flatpts[fi]
        for p in triple
            points[p+1]+=1
            other=triple[1]==p ? triple[2] : triple[1]
            points[p+1]==1 && (first_other[p+1]=other)
            points[p+1]==2 && (second_other[p+1]=other)
        end
    end
    du=any(>(3),points)
    du && prioritize_du && return (;status="existing_du_obstruction",certificate=Int[],flats=length(indices))
    for p in 1:(1<<G.n)-1
        points[p+1]>=3 || continue
        H=[p,first_other[p+1],second_other[p+1]]
        if verify_certificate(G,U,H)
            return (;status="singular_three_space",certificate=H,flats=length(indices))
        end
    end
    (;status=du ? "existing_du_obstruction" : "no_certificate",certificate=Int[],flats=length(indices))
end

"Prepare one actual V5, then sample its eligible U6 cosets without completing them."
function pilot(samplepath,output;parents_limit=64,cosets_per_space=256,seed=520318,max_seconds=300.0)
    started=time();source=read(samplepath);raw=JSON3.read(String(copy(source)))
    receiptpath=joinpath(dirname(samplepath),"provenance-validation.json")
    receipt=JSON3.read(read(receiptpath,String))
    receipt["complete"] && receipt["bindings"]["parents.json"]==bytes2hex(SHA.sha256(source)) ||
        error("missing or mismatched validated-parent receipt")
    parents=[p for p in raw["parents"] if p["uniform_parent_sample"] && p["queued_parent"]]
    rng=Xoshiro(seed);shuffle!(rng,parents);resize!(parents,min(parents_limit,length(parents)))
    G=Q.geometry(8);buf=Int32[];records=Dict{String,Any}[]
    for p in parents
        time()-started>=max_seconds && break
        spaces=p["maximizing_v5_forms"];vi=rand(rng,1:length(spaces));V=UInt32.(spaces[vi]);need=Int(p["need"])
        parent=V5ParentProvenance.parent_component_space(hex2bytes(String(p["lut_hex"])))
        V5ParentProvenance.contained_five_space(parent,V) || error("V5 not contained in declared parent")
        count(q->Q.form_rank(G,q)==8,Q.comp_forms(V))==52-need || error("bent-count mismatch")
        t0=time();r=Q.coset_bent_counts!(buf,G,V,Q.BETA8)
        X=UInt32[i-1 for i in 2:length(buf) if buf[i]==need*r.scale]
        chosen=randperm(rng,length(X))[1:min(cosets_per_space,length(X))]
        C=flat_indices(G,V);outcomes=Dict("existing_du_obstruction"=>0,"singular_three_space"=>0,"no_certificate"=>0)
        witnesses=Dict{String,Any}[]
        for xi in chosen
            x=Q.lift(X[xi],r.Qmask);U=first(Q.rref(vcat(V,x)))
            indices=[fi for fi in C if !Q.par(G.flats[fi]&x)]
            found=inspect(G,U,indices);outcomes[found.status]+=1
            if found.status=="singular_three_space" && length(witnesses)<8
                push!(witnesses,Dict("coset_index"=>xi,"U"=>Int.(U),"input_three_space_basis"=>found.certificate))
            end
        end
        push!(records,Dict("parent_id"=>Int(p["parent_id"]),"maximizing_v5_count"=>length(spaces),
            "sampled_v5_index"=>vi,"b5"=>Int(p["b5"]),"eligible_cosets"=>length(X),
            "sampled_cosets"=>length(chosen),"outcomes"=>outcomes,"witnesses"=>witnesses,"seconds"=>time()-t0))
        println(JSON3.write(Dict("event"=>"obstruction_parent","parents"=>length(records),"seconds"=>time()-started)));flush(stdout)
    end
    summary=Dict("schema"=>"vbfsearch-singular-three-space-pilot-v1","created_utc"=>string(now(UTC))*"Z",
        "sample_sha256"=>bytes2hex(SHA.sha256(source)),"tool_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),
        "solver_sha256"=>VBFSearch.equivalence_solver_fingerprint(),"seed"=>seed,
        "parents"=>length(records),"requested_parents"=>parents_limit,"seconds"=>time()-started,
        "complete"=>length(records)==length(parents),"records"=>records,
        "outcomes"=>Dict(k=>sum(r["outcomes"][k] for r in records) for k in ("existing_du_obstruction","singular_three_space","no_certificate")),
        "scope"=>"One uniform maximizing V5 per sampled queued parent, then uniform eligible cosets. Parent clusters are not independent cosets. No APN completion searches.")
    mkpath(dirname(output));open(io->JSON3.pretty(io,summary),output,"w");summary
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && U6Obstructions.pilot(ARGS[1],ARGS[2];parents_limit=length(ARGS)>2 ? parse(Int,ARGS[3]) : 64)
