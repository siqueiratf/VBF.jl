using SQLite, DBInterface
function test_reference(directory)
    mkpath(directory)
    db=SQLite.DB(joinpath(directory,"fresh_union.sqlite"))
    DBInterface.execute(db,"CREATE TABLE signatures(sigma_hash TEXT PRIMARY KEY)")
    for hash in unique(p["sigma_hash"] for p in VBFSearch.DiscoveryEvidence.gold_coverage())
        DBInterface.execute(db,"INSERT INTO signatures VALUES(?)",(hash,))
    end
    count=only([Int(r.c) for r in DBInterface.execute(db,"SELECT COUNT(*) c FROM signatures")])
    SQLite.close(db)
    digest=bytes2hex(open(SHA.sha256,joinpath(directory,"fresh_union.sqlite")))
    open(io->TOML.print(io,Dict("scope"=>"quadratic (8,8)-APN","provenance_complete"=>true,"fresh_union_sha256"=>digest,
        "fresh_union_distinct_signatures"=>count)),joinpath(directory,"comparison.toml"),"w")
    directory
end

@testset "Public configuration and checkpointed experiment replay" begin
    @test_throws ArgumentError SearchConfig(output="x",method=:unknown)
    @test_throws ArgumentError SearchConfig(output="x",bent="32")
    @test_throws ArgumentError SearchConfig(output="x",duration=Inf)
    mktempdir() do dir
        reference=test_reference(joinpath(dir,"reference"))
        output=joinpath(dir,"run")
        seed=joinpath(dir,"seed.tsv")
        gold=candidate_properties(gold_apn(8).lut)
        write(seed,"sigma_hash\tlut_hex\n"*gold["sigma_hash"]*"\t"*gold["lut_hex"]*"\n")
        config=SearchConfig(;output,reference,supplement="",inputs=[seed],method=:switching,parents=1,
            duration=0.05,workers=1,evaluations=1)
        first=search(config)
        @test !first["finite_plan_exhausted"]
        @test first["exact_luts"]>=0
        before=VBFSearch.status(output)
        stop!(output)
        @test isfile(joinpath(output,"STOP"))
        second=resume(output;duration=60,workers=1,evaluations=10000)
        @test second["finite_plan_exhausted"]
        @test second["exact_luts"]>=before["exact_luts"]
        @test !isfile(joinpath(output,"STOP"))
        @test audit(output;reference,supplement="")["database_integrity"]=="ok"
        input=joinpath(output,"inputs","1_seed.tsv")
        imported=validate([input];output=joinpath(dir,"import"),reference,supplement="",limit=1)
        @test imported["records_verified"]==1
        @test !imported["complete_input_validation"]
        @test_throws ErrorException search(config)
    end
end
