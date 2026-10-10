# Implements 5.3 — Component of APN mapping; Fact 1 and Table 4.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 5.3 — Component of APN mapping; Fact 1 and Table 4
#
# Pseudocode:
#   1. Normalize Boolean components modulo affine functions and compute valid rejection invariants.
#   2. Classify by native EA searches with cached verified target groups; keep inconclusive results.
# VBF API used: partition_refinement_equivalence, partition_refinement_automorphisms, algebraic_degree, walsh_hadamard

if !isdefined(@__MODULE__,:gl_kappa)
    include("helpers.jl")
end
if !isdefined(@__MODULE__,:gl_restriction_kappa_signature)
    include("section2.jl")
end

const GL_TABLE4_MOMENTS = Set([1//1,7//4,5//2,13//4,4//1,19//4,17//2,16//1])

"""Classify component Boolean functions by certified EA searches, GL Fact 1/Table 4."""
function gl_table4(functions=[gold_apn(4)];limit=length(functions),max_comparisons=100000,
    max_nodes=100000,timeout_seconds=60,lift_algorithm=:spectral,seed=940,save_results=false)
    started=time_ns()
    classes=Any[]
    signatures=Any[]
    automorphisms=Any[]
    counts=Int[]
    known=Dict{Any,Int}()
    witnesses=NamedTuple[]
    moments=Dict{Rational{Int128},Int}()
    processed=0
    comparisons=0
    inconclusive=0
    parents_completed=0
    stopped=false
    for (parent,F) in enumerate(Iterators.take(functions,limit))
        for b in 1:(1<<outputbits(F))-1
            if (time_ns()-started)*1e-9>=timeout_seconds || comparisons>=max_comparisons
                stopped=true
                break
            end
            f=gl_normalize_boolean(gl_component(F,b))
            key=Tuple(f.lut)
            moment=gl_kappa(f)
            moments[moment]=get(moments,moment,0)+1
            processed+=1
            if haskey(known,key)
                counts[known[key]]+=1
                continue
            end
            signature=(gl_boolean_signature(f),gl_restriction_kappa_signature(f;algorithm=lift_algorithm))
            matched=0
            uncertain=false
            for j in eachindex(classes)
                signatures[j]==signature || continue
                comparisons>=max_comparisons && (uncertain=true;break)
                remaining=timeout_seconds-(time_ns()-started)*1e-9
                if remaining<=0
                    uncertain=true
                    break
                end
                outcome=partition_refinement_equivalence(f,classes[j];relation=:ea,
                    max_nodes,timeout_seconds=remaining,automorphisms=automorphisms[j],rng=Xoshiro(seed))
                comparisons+=1
                if !isempty(search_solutions(outcome))
                    A=first(search_solutions(outcome))
                    push!(witnesses,merge(gl_witness(f,classes[j],A),
                        (;parent,component=b,target_class=j)))
                    matched=j
                    break
                end
                outcome isa BudgetHit && (uncertain=true)
            end
            if matched>0
                known[key]=matched
                counts[matched]+=1
            elseif !uncertain
                push!(classes,f)
                push!(signatures,signature)
                push!(counts,1)
                known[key]=length(classes)
                remaining=timeout_seconds-(time_ns()-started)*1e-9
                push!(automorphisms,partition_refinement_automorphisms(f;relation=:ea,
                    max_nodes,timeout_seconds=max(0,remaining),rng=Xoshiro(seed)))
            else
                inconclusive+=1
            end
        end
        stopped && break
        parents_completed+=1
    end
    complete=!stopped && inconclusive==0 && parents_completed==min(limit,length(functions))
    full_sixbit=complete && parents_completed==716
    rows=[(;class=j,degree=algebraic_degree(f),moment=gl_kappa(f),multiplicity=counts[j],
        representative_lut=Int.(f.lut)) for (j,f) in enumerate(classes)]
    r=(;parameters=(;limit,max_comparisons,max_nodes,timeout_seconds,lift_algorithm,seed,equivalence_profile=:paper),complete,processed,input_sha256=gl_dataset_hash(functions),parents_completed,full_sixbit,comparisons,inconclusive,rows,
        moments=[(;moment=k,count=v) for (k,v) in sort!(collect(moments);by=first)],witnesses,
        agrees=full_sixbit && length(classes)==37 && Set(keys(moments))==GL_TABLE4_MOMENTS,
        lift_algorithm,seed,elapsed_seconds=(time_ns()-started)*1e-9,stop_reason=complete ? :none : :budget)
    gl_save("table4",r;save_results)
    return r
end

function gl_table4_report(io::IO=stdout;kwargs...)
    return gl_report("Table 4 — component Boolean classes",gl_table4(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_table4_report()
end
