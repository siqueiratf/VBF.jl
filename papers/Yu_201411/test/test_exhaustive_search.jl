include(joinpath(@__DIR__, "..", "exhaustive_search.jl"))

@testset "Yu_201411 - persisted class records round-trip" begin
    n = 5
    M = quadratic_apn_matrix(gold_apn(n, 1))
    F = qam_to_sbox(M)
    rec = class_record(F, M; class_index = 1, chunk = 1)

    @test rec["n"] == n
    @test rec["lut"] == Int.(F.lut)
    @test !isempty(rec["univariate_terms"])
    @test sbox_from_record(rec, n) == F
end

@testset "Yu_201411 - paper restricted polynomial form" begin
    n = 6
    modulus = conway_polynomial(n)
    M = quadratic_apn_matrix(gold_apn(n, 1; modulus))
    terms = paper_restricted_terms_from_qam(M; modulus)

    @test length(terms) == 1
    @test terms[1]["coefficient"] == 1
    @test terms[1]["exponent"] == 3
    @test terms[1]["i"] == 2
    @test terms[1]["t"] == 1

    n7 = 7
    mod7 = conway_polynomial(n7)
    field = validate_field_model(; n = n7, modulus = mod7, generator = 2)
    @test field.modulus_irreducible
    @test field.generator_primitive
    @test field.generator_order == 127

    M7 = quadratic_apn_matrix(gold_apn(n7, 1; modulus = mod7))
    terms7 = paper_restricted_terms_from_qam(M7; modulus = mod7, generator = 2)
    @test paper_polynomial_string(terms7) == "x^3"

    sample = [
        Dict{String,Any}("coefficient" => 5, "coefficient_power_of_generator" => 32, "exponent" => 96),
        Dict{String,Any}("coefficient" => 7, "coefficient_power_of_generator" => 1, "exponent" => 10),
        Dict{String,Any}("coefficient" => 3, "coefficient_power_of_generator" => 7, "exponent" => 80),
    ]
    @test paper_polynomial_string(sample) == "g^32x^96 + g^7x^80 + gx^10"
    @test !occursin("a", paper_polynomial_string(sample))
    @test !occursin("X", paper_polynomial_string(sample))
    @test !occursin("*", paper_polynomial_string(sample))
end

@testset "Yu_201411 - bounded resumable chunked search" begin
    path = joinpath(mktempdir(), "qam_full_n3.toml")
    r1 = exhaustive_qam_search(;
        n = 3,
        expected_classes = nothing,
        result_file = path,
        resume = false,
        threaded = false,
        use_gpu = false,
        dedup = :ea,
        max_chunks = 1,
        io = IOBuffer(),
    )
    r2 = exhaustive_qam_search(;
        n = 3,
        expected_classes = nothing,
        result_file = path,
        resume = true,
        threaded = false,
        use_gpu = false,
        dedup = :ea,
        max_chunks = 1,
        io = IOBuffer(),
    )

    @test isfile(path)
    @test r1.classes >= 0
    @test r2.classes >= r1.classes
    @test r2.chunks_completed > r1.chunks_completed

    sboxes = load_search_sboxes(path)
    @test length(sboxes) == r2.classes
    @test all(F -> differential_uniformity(F) == 2, sboxes)
    @test all(F -> algebraic_degree(F) == 2, sboxes)
end
