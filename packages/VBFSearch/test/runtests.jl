using Test,VBF,TOML,SHA
using VBFSearch, VBFCatalog, SQLite, DBInterface
using VBFSearch: properties, lut_id, each_candidate, validated_study, Fourier, DiscoveryStore, DiscoveryInputs, DiscoveryEvidence
using VBFSearch.DiscoveryStore

include("progress.jl")

@testset "Catalog publication preserves frozen reference scope" begin
    mktempdir() do dir
        withenv("BFA_DATA_DIR"=>dir,"VBF_SEARCH_DATA_DIR"=>dir,"BFA_SOURCE_DIR"=>joinpath(dir,"sources"),"BFA_CATALOG_PATH"=>joinpath(dir,"catalog.sqlite")) do
            db=VBFCatalog.create_catalog(VBFCatalog.catalog_path())
            try
                for F in (gold_apn(8),gold_apn(8,3))
                    VBFCatalog.SQLite.execute(db,"INSERT INTO functions(family,n,m,lut_sha256,lut_blob,is_apn,is_permutation,is_quadratic,source_repo,contributor,added_date) VALUES('fixture',8,8,?,?,1,0,1,'fixture','fixture','fixture')",
                        (VBFCatalog.lut_sha256_hex(F),VBFCatalog.canonical_lut_bytes(F)))
                end
                VBFCatalog.build_sigma_index!(db;corpora=[])
                before=VBFSearch.open_reference(dir)
                metadata=VBFSearch.reference_metadata(before)
                VBFSearch.close_reference(before)
                mkpath(VBFCatalog.catalog_source_dir())
                open(io->TOML.print(io,Dict("corpus"=>[])),joinpath(VBFCatalog.catalog_source_dir(),"sources.toml"),"w")
                run=joinpath(dir,"search","fixture")
                store=open_store(run,Dict("test"=>"publication"))
                new=first(r.sbox for r in taniguchi_apn_representatives(4) if r.new)
                register!(store,properties(new.lut))
                register!(store,properties(new.lut .⊻ 1))
                register!(store,properties(gold_apn(8).lut))
                @test_throws ErrorException publish(run;name="fixture")
                close_store(store)
                result=publish(run;name="fixture")
                @test result["accepted_classes"]==1 && !result["reused"]
                @test result["literature_novelty"]=="unresolved"
                close(db);db=VBFCatalog.load_catalog()
                @test VBFCatalog.corpus_length(db,"fixture")==1
                catalog_bytes=read(VBFCatalog.catalog_path())
                again=publish(run;name="fixture")
                @test read(VBFCatalog.catalog_path())==catalog_bytes
                @test again["reused"] && again["accepted_classes"]==1
                frozen=VBFSearch.open_reference(dir;sources=metadata["sources"])
                @test VBFSearch.reference_metadata(frozen)["sha256"]==metadata["sha256"]
                @test !VBFSearch.reference_contains_signature(frozen,sigma_hash(new))
                VBFSearch.close_reference(frozen)
                current=VBFSearch.open_reference(dir)
                @test VBFSearch.reference_contains_signature(current,sigma_hash(new))
                VBFSearch.close_reference(current)
                @test_throws ErrorException publish(run;name="../escape")
                store=open_store(run,Dict("test"=>"publication");resume=true)
                extra=last(r.sbox for r in taniguchi_apn_representatives(4) if r.new)
                @test sigma_hash(extra)!=sigma_hash(new)
                register!(store,properties(extra.lut));close_store(store)
                @test_throws ErrorException publish(run;name="fixture")
                increment=publish(run;name="fixture_more")
                @test increment["accepted_classes"]==1
                close(db);db=VBFCatalog.load_catalog()
                @test VBFCatalog.corpus_length(db,"fixture")==VBFCatalog.corpus_length(db,"fixture_more")==1
                # Reconstruct publication from immutable declarations without the run DB.
                rebuilt=joinpath(dir,"rebuild.sqlite")
                fresh=VBFCatalog.create_catalog(rebuilt)
                try
                    for F in (gold_apn(8),gold_apn(8,3))
                        VBFCatalog.SQLite.execute(fresh,"INSERT INTO functions(family,n,m,lut_sha256,lut_blob,is_apn,is_permutation,is_quadratic,source_repo,contributor,added_date) VALUES('fixture',8,8,?,?,1,0,1,'fixture','fixture','fixture')",
                            (VBFCatalog.lut_sha256_hex(F),VBFCatalog.canonical_lut_bytes(F)))
                    end
                    entries=TOML.parsefile(joinpath(VBFCatalog.catalog_source_dir(),"sources.toml"))["corpus"]
                    for entry in reverse(entries)
                        VBFCatalog.import_lut_corpus!(fresh,entry)
                    end
                finally
                    close(fresh)
                end
                VBFCatalog.finalize_catalog!(rebuilt)
                @test read(rebuilt)==read(VBFCatalog.catalog_path())
                seeds=joinpath(dir,"seeds.tsv")
                @test DiscoveryInputs.catalog_seeds(seeds;corpora=["fixture"],parents=1)==1
                selected=[];each_candidate(r->push!(selected,r),seeds)
                @test candidate_lut(only(selected).payload)==VBFCatalog.corpus_function(db,"fixture",1).lut
                @test only(selected).hash==sigma_hash(new)
                @test only(selected).fields["catalog_id"]=="fixture:1"
                parsed=VBFSearch.CLI.search_configuration("search",["--output",joinpath(dir,"planned"),"--corpus","fixture","--parents","1"])
                @test parsed.corpora==["fixture"] && parsed.parents==1
                @test VBFSearch.config_from_dict(VBFSearch.config_dict(parsed)).corpora==parsed.corpora
                @test_throws ArgumentError SearchConfig(output=joinpath(dir,"bad"),inputs=[seeds],corpora=["fixture"])
            finally
                close(db)
            end
        end
    end
end

@testset "VBF APN properties and graph witnesses" begin
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

@testset "Input validation binds file digests and retains generation metadata" begin
    mktempdir() do d
        p=properties(gold_apn(8).lut)
        path=joinpath(d,"candidate.tsv")
        write(path,"sigma_hash\tlut_hex\tparent_sigma\n"*p["sigma_hash"]*"\t"*p["lut_hex"]*"\tparent\n")
        records=[]
        each_candidate(row->push!(records,row),path)
        @test only(records).fields["parent_sigma"]=="parent"
        known,proof=validated_study([path])
        @test known==Set([p["sigma_hash"]])
        @test only(proof["sources"])["records"]==1
        write(path,"sigma_hash\tlut_hex\n"*repeat("0",64)*"\t"*p["lut_hex"]*"\n")
        @test_throws ErrorException validated_study([path])
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

@testset "Generic graph evidence" begin
    F=gold_apn(5);G=SBox{5}(F.lut .⊻ 3)
    A=F2AffineMap(identity_linear_map(10),3)
    @test verify_graph_witness(F,G,A)
    @test !verify_graph_witness(F,G,F2AffineMap(A.linear,4))
    @test equivalence_evidence(F,G;max_nodes=0)["status"]=="inconclusive_budget"
    f=collect(0:31);swap=[1<<(i<5 ? i+5 : i-5) for i in 0:9]
    @test verify_ccz_witness(f,f,swap,0)
    @test !verify_ea_witness(f,f,swap,0)
    @test !verify_ccz_witness(f,f,fill(0,10),0)
    @test !verify_ccz_witness(f[1:31],f[1:31],swap,0)
    @test !verify_ccz_witness(f,f,swap,1<<10)
end

@testset "Julia report snapshots live progress and exports reusable seeds" begin
    mktempdir() do dir
        store=DiscoveryStore.open_store(dir,Dict("test"=>"report"))
        try
            F=gold_apn(8);p=properties(F.lut)
            DiscoveryStore.register!(store,p)
            DiscoveryStore.seed!(store,F.lut,p["sigma_hash"],"switching")
            before=DiscoveryStore.query(store,"SELECT * FROM units")
            output=report(dir)
            snapshot=report_snapshot(dir)
            @test snapshot["counts"]["apn_luts"]==1
            @test snapshot["units"]==Dict("pending"=>1)
            @test !snapshot["finite_plan_exhausted"]
            @test DiscoveryStore.query(store,"SELECT * FROM units")==before
            rows=[];each_candidate(row->push!(rows,row),joinpath(output,"seeds.tsv"))
            @test only(rows).payload==p["lut_hex"]
            @test only(rows).hash==p["sigma_hash"]
            @test isfile(joinpath(output,"snapshot.json"))
            @test readlines(joinpath(output,"relationships.csv"))==["candidate_sha256,target_sha256,relation,status,equivalent"]
            proof=compare(F.lut,F.lut)
            certificate=joinpath(dir,"certificate.toml")
            open(io->TOML.print(io,proof),certificate,"w")
            @test verify_certificate(certificate)
            proof["graph_map_constant"]=1
            open(io->TOML.print(io,proof),certificate,"w")
            @test_throws ErrorException verify_certificate(certificate)
        finally
            DiscoveryStore.close_store(store)
        end
    end
end

for file in sort(readdir(joinpath(@__DIR__,"reference");join=true))
    endswith(file,"_test.jl") && include(file)
end

@testset "Original-source reference rebuild" begin
    script=joinpath(@__DIR__,"reference","rebuild.jl")
    # Pkg.test sets JULIA_LOAD_PATH to its sandbox without @stdlib; the child must resolve stdlibs such as Printf.
    cmd = `$(Base.julia_cmd()) --startup-file=no --compiled-modules=existing --project=$(dirname(@__DIR__)) $script`
    @test success(addenv(cmd, "JULIA_LOAD_PATH" => "@:@stdlib"))
end
