using Test,VBF,VBFSearch,TOML,SHA,SQLite,DBInterface

function closure_fixture(directory;F=gold_apn(8))
    rootfile=joinpath(directory,"fixture-root.tsv")
    p=VBFSearch.properties(F.lut)
    write(rootfile,p["lut_hex"]*"\n")
    digest=bytes2hex(open(SHA.sha256,rootfile))
    identity=Dict{String,Any}("schema"=>VBFSearch.CLOSURE_SCHEMA,"campaign"=>rootfile,
        "campaign_sha256"=>digest,"roots_sha256"=>digest,"initial_roots"=>1,"qualification_complete"=>true,
        "inputs"=>Dict(rootfile=>digest),"implementation"=>VBFSearch.implementation_fingerprint(),"julia"=>string(VERSION),
        "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23))
    roots=[(lut_sha256=p["lut_sha256"],lut_hex=p["lut_hex"],sigma_hash=p["sigma_hash"],catalog_id="test-fixture:1")]
    run=joinpath(directory,"frontier")
    VBFSearch._closure_initialize(run,identity,roots)
    run
end

@testset "Campaign initialization binds the qualified published inputs" begin
    mktempdir() do directory
        p=VBFSearch.properties(gold_apn(8).lut)
        # Synthetic audit artifacts exercise the application boundary; this is
        # not a claim that the Gold fixture has the declared campaign profile.
        rootfile=joinpath(directory,"verified.tsv")
        write(rootfile,"sigma_hash\tlut_hex\tcatalog_id\tlut_sha256\tP6_bminK\n"*
            join((p["sigma_hash"],p["lut_hex"],"fixture:1",p["lut_sha256"],"0,0:1,1:3,3:7,7:15,15:30,34:52,96"),'\t')*"\n")
        selected=joinpath(directory,"selected_roots.tsv");cp(rootfile,selected)
        certificates=joinpath(directory,"EA_certificates.tsv");write(certificates,"fixture\n")
        function toml(name,value)
            path=joinpath(directory,name)
            open(io->TOML.print(io,value),path,"w");path
        end
        hash(path)=bytes2hex(open(SHA.sha256,path))
        toml("qualification.toml",Dict("complete"=>true,"inconclusive"=>0,"processed"=>1,"total"=>1,"selected_roots_sha256"=>hash(selected)))
        proof=Dict("complete"=>true,"all_encoded_positive_witnesses_replayed"=>true,"verified_roots_sha256"=>hash(rootfile),
            "verified_seed_classes"=>1,"certificate_sha256"=>hash(certificates))
        toml("equivalence.toml",proof);toml("pool.toml",Dict("fixture"=>true))
        plan=Dict("schema"=>"vbfsearch-literature-closure-plan-v2",
            "roots"=>Dict("n"=>8,"m"=>8,"profile_order"=>"bminK","profile_b6"=>52,"historical_discoveries_as_roots"=>false,
                "qualified_root_file"=>"verified.tsv","equivalence_evidence"=>"equivalence.toml","qualification_evidence"=>"qualification.toml",
                "source_inventory"=>"pool.toml","qualified_root_count"=>1,"sources"=>["fixture"]),
            "methods"=>Dict("v5"=>Dict("target_b6"=>52,"bent"=>"max","heuristic_histogram_pruning"=>false)),
            "promotion"=>Dict("global_b6_filter"=>"none","p6_profile_filter"=>"none"))
        campaign=toml("campaign.toml",plan)
        initialized=closure_init(campaign;output=joinpath(directory,"public-init"))
        @test initialized["initial_roots"]==1 && initialized["state"]=="ready"
        @test initialized["roots_sha256"]==hash(rootfile)
        @test initialized["exact_luts"]==1 && initialized["promoted_parents"]==0
        @test_throws ErrorException closure_init(campaign;output=joinpath(directory,"public-init"))
        proof["complete"]=false;toml("equivalence.toml",proof)
        @test_throws ErrorException closure_init(campaign;output=joinpath(directory,"bad-init"))
        @test !isdir(joinpath(directory,"bad-init"))
    end
end

@testset "Audited root partitions retain global indices and deterministic order" begin
    mktempdir() do directory
        # Synthetic qualification artifacts test partitioning, not a mathematical
        # assertion about the fixture functions' P6 profiles.
        props=VBFSearch.properties.([gold_apn(8).lut,gold_apn(8,3).lut])
        rootfile=joinpath(directory,"verified.tsv")
        open(rootfile,"w") do io
            println(io,"sigma_hash\tlut_hex\tcatalog_id\tlut_sha256\tP6_bminK")
            for (i,p) in enumerate(props)
                println(io,join((p["sigma_hash"],p["lut_hex"],"fixture:$i",p["lut_sha256"],"0,0:1,1:3,3:7,7:15,15:30,34:52,96"),'\t'))
            end
        end
        selected=joinpath(directory,"selected_roots.tsv");cp(rootfile,selected)
        certificates=joinpath(directory,"EA_certificates.tsv");write(certificates,"fixture\n")
        hash(path)=bytes2hex(open(SHA.sha256,path))
        function toml(name,value)
            path=joinpath(directory,name)
            open(io->TOML.print(io,value),path,"w");path
        end
        qualification=Dict("complete"=>true,"inconclusive"=>0,"processed"=>2,"total"=>2,"selected_roots_sha256"=>hash(selected))
        toml("qualification.toml",qualification)
        proof=Dict("complete"=>true,"all_encoded_positive_witnesses_replayed"=>true,"verified_roots_sha256"=>hash(rootfile),
            "verified_seed_classes"=>2,"certificate_sha256"=>hash(certificates))
        toml("equivalence.toml",proof);toml("pool.toml",Dict("fixture"=>true))
        plan=Dict("schema"=>"vbfsearch-literature-closure-plan-v2",
            "roots"=>Dict("n"=>8,"m"=>8,"profile_order"=>"bminK","profile_b6"=>52,"historical_discoveries_as_roots"=>false,
                "qualified_root_file"=>"verified.tsv","equivalence_evidence"=>"equivalence.toml","qualification_evidence"=>"qualification.toml",
                "source_inventory"=>"pool.toml","qualified_root_count"=>2,"sources"=>["fixture"]),
            "methods"=>Dict("v5"=>Dict("target_b6"=>52,"bent"=>"max","heuristic_histogram_pruning"=>false)),
            "promotion"=>Dict("global_b6_filter"=>"none","p6_profile_filter"=>"none"))
        campaign=toml("campaign.toml",plan)
        leftdir=joinpath(directory,"left");rightdir=joinpath(directory,"right")
        left=closure_init(campaign;output=leftdir,root_first=1,root_last=1)
        right=closure_init(campaign;output=rightdir,root_first=2,root_order=:reverse)
        @test left["qualified_roots"]==right["qualified_roots"]==2
        @test left["initial_roots"]==right["initial_roots"]==1
        @test left["root_first"]==left["root_last"]==1
        @test right["root_first"]==right["root_last"]==2 && right["root_order"]=="reverse"
        @test left["roots_sha256"]==right["roots_sha256"]==hash(rootfile)
        @test occursin("assigned published root rows 2:2",right["scope"])
        indices=Set{Int}[]
        for (dir,source) in ((leftdir,"fixture:1"),(rightdir,"fixture:2"))
            s=VBFSearch._closure_open(dir)
            try
                rows=VBFSearch._closure_rows(s.db,"SELECT p.source,c.properties FROM parents p JOIN candidates c ON c.id=p.candidate_id ORDER BY p.id")
                @test only(rows)["source"]==source
                push!(indices,Set(TOML.parse(row["properties"])["root_index"] for row in rows))
                @test s.identity["qualified_roots"]==2 && s.identity["initial_roots"]==1
                @test s.identity["scientific"]["root_selection"]["count"]==1
            finally
                VBFSearch._closure_close(s)
            end
        end
        @test isempty(intersect(indices...)) && union(indices...)==Set([1,2])
        reversed=joinpath(directory,"reversed")
        result=closure_init(campaign;output=reversed,root_order="reverse")
        @test result["initial_roots"]==2 && result["root_last"]==2
        s=VBFSearch._closure_open(reversed)
        try
            rows=VBFSearch._closure_rows(s.db,"SELECT p.source,c.properties FROM parents p JOIN candidates c ON c.id=p.candidate_id ORDER BY p.id")
            @test [r["source"] for r in rows]==["fixture:2","fixture:1"]
            @test [TOML.parse(r["properties"])["root_index"] for r in rows]==[2,1]
        finally
            VBFSearch._closure_close(s)
        end
        cliout=joinpath(directory,"cli-partition")
        open(joinpath(directory,"cli-output.txt"),"w") do io
            redirect_stdout(io) do
                VBFSearch.CLI.closure_command(["init",campaign,"--output",cliout,
                    "--root-first","2","--root-last","2","--root-order","reverse"])
            end
        end
        cli_snapshot=closure_snapshot(cliout)
        @test cli_snapshot["initial_roots"]==1 && cli_snapshot["qualified_roots"]==2
        @test cli_snapshot["root_first"]==cli_snapshot["root_last"]==2 && cli_snapshot["root_order"]=="reverse"
        for (i,(first,last,order)) in enumerate(((0,1,:forward),(2,1,:forward),(1,3,:forward),(1,-1,:forward),(1,2,:random)))
            bad=joinpath(directory,"invalid-$i")
            @test_throws ArgumentError closure_init(campaign;output=bad,root_first=first,root_last=last,root_order=order)
            @test !isdir(bad)
        end
        # Refresh the file's digests after corrupting an unassigned second row.
        # A valid selected row must not bypass checks on the rest of the audit.
        text=read(rootfile,String)
        write(rootfile,replace(text,props[2]["lut_sha256"]=>repeat("0",64)))
        cp(rootfile,selected;force=true)
        proof["verified_roots_sha256"]=hash(rootfile);toml("equivalence.toml",proof)
        qualification["selected_roots_sha256"]=hash(selected);toml("qualification.toml",qualification)
        @test_throws ErrorException closure_init(campaign;output=joinpath(directory,"corrupt-unassigned"),root_first=1,root_last=1)
        @test !isdir(joinpath(directory,"corrupt-unassigned"))
    end
end

@testset "Recursive admission preserves paths and never profile-filters descendants" begin
    mktempdir() do directory
        run=closure_fixture(directory)
        s=VBFSearch._closure_open(run)
        try
            @test_throws ErrorException VBFSearch._closure_open(run)
            job=only(VBFSearch._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='switching'"))
            child=VBFSearch.properties(gold_apn(8,3).lut)
            @test child["sigma_hash"]!=VBFSearch.properties(gold_apn(8).lut)["sigma_hash"]
            VBFSearch._closure_transaction(s) do
                VBFSearch._closure_record_candidate!(s,job,child,"path-a",Dict("fixture"=>"first derivation"))
                VBFSearch._closure_record_candidate!(s,job,child,"path-b",Dict("fixture"=>"alternative derivation"))
                VBFSearch._closure_record_candidate!(s,job,child,"path-a",Dict("fixture"=>"replayed first derivation"))
            end
            @test VBFSearch._closure_count(s.db,"SELECT COUNT(*) n FROM paths")==2
            @test VBFSearch._closure_count(s.db,"SELECT COUNT(*) n FROM jobs WHERE kind='deduplicate'")==1
        finally
            VBFSearch._closure_close(s)
        end
        result=closure_run!(run;duration_seconds=20,max_jobs=1,max_evaluations=1)
        @test result["initial_roots"]==1
        @test result["promoted_parents"]==1
        @test result["total_parents"]==2 && result["unresolved_equivalence"]==0
        @test result["completed_parents"]==0 && !result["closure_complete"]
        @test result["methods"]["v5"]["jobs_pending"]==2
        @test result["methods"]["switching"]["jobs_pending"]==2
        @test !result["running"]
        @test TOML.parsefile(joinpath(run,"progress.toml"))["schema"]=="vbfsearch-closure-progress-v1"
        @test isfile(joinpath(run,"replay","workspace","packages/VBFSearch/src/closure.jl"))
    end
end

@testset "An equal signature is unresolved until a positive witness is replayed" begin
    mktempdir() do directory
        run=closure_fixture(directory);s=VBFSearch._closure_open(run)
        try
            job=only(VBFSearch._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='switching'"))
            p=VBFSearch.properties(gold_apn(8).lut .⊻ UInt8(1))
            VBFSearch._closure_transaction(s) do
                VBFSearch._closure_record_candidate!(s,job,p,"equal-signature",Dict("fixture"=>true))
            end
        finally
            VBFSearch._closure_close(s)
        end
        partial=closure_run!(run;duration_seconds=20,max_jobs=1,max_evaluations=1,equivalence_seconds=0,equivalence_nodes=0)
        @test partial["unresolved_equivalence"]==1
        @test partial["total_parents"]==1 && partial["quadratic_apn_luts"]==2
        @test !partial["closure_complete"]
        resolved=closure_run!(run;duration_seconds=30,max_jobs=1,max_evaluations=1,equivalence_seconds=10,equivalence_nodes=1_000_000)
        @test resolved["unresolved_equivalence"]==0 && resolved["total_parents"]==1
        s=VBFSearch._closure_open(run)
        try
            rows=VBFSearch._closure_rows(s.db,"SELECT evidence FROM comparisons ORDER BY id")
            @test length(rows)==2
            @test VBFSearch.verify_comparison(TOML.parse(last(rows)["evidence"]))
        finally
            VBFSearch._closure_close(s)
        end
    end
end

@testset "Parent completion requires preparation, every extension, and switching" begin
    mktempdir() do directory
        run=closure_fixture(directory);s=VBFSearch._closure_open(run)
        try
            # Model already-committed method coverage; this test exercises the
            # summary predicate, not mathematical exhaustion of a real root.
            VBFSearch._closure_exec(s.db,"UPDATE jobs SET status='done' WHERE kind='prepare_v5'")
            VBFSearch._closure_add_job!(s,1,"v5","fixture-coset-job",Dict("forms"=>[1,2,4,8,16],"need"=>22))
            first=closure_snapshot(run)
            @test first["completed_parents"]==0
            @test first["methods"]["v5"]["parents_completed"]==0
            VBFSearch._closure_exec(s.db,"UPDATE jobs SET status='done' WHERE kind='v5'")
            second=closure_snapshot(run)
            @test second["methods"]["v5"]["parents_completed"]==1
            @test second["completed_parents"]==0 && !second["closure_complete"]
            VBFSearch._closure_exec(s.db,"UPDATE jobs SET status='failed' WHERE kind='switching'")
            third=closure_snapshot(run)
            @test third["blocked_parents"]==1 && !third["closure_complete"]
            @test third["methods"]["switching"]["jobs_failed"]==1
        finally
            VBFSearch._closure_close(s)
        end
    end
end

@testset "Coverage gaps and changed inputs prevent resume" begin
    mktempdir() do directory
        run=closure_fixture(directory);s=VBFSearch._closure_open(run)
        try
            VBFSearch._closure_exec(s.db,"UPDATE jobs SET direction=2,status='paused' WHERE kind='switching'")
        finally
            VBFSearch._closure_close(s)
        end
        @test_throws ErrorException VBFSearch._closure_open(run)
        db=SQLite.DB(joinpath(run,"closure.sqlite"))
        try
            VBFSearch._closure_exec(db,"UPDATE jobs SET direction=1 WHERE kind='switching'")
        finally
            close(db)
        end
        s=VBFSearch._closure_open(run);VBFSearch._closure_close(s)
        write(joinpath(directory,"fixture-root.tsv"),"changed\n")
        @test_throws ErrorException VBFSearch._closure_open(run)
    end
end

@testset "Closure transaction rollback leaves no uncheckpointed discoveries" begin
    mktempdir() do directory
        run=closure_fixture(directory);s=VBFSearch._closure_open(run)
        try
            job=only(VBFSearch._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='switching'"))
            before=closure_snapshot(run)
            @test_throws ErrorException VBFSearch._closure_transaction(s) do
                VBFSearch._closure_record_candidate!(s,job,VBFSearch.properties(gold_apn(8,3).lut),"rollback",Dict("fixture"=>true))
                error("simulate crash before atomic cursor commit")
            end
            after=closure_snapshot(run)
            @test after["exact_luts"]==before["exact_luts"]
            @test after["construction_paths"]==before["construction_paths"]
            @test after["unresolved_equivalence"]==0
        finally
            VBFSearch._closure_close(s)
        end
    end
end

@testset "Live status follows the OS lease and stop preserves the frontier" begin
    mktempdir() do directory
        run=closure_fixture(directory);s=VBFSearch._closure_open(run)
        try
            before=VBFSearch._closure_rows(s.db,"SELECT id,direction,combination,status FROM jobs ORDER BY id")
            VBFSearch._closure_exec(s.db,"INSERT INTO sessions(started,heartbeat,pid,host,state,budgets) VALUES(?,?,?,?,?,?)",
                (VBFSearch._closure_now(),VBFSearch._closure_now(),getpid(),"fixture","running",""))
            @test closure_snapshot(run)["running"]
            closure_stop!(run)
            @test isfile(joinpath(run,"STOP"))
            @test VBFSearch._closure_rows(s.db,"SELECT id,direction,combination,status FROM jobs ORDER BY id")==before
        finally
            VBFSearch._closure_close(s)
        end
        stale=closure_snapshot(run)
        @test !stale["running"] && stale["state"]=="interrupted"
        s=VBFSearch._closure_open(run)
        try
            @test only(VBFSearch._closure_rows(s.db,"SELECT state FROM sessions"))["state"]=="interrupted"
            @test !closure_snapshot(run)["closure_complete"]
        finally
            VBFSearch._closure_close(s)
        end
    end
end

@testset "Real published-root construction cursors survive a bounded resume" begin
    mktempdir() do directory
        # Published Beierle et al. corpus member 3773089; a fixed fixture keeps
        # this bounded regression independent of local generated corpus files.
        F=SBox{8}(hex2bytes("00000001000204070004080d10161c1b00081019202a343f404c5855707e6c63002080a1e8ca6c4f5276daffaa8c260195bd052c5d77c9e287ab1f325f71c3ec00801697ed6fff7cb93da72244c25ed9e36be56c2ea42ca71a961499c749cd42a8083e9fad0f3f9c43e7dd7856f0cc6bde7658f1fb5179d275d9fb5640eeca650050e0b10d5fe9ba3b6fd3862670ca9d520aa2fb7f258bd02975d18c144ae8b7b9c9d9a85c2e384bd0a4b8cd2553493e7e060e77bbc1cfb4572b2f5282fcfe812bfbdd0ccb1939eaa97d5782598fa3749a427ca55a80b8635884b66b885662bd3aca4cbd32c040b3ea1e9461f204887f1ee6788136cc54af8e72e01db648dc23"))
        run=closure_fixture(directory;F)
        result=closure_run!(run;duration_seconds=60,max_jobs=3,max_evaluations=1000)
        @test result["completed_parents"]==0 && !result["closure_complete"]
        s=VBFSearch._closure_open(run)
        try
            prepare=only(VBFSearch._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='prepare_v5'"))
            @test prepare["status"]=="done"
            @test TOML.parse(prepare["result"])["five_spaces"]==2
            chunk=only(VBFSearch._closure_rows(s.db,"SELECT * FROM chunks"))
            @test chunk["first_x"]==1 && chunk["next_x"]==2 && chunk["total_x"]==15227
            @test TOML.parse(chunk["evidence"])["coset_representative"]==29
            switch=only(VBFSearch._closure_rows(s.db,"SELECT direction,combination FROM jobs WHERE kind='switching'"))
            @test switch["direction"]==2 && switch["combination"]=="1"
        finally
            VBFSearch._closure_close(s)
        end
        resumed=closure_run!(run;duration_seconds=15,max_jobs=1,max_evaluations=10)
        @test !resumed["closure_complete"] && resumed["methods"]["switching"]["parents_completed"]==0
        s=VBFSearch._closure_open(run)
        try
            switch=only(VBFSearch._closure_rows(s.db,"SELECT direction FROM jobs WHERE kind='switching'"))
            @test switch["direction"]==3
        finally
            VBFSearch._closure_close(s)
        end
    end
end
