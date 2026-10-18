using Test,VBF,VBFSearch,TOML,SHA,SQLite
isdefined(@__MODULE__,:closure_fixture) || include("closure.jl")

@testset "Controller upgrade retains complete evidence and archived implementation lineage" begin
    mktempdir() do directory
        source=closure_fixture(directory)
        summary=closure_run!(source;duration_seconds=60,max_jobs=2,max_evaluations=1)
        before=closure_snapshot(source)
        original=read(joinpath(source,"closure.sqlite"))
        manifest=read(joinpath(source,"identity.toml"))
        upgraded=joinpath(directory,"upgraded")
        after=closure_upgrade(source;output=upgraded,switching_directions=32)
        for key in ("initial_roots","promoted_parents","construction_paths","exact_luts","campaign_sha256","roots_sha256","methods")
            @test after[key]==before[key]
        end
        @test read(joinpath(source,"closure.sqlite"))==original
        @test read(joinpath(source,"identity.toml"))==manifest
        identity=TOML.parsefile(joinpath(upgraded,"identity.toml"))
        old=TOML.parse(String(copy(manifest)))
        @test identity["implementation"]==VBFSearch.implementation_fingerprint()
        @test identity["scientific"]["switching_directions"]==32
        @test all(key=="switching_directions" || identity["scientific"][key]==value for (key,value) in old["scientific"])
        record=TOML.parsefile(joinpath(upgraded,"upgrade.toml"))
        @test record["source_sessions_through"]==1
        previous=joinpath(upgraded,"lineage","previous")
        @test read(joinpath(previous,"identity.toml"))==manifest
        @test record["source_snapshot_sha256"]==bytes2hex(open(SHA.sha256,joinpath(previous,"closure.sqlite")))
        a=SQLite.DB("file:"*joinpath(previous,"closure.sqlite")*"?mode=ro")
        b=SQLite.DB("file:"*joinpath(upgraded,"closure.sqlite")*"?mode=ro")
        try
            for table in ("candidates","parents","jobs","paths","evaluations","kernels","chunks","comparisons","sessions")
                @test isequal(VBFSearch._closure_rows(a,"SELECT * FROM $table ORDER BY rowid"),VBFSearch._closure_rows(b,"SELECT * FROM $table ORDER BY rowid"))
            end
        finally
            close(a);close(b)
        end
        @test_throws ErrorException closure_upgrade(source;output=upgraded)
        @test_throws ArgumentError closure_upgrade(source;output=joinpath(directory,"bad-policy"),switching_directions=0)
        @test_throws ErrorException closure_upgrade(source;output=joinpath(source,"nested"))
        resumed=closure_run!(upgraded;duration_seconds=60,max_jobs=1,max_evaluations=1)
        @test maximum(row["id"] for row in resumed["sessions"])==2
        second=joinpath(directory,"second-upgrade")
        closure_upgrade(upgraded;output=second,switching_directions=255)
        @test isfile(joinpath(second,"lineage","previous","lineage","previous","closure.sqlite"))
    end
end

@testset "Controller upgrade refuses live, corrupt and mathematically changed sources" begin
    mktempdir() do directory
        source=closure_fixture(directory);target=joinpath(directory,"upgrade")
        store=VBFSearch._closure_open(source)
        try
            @test_throws ErrorException closure_upgrade(source;output=target)
        finally
            VBFSearch._closure_close(store)
        end
        @test !ispath(target)
        archive=joinpath(source,"replay","workspace","packages/VBF/src/VBF.jl")
        text=read(archive)
        write(archive,"corrupt\n")
        @test_throws ErrorException closure_upgrade(source;output=target)
        @test !ispath(target)
        write(archive,text)
        identity=TOML.parsefile(joinpath(source,"identity.toml"))
        write(archive,"valid archived older math\n")
        identity["implementation"]["packages/VBF/src/VBF.jl"]=bytes2hex(open(SHA.sha256,archive))
        VBFSearch.DiscoveryStore.atomic_toml(joinpath(source,"identity.toml"),identity)
        db=SQLite.DB(joinpath(source,"closure.sqlite"))
        VBFSearch._closure_exec(db,"UPDATE metadata SET value=? WHERE key='identity'",(VBFSearch._closure_text(identity),))
        close(db)
        @test_throws ErrorException closure_upgrade(source;output=target)
        @test !ispath(target)
    end
end
