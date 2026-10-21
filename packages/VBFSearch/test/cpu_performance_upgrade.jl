using Test,VBFSearch,TOML,SHA,SQLite
isdefined(@__MODULE__,:closure_fixture) || include("closure.jl")

@testset "CPU upgrades require replay evidence bound to both implementations" begin
    mktempdir() do directory
        source=closure_fixture(directory)
        identity=TOML.parsefile(joinpath(source,"identity.toml"))
        relative="packages/VBF/src/constructions/quadratic_extension_du7.jl"
        archive=joinpath(source,"replay","workspace",relative)
        open(io->write(io,"\n"),archive,"a")
        identity["implementation"][relative]=bytes2hex(open(SHA.sha256,archive))
        VBFSearch.DiscoveryStore.atomic_toml(joinpath(source,"identity.toml"),identity)
        db=SQLite.DB(joinpath(source,"closure.sqlite"))
        try
            VBFSearch._closure_exec(db,"UPDATE metadata SET value=? WHERE key='identity'",(VBFSearch._closure_text(identity),))
        finally
            close(db)
        end
        current=VBFSearch.implementation_fingerprint()
        science=Dict(key=>Dict("rows"=>1,"sha256"=>repeat("a",64)) for key in ("paths","classes","kernels","coverage"))
        function arm(implementation)
            Dict("implementation"=>implementation,"julia"=>string(VERSION),"fixture_sha256"=>repeat("b",64),
                "science"=>deepcopy(science),"result"=>Dict("state"=>"paused_window_limit","processed_packets"=>1))
        end
        evidence=Dict("schema"=>"vbfsearch-cpu-performance-validation-v1",
            "before"=>arm(identity["implementation"]),"after"=>arm(current))
        path=joinpath(directory,"validation.json")
        save(value)=write(path,String(VBFSearch.JSON3.write(value)))
        save(evidence)
        changed=[relative]
        proof=VBFSearch._closure_performance_evidence(path,identity,current,changed)
        @test proof["science"]==science
        for mutate in (
                x->x["before"]["implementation"][relative]="wrong",
                x->x["after"]["implementation"][relative]="wrong",
                x->x["after"]["science"]["paths"]["sha256"]=repeat("c",64),
                x->x["after"]["fixture_sha256"]=repeat("c",64),
                x->x["after"]["result"]["state"]="paused_external",
                x->x["before"]["result"]["processed_packets"]=0,
                x->delete!(x["after"]["science"],"coverage"))
            invalid=deepcopy(evidence);mutate(invalid);save(invalid)
            @test_throws ErrorException VBFSearch._closure_performance_evidence(path,identity,current,changed)
        end
        save(evidence)
        @test_throws ErrorException VBFSearch._closure_performance_evidence(path,identity,current,["packages/VBF/src/VBF.jl"])
        @test_throws ErrorException closure_upgrade(source;output=joinpath(directory,"unvalidated"))
        target=joinpath(directory,"validated")
        before=read(joinpath(source,"closure.sqlite"))
        closure_upgrade(source;output=target,performance_evidence=path)
        @test read(joinpath(source,"closure.sqlite"))==before
        @test read(joinpath(target,"performance-validation.json"))==read(path)
        record=TOML.parsefile(joinpath(target,"upgrade.toml"))
        @test record["performance_validation"]["sha256"]==bytes2hex(open(SHA.sha256,path))
        @test record["prior_implementation"]==identity["implementation"]
        @test record["new_implementation"]==current
        @test record["changed_implementation_paths"]==changed
    end
end

@testset "Validated CPU upgrades preserve sealed coverage and portable predecessor evidence" begin
    mktempdir() do directory
        # Recursive campaign parent 24389 has one maximizing V5, providing a
        # complete real construction job without running a closure campaign.
        root_hex="00000079003b96d40083a55feb53d819009efe19a005c814cfd294f084a2491600094b3be0d23d7679f3976472c30ac220b7957b60cc4396968286eb3d12bbed002d13470c1a89e6802e36e167f247ab10a3fd37bc34c7365f6f175e1813c6b404205c01e8f72640fd5a00defa669174348e925178f948b0023b0141a5a7304b00598aaa04661803409a6fccaf4e168e08cf7cc2ac504ecb87c3566bc8b78f890252c3eae68db1a33be85ff534dcc6572ae415a26e9bc74bdc91467273057f700175989509460630c136fd7322ee883d19f37eedb16040e8167fd4c45507012a077ad5d1efa9ab94be40c94ebd785ce03fdc138977afcd6c4929c0d9eab1f5d7"
        p=VBFSearch.properties(hex2bytes(root_hex))
        rootfile=joinpath(directory,"sealed-root.tsv");write(rootfile,root_hex*"\n")
        digest=VBFSearch.DiscoveryEvidence.filehash(rootfile)
        identity=Dict{String,Any}("schema"=>VBFSearch.CLOSURE_SCHEMA,"campaign"=>rootfile,
            "campaign_sha256"=>digest,"roots_sha256"=>digest,"initial_roots"=>1,"qualification_complete"=>true,
            "inputs"=>Dict(rootfile=>digest),"implementation"=>VBFSearch.implementation_fingerprint(),"julia"=>string(VERSION),
            "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23,"extension_cosets"=>65536))
        source=joinpath(directory,"sealed-source")
        VBFSearch._closure_initialize(source,identity,[(lut_sha256=p["lut_sha256"],lut_hex=p["lut_hex"],
            sigma_hash=p["sigma_hash"],catalog_id="cpu-upgrade-fixture:1")];normalized=true)
        logical(db)=begin
            rows=Any[]
            VBFSearch._closure_foreach_chunk(row->push!(rows,row),db)
            rows
        end
        s=VBFSearch._closure_open(source)
        cold=joinpath(directory,"source-cold")
        before=nothing;paths=nothing;classes=nothing;artifact=nothing
        science=Dict{String,Any}()
        try
            context=VBFSearch.ClosureWorkContext()
            prepare=only(VBFSearch._closure_rows(s,"SELECT * FROM jobs WHERE kind='prepare_v5'"))
            VBFSearch._closure_apply!(s,prepare,VBFSearch._closure_compute(VBFSearch._closure_work_packet(s,prepare);context,seconds=60))
            job=only(VBFSearch._closure_rows(s,"SELECT * FROM jobs WHERE kind='v5'"))
            result=VBFSearch._closure_compute(VBFSearch._closure_work_packet(s,job);context,seconds=60)
            @test result["work"]["done"]
            VBFSearch._closure_apply!(s,job,result)
            switching=only(VBFSearch._closure_rows(s,"SELECT * FROM jobs WHERE kind='switching'"))
            VBFSearch._closure_apply!(s,switching,VBFSearch._closure_compute(VBFSearch._closure_work_packet(s,switching);context,seconds=60,evaluations=1))
            before=logical(s.db)
            paths=VBFSearch._closure_rows(s,"SELECT * FROM paths ORDER BY id")
            classes=VBFSearch._closure_rows(s,"SELECT id,class_id,state FROM candidates ORDER BY id")
            kernels=VBFSearch._closure_rows(s,"SELECT * FROM kernels ORDER BY job_id,direction")
            for (key,rows) in (("coverage",before),("paths",paths),("classes",classes),("kernels",kernels))
                @test !isempty(rows)
                science[key]=Dict("rows"=>length(rows),"sha256"=>bytes2hex(SHA.sha256(VBFSearch.JSON3.write(rows))))
            end
            @test VBFSearch._closure_validate_cursors(s)===nothing
            sealed=VBFSearch.closure_seal_segments!(s;cold_directory=cold)
            @test sealed["rows"]>0
            artifact=only(collect(VBFSearch.closure_segment_artifacts(s.db,source)))
            @test logical(s.db)==before
        finally
            VBFSearch._closure_close(s)
        end
        write(joinpath(source,"STOP"),"stopped fixture\n")
        relative="packages/VBF/src/constructions/quadratic_extension_du7.jl"
        archive=joinpath(source,"replay","workspace",relative)
        open(io->write(io,"\n"),archive,"a")
        identity["implementation"][relative]=VBFSearch.DiscoveryEvidence.filehash(archive)
        VBFSearch.DiscoveryStore.atomic_toml(joinpath(source,"identity.toml"),identity)
        db=SQLite.DB(joinpath(source,"closure.sqlite"))
        try
            VBFSearch._closure_exec(db,"UPDATE metadata SET value=? WHERE key='identity'",(VBFSearch._closure_text(identity),))
            VBFSearch._closure_exec(db,"PRAGMA wal_checkpoint(TRUNCATE)")
        finally
            close(db)
        end
        current=VBFSearch.implementation_fingerprint()
        arm(implementation)=Dict("implementation"=>implementation,"julia"=>string(VERSION),"fixture_sha256"=>digest,
            "science"=>deepcopy(science),"result"=>Dict("state"=>"paused_window_limit","processed_packets"=>3))
        evidence=joinpath(directory,"sealed-validation.json")
        write(evidence,String(VBFSearch.JSON3.write(Dict("schema"=>"vbfsearch-cpu-performance-validation-v1",
            "before"=>arm(identity["implementation"]),"after"=>arm(current)))))
        original_bytes=read(joinpath(source,"closure.sqlite"))
        original_identity=read(joinpath(source,"identity.toml"))
        cold_bytes=read(last(artifact))
        ordinary=joinpath(directory,"ordinary-upgrade")
        refused=try closure_upgrade(source;output=ordinary);nothing catch err;err end
        @test refused isa ErrorException
        @test occursin("closure_rehydrate_segments!",sprint(showerror,refused))
        @test !ispath(ordinary)
        target=joinpath(directory,"sealed-upgrade")
        closure_upgrade(source;output=target,performance_evidence=evidence)
        @test read(joinpath(source,"closure.sqlite"))==original_bytes
        @test read(joinpath(source,"identity.toml"))==original_identity
        @test read(last(artifact))==cold_bytes
        record=TOML.parsefile(joinpath(target,"upgrade.toml"))
        @test record["cold_artifacts_copied"]==1
        @test record["prior_implementation"]==identity["implementation"]
        @test record["new_implementation"]==current
        hidden=cold*".hidden";mv(cold,hidden)
        try
            for checkpoint in (target,joinpath(target,"lineage","previous"))
                @test read(joinpath(checkpoint,first(artifact)))==cold_bytes
                copydb=SQLite.DB("file:"*joinpath(checkpoint,"closure.sqlite")*"?mode=ro")
                try
                    @test only(VBFSearch._closure_rows(copydb,"SELECT value FROM metadata WHERE key='closure_segment_root'"))["value"]=="cold"
                    @test VBFSearch.closure_verify_segments(copydb,checkpoint;full=true,replay=true)["rows"]>0
                    @test logical(copydb)==before
                    @test VBFSearch._closure_rows(copydb,"SELECT * FROM paths ORDER BY id")==paths
                    @test isequal(VBFSearch._closure_rows(copydb,"SELECT id,class_id,state FROM candidates ORDER BY id"),classes)
                    @test VBFSearch._closure_validate_cursors((db=copydb,))===nothing
                finally
                    close(copydb)
                end
            end
        finally
            mv(hidden,cold)
        end
        @test read(joinpath(source,"closure.sqlite"))==original_bytes
        @test read(last(artifact))==cold_bytes
    end
end
