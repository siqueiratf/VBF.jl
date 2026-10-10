"""Replay an EA or CCZ graph map independently of the equivalence solver."""
function verify_graph_witness(F,G,A::F2AffineMap;relation::Symbol=:ea)
    relation in (:ea,:ccz) || throw(ArgumentError("relation must be EA or CCZ"))
    inputbits(F)==inputbits(G)==outputbits(F)==outputbits(G) && inputbits(A)==2inputbits(F) || return false
    verifier=relation==:ea ? verify_ea_witness : verify_ccz_witness
    verifier(F.lut,G.lut,Int.(A.linear.cols),Int(A.constant))
end

"""Exact solver outcome with independently checked positive witnesses.
Budget exhaustion remains inconclusive; finite exhaustion is implementation-dependent.
"""
function equivalence_evidence(F,G;timeout_seconds::Real=2,max_nodes::Int=100_000,relation::Symbol=:ea)
    relation in (:ea,:ccz) || throw(ArgumentError("relation must be EA or CCZ"))
    timeout_seconds>=0 && max_nodes>=0 || throw(ArgumentError("nonnegative equivalence budgets required"))
    inputbits(F)==inputbits(G)==outputbits(F)==outputbits(G) || throw(ArgumentError("different or nonsquare dimensions"))
    1<=inputbits(F)<=16 || throw(ArgumentError("witness evidence supports square dimensions 1:16"))
    if F.lut==G.lut
        A=F2AffineMap(identity_linear_map(2inputbits(F)),0)
        verify_graph_witness(F,G,A;relation) || error("identity certificate failed")
        return Dict("status"=>"identical_lut","columns"=>Int.(A.linear.cols),"constant"=>0)
    end
    result=partition_refinement_equivalence(F,G;relation,timeout_seconds,max_nodes)
    if result isa Found
        A=first(result.functions)
        verify_graph_witness(F,G,A;relation) || error("solver certificate failed independent replay")
        return Dict("status"=>"$(relation)_equivalent_witness_replayed","columns"=>Int.(A.linear.cols),"constant"=>Int(A.constant),"nodes"=>result.nodes_visited,"elapsed_seconds"=>result.elapsed_seconds)
    end
    Dict("status"=>result isa Exhausted ? "exhaustive_$(relation)_inequivalent" : "inconclusive_budget",
         "nodes"=>result.nodes_visited,"elapsed_seconds"=>result.elapsed_seconds,
         "stop"=>result isa Exhausted ? "none" : string(result.where_it_stopped.reason))
end
