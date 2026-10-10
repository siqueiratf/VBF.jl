"""Auditable eight-bit APN properties, corpus comparisons and affine graph certificates."""
module DiscoveryEvidence
using VBF, VBFCatalog, SHA, TOML, Dates
include("verification/signature.jl")
include("verification/ea_witness.jl")
using .IndependentSignature
using .IndependentEAWitness
export properties, open_reference, close_reference, classify, compare, verify_comparison,
       verify_ccz_witness, verify_ea_witness, lut_id, filehash, Reference

filehash(path) = bytes2hex(open(SHA.sha256,path))
lut_id(lut) = bytes2hex(SHA.sha256(UInt8.(lut)))

"""Compute the full DDT and Boolean ANF independently of VBF, then independently compute sigma."""
function properties(lut; detailed=false)
    length(lut)==256 && all(x->x isa Integer && 0<=x<=255,lut) || error("expected 256 bytes")
    f = UInt8.(lut)
    coeffs = copy(f)
    for bit in 0:7, x in 0:255
        x & (1<<bit)==0 || (coeffs[x+1] ⊻= coeffs[(x⊻(1<<bit))+1])
    end
    degree = maximum((count_ones(x) for x in 0:255 if coeffs[x+1]!=0);init=0)
    histogram = zeros(Int,257)
    counts = zeros(Int,256)
    uniformity = 0
    failure = Dict{String,Any}()
    for a in 1:255
        fill!(counts,0)
        for x in 0:255
            counts[Int(f[x+1]⊻f[(x⊻a)+1])+1] += 1
        end
        for (b,c) in enumerate(counts)
            histogram[c+1] += 1
            uniformity = max(uniformity,c)
            if c>2 && isempty(failure)
                failure = Dict("a"=>a,"b"=>b-1,"solutions"=>[x for x in 0:255 if f[x+1]⊻f[(x⊻a)+1]==b-1])
            end
        end
    end
    result = Dict{String,Any}("lut_sha256"=>lut_id(f),"lut_hex"=>bytes2hex(f),
        "n"=>8,"m"=>8,"apn"=>uniformity==2,"differential_uniformity"=>uniformity,
        "algebraic_degree"=>degree,"quadratic"=>degree==2,
        "ddt_histogram"=>[Dict("value"=>i-1,"count"=>c) for (i,c) in enumerate(histogram) if c>0],
        "verification"=>"independent exhaustive DDT and Boolean Mobius transform",
        "literature_novelty"=>"unresolved", "non_apn_witness"=>failure)
    if uniformity==2 && degree==2
        w = Workspace()
        result["sigma_hash"] = bytes2hex(signature(w,f))
        result["polar_ranks"] = fill(7,255)
        result["ortho_lut_hex"] = bytes2hex(w.ortho)
        result["sigma_definition"] = "SHA256 of differential and absolute-Walsh histograms of the ortho-derivative; v1"
    end
    if detailed
        F = SBox{8,UInt8}(f)
        result["linearity"] = Int(linearity(F))
        result["nonlinearity"] = Int(nonlinearity(F))
        result["absolute_walsh_spectrum"] = [Dict("value"=>Int(v),"count"=>Int(c)) for (v,c) in sort!(collect(absolute_walsh_spectrum(F)))]
        result["anf"] = [Dict("input_mask"=>x,"output_coefficient"=>Int(coeffs[x+1])) for x in 0:255 if coeffs[x+1]!=0]
    end
    result
end

const Reference = VBFCatalog.AuditedAPNReference

"""Cover every eight-bit Gold exponent (gcd(k,8)=1), independently verify each representative."""
function gold_coverage()
    [begin
        exponent=(1<<k)+1
        p=properties(gf_monomial_lut(8,exponent;modulus=0x11d))
        p["apn"] && p["quadratic"] || error("invalid Gold representative")
        Dict("k"=>k,"exponent"=>exponent,"modulus"=>0x11d,
            "sigma_hash"=>p["sigma_hash"],"lut_sha256"=>p["lut_sha256"])
    end for k in (1,3,5,7)]
end

"""Require a source-rebuilt reference; freeze its scope and digests, never fall back to an old index."""
function open_reference(dir; supplement_path=get(ENV,"VBF_APN_SUPPLEMENT",joinpath(@__DIR__,"../../../data/apn/supplement.tsv")))
    gold=gold_coverage()
    checker=function(f)
        p=properties(f)
        p["apn"] && p["quadratic"] || error("invalid public supplement")
        p["sigma_hash"]
    end
    r=VBFCatalog.open_apn_reference(dir;supplement_path,supplement_signature=checker,
        required_signatures=[p["sigma_hash"] for p in gold])
    r.metadata["gold_coverage"]=gold
    r
end

close_reference(r) = VBFCatalog.close_apn_reference(r)

"""A sigma match is a filter; an absent sigma separates only the documented quadratic corpus."""
function classify(lut,r::Reference; detailed=false)
    p = properties(lut;detailed)
    p["reference"] = VBFCatalog.reference_metadata(r)
    if !p["apn"]
        p["evidence_level"] = "not_apn"
    elseif !p["quadratic"]
        p["evidence_level"] = "apn_verified_reference_comparison_unavailable"
    else
        hash = p["sigma_hash"]
        hit = VBFCatalog.reference_contains_signature(r,hash)
        p["evidence_level"] = hit ? "invariant_match_unresolved_equivalence" : "inequivalent_to_documented_quadratic_corpus"
        p["reference_signature_match"] = hit
        p["equivalence"] = "unresolved"
        gold_match=any(row->row["sigma_hash"]==hash,VBFCatalog.reference_metadata(r)["gold_coverage"])
        p["apn_power_function_comparison"]=gold_match ? "unresolved_gold_invariant_match" : "inequivalent_to_all_apn_power_functions"
        p["power_function_justification"]=Dict("theorem"=>"Yoshiara 2016, Theorem 2; quadratic APN CCZ-equivalent to a power APN implies EA-equivalent to a Gold function",
            "doi"=>"10.1007/s10801-016-0680-z","gold_k"=>[1,3,5,7],"gold_invariant_match"=>gold_match)
        if VBFCatalog.reference_exact_lut_match(r,hash,lut)
            p["evidence_level"] = "exact_public_lut_match"
            p["equivalence"] = "identical_public_function"
        end
    end
    p
end

# Exhaustive negative outcomes are implementation-dependent; cache them only
# against the exact mathematical solver sources, unlike independently checked witnesses.
function solver_fingerprint()
    root=joinpath(pkgdir(VBF),"src")
    paths=sort!([joinpath(d,f) for (d,_,files) in walkdir(root) for f in files if endswith(f,".jl")])
    bytes2hex(SHA.sha256(join([relpath(p,root)*":"*filehash(p) for p in paths],"\n")))
end

"""Return an independently checked positive map, a separating invariant, exhaustive negative, or inconclusive budget."""
function compare(f,g;relation=:ccz,timeout_seconds=30,max_nodes=1_000_000)
    relation in (:ea,:ccz) || error("relation must be ea or ccz")
    pf,pg = properties(f),properties(g)
    result = Dict{String,Any}("relation"=>string(relation),"candidate_lut_hex"=>pf["lut_hex"],
        "target_lut_hex"=>pg["lut_hex"],"candidate_sha256"=>pf["lut_sha256"],
        "target_sha256"=>pg["lut_sha256"],"julia_version"=>string(VERSION),
        "solver"=>"partition_refinement_equivalence", "algorithm"=>"paper", "rng_seed"=>940,
        "source_sha256"=>filehash(@__FILE__),"solver_implementation_sha256"=>solver_fingerprint(),"timeout_seconds"=>timeout_seconds,"max_nodes"=>max_nodes)
    if get(pf,"sigma_hash",nothing)!==nothing && get(pg,"sigma_hash",nothing)!==nothing && pf["sigma_hash"]!=pg["sigma_hash"]
        merge!(result,Dict("status"=>"inequivalent_by_quadratic_invariant","equivalent"=>false,
            "candidate_sigma"=>pf["sigma_hash"],"target_sigma"=>pg["sigma_hash"],
            "justification"=>"different ortho-derivative signatures; Yoshiara Theorem 1 applies to both verified quadratic APNs"))
        return result
    end
    F,G = SBox{8,UInt8}(UInt8.(f)),SBox{8,UInt8}(UInt8.(g))
    if F.lut==G.lut
        A = identity_affine_map(16,UInt32)
        outcome = nothing
    else
        outcome = partition_refinement_equivalence(F,G;relation,timeout_seconds,max_nodes)
        A = outcome isa Found ? only(search_solutions(outcome)) : nothing
    end
    if A!==nothing
        cols,c = Int.(A.linear.cols),Int(A.constant)
        check = relation===:ea ? verify_ea_witness : verify_ccz_witness
        check(f,g,cols,c) || error("solver produced an invalid graph witness")
        merge!(result,Dict("status"=>"equivalent_with_verified_witness","equivalent"=>true,
            "graph_map_columns"=>cols,"graph_map_constant"=>c,"independent_witness_verified"=>true))
    elseif outcome isa Exhausted
        merge!(result,Dict("status"=>"inequivalent_by_exhaustive_solver","equivalent"=>false,
            "evidence"=>"finite native search exhausted; computational evidence, not a proof-assistant certificate"))
    else
        merge!(result,Dict("status"=>"inconclusive_budget","equivalent"=>"unresolved",
            "stop"=>string(outcome.where_it_stopped.reason)))
    end
    outcome===nothing || merge!(result,Dict("nodes"=>nodes_visited(outcome),"seconds"=>elapsed_seconds(outcome)))
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
