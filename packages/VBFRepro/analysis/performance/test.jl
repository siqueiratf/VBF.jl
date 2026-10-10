using Test, SQLite, DBInterface, DataFrames, JSON3, SHA, CSV, Arrow, TOML
include("BenchAnalysis.jl")
using .BenchAnalysis
using Profile, FlameGraphs, Serialization

@testset "Exclusive profile ownership and artifact replay" begin
    frame(func, file) = Base.StackTraces.StackFrame(func, Symbol(file), 1, nothing, false, false, 0)
    lidict = Dict{UInt64,Base.StackTraces.StackFrame}(
        1 => frame(:paper, "/repo/papers/example/algorithm.jl"),
        2 => frame(:walsh, "/repo/packages/VBF/src/spectra/walsh.jl"),
        3 => frame(:external, "/julia/runtime.jl"))
    data = Profile.add_fake_meta(UInt64[3,2,1,0, 3,1,0, 3,0, 1,2,0])
    g = flamegraph(data; lidict)
    split = BenchAnalysis.ProfileAttribution.attribute_flamegraph(g)
    @test (split.core_samples, split.paper_samples, split.other_samples) == (1, 2, 1)
    rows = DataFrame(BenchAnalysis.ProfileAttribution.profile_components(g))
    @test sum(rows.samples) == split.samples_total == 4
    @test sum(filter(:subsystem => ==("spectra"), rows).samples) == 1
    mktempdir() do dir
        mkpath(joinpath(dir, "one"))
        saved = (; data, lidict, case=(; group="spectra", name="case", n=6,
            paper_id="paper", mode="hybrid", approach="approach", parameters=(; limit=10)),
            provenance=(; source_tree_sha256="source", cpu="cpu", julia_threads=1),
            seed="123", sampling_delay=0.001, julia_version=string(VERSION),
            recorded_at="2026-09-07", profiled_seconds=2.0)
        serialize(joinpath(dir, "one", "profile_raw.jls"), saved)
        mkpath(joinpath(dir, "duplicate"))
        cp(joinpath(dir, "one", "profile_raw.jls"), joinpath(dir, "duplicate", "profile_raw.jls"))
        sessions, components = BenchAnalysis.read_profiles(dir)
        @test nrow(sessions) == 1
        @test sessions.joinable == [true]
        @test sum(components.samples) == 4
        @test sum(components.fraction) == 1.0
        dbpath = joinpath(dir, "derived.sqlite")
        db = SQLite.DB(dbpath)
        SQLite.load!(sessions, db, "profiles")
        close(db)
        benchmark = select(sessions, BenchAnalysis.PROFILE_KEYS)
        benchmark.elapsed_seconds = [2.0]
        @test join_profiles(benchmark, load_profile_summaries(dbpath)).core_fraction == [0.25]
    end
end

@testset "Reproducible benchmark analysis" begin
    mktempdir() do dir
        raw = joinpath(dir, "raw.sqlite")
        params = JSON3.write((; provenance=(; source_tree_sha256="source", cpu="cpu",
            julia_version=string(VERSION), julia_threads=1), case_parameters=(; limit=10), seed=123))
        fixture = DataFrame(id=1:3, run_id=fill("run", 3), repetition=1:3,
            paper_id=Union{Missing,String}["paper", "paper", missing],
            algorithm=fill("case", 3), approach=fill("approach", 3),
            mode=Union{Missing,String}["hybrid", "hybrid", missing], n=fill(6, 3),
            elapsed_seconds=[2.0, 4.0, 0.0], known_apns_recovered=[2, 0, 0],
            total_known_apns=Union{Missing,Int}[4, 0, missing], candidates_processed=[5, 0, 0],
            total_candidates=Union{Missing,Int}[10, 0, missing], distinct_apns=[2, 0, 0],
            reference_scope_json=fill("{}", 3), parameters_json=fill(params, 3))
        db = SQLite.DB(raw)
        SQLite.load!(fixture, db, "benchmark")
        close(db)
        before = open(sha256, raw)
        df = load_benchmarks(raw)
        @test nrow(load_paper_benchmarks(raw)) == 2
        @test nrow(load_core_benchmarks(raw)) == 1
        @test nrow(load_benchmarks(raw; where="approach = ?", params=("approach",))) == 3
        @test_throws ErrorException load_benchmarks(joinpath(dir, "absent.sqlite"))
        metrics = derive_metrics(df)
        @test metrics.known_coverage[1] == 0.5
        @test metrics.search_space_coverage[1] == 0.5
        @test metrics.distinct_apns_per_second[1] == 1.0
        @test all(ismissing, metrics.known_coverage[2:3])
        @test ismissing(metrics.distinct_apns_per_second[3])
        sessions = select(df[[1, 1], :], BenchAnalysis.PROFILE_KEYS)
        sessions.joinable = [true, true]
        sessions.core_samples = [3, 1]
        sessions.paper_samples = [1, 1]
        sessions.other_samples = [0, 2]
        sessions.samples_total = [4, 4]
        joined = join_profiles(metrics, sessions)
        @test nrow(joined) == 3
        @test joined.core_fraction[1] == 0.5
        @test joined.paper_fraction[1] == 0.25
        @test joined.profile_samples_total[1] == 8
        @test joined.core_seconds[2] == 2.0
        @test ismissing(joined.core_fraction[3])
        sessions.source_tree_sha256 .= "different source"
        @test all(ismissing, join_profiles(metrics, sessions).core_fraction)
        @test nrow(group_by_approach(metrics)) == 2
        @test runtime_statistics(metrics; by=[:approach]).n_observations == [3]
        output = joinpath(dir, "analysis.sqlite")
        tables = consolidate(raw; output, profiles=joinpath(dir, "no_profiles"))
        @test nrow(tables["benchmarks"]) == 3
        @test length(export_tables(dir)) == 7
        @test nrow(CSV.read(joinpath(dir, "benchmarks.csv"), DataFrame)) == 3
        @test nrow(DataFrame(Arrow.Table(joinpath(dir, "benchmarks.arrow")))) == 3
        @test nrow(load_profile_summaries(output)) == 0
        @test nrow(load_profile_components(output)) == 0
        @test all(ismissing, load_dataset("benchmarks", output).core_fraction)
        consolidate(raw; output, profiles=joinpath(dir, "no_profiles"))
        @test nrow(load_dataset("benchmarks", output)) == 3
        @test open(sha256, raw) == before
        @test_throws ErrorException consolidate(raw; output=raw)
        CSV.write(joinpath(dir, "data.csv"), metrics)
        Arrow.write(joinpath(dir, "data.arrow"), metrics)
        @test isequal(CSV.read(joinpath(dir, "data.csv"), DataFrame).known_coverage, metrics.known_coverage)
        @test isequal(DataFrame(Arrow.Table(joinpath(dir, "data.arrow"))).known_coverage, metrics.known_coverage)
        emptyraw = joinpath(dir, "empty.sqlite")
        db = SQLite.DB(emptyraw)
        SQLite.load!(fixture[1:0, :], db, "benchmark")
        close(db)
        @test nrow(consolidate(emptyraw; output=joinpath(dir, "empty_analysis.sqlite"),
            profiles=joinpath(dir, "no_profiles"))["benchmarks"]) == 0
    end
end

@testset "Versioned BenchmarkTools file measurements" begin
    mktempdir() do dir
        run = joinpath(dir, "VBF", "run"); mkpath(run)
        manifest = Dict("schema_version" => 1, "run_id" => "run", "seed" => 7,
            "configuration" => Dict("samples" => 10),
            "inputs" => Dict("catalog_sha256" => "catalog"),
            "provenance" => Dict("source_tree_sha256" => "source", "cpu" => "cpu",
                "julia_version" => string(VERSION), "julia_threads" => 1))
        open(joinpath(run, "manifest.toml"), "w") do io; TOML.print(io, manifest); end
        rows = DataFrame(package=["VBF", "VBF"], group=["spectra", "spectra"],
            workload=["ddt", "lat"], case=["ddt_n6", "lat_n6"], n=[6,6],
            status=["ok", "error"], samples=[10,0], time_ns_min=[10.,0.],
            time_ns_median=[20.,0.], time_ns_mean=[25.,0.], memory_bytes=[64,0], allocations=[2,0])
        file = joinpath(run,"timings.tsv"); CSV.write(file, rows; delim='\t')
        digest = open(sha256,file)
        df = load_benchmarks(dir)
        @test nrow(df) == 1
        @test df.elapsed_seconds == [20e-9]
        @test df.trial_samples == [10]
        @test df.measurement_protocol == ["BenchmarkTools trial summary v1"]
        @test df.source_tree_sha256 == ["source"]
        @test df.algorithm == ["spectra/ddt"]
        @test df.seed == ["7"] # fallback for older manifests without workload seeds
        @test JSON3.read(only(df.reference_scope_json)).catalog_sha256 == "catalog"
        @test all(ismissing, derive_metrics(df).known_coverage)
        @test nrow(load_core_benchmarks(dir)) == 1
        @test nrow(load_paper_benchmarks(dir)) == 0
        @test_throws ArgumentError load_benchmarks(dir; where="run_id = ?", params=("run",))
        tables = consolidate(dir; output=joinpath(dir,"analysis.sqlite"), profiles=joinpath(dir,"none"))
        @test tables["runtime"].n_observations == [1] # samples are not independent trials
        export_tables(dir)
        exported = CSV.read(joinpath(dir,"benchmarks.csv"), DataFrame)
        @test exported.trial_samples == [10]
        @test exported.measurement_protocol == ["BenchmarkTools trial summary v1"]
        @test DataFrame(Arrow.Table(joinpath(dir,"runtime.arrow"))).n_observations == [1]
        @test open(sha256,file) == digest
        mixed = vcat(df,df; cols=:union)
        mixed.measurement_protocol[2] = "legacy timed repetition"
        @test nrow(runtime_statistics(mixed)) == 2
        mixed.measurement_protocol .= "BenchmarkTools trial summary v1"
        mixed.package[2] = "VBFSearch"
        @test nrow(runtime_statistics(mixed)) == 2
        rows.n[1] = 0; CSV.write(file,rows;delim='\t')
        @test ismissing(only(load_benchmarks(dir).n))
        rows.time_ns_median[1] = -1; CSV.write(file,rows;delim='\t')
        @test_throws ArgumentError load_benchmarks(dir)
        rm(joinpath(run,"manifest.toml"))
        @test_throws ArgumentError load_benchmarks(dir)
    end
end

@testset "Profile joins use workload and input identity" begin
    @test BenchAnalysis.canonical_json((; b=2, a=(; y=4, x=3))) ==
        BenchAnalysis.canonical_json(Dict("a"=>Dict("x"=>3,"y"=>4), "b"=>2))
    mktempdir() do dir
        timing = joinpath(dir,"timing"); profile=joinpath(dir,"profile")
        mkpath(timing);mkpath(profile)
        provenance=Dict("source_tree_sha256"=>"source","cpu"=>"cpu",
            "julia_version"=>string(VERSION),"julia_threads"=>1)
        parameters=Dict("limit"=>10)
        spec=Dict("group"=>"spectra","workload"=>"ddt","n"=>6,"parameters"=>parameters,"seed"=>9)
        metadata=Dict("schema_version"=>1,"measurement_protocol"=>"BenchmarkTools trial summary v1",
            "package"=>"VBF","config"=>Dict("seed"=>7,"samples"=>3),
            "provenance"=>provenance,"inputs"=>Dict("catalog_sha256"=>"input"),"workloads"=>[spec])
        open(joinpath(timing,"manifest.toml"),"w") do io;TOML.print(io,metadata);end
        CSV.write(joinpath(timing,"timings.tsv"),DataFrame(package=["VBF"],group=["spectra"],
            workload=["ddt"],case=["ddt_n6"],n=[6],approach=["spectra"],status=["ok"],
            samples=[3],time_ns_min=[10.],time_ns_median=[20.],time_ns_mean=[25.],
            memory_bytes=[64],allocations=[2]);delim='\t')
        frame=Base.StackTraces.StackFrame(:ddt,Symbol("/repo/packages/VBF/src/spectra/ddt.jl"),1,nothing,false,false,0)
        saved=(;data=Profile.add_fake_meta(UInt64[1,0]),lidict=Dict(UInt64(1)=>frame),
            case=(;group="spectra",name="ddt",n=6,paper_id="",mode="",approach="spectra",parameters=(;limit=10)),
            seed="9",sampling_delay=.001,profiled_seconds=1.,recorded_at="fixture",julia_version=string(VERSION),
            provenance=(;source_tree_sha256="source",cpu="cpu",julia_threads=1))
        serialize(joinpath(profile,"profile_raw.jls"),saved)
        profilemeta=Dict("schema_version"=>1,"measurement_protocol"=>"Julia sampling profile v1",
            "package"=>"VBF","provenance"=>provenance,"inputs"=>Dict("catalog_sha256"=>"input"))
        writeprofile()=open(joinpath(profile,"manifest.toml"),"w") do io;TOML.print(io,profilemeta);end
        writeprofile()
        timingrows=load_benchmarks(timing)
        @test timingrows.seed == ["9"] # recorded workload seed overrides global seed 7
        sessions,_=BenchAnalysis.read_profiles(profile)
        @test only(sessions.joinable)
        @test only(join_profiles(timingrows,sessions).core_fraction) == 1.
        @test timingrows.case_parameters_json != sessions.case_parameters_json
        @test timingrows.workload_parameters_json == sessions.workload_parameters_json
        conflicting=copy(timingrows);conflicting.workload_parameters_json .= "{\"limit\":11}"
        @test all(ismissing,join_profiles(conflicting,sessions).core_fraction)
        profilemeta["inputs"]["catalog_sha256"]="other";writeprofile()
        mismatch,_=BenchAnalysis.read_profiles(profile)
        @test all(ismissing,join_profiles(timingrows,mismatch).core_fraction)
        profilemeta["measurement_protocol"]="unknown";writeprofile()
        unknown,_=BenchAnalysis.read_profiles(profile)
        @test !only(unknown.joinable)
        profilemeta["measurement_protocol"]="Julia sampling profile v1"
        profilemeta["inputs"]["catalog_sha256"]="input";writeprofile()
        serialize(joinpath(profile,"profile_raw.jls"),merge(saved,(;data=UInt64[],lidict=Dict{UInt64,Base.StackTraces.StackFrame}())))
        emptyprofile,emptycomponents=BenchAnalysis.read_profiles(profile)
        emptyjoined=join_profiles(timingrows,emptyprofile)
        @test only(emptyjoined.profile_sessions)==1
        @test only(emptyjoined.profile_samples_total)==0
        @test ismissing(only(emptyjoined.core_fraction))
        @test isempty(emptycomponents)
    end
end
