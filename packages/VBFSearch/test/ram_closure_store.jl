"""RAM exact-LUT identity, staged EA admission and bounded evidence tests."""
module RAMClosureStoreTests
using Test,VBF,VBFSearch
include(joinpath(@__DIR__,"..","tools","ram_closure_store.jl"))
using .RAMClosureStore
const FP=VBFSearch

"""Small stores keep metadata tests independent of available machine RAM."""
store(;kwargs...)=Store(;candidate_capacity=16,class_capacity=16,comparison_capacity=16,
    comparison_bytes=1<<20,nshards=4,kwargs...)

@testset "Persistent candidate properties retain LUTs and independent failure proofs" begin
    p=FP.properties(gold_apn(8).lut)
    compact=compact_record_properties(p)
    @test COMPACT_RECORD_PROPERTIES_FORMAT=="vbfsearch-ram-candidate-core-v1"
    @test Set(keys(compact))==Set(("lut_sha256","lut_hex","apn","quadratic",
        "algebraic_degree","differential_uniformity","sigma_hash"))
    @test all(compact[key]==p[key] for key in keys(compact))
    @test FP._closure_check_result_properties(compact)
    @test compact_record_properties(compact)==compact
    native=FP._closure_prepare_construction(FP._ClosurePreparedCandidate,p)
    @test native isa FP._ClosurePreparedCandidate
    @test compact_record_properties(native)==compact
    @test compact_record_properties(native) isa Dict{String,Any}
    p["lut_hex"]=repeat("00",256)
    @test compact["lut_hex"]!=p["lut_hex"]
    @test_throws ErrorException compact_record_properties(p)

    nonquadratic=FP.properties(kasami_apn(8,3).lut)
    @test nonquadratic["apn"] && nonquadratic["algebraic_degree"]>2
    nonquadratic_compact=compact_record_properties(nonquadratic)
    @test nonquadratic_compact["differential_uniformity"]==nonquadratic["differential_uniformity"]
    @test !nonquadratic_compact["quadratic"] && !haskey(nonquadratic_compact,"sigma_hash")

    rejected=FP.properties(zeros(UInt8,256));failure=rejected["non_apn_witness"]
    failure["diagnostic"]=Dict("nested"=>[Dict("value"=>17)])
    saved=compact_record_properties(rejected)
    @test !saved["apn"] && saved["differential_uniformity"]==256
    @test saved["non_apn_witness"]==failure
    @test saved["non_apn_witness"]!==failure
    @test saved["non_apn_witness"]["solutions"]!==failure["solutions"]
    failure["solutions"][1]=255
    failure["diagnostic"]["nested"][1]["value"]=23
    @test saved["non_apn_witness"]["solutions"][1]==0
    @test saved["non_apn_witness"]["diagnostic"]["nested"][1]["value"]==17
    saved["non_apn_witness"]["solutions"][2]=255
    @test failure["solutions"][2]==1
    @test compact_record_properties(saved)==saved
    @test FP._closure_check_result_properties(saved)

    forged=FP.properties(gold_apn(8).lut);forged["quadratic"]=false
    @test_throws ErrorException compact_record_properties(forged)
    forged=FP.properties(gold_apn(8).lut);delete!(forged,"differential_uniformity")
    @test_throws KeyError compact_record_properties(forged)
    forged=FP.properties(gold_apn(8).lut);forged["sigma_hash"]="wrong"
    @test_throws ArgumentError compact_record_properties(forged)
end

@testset "Compact candidate identity has no retained property dictionaries" begin
    s=store();p=FP.properties(gold_apn(8).lut);original=p["lut_hex"]
    slot,isnew=observe_candidate!(s,p)
    @test isnew && slot==1
    @test observe_candidate!(s,p)==(slot,false)
    p["lut_hex"]=repeat("00",256)
    @test candidate(s,slot).lut_hex==original
    @test candidate(s,slot).state=="awaiting_equivalence"
    @test RAMClosureStore.candidate_properties(s,slot)["lut_hex"]==original
    @test stats(s).full_property_records_retained==0
    forged=FP.properties(gold_apn(8).lut);forged["sigma_hash"]=repeat("0",64)
    @test_throws ErrorException observe_candidate!(s,forged)
    nonapn=FP.properties(zeros(UInt8,256));other,_=observe_candidate!(s,nonapn)
    @test !candidate(s,other).apn
    @test classify_if_empty!(s,other)==(status=:ineligible,class_id=0)
    @test stats(s).candidate_count==2
    @test stats(s).class_count==0
end

@testset "Audited root order and empty-signature fast admission" begin
    s=store();a=FP.properties(gold_apn(8).lut);b=FP.properties(gold_apn(8,3).lut)
    @test a["sigma_hash"]!=b["sigma_hash"]
    roots=[(id=1,properties=a,source="root-a"),(id=2,properties=b,source="root-b")]
    @test_throws ArgumentError initialize_roots!(s,roots)
    @test initialize_roots!(s,roots;audited=true)==[1,2]
    @test [r.candidate_id for r in class_rows(s)]==[a["lut_sha256"],b["lut_sha256"]]
    @test [r.id for r in class_rows(s)]==[1,2]
    @test [r.source for r in class_rows(s)]==["root-a","root-b"]
    @test all(r->r.origin=="root",class_rows(s))
    @test classify_if_empty!(s,1)==(status=:already_classified,class_id=1)
    @test_throws ArgumentError initialize_roots!(s,roots;audited=true)
    fresh=store();sa,_=observe_candidate!(fresh,a);sb,_=observe_candidate!(fresh,b)
    @test classify_if_empty!(fresh,sa)==(status=:admitted,class_id=1)
    @test classify_if_empty!(fresh,sb)==(status=:admitted,class_id=2)
    @test stats(fresh).comparison_count==0
end

@testset "Same-signature stale negatives revalidate and positives replay witnesses" begin
    s=store();a=FP.properties(gold_apn(8).lut);b=FP.properties(gold_apn(8,3).lut)
    initialize_roots!(s,[(properties=a,source="root")];audited=true)
    first,_=observe_candidate!(s,b)
    second,_=observe_candidate!(s,FP.properties(gold_apn(8,3).lut .⊻ UInt8(1)))
    @test candidate(s,first).sigma==candidate(s,second).sigma
    one=prepare_admission(s,first);two=prepare_admission(s,second)
    @test isempty(one.target_ids) && isempty(two.target_ids)
    result_one=compute_admission(s,one;seconds=0,nodes=0)
    result_two=compute_admission(s,two;seconds=0,nodes=0)
    @test commit_admission!(s,one,result_one)==(status=:admitted,class_id=2)
    @test commit_admission!(s,two,result_two)==(status=:revalidate,class_id=0)
    @test stats(s).class_count==2
    @test classify_if_empty!(s,second)==(status=:requires_comparison,class_id=0)
    retry=prepare_admission(s,second)
    @test retry.target_ids==[2]
    proof=compute_admission(s,retry;seconds=30.0,nodes=100_000)
    @test only(proof["comparisons"])["proof"]["status"]=="equivalent_with_verified_witness"
    @test commit_admission!(s,retry,proof)==(status=:equivalent,class_id=2)
    @test candidate(s,second).state=="equivalent"
    @test stats(s).class_count==2 && stats(s).comparison_count==1
    saved=only(collect(comparison_rows(s)))
    @test saved.target_parent==2 && FP.verify_comparison(saved.proof)
    @test prepare_admission(s,second).status==:already_classified

    third,_=observe_candidate!(s,FP.properties(gold_apn(8,3).lut .⊻ UInt8(2)))
    pending=prepare_admission(s,third)
    incomplete=compute_admission(s,pending;seconds=0.0,nodes=0)
    @test commit_admission!(s,pending,incomplete)==(status=:unresolved,class_id=0)
    @test candidate(s,third).state=="unresolved_equivalence"
    @test classify_candidate!(s,third;seconds=30.0,nodes=100_000)==(status=:equivalent,class_id=2)
    @test stats(s).comparison_count==2
end

@testset "Proof tampering cannot publish a class or comparison" begin
    s=store();root=FP.properties(gold_apn(8).lut)
    initialize_roots!(s,[(properties=root,source="root")];audited=true)
    slot,_=observe_candidate!(s,FP.properties(gold_apn(8).lut .⊻ UInt8(1)))
    snapshot=prepare_admission(s,slot);result=compute_admission(s,snapshot;seconds=30.0,nodes=100_000)
    altered=deepcopy(result);negative=copy(only(altered["comparisons"])["proof"])
    negative["status"]="inequivalent_by_exhaustive_solver";negative["solver_implementation_sha256"]="wrong"
    altered["comparisons"][1]["proof"]=negative
    @test_throws ErrorException commit_admission!(s,snapshot,altered)
    changed=deepcopy(result);badproof=copy(only(changed["comparisons"])["proof"])
    badproof["candidate_sha256"]="wrong";changed["comparisons"][1]["proof"]=badproof
    @test_throws ErrorException commit_admission!(s,snapshot,changed)
    wrong=deepcopy(result);wrong["packet_sha256"]="wrong"
    @test_throws ErrorException commit_admission!(s,snapshot,wrong)
    @test candidate(s,slot).class_id==0
    @test stats(s).class_count==1 && stats(s).comparison_count==0
    @test commit_admission!(s,snapshot,result)==(status=:equivalent,class_id=1)
end

@testset "Capacity limits retain evidence and never overrun counters" begin
    a=FP.properties(gold_apn(8).lut);b=FP.properties(gold_apn(8,3).lut)
    limited=Store(candidate_capacity=1,class_capacity=1,comparison_capacity=0)
    one,_=observe_candidate!(limited,a)
    @test_throws StoreFull observe_candidate!(limited,b)
    @test observe_candidate!(limited,a)==(one,false)
    @test stats(limited).candidate_count==1
    @test classify_if_empty!(limited,one).status==:admitted
    zero=Store(candidate_capacity=2,class_capacity=0)
    slot,_=observe_candidate!(zero,a)
    @test_throws StoreFull classify_if_empty!(zero,slot)
    @test stats(zero).class_count==0 && candidate(zero,slot).class_id==0

    full=Store(candidate_capacity=2,class_capacity=2,comparison_capacity=0)
    initialize_roots!(full,[(properties=a,source="root")];audited=true)
    candidate_slot,_=observe_candidate!(full,FP.properties(gold_apn(8).lut .⊻ UInt8(1)))
    snapshot=prepare_admission(full,candidate_slot);result=compute_admission(full,snapshot;seconds=30.0,nodes=100_000)
    problem=try commit_admission!(full,snapshot,result);nothing catch error;error end
    @test problem isa StoreFull && problem.kind==:comparisons
    @test problem.retained.result===result && !isempty(result["comparisons"])
    @test stats(full).comparison_count==0 && stats(full).class_count==1
    @test candidate(full,candidate_slot).class_id==0

    bytes=Store(candidate_capacity=2,class_capacity=2,comparison_capacity=2,comparison_bytes=1)
    initialize_roots!(bytes,[(properties=a,source="root")];audited=true)
    slot,_=observe_candidate!(bytes,FP.properties(gold_apn(8).lut .⊻ UInt8(1)))
    snapshot=prepare_admission(bytes,slot);result=compute_admission(bytes,snapshot;seconds=30.0,nodes=100_000)
    @test_throws StoreFull commit_admission!(bytes,snapshot,result)
    @test stats(bytes).comparison_bytes==0
end

@testset "Digest shards deduplicate concurrent observations" begin
    s=store();p=FP.properties(gold_apn(8).lut);tasks=min(2,Threads.nthreads(:default))
    @sync for _ in 1:tasks
        Threads.@spawn for _ in 1:16;observe_candidate!(s,p;trusted=true);end
    end
    @test stats(s).candidate_count==1
    @test length(collect(candidate_rows(s)))==1
    @test candidate(s,1).id==p["lut_sha256"]
    @test stats(s).class_count==0
end

@testset "Signature owners publish concurrent classes without duplicate admission" begin
    s=store();ps=FP.properties.([gold_apn(8).lut,gold_apn(8,3).lut])
    slots=[first(observe_candidate!(s,p)) for p in ps]
    @sync for slot in slots
        Threads.@spawn classify_if_empty!(s,slot)
    end
    @test stats(s).class_count==2
    @test sort!([candidate(s,slot).class_id for slot in slots])==[1,2]
    @test Set(r.candidate_id for r in class_rows(s))==Set(p["lut_sha256"] for p in ps)
    same=store();slot,_=observe_candidate!(same,first(ps))
    @sync for _ in 1:2
        Threads.@spawn classify_if_empty!(same,slot)
    end
    @test stats(same).class_count==1
    @test candidate(same,slot).class_id==1
end
end
