using Test, Random, VBF, SQLite, DBInterface, JSON3
include(joinpath(@__DIR__,"../tools/analysis/v5_frontier_symmetry_audit.jl"))
const FSA=V5FrontierSymmetryAudit

@testset "frontier reservoir covers unprepared admitted parents" begin
    function sample(seed;N=100_000,n=1024)
        rng=Xoshiro(seed);chosen=Int[]
        for i in 1:N
            FSA.reservoir_add!(chosen,i,i,n,rng)
        end
        return chosen
    end
    a=sample(20261018)
    @test a==sample(20261018)
    @test length(a)==length(unique(a))==1024
    # Only the first 1000 imaginary parents have prepared jobs. Sampling all
    # admitted parents must retain the large later unprepared frontier.
    @test count(>(1000),a)>980
    @test sample(1;N=12,n=12)==collect(1:12)
    @test isempty(sample(1;N=12,n=0))
    counts=zeros(Int,20)
    for seed in 1:1000, i in sample(seed;N=20,n=5)
        counts[i]+=1
    end
    @test all(c->175<=c<=325,counts)
end

@testset "bounded positive-space orbit stage preserves its selection scope" begin
    @test FSA.generator_order(UInt16[1,2,4,8,16,32,64,128])==1
    @test FSA.generator_order(UInt16[2,1,4,8,16,32,64,128])==2
    @test FSA.generator_order(UInt16[2,4,1,8,16,32,64,128])==3
    mktempdir() do dir
        FSA.write_json(joinpath(dir,"stabilizers.json"),Dict("spaces"=>Any[]))
        config=(;output=dir,seed=UInt64(123),orbit_spaces=0,max_seconds=1.0)
        source=[Dict("generator_count"=>1)]
        report=FSA.positive_orbits(config,Dict(),source)
        @test report["complete"]
        @test !report["all_positive_spaces_covered"]
        @test report["selected_positive_spaces"]==0
        @test report["input_positive_spaces"]==1
        @test report["saved_cosets"]==0
    end
end

@testset "finite population confidence uses exact hypergeometric tails" begin
    for N in 1:14,n in 0:N,K in 0:N,x in 0:n
        numerator=sum((binomial(big(K),j)*binomial(big(N-K),n-j)
            for j in max(0,n+K-N):min(x,n,K));init=big(0))
        exact=Float64(numerator//binomial(big(N),n))
        @test FSA.hypergeometric_cdf(x,N,K,n)≈exact atol=2e-13
    end
    @test FSA.population_success_upper(10,2,0;alpha=0.05)==7
    @test FSA.population_success_upper(100,100,0)==0
    @test FSA.population_success_upper(100,0,0)==100
    @test FSA.population_success_upper(100,100,5)==5
    @test 0.0028<FSA.population_success_upper(1_379_272,1024,0)/1_379_272<0.0031
    @test_throws ArgumentError FSA.population_success_upper(10,11,0)
end

@testset "one-pass maximizing component preparation matches declared search" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4);F=gold_apn(4)
    best,spaces=FSA.maximizing_component_spaces(G,F)
    a=anf(F)
    c=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:3 for j in i+1:3]
    components=Q.comp_forms(Q.coord_forms(c,4));bent=Q.bent_mask(G,components)
    expected_best=first(Q.max_bent_dim(components,bent,1))
    expected=sort!([first(Q.rref(r.forms)) for r in
        Q.subspaces_of_comp(components,bent,1;keep=nb->nb==expected_best)];by=Tuple)
    @test best==expected_best==1
    @test spaces==expected
    @test length(spaces)==10
end

@testset "parallel preparation keeps each space attached to its own parent" begin
    Q=VBF.QuadraticExtensions;G=Q.geometry(4);gold=gold_apn(4)
    parents=Dict{String,Any}[]
    for i in 1:12
        columns=UInt16[1,2,4,8]
        for (k,(a,b)) in enumerate(((1,2),(2,3),(3,4),(4,1)))
            isodd(i>>(k-1)) && (columns[b]⊻=columns[a])
        end
        A=F2LinearMap{4,UInt16}(columns)
        F=SBox{4,UInt8}(UInt8[gold(A(x)) for x in 0:15])
        push!(parents,Dict("parent_id"=>i,"origin"=>"discovered","prepared_parent"=>false,
            "completed_parent"=>false,"queue_state"=>"queued_unprepared",
            "uniform_parent_sample"=>true,"sample_designs"=>["uniform_parents"],
            "uniform_parent_inclusion_probability"=>1.0,"uniform_parent_design_weight"=>1.0,
            "lut_hex"=>bytes2hex(F.lut)))
    end
    mktempdir() do dir
        FSA.write_json(joinpath(dir,"frame.json"),Dict("fixed"=>true))
        config=(;output=dir)
        for repetition in 1:8
            prepared,all_spaces=FSA.prepare_parents!(config,Dict(),parents;geometry=G)
            @test length(prepared)==length(parents)
            @test length(all_spaces)==120
            for p in prepared
                @test FSA.validate_prepared_parent(G,p)
                F=SBox{4,UInt8}(hex2bytes(p["lut_hex"]))
                a=anf(F);c=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:3 for j in i+1:3]
                components=Q.comp_forms(Q.coord_forms(c,4));bent=Q.bent_mask(G,components)
                expected_best=first(Q.max_bent_dim(components,bent,1))
                expected=sort!([Int.(first(Q.rref(r.forms))) for r in
                    Q.subspaces_of_comp(components,bent,1;keep=nb->nb==expected_best)];by=Tuple)
                @test p["maximizing_v5_forms"]==expected
            end
            corrupted=deepcopy(first(prepared))
            corrupted["maximizing_v5_count"]+=1
            @test_throws ErrorException FSA.validate_prepared_parent(G,corrupted)
            corrupted=deepcopy(first(prepared));corrupted["b5"]=0
            @test_throws ErrorException FSA.validate_prepared_parent(G,corrupted)
            own=Set(Tuple(V) for V in first(prepared)["maximizing_v5_forms"])
            different=findfirst(p->Set(Tuple(V) for V in p["maximizing_v5_forms"])!=own,prepared)
            @test different!==nothing
            if different!==nothing
                corrupted=deepcopy(first(prepared))
                corrupted["maximizing_v5_forms"]=prepared[different]["maximizing_v5_forms"]
                @test_throws ErrorException FSA.validate_prepared_parent(G,corrupted)
            end
        end
    end
end

@testset "frontier frame includes queued and completed parents" begin
    mktempdir() do dir
        path=joinpath(dir,"closure.sqlite");db=SQLite.DB(path)
        DBInterface.execute(db,"CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT)")
        DBInterface.execute(db,"INSERT INTO metadata VALUES('identity','fixed-test-frame')")
        DBInterface.execute(db,"CREATE TABLE parents(id INTEGER PRIMARY KEY,candidate_id TEXT,origin TEXT)")
        DBInterface.execute(db,"CREATE TABLE candidates(id TEXT PRIMARY KEY,lut_hex TEXT,sigma TEXT,apn INTEGER,degree INTEGER,class_id INTEGER)")
        DBInterface.execute(db,"CREATE TABLE jobs(id INTEGER PRIMARY KEY,parent_id INTEGER,kind TEXT,status TEXT)")
        for i in 1:6
            lut=fill(UInt8(i),256)
            candidate=bytes2hex(FSA.sha256(lut))
            DBInterface.execute(db,"INSERT INTO candidates VALUES(?,?,?,?,?,?)",(candidate,bytes2hex(lut),"sigma$i",1,2,i))
            DBInterface.execute(db,"INSERT INTO parents VALUES(?,?,?)",(i,candidate,i<=2 ? "root" : "discovered"))
            DBInterface.execute(db,"INSERT INTO jobs(parent_id,kind,status) VALUES(?,?,?)",(i,"prepare_v5",i<=4 ? "done" : "pending"))
            DBInterface.execute(db,"INSERT INTO jobs(parent_id,kind,status) VALUES(?,?,?)",(i,"switching",i<=3 ? "done" : "pending"))
            if i<=4
                DBInterface.execute(db,"INSERT INTO jobs(parent_id,kind,status) VALUES(?,?,?)",(i,"v5",i<=3 ? "done" : "pending"))
            end
        end
        close(db)
        before=read(path)
        frame,records=FSA.sample_frame(path;parents=6,supplement=1)
        @test frame["population_parents"]==6
        @test frame["uniform_sample_size"]==6
        @test count(r->r["completed_parent"],records)==3
        @test count(r->r["queue_state"]=="queued_unprepared",records)==2
        @test count(r->r["queue_state"]=="queued_prepared",records)==1
        @test all(r->r["uniform_parent_sample"],records)
        @test all(r->r["uniform_parent_inclusion_probability"]==1.0,records)
        @test read(path)==before
    end
end

@testset "downstream audit refuses missing or stale provenance receipts" begin
    mktempdir() do dir
        config=(;output=dir)
        @test_throws ErrorException FSA.require_provenance_validation(config)
        names=("frame.json","parents-frame.json","parents.json","spaces.json")
        for name in names
            FSA.write_json(joinpath(dir,name),Dict("fixed"=>name))
        end
        receipt=Dict("complete"=>true,"bindings"=>Dict(name=>FSA.file_sha(joinpath(dir,name)) for name in names))
        FSA.write_json(joinpath(dir,"provenance-validation.json"),receipt)
        @test FSA.require_provenance_validation(config)
        FSA.write_json(joinpath(dir,"spaces.json"),Dict("changed"=>true))
        @test_throws ErrorException FSA.require_provenance_validation(config)
    end
end

@testset "cluster rates do not count sibling spaces as independent parents" begin
    frame=Dict{String,Any}("population_parents"=>10000)
    parents=[Dict("parent_id"=>i,"uniform_parent_sample"=>true) for i in 1:100]
    spaces=[Dict{String,Any}("parent_id"=>i,"generator_count"=>0,"audit_complete"=>true)
        for i in 1:100 for _ in 1:20]
    rates=FSA.rate_summary(frame,parents,spaces)
    @test rates["uniform_sampled_parents"]==100
    @test rates["uniform_parent_sample_total_v5_spaces"]==2000
    @test rates["v5_job_weighted_hajek_ratio_identified_estimate"]==[0.0,0.0]
    @test rates["parent_prevalence_exact_finite_population_one_sided_95pct_upper"]>0.025
    @test rates["v5_job_weighted_conservative_one_sided_95pct_upper"]>0.9
    # An incomplete search makes that parent's status unknown, not negative.
    spaces[1]["audit_complete"]=false
    unknown=FSA.rate_summary(frame,parents,spaces)
    @test unknown["sampled_parents_with_unknown_stabilizers"]==1
    @test unknown["parent_prevalence_identified_estimate"]==[0.0,0.01]
    @test unknown["parent_prevalence_exact_finite_population_one_sided_95pct_upper"]>
        rates["parent_prevalence_exact_finite_population_one_sided_95pct_upper"]
    # Conditioning an SRS on its number of queued parents leaves an SRS in
    # that known queue population; completed supplemental parents stay out.
    for p in parents
        p["queued_parent"]=p["parent_id"]>10
    end
    for s in spaces
        s["queue_state"]=s["parent_id"]>10 ? "queued_unprepared" : "complete"
    end
    frame["population_strata"]=Dict("root/complete"=>1000,
        "discovered/queued_unprepared"=>8990,"discovered/queued_prepared"=>10)
    queue=FSA.queue_rate_summary(frame,parents,spaces)
    @test queue["population_parents"]==9000
    @test queue["uniform_sampled_parents"]==90
    @test queue["sampled_parents_with_unknown_stabilizers"]==0
end
