using Test, VBF, VBFCatalog, JSON3
import VBFCatalog: SQLite, DBInterface

include("harness.jl")
include("persistence.jl")
include("observation.jl")
include("../packages/VBFCatalog/data-build/migrations/004_benchmark.jl")
include("../packages/VBFCatalog/data-build/migrations/005_paper_provenance.jl")
include("../packages/VBFCatalog/data-build/migrations/006_consolidate_paper_columns.jl")
using .BenchHarness, .BenchPersistence, .BenchObservation

rows(db) = [NamedTuple(r) for r in DBInterface.execute(db, "SELECT * FROM benchmark ORDER BY id")]

@testset "raw benchmark persistence" begin
    mktempdir() do dir
        path = joinpath(dir, "catalog.sqlite")
        db = create_catalog(path)
        F = gold_apn(4, 1)
        SQLite.execute(db, "INSERT INTO functions (family,n,m,lut_sha256,lut_blob,is_apn,is_permutation,is_quadratic,source_repo,contributor,added_date) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            ("test", 4, 4, lut_sha256_hex(F), canonical_lut_bytes(F), 1, 0, 1, "test", "test", "2026-09-06"))
        writer = execution_writer(db; reference_family = "test")
        reg = Registry()
        bench!(reg; group = "constructions", name = "gold_apn", n = 4, reps = 2,
            approach = "test construction", setup = () -> F, call = f -> [f, f],
            parameters = (; label = "quotes ' and Unicode α"),
            metrics = (p, v, s) -> (; search_space_size = big(2)^200))
        run_registry(reg; on_execution = writer, io = devnull)
        stored = rows(db)
        @test length(stored) == 2 # warm-up and allocation probes are excluded
        @test [r.repetition for r in stored] == [1, 2]
        @test all(r -> r.total_apns == 2 && r.distinct_apns == 1 &&
                       r.known_apns_recovered == 1 && r.total_known_apns == 1, stored)
        @test stored[1].search_space_size == string(big(2)^200)
        @test stored[1].approach == "test construction"
        @test ismissing(stored[1].candidates_processed)
        @test ismissing(stored[1].time_to_first_apn_seconds)
        @test JSON3.read(stored[1].parameters_json).case_parameters.label == "quotes ' and Unicode α"
        @test JSON3.read(stored[1].apn_identities_json)[1] == [4, lut_sha256_hex(F)]

        reg = Registry()
        bench!(reg; group = "spectra", name = "ddt", n = 4, reps = 1,
            setup = () -> F, call = ddt)
        run_registry(reg; on_execution = execution_writer(db), io = devnull)
        r = rows(db)[end]
        @test ismissing(r.total_apns) && ismissing(r.distinct_apns)
        @test ismissing(r.known_apns_recovered) && ismissing(r.total_known_apns)
        @test ismissing(r.reference_scope_json) && ismissing(r.apn_identities_json)
        @test r.elapsed_seconds >= 0

        reg = Registry()
        bench!(reg; group = "test", name = "callable_payload", reps = 1,
            setup = () -> (sin, zeros(100_000)), call = p -> p[1](p[2][1]))
        run_registry(reg; on_execution = execution_writer(db), io = devnull)
        metadata = JSON3.read(rows(db)[end].parameters_json).payload_after_call
        @test metadata[1].name == "sin"
        @test metadata[2].dimensions == [100_000]
        @test sizeof(rows(db)[end].parameters_json) < 10_000

        reg = Registry()
        calls = Ref(0)
        bench!(reg; group = "test", name = "fails", reps = 2,
            call = _ -> ((calls[] += 1) == 4 ? error("intentional failure") : nothing))
        @test_throws ErrorException run_registry(reg; on_execution = execution_writer(db), io = devnull)
        @test length(rows(db)) == 5 # previous completed repetition survives
        @test ismissing(rows(db)[end].n)

        SQLite.execute(db, "UPDATE schema_meta SET schema_version = 3")
        close(db)
        migrate_benchmark(path)
        migrate_benchmark(path)
        migrate_paper_provenance(path)
        migrate_paper_provenance(path)
        migrate_consolidate_paper_columns(path)
        migrate_consolidate_paper_columns(path)
        db = load_catalog(path)
        @test length(rows(db)) == 5
        @test count_functions(db) == 1
        rebuilt = create_catalog(joinpath(dir, "rebuilt.sqlite"))
        VBFCatalog._copy_benchmark_history!(rebuilt, path)
        @test isequal(rows(rebuilt), rows(db))
        @test count_functions(rebuilt) == 0 # only observations are copied
        close(rebuilt)
        close(db)
    end
end

@testset "observation preserves mathematical outputs" begin
    cases = [
        o -> search_quadratic_apn(Val(4); limit = 3, observer = o),
        o -> search_quadratic_apn_le(collect(0:15), collect(0:15);
            pos = collect(1:15), limit = 1, observer = o),
        o -> search_qam(4, 2; limit = 2, max_evaluations = 256, observer = o),
        o -> search_qam_full(3; limit = 1, max_evaluations = 256, observer = o),
        o -> extend_quadratic_apn(gold_apn(3, 1); limit = 1, observer = o),
        o -> switching_neighbors(gold_apn(3, 1); observer = o),
        o -> apn_trims(gold_apn(3, 1); observer = o),
        o -> known_apn_monomials(5; observer = o),
        o -> taniguchi_apn_representatives(3; observer = o),
    ]
    for f in cases
        o = Observation()
        o.start = time_ns()
        observed = f(o)
        plain = f(nothing)
        hashes(v) = lut_sha256_hex.(BenchPersistence.apn_outputs(v))
        @test hashes(observed) == hashes(plain)
        @test o.candidates >= o.final_tests >= 0
        @test all(F -> differential_uniformity(F) == 2, o.apns)
        @test isempty(o.apns) ? o.first_apn === nothing : o.first_apn >= 0
    end

    mktempdir() do dir
        db = create_catalog(joinpath(dir, "observed.sqlite"))
        reg = Registry()
        bench!(reg; group = "constructions", name = "search_qam", n = 4, reps = 2,
            setup = () -> (input = nothing, observation = Observation()),
            call = p -> observed_call((_, o) -> search_qam(4, 2;
                limit = 2, max_evaluations = 256, observer = o), p),
            metrics = observation_metrics)
        bench!(reg; group = "constructions", name = "search_qam_full", n = 3, reps = 2,
            setup = () -> (input = nothing, observation = Observation()),
            call = p -> observed_call((_, o) -> search_qam_full(3;
                limit = 1, max_evaluations = 256, observer = o), p),
            metrics = observation_metrics)
        run_registry(reg; on_execution = execution_writer(db), io = devnull)
        for r in rows(db)
            @test r.candidates_processed == r.candidates_final_apn_test
            @test r.candidates_processed <= 256
            if endswith(r.algorithm, "search_qam_full")
                @test r.total_apns >= r.distinct_apns > 0
                @test 0 <= r.time_to_first_apn_seconds <= r.elapsed_seconds
            else
                @test r.total_apns == r.distinct_apns == 0
                @test ismissing(r.time_to_first_apn_seconds)
            end
            @test r.known_apns_recovered == r.total_known_apns == 0
            @test parse(BigInt, r.search_space_size) >= r.candidates_processed
        end
        close(db)
    end
end
