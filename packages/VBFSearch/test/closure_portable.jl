module ClosurePortableTests
using Test,VBF,VBFSearch,TOML,SHA,SQLite,DBInterface
const VS=VBFSearch

function fixture(directory)
    mkpath(directory)
    props=VS.properties(gold_apn(8).lut)
    input=joinpath(directory,"original.tsv");write(input,props["lut_hex"]*"\n")
    digest=VS.DiscoveryEvidence.filehash(input)
    identity=Dict{String,Any}("schema"=>VS.CLOSURE_SCHEMA,"campaign"=>input,
        "campaign_sha256"=>digest,"roots_sha256"=>digest,"initial_roots"=>1,"qualification_complete"=>true,
        "inputs"=>Dict(input=>digest),"implementation"=>VS.implementation_fingerprint(),"julia"=>string(VERSION),
        "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23))
    roots=[(lut_sha256=props["lut_sha256"],lut_hex=props["lut_hex"],sigma_hash=props["sigma_hash"],catalog_id="portable-fixture:1")]
    run=joinpath(directory,"frontier");VS._closure_initialize(run,identity,roots)
    project=Base.active_project();@assert project!==nothing
    environment=joinpath(run,"replay","workspace","portable-active-environment")
    mkpath(environment)
    cp(project,joinpath(environment,"Project.toml"))
    cp(joinpath(dirname(project),"Manifest.toml"),joinpath(environment,"Manifest.toml"))
    (;run,input,environment,identity)
end

@testset "Execution relocation verifies bytes and preserves scientific identity" begin
    mktempdir() do directory
        f=fixture(joinpath(directory,"source"))
        before=read(joinpath(f.run,"identity.toml"))
        wrong=joinpath(directory,"wrong.tsv");write(wrong,"corruption\n")
        @test_throws ErrorException VS.closure_relocate!(f.run;paths=Dict(f.input=>wrong))
        @test !isfile(joinpath(f.run,VS._CLOSURE_PATH_MAP))
        @test_throws ErrorException VS.closure_relocate!(f.run;paths=Dict("unknown"=>f.input))
        relocated=VS.closure_relocate!(f.run;active_project=f.environment)
        @test relocated["inputs"][f.input]["sha256"]==f.identity["inputs"][f.input]
        @test !isabspath(relocated["inputs"][f.input]["path"])
        rm(f.input)
        store=VS._closure_open(f.run)
        @test store.identity==f.identity
        @test_throws ErrorException VS.closure_relocate!(f.run)
        VS._closure_close(store)
        @test read(joinpath(f.run,"identity.toml"))==before
        second=VS.closure_relocate!(f.run;active_project=f.environment)
        @test second["previous_map_sha256"]!="none"
        archive=joinpath(f.run,second["inputs"][f.input]["path"])
        write(archive,"damaged archived input")
        @test_throws ErrorException VS._closure_open(f.run)
    end
end

@testset "Portable snapshot includes committed WAL and verifies moved bundles" begin
    mktempdir() do directory
        f=fixture(joinpath(directory,"source"))
        VS.closure_relocate!(f.run;active_project=f.environment)
        controller=joinpath(f.run,"execution","controllers","fixture","controller.jl")
        mkpath(dirname(controller));write(controller,"# frozen operational controller\n")
        controller_hash=VS.DiscoveryEvidence.filehash(controller)
        VS.DiscoveryStore.atomic_toml(joinpath(dirname(controller),"source-hashes.toml"),Dict("controller.jl"=>controller_hash))
        store=VS._closure_open(f.run)
        bundle=joinpath(directory,"generation-1")
        try
            VS._closure_exec(store.db,"INSERT INTO metadata VALUES('portable-wal-fixture','committed')")
            @test_throws ErrorException VS.closure_export_checkpoint(f.run;output=bundle,active_project=f.environment)
            @test !ispath(bundle)
            VS._closure_exec(store.db,"BEGIN IMMEDIATE")
            @test_throws ErrorException VS.closure_export_checkpoint(store;output=bundle,active_project=f.environment)
            VS._closure_exec(store.db,"ROLLBACK")
            exported=VS.closure_export_checkpoint(store;output=bundle,active_project=f.environment)
            @test exported["verified"]
            @test !isfile(joinpath(bundle,"closure.sqlite-wal"))
            @test !isfile(joinpath(bundle,"closure.sqlite-shm"))
            @test VS.closure_verify_checkpoint(bundle)["verified"]
            @test VS.DiscoveryEvidence.filehash(joinpath(bundle,"execution","controllers","fixture","controller.jl"))==controller_hash
            @test_throws ErrorException VS.closure_export_checkpoint(store;output=bundle,active_project=f.environment)
        finally
            VS._closure_close(store)
        end
        moved=joinpath(directory,"another-prefix","generation-1");mkpath(dirname(moved));mv(bundle,moved)
        rm(joinpath(directory,"source");recursive=true)
        @test VS.closure_verify_checkpoint(moved)["verified"]
        store=VS._closure_open(moved)
        try
            @test only(VS._closure_rows(store.db,"SELECT value FROM metadata WHERE key='portable-wal-fixture'"))["value"]=="committed"
            @test store.identity==f.identity
        finally
            VS._closure_close(store)
        end
        # Ordinary resume is allowed to update the working database. Sealed
        # publication verification must then reject the changed generation.
        changed=SQLite.DB(joinpath(moved,"closure.sqlite"))
        try
            VS._closure_exec(changed,"INSERT INTO metadata VALUES('working-copy-change','1')")
        finally
            close(changed)
        end
        @test_throws ErrorException VS.closure_verify_checkpoint(moved)
    end
end

@testset "Bundle corruption, active environment changes and failed staging" begin
    mktempdir() do directory
        f=fixture(joinpath(directory,"source"))
        VS.closure_relocate!(f.run;active_project=f.environment)
        bundle=joinpath(directory,"good")
        VS.closure_export_checkpoint(f.run;output=bundle,active_project=f.environment)
        corrupted=joinpath(directory,"corrupt");cp(bundle,corrupted)
        manifest=TOML.parsefile(joinpath(corrupted,VS._CLOSURE_BUNDLE_MANIFEST))
        relative=manifest["active_environment"]["project"]["path"]
        open(joinpath(corrupted,relative),"a") do io;write(io,"\n# changed\n");end
        @test_throws ErrorException VS.closure_verify_checkpoint(corrupted)
        # A path traversal must fail before publication and retain the last good generation.
        failed=joinpath(directory,"failed")
        @test_throws ErrorException VS.closure_export_checkpoint(f.run;output=failed,active_project=f.environment,extra_paths=["../escape"])
        @test !ispath(failed)
        @test VS.closure_verify_checkpoint(bundle)["verified"]
        @test_throws ErrorException VS.closure_export_checkpoint(f.run;output=joinpath(directory,"over-budget"),active_project=f.environment,reserve_bytes=typemax(Int))
        @test !ispath(joinpath(directory,"over-budget"))
        @test_throws ErrorException VS._closure_portable_relative("../escape")
        @test_throws ErrorException VS._closure_portable_relative("/absolute")
        # A valid archived environment can still differ from the actually loaded environment.
        other=joinpath(f.run,"replay","workspace","different-environment");mkpath(other)
        write(joinpath(other,"Project.toml"),"[deps]\n")
        cp(joinpath(f.environment,"Manifest.toml"),joinpath(other,"Manifest.toml"))
        @test_throws ErrorException VS.closure_relocate!(f.run;active_project=other)
        @test_throws ErrorException VS.closure_export_checkpoint(f.run;output=joinpath(directory,"changed-environment"),active_project=other)
        @test VS.closure_relocate!(f.run)["active_environment"]["project"]["sha256"]==VS.DiscoveryEvidence.filehash(joinpath(f.environment,"Project.toml"))
        # A fresh explicit pin can be inspected, but resume still checks the
        # actually loaded environment against it.
        fresh=fixture(joinpath(directory,"fresh"))
        alternative=joinpath(fresh.run,"replay","workspace","different-environment");mkpath(alternative)
        cp(joinpath(other,"Project.toml"),joinpath(alternative,"Project.toml"))
        cp(joinpath(other,"Manifest.toml"),joinpath(alternative,"Manifest.toml"))
        VS.closure_relocate!(fresh.run;active_project=alternative)
        @test_throws ErrorException VS._closure_open(fresh.run)
        unsafe=joinpath(f.run,"execution","unsafe-symlink");mkpath(dirname(unsafe));symlink(f.input,unsafe)
        @test_throws ErrorException VS.closure_export_checkpoint(f.run;output=joinpath(directory,"symlink-export"),active_project=f.environment)
        @test !ispath(joinpath(directory,"symlink-export"))
        rm(unsafe)
        # Matching metadata and identity files cannot authorize a changed runtime.
        mismatch=fixture(joinpath(directory,"wrong-runtime"))
        wrong_identity=deepcopy(mismatch.identity);wrong_identity["julia"]="0.0.0"
        wrong_db=SQLite.DB(joinpath(mismatch.run,"closure.sqlite"))
        try
            VS._closure_exec(wrong_db,"UPDATE metadata SET value=? WHERE key='identity'",(VS._closure_text(wrong_identity),))
        finally
            close(wrong_db)
        end
        VS.DiscoveryStore.atomic_toml(joinpath(mismatch.run,"identity.toml"),wrong_identity)
        @test_throws ErrorException VS.closure_relocate!(mismatch.run)
        @test_throws ErrorException VS.closure_export_checkpoint(mismatch.run;output=joinpath(directory,"wrong-runtime-export"),active_project=mismatch.environment)
        @test !ispath(joinpath(directory,"wrong-runtime-export"))
    end
end

@testset "Checkpoint exports automatically carry external sealed evidence" begin
    mktempdir() do directory
        f=fixture(joinpath(directory,"source"));VS.closure_relocate!(f.run;active_project=f.environment)
        store=VS._closure_open(f.run);bundle=joinpath(directory,"sealed-generation")
        before=nothing;sealed=nothing
        try
            VS._closure_exec(store.db,"INSERT INTO jobs(id,parent_id,kind,job_key,payload,status,direction) VALUES(3,1,'v5','portable:v5','','done',3)")
            records=[Dict{String,Any}("job_id"=>3,"first_x"=>i,"next_x"=>i+1,"total_x"=>2,"capped"=>0,"evidence"=>"opaque = \"fixture $i\"\n") for i in 1:2]
            evidence=VS._closure_pack_chunks(records)
            VS._closure_exec(store.db,"INSERT INTO chunks VALUES(3,1,3,2,0,?)",(evidence,))
            before=Any[];VS._closure_foreach_chunk(row->push!(before,row),store.db)
            sealed=VS.closure_seal_segments!(store;cold_directory=joinpath(directory,"external-cold"))
            @test sealed["rows"]==1
            @test VS.closure_export_checkpoint(store;output=bundle)["verified"]
            @test isfile(joinpath(bundle,"cold",sealed["digest"]*".zst"))
        finally
            VS._closure_close(store)
        end
        rm(joinpath(directory,"source");recursive=true)
        rm(joinpath(directory,"external-cold");recursive=true)
        @test VS.closure_verify_checkpoint(bundle)["verified"]
        reopened=VS._closure_open(bundle)
        try
            after=Any[];VS._closure_foreach_chunk(row->push!(after,row),reopened.db)
            @test before==after
            @test only(VS._closure_rows(reopened.db,"SELECT value FROM metadata WHERE key='closure_segment_root'"))["value"]=="cold"
            @test VS.closure_verify_segments(reopened.db,bundle;full=true)["rows"]==1
        finally
            VS._closure_close(reopened)
        end
        rm(joinpath(bundle,"cold",sealed["digest"]*".zst"))
        @test_throws ErrorException VS._closure_open(bundle)
    end
end
end
