"""Bounded probability pilot of algebraic-core transfer and degree-two relaxation.

Root-parent input provenance is pinned by its existing validation receipt. One
maximizing V5 is uniform within each sampled queued parent, then four eligible
U6 cosets are uniform within that V5. These are clustered observations, not
independent draws from all U6 spaces or all future recursive parents.

A rank22 original-flat obstruction fixes its U6 annihilator exactly; literal
support reuse cannot cover any different U6. For arbitrary binary-linear maps,
rank, triangle count and triangle-component size are necessary invariants only.
Passing them does not establish an isomorphism or allow any pruning.
"""
module QuadraticCompletionCorePilot
using VBF,JSON3,SHA,Random,Dates
include("quadratic_completion_core.jl")
const K=QuadraticCompletionCore
const Q=VBF.QuadraticExtensions

"Rows of the degree-one/two Veronese embedding, with no constant coordinate."
function lifted_rows(flats,D)
    A=falses(length(flats),D*(D+1)÷2)
    for (row,c) in enumerate(flats)
        column=0
        for i in 0:D-1
            column+=1;A[row,column]=isodd(c>>i)
        end
        for i in 0:D-2,j in i+1:D-1
            column+=1;A[row,column]=isodd(c>>i)&&isodd(c>>j)
        end
    end
    A
end

"Necessary degree-two interpolation; inconsistency retains an odd-row witness."
function quadratic_lift_certificate(flats,D)
    start=time_ns();A=lifted_rows(flats,D)
    if VBF.solve_f2(A,trues(length(flats)))!==nothing
        return (;status="no_certificate",witness=Int[],seconds=(time_ns()-start)*1e-9)
    end
    equations=vcat(permutedims(A),trues(1,length(flats)))
    rhs=falses(size(equations,1));rhs[end]=true
    witness_vector=VBF.solve_f2(equations,rhs)
    witness_vector===nothing && error("inconsistency witness missing")
    witness=findall(witness_vector)
    isodd(length(witness)) && all(j->iseven(count(identity,A[witness,j])),axes(A,2)) ||
        error("odd Veronese witness did not replay")
    (;status="unsat",witness,seconds=(time_ns()-start)*1e-9)
end

"Triangle-hypergraph invariants preserved by every binary-linear embedding."
function triangle_invariants(flats)
    index=Dict(c=>i for (i,c) in enumerate(flats));adj=[Int[] for _ in flats];triangles=0
    for i in eachindex(flats),j in i+1:length(flats)
        k=get(index,flats[i]⊻flats[j],0)
        k>j || continue
        triangles+=1
        for (a,b) in ((i,j),(i,k),(j,k));push!(adj[a],b);push!(adj[b],a);end
    end
    seen=falses(length(flats));components=Int[]
    for root in eachindex(flats)
        seen[root] && continue
        todo=[root];seen[root]=true;count=0
        while !isempty(todo)
            vertex=pop!(todo);count+=1
            for neighbor in adj[vertex]
                seen[neighbor] && continue
                seen[neighbor]=true;push!(todo,neighbor)
            end
        end
        push!(components,count)
    end
    (;count=length(flats),triangles,largest_triangle_component=maximum(components;init=0))
end

"Pilot cheap necessary transfer tests; no unmatched candidate becomes a proof."
function pilot(samplepath,corepath,output;parents_limit=64,cosets_per_parent=4,
               seed=8102254,max_seconds=100.0)
    mkpath(dirname(output));proof_directory=joinpath(dirname(output),"pilot-proofs");mkpath(proof_directory)
    started=time();source=read(samplepath);raw=JSON3.read(String(copy(source)))
    receipt=JSON3.read(read(joinpath(dirname(samplepath),"provenance-validation.json"),String))
    receipt.complete && receipt.bindings["parents.json"]==bytes2hex(sha256(source)) || error("unvalidated parents")
    parents=[p for p in raw.parents if p.uniform_parent_sample&&p.queued_parent]
    rng=Xoshiro(seed);shuffle!(rng,parents);resize!(parents,min(parents_limit,length(parents)))
    core=JSON3.read(read(corepath,String));corefeatures=triangle_invariants(UInt32.(core.core.flats))
    coreambient=Set(UInt32.(core.original_flats));G=Q.geometry(8);buffer=Int32[]
    ranktable=Q.PolarRankTable(G);records=Any[];parent_records=Any[]
    K.D.solve((;r=2,D=2,flats=UInt32[1,2,3]);timeout_seconds=Inf)
    quadratic_lift_certificate(UInt32[1,2,3],2)
    for parent in parents
        time()-started>=max_seconds && break
        vi=rand(rng,eachindex(parent.maximizing_v5_forms));V=UInt32.(parent.maximizing_v5_forms[vi])
        parent_space=K.C.O.V5ParentProvenance.parent_component_space(hex2bytes(String(parent.lut_hex)))
        K.C.O.V5ParentProvenance.contained_five_space(parent_space,V) || error("parent containment")
        count(q->Q.form_rank(G,q)==8,Q.comp_forms(V))==52-parent.need || error("b5 mismatch")
        prep=time_ns();counts=Q.coset_bent_counts!(buffer,G,V,Q.BETA8;rank_table=ranktable)
        X=UInt32[i-1 for i in 2:length(buffer) if buffer[i]==Int(parent.need)*counts.scale]
        chosen=randperm(rng,length(X))[1:min(cosets_per_parent,length(X))]
        baseindices=K.C.O.flat_indices(G,V)
        push!(parent_records,(;parent_id=Int(parent.parent_id),v5_index=vi,V,
            eligible_cosets=length(X),chosen,preparation_seconds=(time_ns()-prep)*1e-9))
        for xi in chosen
            x=Q.lift(X[xi],counts.Qmask);U=first(Q.rref(vcat(V,x)))
            ambientindices=[fi for fi in baseindices if !Q.par(G.flats[fi]&x)]
            prior=K.C.O.inspect(G,U,ambientindices)
            p=K.S.problem(G,U);lookup_start=time_ns()
            features=triangle_invariants(p.flats)
            necessary=features.count>=corefeatures.count&&features.triangles>=corefeatures.triangles&&
                features.largest_triangle_component>=corefeatures.largest_triangle_component
            ambientset=Set(G.flats[ambientindices]);literal=all(c->c in ambientset,coreambient)
            lookup_seconds=(time_ns()-lookup_start)*1e-9
            lifted=quadratic_lift_certificate(p.flats,p.D)
            domain=nothing;domain_replayed=false
            if prior.status=="no_certificate" && time()-started<max_seconds
                result=K.D.solve(p;max_nodes=10000,timeout_seconds=0.02,capture_proof=true)
                domain_replayed=result.status=="unsat" && K.D.replay_unsat(p,result.proof)
                result.status=="unsat" && !domain_replayed && error("domain proof failed")
                proofpath=nothing
                if result.status=="unsat"
                    proofpath=joinpath(proof_directory,"$(parent.parent_id)-$xi.json.gz")
                    open(pipeline(`gzip -c`,stdout=proofpath),"w") do io
                        JSON3.write(io,(;U,r=p.r,D=p.D,flats=p.flats,proof=result.proof))
                    end
                end
                domain=(;status=result.status,nodes=result.nodes,seconds=result.seconds,proofpath)
            end
            push!(records,(;parent_id=Int(parent.parent_id),v5_index=vi,coset_index=xi,U,
                residual_flat_count=length(p.flats),prior_status=prior.status,features,
                literal_core_match=literal,necessary_embedding_features=necessary,lookup_seconds,
                quadratic_lift=lifted,domain,domain_replayed))
        end
    end
    result=(;created_utc=string(now(UTC)),seed,requested_parents=parents_limit,
        parents=length(parent_records),requested_cosets_per_parent=cosets_per_parent,
        sampled_cosets=length(records),complete=length(parent_records)==length(parents),
        sample_sha256=bytes2hex(sha256(source)),core_sha256=bytes2hex(open(sha256,corepath)),
        tool_sha256=bytes2hex(open(sha256,@__FILE__)),core_features=corefeatures,
        arbitrary_binary_embeddings_tested=false,
        embedding_warning="Necessary feature matches remain unknown; no transfer or pruning follows.",
        seconds=time()-started,parent_records,records)
    mkpath(dirname(output));write(output,JSON3.write(result))
    println(JSON3.write((;parents=result.parents,sampled_cosets=result.sampled_cosets,
        quadratic_lift_rejects=count(r->r.quadratic_lift.status=="unsat",records),
        literal_core_matches=count(r->r.literal_core_match,records),
        necessary_embedding_candidates=count(r->r.necessary_embedding_features,records),
        domains=Dict(s=>count(r->r.domain!==nothing&&r.domain.status==s,records) for s in ("sat","unsat","unknown")),
        seconds=result.seconds)))
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && QuadraticCompletionCorePilot.pilot(ARGS[1],ARGS[2],ARGS[3])
