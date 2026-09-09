using Test, SQLite, DBInterface, DataFrames, JSON3, SHA, CSV, Arrow
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
