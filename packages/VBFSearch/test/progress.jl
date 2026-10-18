@testset "Progress reads committed state without blocking the writer" begin
    mktempdir() do dir
        store=open_store(dir,Dict("test"=>"progress"))
        reporter=open_progress_reporter(dir,7,time_ns();interval_seconds=60)
        try
            F=gold_apn(8)
            p=properties(F.lut)
            p["additional_signature"]=true
            p["evidence_level"]="inequivalent_to_documented_quadratic_corpus"
            register!(store,p)
            seed!(store,F.lut,p["sigma_hash"],"v5")
            @test report_progress!(reporter)
            @test !report_progress!(reporter)
            path=joinpath(dir,"progress.toml")
            before=TOML.parsefile(path)
            @test before["session"]==7
            @test before["exact_luts"]==1
            @test before["additional_signature_buckets"]==1
            held=Channel{Nothing}(1)
            release=Channel{Nothing}(1)
            other=@async lock(reporter.guard) do
                put!(held,nothing)
                take!(release)
            end
            take!(held)
            try
                @test !report_progress!(reporter;force=true)
            finally
                put!(release,nothing)
                wait(other)
            end
            q=properties(F.lut .⊻ UInt8(1))
            q["additional_signature"]=true
            q["evidence_level"]=p["evidence_level"]
            transaction(store) do
                register!(store,q)
                claim!(store)
                @test report_progress!(reporter;force=true)
                during=TOML.parsefile(path)
                @test during["exact_luts"]==1
                @test during["units"]==Dict("pending"=>1)
            end
            @test report_progress!(reporter;force=true)
            after=TOML.parsefile(path)
            @test after["exact_luts"]==2
            @test after["additional_signature_buckets"]==1
            @test after["corpus_absent_signature_buckets"]==1
            @test after["units"]==Dict("running"=>1)
            @test_throws ErrorException transaction(store) do
                finish!(store,only(query(store,"SELECT * FROM units")),Dict();done=true)
                error("rollback")
            end
            @test report_progress!(reporter;force=true)
            @test TOML.parsefile(path)["units"]==Dict("running"=>1)
        finally
            close_progress_reporter(reporter)
            close_store(store)
        end
        store=open_store(dir,Dict("test"=>"progress");resume=true)
        try
            @test snapshot(store)["units"]==Dict("paused"=>1)
            @test claim!(store)!==nothing
        finally
            close_store(store)
        end
    end
end
