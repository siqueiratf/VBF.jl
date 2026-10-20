module ClosurePortableUpgradeTests
using Test,VBF,VBFSearch,TOML,SQLite
const VS=VBFSearch

@testset "Execution upgrades preserve relocation, runtime pins and controller lineage" begin
    mktempdir() do directory
        original=joinpath(directory,"original");mkpath(original)
        p=VS.properties(gold_apn(8).lut)
        input=joinpath(original,"root.tsv");write(input,p["lut_hex"]*"\n")
        digest=VS.DiscoveryEvidence.filehash(input)
        identity=Dict{String,Any}("schema"=>VS.CLOSURE_SCHEMA,"campaign"=>input,"campaign_sha256"=>digest,
            "roots_sha256"=>digest,"initial_roots"=>1,"qualification_complete"=>true,"inputs"=>Dict(input=>digest),
            "implementation"=>VS.implementation_fingerprint(),"julia"=>string(VERSION),
            "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23,"switching_directions"=>1))
        run=joinpath(original,"run")
        VS._closure_initialize(run,identity,[(lut_sha256=p["lut_sha256"],lut_hex=p["lut_hex"],sigma_hash=p["sigma_hash"],catalog_id="upgrade-portable:fixture")])
        env=joinpath(run,"replay","workspace","portable-environment");mkpath(env)
        project=Base.active_project()
        cp(project,joinpath(env,"Project.toml"));cp(joinpath(dirname(project),"Manifest.toml"),joinpath(env,"Manifest.toml"))
        VS.closure_relocate!(run;active_project=env)
        controller=joinpath(run,"execution","controllers","prior","controller.jl");mkpath(dirname(controller));write(controller,"# pinned prior controller\n")
        source=joinpath(directory,"relocated-source")
        VS.closure_export_checkpoint(run;output=source)
        rm(original;recursive=true)
        source_identity=read(joinpath(source,"identity.toml"))
        source_map=TOML.parsefile(joinpath(source,VS._CLOSURE_PATH_MAP))
        source_db_hash=VS.DiscoveryEvidence.filehash(joinpath(source,"closure.sqlite"))
        target=joinpath(directory,"upgraded")
        summary=VS.closure_upgrade(source;output=target,switching_directions=255)
        @test summary["initial_roots"]==1
        @test read(joinpath(source,"identity.toml"))==source_identity
        @test VS.DiscoveryEvidence.filehash(joinpath(source,"closure.sqlite"))==source_db_hash
        new_identity=TOML.parsefile(joinpath(target,"identity.toml"))
        new_map=TOML.parsefile(joinpath(target,VS._CLOSURE_PATH_MAP))
        @test new_identity["inputs"]==identity["inputs"]
        @test new_map["identity_sha256"]==VS.DiscoveryEvidence.filehash(joinpath(target,"identity.toml"))
        @test new_map["runtime_build"]==source_map["runtime_build"]
        @test new_map["active_environment"]==source_map["active_environment"]
        @test new_map["previous_map_sha256"]==VS.DiscoveryEvidence.filehash(joinpath(source,VS._CLOSURE_PATH_MAP))
        @test all(!isabspath(entry["path"]) for entry in values(new_map["inputs"]))
        previous=joinpath(target,"lineage","previous")
        @test read(joinpath(previous,"identity.toml"))==source_identity
        @test TOML.parsefile(joinpath(previous,VS._CLOSURE_PATH_MAP))==source_map
        @test read(joinpath(target,"execution","controllers","prior","controller.jl"),String)=="# pinned prior controller\n"
        record=TOML.parsefile(joinpath(target,"upgrade.toml"))
        @test record["source_execution_paths_sha256"]==VS.DiscoveryEvidence.filehash(joinpath(source,VS._CLOSURE_PATH_MAP))
        @test record["execution_paths_sha256"]==VS.DiscoveryEvidence.filehash(joinpath(target,VS._CLOSURE_PATH_MAP))
        store=VS._closure_open(target)
        try
            @test store.identity==new_identity
            @test VS._closure_count(store.db,"SELECT COUNT(*) n FROM parents")==1
            @test TOML.parse(only(VS._closure_rows(store.db,"SELECT value FROM metadata WHERE key='execution_upgrade'"))["value"])==record
        finally
            VS._closure_close(store)
        end
        # Unsupported old cloning paths must fail before producing a broken copy.
        write(joinpath(source,"STOP"),"stopped fixture\n")
        for (name,call) in (("compact",out->VS.closure_compact(source;output=out,helper="unused")),
                            ("reduce",out->VS.closure_reduce(source;output=out,helper="unused")))
            output=joinpath(directory,name)
            failure=try call(output);nothing catch error;error end
            @test failure isa ErrorException
            @test occursin("execution paths",sprint(showerror,failure))
            @test !ispath(output) && !ispath(output*".reducing")
        end
        @test "packages/VBFSearch/src/closure_portable.jl" in VS._CLOSURE_UPGRADE_PATHS
        @test "packages/VBFSearch/src/closure_segments.jl" in VS._CLOSURE_UPGRADE_PATHS
        @test !("packages/VBF/src/VBF.jl" in VS._CLOSURE_UPGRADE_PATHS)
    end
end
end
