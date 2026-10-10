import TOML

"""Check an affine graph map through VBF; EA also preserves the output subspace.

Positive graph witnesses can be replayed through VBF. Exhaustive negatives
depend on the recorded solver implementation; a budget stop proves nothing.
These checks do not assert completeness of a reference corpus.
"""
function verify_graph_witness(F,G,A::F2AffineMap;relation::Symbol=:ea)
    relation in (:ea,:ccz) || throw(ArgumentError("relation must be EA or CCZ"))
    inputbits(F)==inputbits(G)==outputbits(F)==outputbits(G) && inputbits(A)==2inputbits(F) || return false
    is_invertible(A.linear) || return false
    relation==:ea && !all(iszero(c>>inputbits(F)) for c in A.linear.cols[1:inputbits(F)]) && return false
    ccz_equivalent_function(F,A)==G
end

"""Exact solver outcome with a replayed positive witness; budget stops stay inconclusive."""
function equivalence_evidence(F,G;timeout_seconds::Real=2,max_nodes::Int=100_000,
    max_memory_bytes::Int=512*1024^2,relation::Symbol=:ea)
    relation in (:ea,:ccz) || throw(ArgumentError("relation must be EA or CCZ"))
    timeout_seconds>=0 && max_nodes>=0 && max_memory_bytes>=0 ||
        throw(ArgumentError("nonnegative equivalence budgets required"))
    inputbits(F)==inputbits(G)==outputbits(F)==outputbits(G) || throw(ArgumentError("different or nonsquare dimensions"))
    1<=inputbits(F)<=16 || throw(ArgumentError("witness evidence supports square dimensions 1:16"))
    if F.lut==G.lut
        A=F2AffineMap(identity_linear_map(2inputbits(F)),0)
        verify_graph_witness(F,G,A;relation) || error("identity certificate failed")
        return Dict("status"=>"identical_lut","columns"=>Int.(A.linear.cols),"constant"=>0)
    end
    result=partition_refinement_equivalence(F,G;relation,timeout_seconds,max_nodes,max_memory_bytes)
    if result isa Found
        A=first(result.functions)
        verify_graph_witness(F,G,A;relation) || error("solver certificate failed graph replay")
        return Dict("status"=>"$(relation)_equivalent_witness_replayed","columns"=>Int.(A.linear.cols),
            "constant"=>Int(A.constant),"nodes"=>result.nodes_visited,"elapsed_seconds"=>result.elapsed_seconds)
    end
    Dict("status"=>result isa Exhausted ? "exhaustive_$(relation)_inequivalent" : "inconclusive_budget",
        "nodes"=>result.nodes_visited,"elapsed_seconds"=>result.elapsed_seconds,
        "stop"=>result isa Exhausted ? "none" : string(result.where_it_stopped.reason))
end

"""Content digest of VBF's Julia sources, binding implementation-dependent negatives."""
function equivalence_solver_fingerprint()
    root=joinpath(pkgdir(VBF),"src")
    paths=sort!([joinpath(d,f) for (d,_,files) in walkdir(root) for f in files if endswith(f,".jl")])
    bytes2hex(SHA.sha256(join([relpath(p,root)*":"*bytes2hex(open(SHA.sha256,p)) for p in paths],"\n")))
end

"""Return a canonical pair orientation and its dimension-bound content addresses."""
function _equivalence_pair(F::SBox,G::SBox)
    inputbits(F)==inputbits(G) || throw(ArgumentError("different dimensions"))
    1<=inputbits(F)<=16 || throw(ArgumentError("supported dimensions are 1:16"))
    a,b=lut_sha256_hex(F),lut_sha256_hex(G)
    a<=b ? (F,G,a,b) : (G,F,b,a)
end

"""
    list_equivalence_checks(db, F, G; relation=:ccz)

Return all attempts for these exact square LUTs, newest first. Rows contain
SQL-queryable status, solver digest and time, plus TOML parameters and evidence.
The stored witness always maps `left_sha256` to `right_sha256`, independent of
the caller's order. Bulk members and curated entries use the same LUT hashes.
"""
function list_equivalence_checks(db::SQLite.DB,F::SBox,G::SBox;relation::Symbol=:ccz)
    relation in (:ea,:ccz) || throw(ArgumentError("relation must be EA or CCZ"))
    _,_,a,b=_equivalence_pair(F,G)
    [NamedTuple(r) for r in DBInterface.execute(db,
        "SELECT * FROM equivalence_checks WHERE n=? AND left_sha256=? AND right_sha256=? AND relation=? ORDER BY id DESC",
        (inputbits(F),a,b,string(relation)))]
end

"""
    verify_equivalence_check(row, F, G) -> Bool

Bind a stored positive check to the supplied LUTs and replay its graph witness
through VBF. Returns false for malformed evidence, negatives and budget stops.
An exhaustive negative is computational evidence, not a replayable certificate.
"""
function verify_equivalence_check(row,F::SBox,G::SBox)
    try
        left,right,a,b=_equivalence_pair(F,G)
        row.n==inputbits(F) && row.left_sha256==a && row.right_sha256==b || return false
        row.status=="equivalent" && row.relation in ("ea","ccz") || return false
        proof=TOML.parse(row.evidence)
        proof["status"] in ("identical_lut","$(row.relation)_equivalent_witness_replayed") || return false
        cols,constant=proof["columns"],proof["constant"]
        d=2inputbits(F); mask=(UInt64(1)<<d)-1
        length(cols)==d && all(x->x isa Integer && 0<=x<=mask,cols) || return false
        constant isa Integer && 0<=constant<=mask || return false
        A=F2AffineMap(F2LinearMap(UInt32.(cols)),UInt32(constant))
        verify_graph_witness(left,right,A;relation=Symbol(row.relation))
    catch err
        err isa InterruptException && rethrow()
        false
    end
end

"""
    check_equivalence!(db, F, G; relation=:ccz, timeout_seconds=30,
        max_nodes=1_000_000, max_memory_bytes=512*1024^2, reuse=true)

Run the native VBF solver and append its outcome to the catalog, returning the
stored row. Reuses replayable positives and exhaustive negatives from identical
VBF sources and Julia version. Inconclusive attempts are retained and retried.
Pass `reuse=false` to record a fresh attempt. EA negatives apply to CCZ only
with an additional mathematical argument, e.g. both functions are quadratic APN.
No LUTs are inserted into the curated functions table and no classes are merged.
"""
function check_equivalence!(db::SQLite.DB,F::SBox,G::SBox;relation::Symbol=:ccz,
    timeout_seconds::Real=30,max_nodes::Int=1_000_000,max_memory_bytes::Int=512*1024^2,reuse::Bool=true)
    relation in (:ea,:ccz) || throw(ArgumentError("relation must be EA or CCZ"))
    timeout_seconds>=0 && max_nodes>=0 && max_memory_bytes>=0 ||
        throw(ArgumentError("nonnegative equivalence budgets required"))
    left,right,a,b=_equivalence_pair(F,G)
    solver=equivalence_solver_fingerprint()
    if reuse
        for row in list_equivalence_checks(db,F,G;relation)
            verify_equivalence_check(row,F,G) && return row
            if row.status=="inequivalent" && row.solver_sha256==solver && row.julia_version==string(VERSION)
                proof=TOML.parse(row.evidence)
                proof["status"]=="exhaustive_$(relation)_inequivalent" && return row
            end
        end
    end
    proof=equivalence_evidence(left,right;relation,timeout_seconds,max_nodes,max_memory_bytes)
    status=haskey(proof,"columns") ? "equivalent" :
        startswith(proof["status"],"exhaustive_") ? "inequivalent" : "inconclusive"
    params=Dict("timeout_seconds"=>Float64(timeout_seconds),"max_nodes"=>max_nodes,
        "max_memory_bytes"=>max_memory_bytes,"algorithm"=>"paper","rng_seed"=>940,
        "solver"=>"VBF.partition_refinement_equivalence")
    serialize(x)=sprint(io->TOML.print(io,x;sorted=true))
    SQLite.execute(db,"INSERT INTO equivalence_checks(n,left_sha256,right_sha256,relation,status,solver_sha256,julia_version,created_utc,parameters,evidence) VALUES(?,?,?,?,?,?,?,?,?,?)",
        (inputbits(F),a,b,string(relation),status,solver,string(VERSION),_utc_now_iso(),serialize(params),serialize(proof)))
    id=only(Int(r.id) for r in DBInterface.execute(db,"SELECT last_insert_rowid() id"))
    only(NamedTuple(r) for r in DBInterface.execute(db,"SELECT * FROM equivalence_checks WHERE id=?",(id,)))
end
