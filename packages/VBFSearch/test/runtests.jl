using Test,VBF,TOML,SHA
using VBFSearch, VBFCatalog
using VBFSearch: properties, lut_id, each_candidate, validated_study, Fourier, DiscoveryStore, DiscoveryInputs, DiscoveryEvidence
using VBFSearch.DiscoveryStore

@testset "Independent APN properties and graph witnesses" begin
    gold=gold_apn(8).lut
    p=properties(gold;detailed=true)
    @test p["apn"] && p["quadratic"] && p["differential_uniformity"]==2
    @test p["sigma_hash"]==VBFCatalog.sigma_hash(SBox{8}(gold))
    bad=zeros(UInt8,256);q=properties(bad)
    @test !q["apn"] && q["differential_uniformity"]==256
    @test length(q["non_apn_witness"]["solutions"])==256
    @test_throws ErrorException properties([256;zeros(Int,255)])
    @test verify_comparison(compare(gold,gold))
    target=gold .⊻ UInt8(17)
    @test properties(target)["sigma_hash"]==p["sigma_hash"]
    unresolved=compare(gold,target;max_nodes=0)
    @test unresolved["status"]=="inconclusive_budget" && unresolved["equivalent"]=="unresolved"
    @test !verify_comparison(unresolved)
    recovered=compare(gold,target;timeout_seconds=20)
    @test recovered["status"]=="equivalent_with_verified_witness"
    @test verify_comparison(recovered)
    negative=compare(gold,zeros(UInt8,256);timeout_seconds=20)
    @test negative["status"]=="inequivalent_by_exhaustive_solver"
    @test negative["equivalent"]===false
    proof=Dict("candidate_lut_hex"=>bytes2hex(gold),"target_lut_hex"=>bytes2hex(target),
        "candidate_sha256"=>lut_id(gold),"target_sha256"=>lut_id(target),"relation"=>"ea",
        "status"=>"equivalent_with_verified_witness","graph_map_columns"=>[1<<i for i in 0:15],"graph_map_constant"=>17)
    @test verify_comparison(proof)
    proof["graph_map_constant"]=18
    @test !verify_comparison(proof)
    ident=UInt8.(0:255);swapcols=[1<<(i⊻8) for i in 0:15]
    @test verify_ccz_witness(ident,ident,swapcols,0)
    @test !verify_ea_witness(ident,ident,swapcols,0)
    @test !verify_ccz_witness(ident,ident,zeros(Int,16),0)
    other=gf_monomial_lut(8,9)
    separation=compare(gold,other)
    @test separation["status"]=="inequivalent_by_quadratic_invariant"
    @test verify_comparison(separation)
end

@testset "Classification never merges on sigma or a budget stop" begin
    mktempdir() do dir
        s=open_store(dir,Dict("test"=>"classification"))
        gold=gold_apn(8).lut
        for lut in (gold,gold .⊻ UInt8(1),gf_monomial_lut(8,9))
            register!(s,properties(lut))
        end
        # An exhaustive negative from another solver revision must be replayed.
        stale=Dict("candidate_sha256"=>lut_id(gold),"target_sha256"=>lut_id(gold .⊻ UInt8(1)),
            "relation"=>"ea","status"=>"inequivalent_by_exhaustive_solver",
            "solver_implementation_sha256"=>"obsolete")
        DiscoveryStore.execute!(s.db,"INSERT INTO comparisons(candidate_id,target_id,relation,evidence) VALUES(?,?,?,?)",
            (stale["candidate_sha256"],stale["target_sha256"],"ea",DiscoveryStore.texttoml(stale)))
        close_store(s)
        partial=classify_snapshot(dir;nodes=0,max_pairs=1)
        @test partial["snapshot_luts"]==3 && partial["signature_class_lower_bound"]==2
        @test partial["proven_equivalence_components"]==3
        @test !partial["exact_snapshot_class_count_established"]
        @test partial["unresolved_component_pairs"]==1
        complete=classify_snapshot(dir;seconds=30,max_pairs=1)
        @test complete["proven_equivalence_components"]==2
        @test complete["exact_snapshot_class_count_established"]
        again=classify_snapshot(dir;max_pairs=0)
        @test again["exact_snapshot_class_count_established"] && again["pair_checks_this_session"]==0
    end
end

@testset "Input verification binds prior evidence and retains generation metadata" begin
    mktempdir() do d
        p=properties(gold_apn(8).lut)
        path=joinpath(d,"candidate.tsv")
        write(path,"sigma_hash\tlut_hex\tparent_sigma\n"*p["sigma_hash"]*"\t"*p["lut_hex"]*"\tparent\n")
        records=[]
        each_candidate(row->push!(records,row),path)
        @test only(records).fields["parent_sigma"]=="parent"
        known,proof=validated_study([path],d;reuse=false)
        @test known==Set([p["sigma_hash"]])
        @test only(proof["sources"])["records"]==1
        write(path,"sigma_hash\tlut_hex\n"*repeat("0",64)*"\t"*p["lut_hex"]*"\n")
        @test_throws ErrorException validated_study([path],d;reuse=false)
    end
end

@testset "Atomic storage, locking, exact identity and resume" begin
    mktempdir() do dir
        identity=Dict("test"=>true)
        s=open_store(dir,identity);gold=gold_apn(8).lut;p=properties(gold)
        @test_throws ErrorException open_store(dir,identity;resume=true)
        seed!(s,gold,p["sigma_hash"],"switching");u=claim!(s)
        @test_throws ErrorException transaction(s) do
            register!(s,p)
            error("simulated failure before commit")
        end
        @test snapshot(s)["exact_luts"]==0
        @test_throws ErrorException finish!(s,u,Dict("stop"=>"none");done=true)
        events=Tuple[]
        callback=(event,value)->begin
            push!(events,(event,value))
            checkpoint!(s,u,event,value,event===:candidate_complete ? properties(value.candidate.lut) : nothing)
        end
        r=switching_neighbors_bounded(SBox{8}(gold);max_evaluations=1,timeout_seconds=60,checkpoint=callback)
        @test r isa BudgetHit
        @test length(query(s,"SELECT * FROM evaluations"))==1
        current=only(query(s,"SELECT direction,combination FROM units"))
        close_store(s)
        @test_throws ErrorException open_store(dir,Dict("test"=>false);resume=true)
        s=open_store(dir,identity;resume=true);u=claim!(s)
        @test u["direction"]==current["direction"] && u["combination"]==current["combination"]
        callback=(event,value)->checkpoint!(s,u,event,value,event===:candidate_complete ? properties(value.candidate.lut) : nothing)
        r=switching_neighbors_bounded(SBox{8}(gold);max_evaluations=10000,timeout_seconds=60,
            start_direction=Int(u["direction"]),start_combination=parse(BigInt,u["combination"]),checkpoint=callback)
        @test r isa Exhausted
        finish!(s,u,Dict("stop"=>"none");done=true)
        DiscoveryStore.execute!(s.db,"INSERT INTO metadata VALUES('plan_complete','true')")
        @test snapshot(s)["finite_plan_exhausted"]
        # A common sigma must never merge distinct LUTs.
        register!(s,p);q=properties(gold .⊻ UInt8(1));register!(s,q)
        @test length(query(s,"SELECT * FROM candidates WHERE sigma=?",(p["sigma_hash"],)))>=2
        close_store(s)
    end
end

@testset "V5 coset chunks preserve enumeration" begin
    G=Fourier.geometry(6);beta=Fourier.bent_fourier(G)
    F=gold_apn(6);a=anf(F)
    c=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:5 for j in (i+1):5]
    forms=Fourier.coord_forms(c,6)
    V=Fourier.rref(forms[1:3])[1]
    mask=Fourier.bent_mask(G,Fourier.comp_forms(vcat(V,forms[4])))
    need=count(identity,mask[9:16])
    full=Fourier.v5_extensions(G,V,need,Fourier.V5Work(12);beta,max_kernel=12)
    @test full.nX>1
    @test !isempty(full.Ss)
    @test Fourier.rref(forms)[1] in full.Ss
    @test all(S->differential_uniformity(last(Fourier.function_of(G,S)))==2,full.Ss)
    collected=Set{Vector{UInt32}}();cursor=1
    while cursor<=full.nX
        r=Fourier.v5_extensions(G,V,need,Fourier.V5Work(12);beta,max_kernel=12,max_x=2,start_x=cursor)
        union!(collected,r.Ss);@test r.next_x==cursor+r.nX_used;cursor=r.next_x
    end
    @test collected==full.Ss
    stopped=Fourier.v5_extensions(G,V,need,Fourier.V5Work(12);beta,start_x=1,should_stop=()->true)
    @test stopped.nX_used==0 && stopped.next_x==1
    @test_throws ErrorException Fourier.v5_extensions(G,V,need,Fourier.V5Work(12);beta,start_x=full.nX+2)
end

@testset "V5 chunk ledger atomically expands a typed proof" begin
    mktempdir() do dir
        s=open_store(dir,Dict("test"=>"V5 ledger"));gold=gold_apn(8).lut;p=properties(gold)
        seed!(s,gold,p["sigma_hash"],"v5");u=claim!(s)
        # This constructor infers Dict{String,Integer}; storing candidate IDs
        # must not fail after an otherwise valid extension computation.
        proof=Dict("first_x"=>1,"next_x"=>2,"total_x"=>2,"capped"=>false)
        commit_chunk!(s,u,proof,[p])
        @test only(query(s,"SELECT direction FROM units"))["direction"]==2
        @test only(query(s,"SELECT COUNT(*) c FROM candidates"))["c"]==1
        @test_throws ErrorException commit_chunk!(s,u,proof,[p])
        @test only(query(s,"SELECT COUNT(*) c FROM chunks"))["c"]==1
        close_store(s)
    end
end

@testset "Status reads live committed progress without changing cursors" begin
    mktempdir() do dir
        s=open_store(dir,Dict("configuration"=>Dict("method"=>"v5")))
        try
            gold=gold_apn(8).lut;p=properties(gold)
            seed!(s,gold,p["sigma_hash"],"prepare_v5")
            register!(s,p)
            DiscoveryStore.execute!(s.db,"INSERT INTO metadata VALUES('plan_complete','true')")
            before=query(s,"SELECT * FROM units")
            output=joinpath(dir,"status.txt")
            result=open(output,"w") do io
                redirect_stdout(io) do
                    status(dir)
                end
            end
            @test result["exact_luts"]==1 && result["additional_signatures"]==0
            @test result["units"]==Dict("pending"=>1)
            @test !result["finite_plan_exhausted"]
            @test query(s,"SELECT * FROM units")==before
            unit=claim!(s);finish!(s,unit,Dict("test"=>"complete");done=true)
            result=open(output,"w") do io
                redirect_stdout(io) do
                    status(dir)
                end
            end
            @test result["finite_plan_exhausted"]
            @test occursin("literature novelty: unresolved",read(output,String))
        finally
            close_store(s)
        end
    end
end

include("cli.jl")
include("pipeline.jl")
