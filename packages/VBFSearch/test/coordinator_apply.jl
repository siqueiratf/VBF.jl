module CoordinatorApplyTests
using Test,VBF,VBFSearch,SHA
const VS=VBFSearch

# A fixed quadratic APN from the independently validated uniform-parent holdout.
# The fixture consumes this LUT directly and does not depend on local run files.
const ROOT_HEX="000000720030783a002aa7ff859f5a3200f50e89d411a2155e81f75a0fe0de4300516c4f3c5d283b2d56e6ef94df271e20844294c85cd23453dd966a3e80834f008aea1273c9e1298020cd1f76e643a1106ff4f9b7f82b16ce9b8daaec89d7c004df822b4ba0b52ca958880b63a23a89341abce0afb15f33c7c3e89ed9ed8ec800f45adc2feb0dbb409ebd11ea046ff308095c2ff3c2df9c163de5bc6873e38a02a734e311845fb86fe0fe03f94610dd2a7a1230ed8dadbf1963868e5b11bc84017fb1bd5d1395a9c195d6f0187c77611992a75e912a579e87269e4d8a1beb080728db866778c3aeeaef91e60f3a0c4b3fe5ed458b6121b98c7cf97bbd7db002"
const FORMS=[136005744,76718742,34531144,25906815,8304766]

function fixture(directory)
    p=VS.properties(hex2bytes(ROOT_HEX))
    rootfile=joinpath(directory,"root.tsv");write(rootfile,ROOT_HEX*"\n")
    digest=bytes2hex(open(SHA.sha256,rootfile))
    identity=Dict{String,Any}("schema"=>VS.CLOSURE_SCHEMA,"campaign"=>rootfile,"campaign_sha256"=>digest,
        "roots_sha256"=>digest,"initial_roots"=>1,"qualification_complete"=>true,
        "inputs"=>Dict(rootfile=>digest),"implementation"=>VS.implementation_fingerprint(),"julia"=>string(VERSION),
        "scientific"=>Dict("n"=>8,"m"=>8,"target_b6"=>52,"max_kernel"=>23,"extension_cosets"=>65536))
    rows=[(lut_sha256=p["lut_sha256"],lut_hex=p["lut_hex"],sigma_hash=p["sigma_hash"],catalog_id="coordinator-test:1")]
    run=joinpath(directory,"run");VS._closure_initialize(run,identity,rows)
    s=VS._closure_open(run)
    VS._closure_add_job!(s,1,"v5","coordinator-test:v5",Dict("forms"=>FORMS,"need"=>22,"b5"=>30))
    s,only(VS._closure_rows(s.db,"SELECT * FROM jobs WHERE kind='v5'"))
end

snapshot(s)=Dict(table=>VS._closure_rows(s.db,"SELECT * FROM $table ORDER BY rowid") for table in
    ("candidates","parents","jobs","paths","chunks","evaluations","kernels","comparisons"))

@testset "Concrete coset apply preserves dictionary fallback and late rollback" begin
    mktempdir() do directory
        s,job=fixture(directory)
        try
            result=VS._closure_compute(VS._closure_work_packet(s,job);seconds=60,evaluations=256)
            @test result["work"]["done"]
            @test result["work"]["processed_cosets"]>1000
            @test !isempty(result["work"]["records"])
            @test result["work"]["chunks"] isa Vector{VS._ClosurePreparedV5Chunk}
            wire=VS.JSON3.read(VS.JSON3.write(result),Dict{String,Any})
            @test first(wire["work"]["chunks"]) isa AbstractDict
            @test !(first(wire["work"]["chunks"]) isa VS._ClosurePreparedV5Chunk)
            base=snapshot(s);expected=nothing
            for payload in (result,wire)
                VS._closure_exec(s.db,"BEGIN IMMEDIATE")
                @test VS._closure_apply!(s,job,payload)==result["work"]["evaluations"]
                observed=snapshot(s)
                if expected===nothing
                    expected=observed
                else
                    @test isequal(observed,expected)
                end
                @test only(VS._closure_rows(s.db,"SELECT evidence FROM chunks"))["evidence"]==result["work"]["ledger"].evidence
                VS._closure_exec(s.db,"ROLLBACK")
                @test isequal(snapshot(s),base)

                # The completion flag is checked after candidate/path insertion,
                # compact ledger insertion and the persisted cursor UPDATE.
                bad=copy(payload);badwork=copy(payload["work"]);badwork["done"]=false;bad["work"]=badwork
                failure=try
                    VS._closure_apply!(s,job,bad)
                    nothing
                catch e
                    e
                end
                @test failure isa ErrorException
                @test occursin("extension completion flag mismatch",sprint(showerror,failure))
                @test isequal(snapshot(s),base)
            end
            @test VS._closure_apply!(s,job,result)==result["work"]["evaluations"]
            @test isequal(snapshot(s),expected)
            @test_throws ErrorException VS._closure_apply!(s,job,wire)
        finally
            VS._closure_close(s)
        end
    end
end
end
