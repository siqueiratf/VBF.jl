"""Ownership and real construction parity for the bounded RAM arena experiment."""
module ArenaToyTests
using Test,VBF,VBFSearch
include(joinpath(@__DIR__,"..","tools","arena_toy.jl"))
using .ArenaToy

@testset "Verified APN records own bytes and fixed slabs deduplicate exact LUTs" begin
    lut=copy(gold_apn(8).lut);original=copy(lut)
    candidate=VerifiedCandidate(lut);fill!(lut,0)
    @test isbitstype(VerifiedCandidate) && isbitstype(ArenaPath)
    @test collect(candidate.lut)==original
    @test bytes2hex(collect(candidate.id))==VBFSearch.DiscoveryEvidence.lut_id(original)
    arena=CandidateArena(2;nshards=4,path_capacity=1)
    @test insert_candidate!(arena,candidate)==(1,true)
    @test insert_candidate!(arena,candidate)==(1,false)
    second=VerifiedCandidate(original .⊻ UInt8(1))
    @test insert_candidate!(arena,second)==(2,true)
    @test insert_candidate!(arena,candidate)==(1,false)
    @test_throws ArenaFull insert_candidate!(arena,VerifiedCandidate(original .⊻ UInt8(2)))
    @test memory_stats(arena).candidates==2
    @test [r.id for r in candidate_rows(arena)]==sort!([bytes2hex(collect(c.id)) for c in (candidate,second)])
    edge=ArenaPath(1,9,1,1,1,3,UInt64(0),UInt8(1))
    @test record_path!(arena,edge)==1
    @test path_rows(arena)==[edge]
    @test_throws ArenaFull record_path!(arena,edge)
    @test_throws ArgumentError record_path!(arena,ArenaPath(1,9,3,1,1,3,UInt64(0),UInt8(1)))
    @test memory_stats(arena).paths==1
    @test memory_stats(arena).candidate_slab_bytes==2*(256+32+32+1)
    @test memory_stats(arena).path_slab_bytes==sizeof(ArenaPath)
    @test_throws ArenaFull insert_candidate!(CandidateArena(0),candidate)
    @test_throws ArgumentError CandidateArena(-1)
    @test_throws ArgumentError CandidateArena(1;nshards=0)
    @test_throws ArgumentError VerifiedCandidate(zeros(UInt8,256))
end

@testset "Concurrent duplicate insertion and edges use disjoint records" begin
    count=min(2,Threads.nthreads(:default));iterations=16
    candidates=[VerifiedCandidate(gold_apn(8).lut .⊻ UInt8(i)) for i in 0:3]
    arena=CandidateArena(4;nshards=4,path_capacity=count*iterations*4)
    indices=zeros(Int,count*iterations*4)
    @sync for worker in 1:count
        Threads.@spawn for iteration in 1:iterations, i in 1:4
            slot,_=insert_candidate!(arena,candidates[i])
            position=(worker-1)*iterations*4+(iteration-1)*4+i
            indices[position]=record_path!(arena,ArenaPath(worker,position,slot,1,i,
                iteration,UInt64(0),UInt8(1)))
        end
    end
    @test memory_stats(arena).candidates==4
    @test memory_stats(arena).paths==length(indices)
    @test sort(indices)==collect(eachindex(indices))
    @test length(candidate_rows(arena))==4
    @test sort([p.job for p in path_rows(arena)])==collect(eachindex(indices))
    @test all(p->arena.ids[p.candidate]==candidates[p.record].id,path_rows(arena))
end

# Existing controller fixture: one maximizing five-space, bounded V5 slices.
const ROOT_LUT=hex2bytes("00000079003b96d40083a55feb53d819009efe19a005c814cfd294f084a2491600094b3be0d23d7679f3976472c30ac220b7957b60cc4396968286eb3d12bbed002d13470c1a89e6802e36e167f247ab10a3fd37bc34c7365f6f175e1813c6b404205c01e8f72640fd5a00defa669174348e925178f948b0023b0141a5a7304b00598aaa04661803409a6fccaf4e168e08cf7cc2ac504ecb87c3566bc8b78f890252c3eae68db1a33be85ff534dcc6572ae415a26e9bc74bdc91467273057f700175989509460630c136fd7322ee883d19f37eedb16040e8167fd4c45507012a077ad5d1efa9ab94be40c94ebd785ce03fdc138977afcd6c4929c0d9eab1f5d7")

@testset "Several workers preserve production switching and V5 mathematical results" begin
    count=min(2,Threads.nthreads(:default))
    packets=packet_factory([ROOT_LUT];directions_per_packet=128,prepare_v5=true)
    before=deepcopy(packets)
    sequential_arena=CandidateArena(256;path_capacity=1024)
    parallel_arena=CandidateArena(256;path_capacity=1024)
    sequential=run_packets!(sequential_arena,packets;concurrency=1)
    parallel=run_packets!(parallel_arena,packets;concurrency=count)
    @test packets==before
    @test all(==(1),sequential.complete) && all(==(1),parallel.complete)
    @test [r["work"] for r in sequential.results]==[r["work"] for r in parallel.results]
    @test candidate_rows(sequential_arena)==candidate_rows(parallel_arena)
    complete_directions=sort!([e["direction"] for r in parallel.results if r["kind"]=="switching"
        for e in r["work"]["events"] if e["event"]=="direction_complete"])
    @test complete_directions==collect(1:255)
    @test all(r->r["work"]["proof"]["next_direction"]==min(256,r["packet"]["direction"]+
        r["packet"]["switching_directions"]) && r["work"]["proof"]["next_combination"]=="1",
        (r for r in parallel.results if r["kind"]=="switching"))
    @test all(context->context.geometry===parallel.contexts[1].geometry,parallel.contexts)
    @test length(unique(objectid(c.property_cache) for c in parallel.contexts))==count
    @test !any(c->islocked(c.guard),parallel.contexts)

    prepared=first(sequential.results)["work"];p=VBFSearch.properties(ROOT_LUT)
    @test length(prepared["spaces"])==1
    payload=Dict("forms"=>only(prepared["spaces"]),"need"=>52-prepared["max_b5"],"b5"=>prepared["max_b5"])
    v5=[work_packet(p;job_id=i,parent_id=1,kind="v5",direction=first,
        payload=payload,extension_cosets=2) for (i,first) in enumerate((1,3))]
    reference=run_packets!(CandidateArena(256;path_capacity=1024),v5;concurrency=1,contexts=sequential.contexts)
    disjoint_arena=CandidateArena(256;path_capacity=1024)
    disjoint=run_packets!(disjoint_arena,v5;concurrency=count,contexts=parallel.contexts)
    @test [r["work"] for r in reference.results]==[r["work"] for r in disjoint.results]
    @test all(r->r["work"]["processed_cosets"]==2,disjoint.results)
    @test [r["work"]["proof"]["first_x"] for r in disjoint.results]==[1,3]
    @test [r["work"]["proof"]["next_x"] for r in disjoint.results]==[3,5]
    @test length(unique(objectid(c.work) for c in disjoint.contexts))==count
    @test all(r->r["packet_sha256"]==r["packet"]["packet_sha256"],disjoint.results)
    @test memory_stats(disjoint_arena).candidates<=memory_stats(disjoint_arena).capacity
    @test_throws ArgumentError run_packets!(CandidateArena(2),packets;concurrency=2,
        contexts=[parallel.contexts[1],parallel.contexts[1]])

    @test_throws ArgumentError run_packets!(CandidateArena(2),[packets[2],deepcopy(packets[2])])
    overlap=work_packet(p;job_id=99,parent_id=1,kind="v5",direction=2,payload,extension_cosets=2)
    @test_throws ArgumentError run_packets!(CandidateArena(2),[v5[1],overlap])
    incomplete=deepcopy(parallel.results[2]);incomplete["work"]["proof"]["next_direction"]-=1
    @test_throws ErrorException ArenaToy.validate_scope(packets[2],incomplete)

    for field in (:cnt,:g5,:pts,:flat_histogram,:bitmap)
        left=VBFSearch.Fourier.V5Work(4);right=VBFSearch.Fourier.V5Work(4)
        setproperty!(right,field,getproperty(left,field))
        contexts=make_contexts(2);contexts[1].work=left;contexts[2].work=right
        @test_throws ArgumentError run_packets!(CandidateArena(2),packets;concurrency=2,contexts)
    end
    for field in (:zeroes,:signatures,:bad)
        left=VBFSearch.Fourier.V5Work(4);right=VBFSearch.Fourier.V5Work(4)
        setproperty!(right.du7,field,getproperty(left.du7,field))
        contexts=make_contexts(2);contexts[1].work=left;contexts[2].work=right
        @test_throws ArgumentError run_packets!(CandidateArena(2),packets;concurrency=2,contexts)
    end
    bad=deepcopy(packets[2]);bad["job_id"]=999;bad["packet_sha256"]="invalid"
    problem=try
        run_packets!(CandidateArena(2),[packets[1],bad];contexts=sequential.contexts)
        nothing
    catch error
        error
    end
    @test problem isa ArenaRunFailure
    @test problem.cause isa ErrorException
    @test problem.complete==UInt8[1,0]
    @test problem.results[1]["work"]==sequential.results[1]["work"]
    @test problem.results[2]===nothing
    @test !islocked(only(sequential.contexts).guard)

    emitting=work_packet(p;job_id=100,parent_id=1,kind="v5",direction=308,
        payload,extension_cosets=1)
    full_arena=CandidateArena(2;path_capacity=0)
    capacity_problem=try
        run_packets!(full_arena,[emitting];contexts=sequential.contexts)
        nothing
    catch error
        error
    end
    @test capacity_problem isa ArenaRunFailure
    @test capacity_problem.cause isa ArenaFull
    @test capacity_problem.cause.kind==:paths && capacity_problem.cause.capacity==0
    @test capacity_problem.complete==UInt8[0]
    @test memory_stats(full_arena).paths==0 && memory_stats(full_arena).candidates==1
    returned=only(capacity_problem.results)
    @test returned["packet_sha256"]==emitting["packet_sha256"]
    @test returned["work"]["processed_cosets"]==1
    @test returned["work"]["proof"]["first_x"]==308 && returned["work"]["proof"]["next_x"]==309
    records=returned["work"]["records"]
    @test !isempty(records)
    @test any(r->r["properties"]["lut_sha256"]=="6db4a4310662088314774d45104f529ec3922334ae8f902d6803ceb8ebb814ba",records)
    @test all(r->r["witness"]["eligible_coset_index"]==308 && length(r["witness"]["output_forms"])==8,records)
    @test !islocked(only(sequential.contexts).guard)
end

end
