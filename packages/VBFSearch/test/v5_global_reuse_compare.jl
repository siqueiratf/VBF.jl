using Test,SQLite,DBInterface,JSON3,VBF
include(joinpath(@__DIR__,"../tools/analysis/v5_global_reuse_compare.jl"))
@testset "Certified global V5 classification and frontier lookup" begin
    mktempdir() do d
        source=joinpath(d,"source.sqlite");out=joinpath(d,"audit")
        db=SQLite.DB(source)
        DBInterface.execute(db,"CREATE TABLE metadata(key TEXT,value TEXT)")
        DBInterface.execute(db,"INSERT INTO metadata VALUES('identity','test=true')")
        DBInterface.execute(db,"CREATE TABLE parents(id INTEGER PRIMARY KEY,origin TEXT)")
        DBInterface.execute(db,"CREATE TABLE jobs(id INTEGER PRIMARY KEY,parent_id INTEGER,kind TEXT,payload TEXT,status TEXT,result TEXT)")
        G=VBF.QuadraticExtensions.geometry(8)
        R=UInt32[134658561,34016355,17372590,10987437,4393092]
        S=VBF.transform_quadratic_space(G,R,UInt16[2,1,4,8,16,32,64,128])
        T=UInt32[1,2,4,8,16]
        for (i,forms) in enumerate([R,S,R,T])
            b5=VBF.quadratic_space_rank_signature(G,forms)[9]
            DBInterface.execute(db,"INSERT INTO parents VALUES(?,'root')",(i,))
            payload="b5=$b5\nneed=$(52-b5)\nforms=[$(join(Int.(forms),','))]\n"
            DBInterface.execute(db,"INSERT INTO jobs VALUES(?,?,'v5',?,?,?)",(i,i,payload,
                i==4 ? "pending" : "done",i==4 ? "" : "total_x=10\nnext_x=11\ncapped=false"))
        end
        close(db);before=read(source)
        redirect_stdout(devnull) do
            V5GlobalReuseAudit.extract(source,out)
            V5GlobalReuseAudit.fingerprint_index(out)
        end
        partial=redirect_stdout(devnull) do;V5GlobalReuseCompare.classify(out;max_pairs=0);end
        @test !partial["complete"]
        @test partial["distinct_orbits_lower_bound"]==2
        @test partial["distinct_orbits_upper_bound"]==3
        report=redirect_stdout(devnull) do;V5GlobalReuseCompare.classify(out);end
        @test report["complete"]
        @test report["distinct_orbits_lower_bound"]==report["distinct_orbits_upper_bound"]==2
        @test report["positive_pairs"]==1
        @test report["reusable_jobs_lower_bound"]==report["reusable_jobs_upper_bound"]==2
        again=redirect_stdout(devnull) do;V5GlobalReuseCompare.classify(out);end
        @test again["new_pair_attempts"]==0
        @test again["cached_positive_witnesses_replayed"]==1
        H=VBF.transform_quadratic_space(G,R,UInt16[1,3,4,8,16,32,64,128])
        U=UInt32[1,2,4,8,1<<27]
        sample=[Dict("parent_id"=>100+i,"origin"=>"discovered","forms"=>Int.(forms),
            "need"=>52-VBF.quadratic_space_rank_signature(G,forms)[9],"prepared"=>false) for (i,forms) in enumerate([R,H,U,T])]
        samplepath=joinpath(d,"spaces.json");open(io->JSON3.write(io,sample),samplepath,"w")
        lookup=V5GlobalReuseCompare.lookup(out,samplepath,joinpath(d,"lookup.json"))
        @test lookup["results"][1]["status"]=="exact_prepared_space"
        @test lookup["results"][1]["target_has_complete_expansion"]
        @test lookup["results"][2]["status"]=="equivalent_witness_replayed"
        @test lookup["results"][2]["target_has_complete_expansion"]
        @test lookup["results"][3]["status"]=="absent_by_necessary_invariant"
        @test lookup["results"][4]["status"]=="exact_prepared_space"
        @test !lookup["results"][4]["target_has_complete_expansion"]
        @test lookup["results"][4]["complete_expansion_coverage_status"]=="not_covered_by_necessary_invariant"
        @test lookup["coverage_statuses"]["covered_by_verified_space"]==2
        @test lookup["sample_file_unchanged"]
        budget=V5GlobalReuseCompare.lookup(out,samplepath,joinpath(d,"budget.json");max_seconds=0)
        @test budget["statuses"]["unknown_global_budget"]==4
        localdir=joinpath(d,"sample-index")
        localreport=redirect_stdout(devnull) do;V5GlobalReuseCompare.sample_index(samplepath,localdir);end
        @test localreport["sample_space_orbits"]["complete"]
        @test localreport["sample_space_orbits"]["reusable_jobs_lower_bound"]==1
        @test all(p->p["maximizing_spaces"]==1 && p["complete"],localreport["parents"])
        precomputed=V5GlobalReuseCompare.lookup(out,samplepath,joinpath(d,"precomputed.json");sample_index_directory=localdir)
        @test precomputed["precomputed_sample_fingerprints"]==4
        @test precomputed["statuses"]==lookup["statuses"]
        @test before==read(source)
        cached=SQLite.DB(joinpath(out,"equivalence-pairs.sqlite"))
        DBInterface.execute(cached,"UPDATE pairs SET columns=? WHERE status='equivalent_witness_replayed'",(zeros(UInt8,16),))
        close(cached)
        @test_throws ErrorException V5GlobalReuseCompare.classify(out)
    end
end

@testset "Parent-LUT containment rejects consistently mislabelled sample artifacts" begin
    mktempdir() do d
        P=V5ParentProvenance;Q=VBF.QuadraticExtensions;G=Q.geometry(8)
        F=gold_apn(8);S=P.parent_component_space(F.lut);V=first(Q.rref(S[1:5]))
        b5=count(q->Q.form_rank(G,q)==8,Q.comp_forms(V))
        p=Dict("parent_id"=>7,"lut_hex"=>bytes2hex(F.lut),"maximizing_v5_count"=>1,"maximizing_v5_forms"=>[Int.(V)])
        parentpath=joinpath(d,"parents.json");open(io->JSON3.write(io,Dict("parents"=>[p])),parentpath,"w")
        r=Dict("parent_id"=>7,"forms"=>Int.(V),"b5"=>b5,"need"=>52-b5,"parent_v5_index"=>1,"parent_maximizing_v5_count"=>1)
        samplepath=joinpath(d,"spaces.json")
        function write_sample()
            open(io->JSON3.write(io,Dict("parents_sha256"=>P.filehash(parentpath),"spaces"=>[r])),samplepath,"w")
        end
        write_sample();valid=P.validate_sample(samplepath)
        @test valid["parent_lut_binding_available"]
        @test valid["checked_parents"]==1
        @test valid["checked_spaces"]==1
        parentbytes=read(parentpath)
        write(parentpath,vcat(parentbytes,UInt8[0x20]))
        @test_throws ErrorException P.validate_sample(samplepath)
        write(parentpath,parentbytes)
        p["candidate_id"]=repeat("0",64)
        open(io->JSON3.write(io,Dict("parents"=>[p])),parentpath,"w")
        write_sample()
        @test_throws ErrorException P.validate_sample(samplepath)
        delete!(p,"candidate_id")
        write(parentpath,parentbytes)
        write_sample()
        outside=first(UInt32(1)<<k for k in 0:27 if Q.span_dim(vcat(S,[UInt32(1)<<k]))>length(S))
        wrong=first(Q.rref(vcat(V[1:4],[outside])))
        @test !P.contained_five_space(S,wrong)
        r["forms"]=Int.(wrong)
        p["maximizing_v5_forms"]=[Int.(wrong)]
        open(io->JSON3.write(io,Dict("parents"=>[p])),parentpath,"w")
        write_sample()
        # Both manifests and every digest agree; the mathematical relation to
        # the actual parent LUT is wrong, reproducing the producer race bug.
        @test_throws ErrorException P.validate_sample(samplepath)
        dest=joinpath(d,"must-not-create")
        @test_throws ErrorException V5GlobalReuseCompare.sample_index(samplepath,dest)
        @test !ispath(dest)
    end
end
