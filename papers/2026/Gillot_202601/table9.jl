# Implements 9 — Extension of bent; Fact 6 and Table 9.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 9 — Extension of bent; Fact 6 and Table 9
#
# Pseudocode:
#   1. Build the thirteen primary Polujan–Pott bent roots and verify every nonzero component.
#   2. Enumerate bounded three-output completions and certify any known CCZ matches.
# VBF API used: apn_extensions, walsh_hadamard, partition_refinement_equivalence

const GL_BENT_ANFS = [
    ["ad+be+cf", "ae+af+bd+be+cd", "ad+ae+bd+be+bf+ce"],
    ["ad+be+cf", "ae+af+bd+be+cd", "ab+ad+ae+bd+be+bf+ce"],
    ["ad+be+cf", "ae+af+bd+be+cd", "ac+ad+bf+de"],
    ["ad+be+cf", "ae+af+bd+be+cd", "ad+ae+bd+be+bf+ce+abc"],
    ["ad+be+cf+abc", "ac+ae+bc+df+abd", "ac+bd+be+ef+abe"],
    ["ad+be+cf+abc", "ac+ae+bc+df+abd", "ab+ad+af+cd+df+ef+abf+acf+bdf"],
    ["ad+be+cf+abc", "ac+ae+bc+df+abd", "ab+ac+bd+be+ce+de+ef+abe+cde"],
    ["ab+ad+bf+ce+de+abc+bde", "ac+bc+bd+ce+ef+abf+bce", "af+bc+bf+ce+de+ef+abc+abd+bef"],
    ["ab+ad+bf+ce+de+abc+bde", "ac+bc+bd+ce+ef+abf+bce", "af+be+bf+ce+cf+de+ef+abc+abd+bcd+bef+cdf"],
    ["ad+bf+cd+ce+cf+de+df+abc+bde+cdf", "ab+ce+df+abd+acd+bce+bcf+bde", "ab+ac+be+ce+cf+de+abc+acd+bcf+bdf+cde"],
    ["ad+bf+cd+ce+cf+de+df+abc+bde+cdf", "ab+ce+df+abd+acd+bce+bcf+bde", "ab+ac+bd+be+cd+ce+cf+de+abc+acd+bcf+bdf+cde"],
    ["ad+bf+cd+ce+cf+de+df+abc+bde+cdf", "ab+ce+df+abd+acd+bce+bcf+bde", "ad+ae+af+bc+bf+ce+ef+abd+abe+abf+acf+ade+aef+bcf+bdf+cde"],
    ["ad+bf+cd+ce+cf+de+df+abc+bde+cdf", "ab+ce+df+abd+acd+bce+bcf+bde", "ac+ad+bd+cd+ce+cf+df+ef+abc+abe+ade+adf+bce+bef+cef+def"],
]

if !isdefined(@__MODULE__,:gl_kappa)
    include("helpers.jl")
end

"""Build and independently verify the 13 primary Polujan–Pott bent roots used in GL Section 9."""
function gl_bent_roots()
    roots=VBFTable{6,3,UInt8}[]
    for coordinates in GL_BENT_ANFS
        functions=gl_boolean_anf.(coordinates)
        F=VBFTable{6,3}([sum(Int(f.lut[x])<<(j-1) for (j,f) in enumerate(functions)) for x in 1:64])
        all(gl_kappa(gl_component(F,b))==1 for b in 1:7) || error("primary bent root verification failed")
        push!(roots,F)
    end
    return roots
end

"""Bounded three-coordinate extension of all 13 bent roots, GL Fact 6/Table 9."""
function gl_table9(;known_roots=Pair{String,SBox}[],limit=13,max_nodes=100000,
    max_solutions=20,max_comparisons=1000,timeout_seconds=60,seed=940,save_results=false)
    started=time_ns()
    rows=NamedTuple[]
    comparisons=0
    classification_complete=true
    complete=true
    for (i,G) in enumerate(Iterators.take(gl_bent_roots(),limit))
        remaining=timeout_seconds-(time_ns()-started)*1e-9
        if remaining<=0
            complete=false
            break
        end
        outcome=apn_extensions(G;max_nodes,max_solutions,timeout_seconds=remaining)
        complete &= outcome isa Exhausted
        matches=NamedTuple[]
        for F in search_solutions(outcome)
            remaining=timeout_seconds-(time_ns()-started)*1e-9
            if isempty(known_roots) || remaining<=0 || comparisons>=max_comparisons
                classification_complete=false
                continue
            end
            match=gl_classify_ccz(F,known_roots;max_nodes,
                max_comparisons=max_comparisons-comparisons,timeout_seconds=remaining,seed)
            comparisons+=length(match.checks)
            classification_complete &= match.status===:matched
            push!(matches,match)
        end
        push!(rows,(;label=i,source_lut=Int.(G.lut),complete=outcome isa Exhausted,
            completion_luts=[Int.(F.lut) for F in search_solutions(outcome)],
            nodes=nodes_visited(outcome),solutions=length(search_solutions(outcome)),
            stop_reason=outcome isa BudgetHit ? outcome.where_it_stopped.reason : :none,matches,
            proven_empty=proves_emptiness(outcome),elapsed_seconds=elapsed_seconds(outcome)))
    end
    complete &= length(rows)==13
    r=(;parameters=(;limit,max_nodes,max_solutions,max_comparisons,timeout_seconds,seed),complete,classification_complete,processed=length(rows),comparisons,rows,seed,
        normalization="affine/component evaluation pivots, first free output0or1; residual GL3 duplicates may remain",
        bent_source="Polujan and Pott, On design-theoretic aspects of Boolean and vectorial bent functions, arXiv:2003.12308v3, Appendix A",
        union_ea_classes_verified=false,elapsed_seconds=(time_ns()-started)*1e-9,
        stop_reason=complete ? :none : :budget)
    gl_save("table9",r;save_results)
    return r
end

function gl_table9_report(io::IO=stdout;kwargs...)
    return gl_report("Table 9 — bent extensions",gl_table9(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_table9_report(limit=1,max_nodes=50000,timeout_seconds=5)
end
