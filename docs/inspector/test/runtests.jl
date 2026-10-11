# Tests the request handler of the APN8 class check page directly (no socket).
# Study: census of quadratic APN functions on F_2^8 (packages/VBFSearch/data/research/archive/census)
#
# Pseudocode:
#   1. Include server.jl and build HTTP.Request values by hand.
#   2. Send each input to APN8Web.handle and decode the JSON response.
#   3. Check the verdicts: known corpus member, census member, Gold x^3, a non-APN LUT,
#      a non-quadratic APN function, and malformed input.
# VBF API used: SBox, gf_monomial_lut
# VBFCatalog API used: load_catalog, corpus_function
#
# Run from the repository root: make -C docs test

using HTTP
using JSON3
using Random
using Test
using VBF
using VBFCatalog

include(joinpath(@__DIR__, "../server.jl"))

call(method, path, body = "") =
    APN8Web.handle(HTTP.Request(method, path, ["Content-Type" => "text/plain"], body))
classify(body) = (r = call("POST", "/api/classify", body); (r.status, JSON3.read(String(r.body))))
lutstr(lut; sep = ", ") = "[" * join(lut, sep) * "]"

const CENSUS = [split(l, '\t') for l in eachline(APN8Web.CENSUS_TSV)]

@testset "APN8 web handler" begin
    APN8Web.init!()

    @testset "page and routes" begin
        r = call("GET", "/")
        @test r.status == 200
        @test occursin("<textarea", String(r.body))
        @test call("GET", "/nothing").status == 404
        h = JSON3.read(String(call("GET", "/api/health").body))
        @test h.ok && h.census == 553 && h.index_rows > 4_000_000
        @test String(call("GET", "/inspector/").body) == APN8Web.PAGE
        @test APN8Web.PAGE == read(joinpath(APN8Web.REPO_ROOT,"docs/src/assets/apn-inspector.html"), String)
        @test occursin("/api/health", APN8Web.PAGE)
        @test call("GET", "/docs/").status == 404
    end

    @testset "documentation and API share one origin" begin
        mktempdir() do dir
            build = joinpath(dir, "build")
            mkpath(joinpath(build, "assets"))
            mkpath(joinpath(build, "inspector"))
            write(joinpath(build, "index.html"), "Documentation home")
            write(joinpath(build, "inspector.html"), "Inspector docs (flat URL)")
            write(joinpath(build, "inspector", "index.html"), "Inspector docs (pretty URL)")
            write(joinpath(build, "assets", "apn-inspector.html"), APN8Web.PAGE)
            write(joinpath(build, "assets", "docs.css"), "body {}")
            secret = joinpath(dir, "private.txt")
            write(secret, "must not be served")
            symlink(secret, joinpath(build, "leak.txt"))
            APN8Web.DOCS_DIRECTORY[] = build
            try
                @test HTTP.header(call("GET", "/"), "Location") == "/docs/"
                @test HTTP.header(call("GET", "/docs"), "Location") == "/docs/"
                @test String(call("GET", "/docs/").body) == "Documentation home"
                @test String(call("GET", "/docs/inspector.html").body) == "Inspector docs (flat URL)"
                @test HTTP.header(call("GET", "/docs/inspector"), "Location") == "/docs/inspector/"
                @test String(call("GET", "/docs/inspector/").body) == "Inspector docs (pretty URL)"
                r = call("GET", "/docs/assets/apn-inspector.html")
                @test String(r.body) == APN8Web.PAGE
                @test HTTP.header(r, "Content-Type") == "text/html; charset=utf-8"
                @test HTTP.header(call("GET", "/docs/assets/docs.css"), "Content-Type") == "text/css; charset=utf-8"
                @test call("GET", "/docs/missing").status == 404
                for path in ("/docs/../private.txt", "/docs/%2e%2e/private.txt",
                             "/docs/%2e%2e%2fprivate.txt", "/docs/%00", "/docs/leak.txt")
                    @test call("GET", path).status == 400
                end
                @test call("GET", "/api/health").status == 200
                @test classify("x^3")[2].apn
                @test call("GET", "/inspector/").status == 200
            finally
                APN8Web.DOCS_DIRECTORY[] = ""
            end
        end
    end

    @testset "coefficient decoder agrees with VBF.QuadraticAPNTree.lut" begin
        for (_, c) in CENSUS[1:20]
            C = zeros(UInt16, 8, 8)
            t = 0
            for i in 1:8, j in i + 1:8
                t += 1
                C[i, j] = C[j, i] = parse(UInt16, c[2t - 1:2t]; base = 16)
            end
            @test APN8Web.coeffs_to_lut(c) == Int.(VBF.QuadraticAPNTree.lut(C, 8))
        end
    end

    @testset "known beierle2025_n8 member" begin
        cat = load_catalog()
        G = corpus_function(cat, "beierle2025_n8", 1000)
        close(cat)
        st, j = classify(lutstr(Int.(G.lut)))
        @test st == 200
        @test j.format == "lut"
        @test j.apn && j.algebraic_degree == 2
        @test j.status == "reference_match"
        @test j.ea_available
        @test occursin("equivalence unresolved",j.verdict)
    end

    @testset "census member (one of the 553)" begin
        h, c = CENSUS[7]
        st, j = classify(String(c))
        @test st == 200
        @test j.format == "coefficients"
        @test j.status == "reference_match"
        @test j.sigma == h
        @test any(m.source=="legacy20261009_n8" for m in j.matches)
        # The same function as a newline-separated LUT.
        st2, j2 = classify(join(APN8Web.coeffs_to_lut(String(c)), "\n"))
        @test j2.format == "lut" && j2.status == "reference_match" && j2.sigma == h
    end

    @testset "other lists: extra class, search trial, raw-only" begin
        st, j = classify("60586b23865a010415cf78320eb7700de3f03212e2d82ccc969a6142")
        @test st == 200 && j.status == "reference_match"
        @test any(m.source=="legacy20261009_n8" for m in j.matches)
        t = split(collect(eachline(joinpath(APN8Web.STUDY_DIR, "search_b52", "new_classes_trial_773.tsv")))[2], '\t')
        st, j = classify(String(t[5]))
        @test j.status == "reference_match" && j.sigma == t[1]
        r = split(collect(eachline(APN8Web.PUBLIC_TSV))[2], '\t')
        lut = [parse(Int, r[3][2k - 1:2k]; base = 16) for k in 1:256]
        st, j = classify(lutstr(lut))
        @test j.status == "reference_match" && j.sigma == r[1]
        @test j.reference_signature_match
        # A class found only in the Framework run (compressed list).
        fw = first(Iterators.filter(l -> occursin("\tnew\t", l),
            eachline(`gzip -dc $(joinpath(APN8Web.STUDY_DIR, "search_b52", "framework_20261009_new.tsv.gz"))`)))
        t = split(fw, '\t')
        st, j = classify(String(t[5]))
        @test j.status == "reference_match" && j.sigma == t[1]
        @test j.reference_signature_match
    end

    @testset "Gold x^3 is known" begin
        st, j = classify("x^3")
        @test j.format == "polynomial"
        @test j.status == "reference_match"
        st2, j2 = classify(join(gf_monomial_lut(8, 3; modulus = 0x11B), " "))
        @test j2.status == "reference_match" && j2.sigma == j.sigma
        st3, j3 = classify("x^3 mod=0x11D")
        @test j3.status == "reference_match"
    end

    @testset "non-APN random LUT" begin
        lut = randperm(Xoshiro(2026), 256) .- 1
        st, j = classify(lutstr(lut; sep = ","))
        @test st == 200
        @test j.ok && !j.apn
        @test j.status == "not_apn"
        @test j.differential_uniformity > 2
        r = call("POST", "/api/ea", lutstr(lut))
        @test r.status == 400
    end

    @testset "APN, not quadratic (Kasami x^57)" begin
        st, j = classify("x^57")
        @test j.apn && j.algebraic_degree > 2
        @test j.status == "apn_not_quadratic"
        @test !haskey(j, :sigma)
    end

    @testset "malformed input" begin
        for bad in ["", "1 2 3", join(fill(300, 256), " "), "hello world",
                    "x^3 +* (", repeat("g", 56), "x^3 mod=0x1F"]
            st, j = classify(bad)
            @test st == 400
            @test !j.ok && j.status == "error"
            @test !isempty(j.error)
        end
        @test occursin("found 3", classify("1 2 3")[2].error)
        @test occursin("outside 0..255", classify(join(fill(300, 256), " "))[2].error)
    end

    @testset "bounded pair comparison and downloadable witness" begin
        body=JSON3.write(Dict("candidate"=>"x^3","target"=>"x^3","relation"=>"ccz"))
        r=call("POST","/api/compare",body)
        @test r.status==200
        id=JSON3.read(String(r.body)).id
        deadline=time()+30
        job=APN8Web.JOBS[id]
        while APN8Web.job_dict(job)["state"] in ("queued","running") && time()<deadline
            sleep(0.01)
        end
        result=APN8Web.job_dict(job)
        @test result["state"]=="done" && result["equivalent"]===true
        @test APN8Web.VBFSearch.verify_comparison(result["evidence"])
        @test call("GET","/api/ea/$id/certificate").status==200
        @test call("POST","/api/compare",JSON3.write(Dict("candidate"=>"x^3","target"=>"x^3","max_nodes"=>0))).status==400
        @test call("GET","/api/candidates").status==400
        gold=APN8Web.analyze("x^3")
        @test gold["apn_power_function_comparison"]=="unresolved_gold_invariant_match"
        extra=APN8Web.analyze("60586b23865a010415cf78320eb7700de3f03212e2d82ccc969a6142")
        @test extra["apn_power_function_comparison"]=="inequivalent_to_all_apn_power_functions"
        @test extra["literature_novelty"]=="unresolved"
    end

    @testset "saved candidate browsing and pair ledger" begin
        mktempdir() do dir
            db=APN8Web.SQLite.DB(joinpath(dir,"run.sqlite"))
            execute(sql,args=())=foreach(_->nothing,APN8Web.DBInterface.execute(db,sql,args))
            execute("CREATE TABLE candidates(lut_id TEXT,evidence TEXT,additional INTEGER)")
            execute("CREATE TABLE comparisons(id INTEGER PRIMARY KEY,candidate_id TEXT,target_id TEXT,relation TEXT,evidence TEXT)")
            p=APN8Web.analyze("x^3")
            encoded=sprint(io->APN8Web.TOML.print(io,p;sorted=true))
            execute("INSERT INTO candidates VALUES(?,?,0)",(p["lut_sha256"],encoded))
            APN8Web.SQLite.close(db)
            open(io->APN8Web.TOML.print(io,Dict("scope"=>"fixture snapshot")),joinpath(dir,"classification.toml"),"w")
            APN8Web.RUN_DIRECTORY[]=dir
            try
                r=call("GET","/api/candidates?limit=1&offset=0&additional=false")
                @test r.status==200
                @test call("GET","/api/classification").status==200
                parsed=JSON3.read(String(r.body))
                @test parsed.total==1 && only(parsed.candidates).lut_sha256==p["lut_sha256"]
                @test JSON3.read(String(call("GET","/api/candidates?additional=true").body)).total==0
                job=APN8Web.EAJob(1000,"fixture","queued",nothing,"",time(),0.0,Dict{String,Any}())
                F=SBox{8}(gold_apn(8).lut)
                APN8Web.run_ea!(job,F,F;relation=:ccz)
                @test APN8Web.job_dict(job)["state"]=="done"
                ledger=JSON3.read(String(call("GET","/api/relationships").body))
                @test length(ledger.comparisons)==1 && only(ledger.comparisons).equivalent
            finally
                APN8Web.RUN_DIRECTORY[]=""
            end
        end
    end
end
