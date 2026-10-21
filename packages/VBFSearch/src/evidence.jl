"""Auditable eight-bit APN properties, corpus comparisons and affine graph certificates."""
module DiscoveryEvidence
using VBF, VBFCatalog, SHA, TOML, Dates
using ..VBFSearch: equivalence_evidence, equivalence_solver_fingerprint, AuditedAPNReference,
    _EquivalenceSolverSession,
    open_apn_reference, close_apn_reference, reference_metadata,
    reference_contains_signature, reference_exact_lut_match
include("verification/ea_witness.jl")
using .GraphWitnesses
using ..APNPowerEvidence
export equivalence_evidence, verify_graph_witness, properties, open_reference, close_reference, classify, compare, verify_comparison,
       verify_ccz_witness, verify_ea_witness, lut_id, filehash, Reference

filehash(path) = bytes2hex(open(SHA.sha256,path))
lut_id(lut) = bytes2hex(SHA.sha256(UInt8.(lut)))

"""Bounded exact-LUT property cache, optionally shared within one execution.

Values are copied at the boundary so callers cannot mutate previously verified
properties. Cache keys retain every input byte, including the detailed mode.
Miss calculations and boundary copies run outside the lock. Concurrent misses
may repeat mathematics, but retain only one verified entry for each exact key.
"""
mutable struct PropertyCache
    max_entries::Int
    values::Dict{Tuple{String,Bool},Dict{String,Any}}
    order::Vector{Tuple{String,Bool}}
    guard::ReentrantLock
    hits::Int
    misses::Int
end

"""Allocate an empty bounded property cache; zero entries disables retention."""
function PropertyCache(;max_entries::Integer=64)
    max_entries>=0 || throw(ArgumentError("nonnegative property cache capacity required"))
    PropertyCache(Int(max_entries),Dict{Tuple{String,Bool},Dict{String,Any}}(),
        Tuple{String,Bool}[],ReentrantLock(),0,0)
end

"""Read or populate a cache without allowing mutable results to poison it."""
function _cached_properties(cache::PropertyCache,lut,detailed)
    length(lut)==256 && all(x->x isa Integer && 0<=x<=255,lut) || error("expected 256 bytes")
    bytes=UInt8.(lut);key=(bytes2hex(bytes),Bool(detailed))
    cached=lock(cache.guard) do
        value=get(cache.values,key,nothing)
        if value===nothing
            cache.misses+=1
        else
            cache.hits+=1
        end
        value
    end
    cached===nothing || return deepcopy(cached)
    result=properties(bytes;detailed)
    cache.max_entries==0 && return result
    owned=deepcopy(result)
    lock(cache.guard) do
        if !haskey(cache.values,key)
            if length(cache.values)>=cache.max_entries
                delete!(cache.values,popfirst!(cache.order))
            end
            cache.values[key]=owned
            push!(cache.order,key)
        end
    end
    result
end

"""Compute candidate properties through VBF's public mathematical APIs."""
function properties(lut; detailed=false,cache::Union{Nothing,PropertyCache}=nothing)
    cache===nothing || return _cached_properties(cache,lut,detailed)
    length(lut)==256 && all(x->x isa Integer && 0<=x<=255,lut) || error("expected 256 bytes")
    f=UInt8.(lut);F=SBox{8}(f)
    degree=algebraic_degree(F);spectrum=differential_spectrum(F)
    uniformity=maximum(first,spectrum);failure=Dict{String,Any}()
    if uniformity>2
        D=ddt(F);index=findfirst(>(2),@view D[2:end,:])
        a,b=Tuple(index);b-=1
        failure=Dict("a"=>a,"b"=>b,"solutions"=>[x for x in 0:255 if F(x)⊻F(x⊻a)==b])
    end
    result=Dict{String,Any}("lut_sha256"=>lut_id(f),"lut_hex"=>bytes2hex(f),
        "n"=>8,"m"=>8,"apn"=>uniformity==2,"differential_uniformity"=>uniformity,
        "algebraic_degree"=>degree,"quadratic"=>degree==2,
        "ddt_histogram"=>[Dict("value"=>Int(v),"count"=>Int(c)) for (v,c) in VBF.sorted_pairs(spectrum)],
        "verification"=>"VBF differential spectrum, algebraic degree and ortho-derivative signature",
        "literature_novelty"=>"unresolved","non_apn_witness"=>failure)
    if uniformity==2 && degree==2
        pi=ortho_derivative(F)
        result["sigma_hash"]=VBF.sigma_hash_from_ortho_derivative(pi)
        result["ortho_lut_hex"]=bytes2hex(UInt8.(pi.lut))
        result["sigma_definition"]="SHA256 of differential and absolute-Walsh histograms of the ortho-derivative; v1"
    end
    if detailed
        result["linearity"]=Int(linearity(F));result["nonlinearity"]=Int(nonlinearity(F))
        result["absolute_walsh_spectrum"]=[Dict("value"=>Int(v),"count"=>Int(c)) for (v,c) in VBF.sorted_pairs(absolute_walsh_spectrum(F))]
        coeffs=anf(F)
        result["anf"]=[Dict("input_mask"=>x,"output_coefficient"=>Int(coeffs[x+1])) for x in 0:255 if coeffs[x+1]!=0]
    end
    result
end

const Reference = AuditedAPNReference

"""Cover every eight-bit Gold exponent (gcd(k,8)=1), check each representative with VBF."""
function gold_coverage()
    [begin
        k=row.k;exponent=row.exponent
        p=properties(row.F.lut)
        p["apn"] && p["quadratic"] || error("invalid Gold representative")
        Dict("k"=>k,"exponent"=>exponent,"modulus"=>0x11d,
            "sigma_hash"=>p["sigma_hash"],"lut_sha256"=>p["lut_sha256"])
    end for row in build_gold_coverage(8;modulus=285).records]
end

"""Require a source-rebuilt reference; freeze its scope and digests, never fall back to an old index."""
function open_reference(dir; supplement_path=get(ENV,"VBF_APN_SUPPLEMENT",""),sources=nothing)
    gold=gold_coverage()
    checker=function(f)
        p=properties(f)
        p["apn"] && p["quadratic"] || error("invalid public supplement")
        p["sigma_hash"]
    end
    r=open_apn_reference(dir;supplement_path,supplement_signature=checker,
        required_signatures=[p["sigma_hash"] for p in gold],sources)
    r.metadata["gold_coverage"]=gold
    r
end

close_reference(r) = close_apn_reference(r)

"""A sigma match is a filter; an absent sigma separates only the documented quadratic corpus."""
function classify(lut,r::Reference; detailed=false)
    p = properties(lut;detailed)
    p["reference"] = reference_metadata(r)
    if !p["apn"]
        p["evidence_level"] = "not_apn"
    elseif !p["quadratic"]
        p["evidence_level"] = "apn_verified_reference_comparison_unavailable"
    else
        hash = p["sigma_hash"]
        hit = reference_contains_signature(r,hash)
        p["evidence_level"] = hit ? "invariant_match_unresolved_equivalence" : "inequivalent_to_documented_quadratic_corpus"
        p["reference_signature_match"] = hit
        p["equivalence"] = "unresolved"
        gold_match=any(row->row["sigma_hash"]==hash,reference_metadata(r)["gold_coverage"])
        p["apn_power_function_comparison"]=gold_match ? "unresolved_gold_invariant_match" : "inequivalent_to_all_apn_power_functions"
        p["power_function_justification"]=Dict("theorem"=>"Yoshiara 2016, Theorem 2; quadratic APN CCZ-equivalent to a power APN implies EA-equivalent to a Gold function",
            "doi"=>"10.1007/s10801-016-0680-z","gold_k"=>[1,3,5,7],"gold_invariant_match"=>gold_match)
        if reference_exact_lut_match(r,hash,lut)
            p["evidence_level"] = "exact_public_lut_match"
            p["equivalence"] = "identical_public_function"
        end
    end
    p
end

# Exhaustive negative outcomes are implementation-dependent; cache them only
# against the exact mathematical solver sources, while positive maps are checked through VBF's graph API.
solver_fingerprint() = equivalence_solver_fingerprint()
solver_fingerprint(::Nothing) = solver_fingerprint()
solver_fingerprint(session::_EquivalenceSolverSession) = session.solver_sha256
_evidence_fingerprint(::Nothing) = filehash(@__FILE__)
_evidence_fingerprint(session::_EquivalenceSolverSession) = session.evidence_sha256

"""Return a checked positive map, a separating invariant, exhaustive negative, or inconclusive budget."""
function compare(f,g;relation=:ccz,timeout_seconds=30,max_nodes=1_000_000)
    relation in (:ea,:ccz) || error("relation must be ea or ccz")
    pf,pg = properties(f),properties(g)
    _compare_verified_properties(f,g,pf,pg;relation,timeout_seconds,max_nodes)
end

"""Reuse locally verified properties inside the trusted worker boundary.

This private helper is never fed transported property claims: its callers first
run `properties` on each LUT, optionally through an exact-LUT compute cache.
Exact byte identities are checked here so a verified property record cannot
accidentally be paired with another candidate or target.
Public `compare` always performs both property calculations itself. Solver
fingerprints, bounded native search and full positive-witness replay are shared
with that public path.
"""
function _compare_verified_properties(f,g,pf,pg;relation=:ccz,timeout_seconds=30,max_nodes=1_000_000,solver_session=nothing)
    relation in (:ea,:ccz) || error("relation must be ea or ccz")
    for (lut,p) in ((f,pf),(g,pg))
        bytes=UInt8.(lut)
        lut_id(bytes)==p["lut_sha256"] && bytes2hex(bytes)==p["lut_hex"] || error("comparison properties belong to another LUT")
    end
    result = Dict{String,Any}("relation"=>string(relation),"candidate_lut_hex"=>pf["lut_hex"],
        "target_lut_hex"=>pg["lut_hex"],"candidate_sha256"=>pf["lut_sha256"],
        "target_sha256"=>pg["lut_sha256"],"julia_version"=>string(VERSION),
        "solver"=>"partition_refinement_equivalence", "algorithm"=>"paper", "rng_seed"=>940,
        "source_sha256"=>_evidence_fingerprint(solver_session),"solver_implementation_sha256"=>solver_fingerprint(solver_session),"timeout_seconds"=>timeout_seconds,"max_nodes"=>max_nodes)
    if get(pf,"sigma_hash",nothing)!==nothing && get(pg,"sigma_hash",nothing)!==nothing && pf["sigma_hash"]!=pg["sigma_hash"]
        merge!(result,Dict("status"=>"inequivalent_by_quadratic_invariant","equivalent"=>false,
            "candidate_sigma"=>pf["sigma_hash"],"target_sigma"=>pg["sigma_hash"],
            "justification"=>"different ortho-derivative signatures; Yoshiara Theorem 1 applies to both verified quadratic APNs"))
        return result
    end
    F,G = SBox{8,UInt8}(UInt8.(f)),SBox{8,UInt8}(UInt8.(g))
    proof=equivalence_evidence(F,G;relation,timeout_seconds,max_nodes)
    if haskey(proof,"columns")
        merge!(result,Dict("status"=>"equivalent_with_verified_witness","equivalent"=>true,
            "graph_map_columns"=>proof["columns"],"graph_map_constant"=>proof["constant"],"witness_verified"=>true))
    elseif startswith(proof["status"],"exhaustive_")
        merge!(result,Dict("status"=>"inequivalent_by_exhaustive_solver","equivalent"=>false,
            "evidence"=>"finite native search exhausted; computational evidence, not a proof-assistant certificate"))
    else
        merge!(result,Dict("status"=>"inconclusive_budget","equivalent"=>"unresolved","stop"=>proof["stop"]))
    end
    haskey(proof,"nodes") && (result["nodes"]=proof["nodes"])
    haskey(proof,"elapsed_seconds") && (result["seconds"]=proof["elapsed_seconds"])
    result
end

"""Recheck stored positive witnesses and invariant separations without trusting their status labels."""
function verify_comparison(r)
    r["relation"] in ("ea","ccz") || return false
    f,g = hex2bytes(r["candidate_lut_hex"]),hex2bytes(r["target_lut_hex"])
    lut_id(f)==r["candidate_sha256"] && lut_id(g)==r["target_sha256"] || return false
    if r["status"]=="equivalent_with_verified_witness"
        get(r,"equivalent",true)===true || return false
        check = r["relation"]=="ea" ? verify_ea_witness : verify_ccz_witness
        return check(f,g,r["graph_map_columns"],r["graph_map_constant"])
    elseif r["status"]=="inequivalent_by_quadratic_invariant"
        r["equivalent"]===false || return false
        pf,pg = properties(f),properties(g)
        return get(pf,"sigma_hash",nothing)==r["candidate_sigma"] &&
            get(pg,"sigma_hash",nothing)==r["target_sigma"] && r["candidate_sigma"]!=r["target_sigma"]
    end
    false
end
end
