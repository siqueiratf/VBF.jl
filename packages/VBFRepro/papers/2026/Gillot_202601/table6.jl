# Implements 7 — Two switchings; Fact 4 and Table 6.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 7 — Two switchings; Fact 4 and Table 6
#
# Pseudocode:
#   1. Enumerate codimension-two output subspaces and construct their rectangular projections.
#   2. Apply necessary tests, bounded normalized completions and certified known-root comparisons.
# VBF API used: extract_linear_subspaces_bounded, apn_extensions, partition_refinement_equivalence

if !isdefined(@__MODULE__,:gl_kappa)
    include("helpers.jl")
end

"""Enumerate bounded codimension-two projections and APN completions, GL Fact 4/Table 6."""
function gl_table6(functions=[gold_apn(4)];known_roots=Pair{String,SBox}[],limit=length(functions),
    max_subfunctions=10,max_nodes=10^6,max_solutions=20,max_comparisons=1000,
    timeout_seconds=60,seed=940,max_subfunctions_per_parent=typemax(Int),save_results=false)
    started=time_ns()
    records=NamedTuple[]
    subfunctions=0
    solutions=0
    comparisons=0
    complete=true
    classification_complete=true
    for (parent,F) in enumerate(Iterators.take(functions,limit))
        N=inputbits(F)
        N>=3 || throw(ArgumentError("two-coordinate projections require N≥3"))
        remaining=timeout_seconds-(time_ns()-started)*1e-9
        if remaining<=0 || subfunctions>=max_subfunctions
            complete=false
            break
        end
        spaces=extract_linear_subspaces_bounded(UInt32.(1:(1<<N)-1),N-2;
            max_bits=N,max_nodes,timeout_seconds=remaining,algorithm=:optimized)
        spaces isa Exhausted || (complete=false)
        local_subfunctions=0
        for basis in search_solutions(spaces)
            if local_subfunctions>=max_subfunctions_per_parent
                complete=false
                break
            end
            remaining=timeout_seconds-(time_ns()-started)*1e-9
            if remaining<=0 || subfunctions>=max_subfunctions
                complete=false
                break
            end
            G=VBFTable{N,N-2}([sum(parity(Int(v)&Int(b))<<(j-1) for (j,b) in enumerate(basis)) for v in F.lut])
            outcome=apn_extensions(G;max_nodes,max_solutions,timeout_seconds=remaining)
            subfunctions+=1
            local_subfunctions+=1
            complete &= outcome isa Exhausted
            matches=NamedTuple[]
            for H in search_solutions(outcome)
                solutions+=1
                remaining=timeout_seconds-(time_ns()-started)*1e-9
                if isempty(known_roots) || remaining<=0 || comparisons>=max_comparisons
                    classification_complete=false
                    continue
                end
                match=gl_classify_ccz(H,known_roots;max_nodes,
                    max_comparisons=max_comparisons-comparisons,timeout_seconds=remaining,seed)
                comparisons+=length(match.checks)
                classification_complete &= match.status===:matched
                push!(matches,match)
            end
            push!(records,(;parent,basis=Int.(basis),projection_lut=Int.(G.lut),
                completion_luts=[Int.(H.lut) for H in search_solutions(outcome)],
                complete=outcome isa Exhausted,stop_reason=outcome isa BudgetHit ? outcome.where_it_stopped.reason : :none,
                nodes=nodes_visited(outcome),solutions=length(search_solutions(outcome)),matches))
        end
    end
    expected=sum((inputbits(F)>=3 ? ((big(1)<<inputbits(F))-1)*
        ((big(1)<<inputbits(F))-2)÷6 : big(0) for F in Iterators.take(functions,limit));init=big(0))
    complete &= subfunctions==expected
    r=(;parameters=(;limit,max_subfunctions,max_subfunctions_per_parent,max_nodes,max_solutions,max_comparisons,timeout_seconds,seed),complete,classification_complete,processed=subfunctions,expected,solutions,comparisons,records,
        input_sha256=gl_dataset_hash(functions),seed,elapsed_seconds=(time_ns()-started)*1e-9,
        stop_reason=complete ? :none : :budget,full_known_closure=complete && classification_complete &&
            length(functions)==716 && limit>=716)
    gl_save("table6",r;save_results)
    return r
end

function gl_table6_report(io::IO=stdout;kwargs...)
    return gl_report("Table 6 — two-coordinate extensions",gl_table6(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_table6_report(max_subfunctions=1,max_nodes=100000)
end
