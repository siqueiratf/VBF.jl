using Test
using TOML

@testset "toml_safe coerces report values to TOML-serializable types" begin
    # A structure shaped like the report's section results: nested NamedTuples,
    # Symbols, a BigInt (candidate_space), nothing, and integer vectors.
    sample = (
        overall = true,
        n_classes = 9,
        candidate_space = big(2)^50,    # fits Int64 -> stays an Int
        huge = big(2)^70,               # exceeds Int64 -> string
        walsh_class = :W1,
        gamma = nothing,
        vary = [13, 12],
        expected = (A = 7, B = 112),
    )
    safe = toml_safe(sample)
    @test safe isa AbstractDict
    @test safe["overall"] === true
    @test safe["n_classes"] == 9
    @test safe["candidate_space"] === Int(big(2)^50)     # in-range BigInt -> Int
    @test safe["huge"] == string(big(2)^70)              # out-of-range -> string
    @test safe["walsh_class"] == "W1"
    @test safe["gamma"] == "nothing"
    @test safe["vary"] == [13, 12]
    @test safe["expected"] isa AbstractDict && safe["expected"]["A"] == 7

    # Round-trips through an actual TOML file.
    path = tempname() * ".toml"
    open(path, "w") do io
        TOML.print(io, toml_safe(Dict("results" => sample)); sorted = true)
    end
    back = TOML.parsefile(path)
    @test back["results"]["n_classes"] == 9
    @test back["results"]["expected"]["B"] == 112
    rm(path; force = true)
end

@testset "small_searches save_results writes a parseable TOML artifact" begin
    path = paper_results_path("small_searches.toml")
    rm(path; force = true)
    buf = IOBuffer()
    small_searches_report(; limit = 5, max_evaluations = 1 << 24,
                          save_results = true, io = buf)
    @test isfile(path)
    data = TOML.parsefile(path)
    @test haskey(data, "small_searches")
    @test data["small_searches"]["n4_full"]["gold"] == true
    rm(path; force = true)
end
