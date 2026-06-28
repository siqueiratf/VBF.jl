using Test
using Nemo

# Polynomial interpolation helpers (test-only; inlined from APNLib polynomial.jl)
function int_to_field_element(value::Integer, field, n::Int)
    coeffs = [isodd((value >> b) & 1) ? 1 : 0 for b in 0:(n - 1)]
    field(coeffs)
end

function _field_power_lookup(generator, n::Int)
    field = parent(generator)
    powers = Dict{typeof(generator), Int}()
    current = one(field)
    for exponent in 0:(1 << n - 2)
        powers[current] = exponent
        current = current * generator
    end
    powers
end

function format_sbox_polynomial(lut::Vector{Int}, n::Int)::String
    field_size = 1 << n
    field = Nemo.GF(2, n, "g")
    R, _ = Nemo.polynomial_ring(field, "x")
    inputs  = [int_to_field_element(v, field, n) for v in 0:(field_size - 1)]
    outputs = [int_to_field_element(lut[v + 1], field, n) for v in 0:(field_size - 1)]
    polynomial = interpolate(R, inputs, outputs)
    iszero(polynomial) && return "0"

    generator = gen(field)
    powers = _field_power_lookup(generator, n)
    terms = String[]
    for exponent in 0:degree(polynomial)
        coefficient = coeff(polynomial, exponent)
        iszero(coefficient) && continue
        if coefficient == one(field)
            push!(terms, "x^$exponent")
        else
            gen_exp = powers[coefficient]
            push!(terms, "g^$(gen_exp)x^$exponent")
        end
    end
    isempty(terms) ? "0" : join(terms, " + ")
end

@testset "Dynamic DDT Updates" begin
    sbox = fill(-1, 4)
    ddt = zeros(Int, 4, 4)

    sbox[0 + 1] = 0
    @test addDDTInformation(0, sbox, ddt) == true
    @test all(ddt .== 0)

    sbox[3 + 1] = 3
    @test addDDTInformation(3, sbox, ddt) == true
    @test ddt[3 + 1, 3 + 1] == 2
    @test removeDDTInformation(3, sbox, ddt) == true
    @test all(ddt .== 0)
end

@testset "S-box Search State Helpers" begin
    sbox = [0, -1, -1, 3]

    @test isComplete(sbox) == false
    @test nextFreePosition(sbox) == 1
    @test isComplete([0, 1, 2, 3]) == true
end

@testset "APN Search Solution Callbacks" begin
    observed = Vector{Vector{Int}}()
    context = APNSearchContext(
        2,
        collect(0:3),
        collect(0:3),
        on_solution = sbox -> push!(observed, sbox),
        verify_apn_on_solution = false,
    )
    sbox = [0, 1, 2, 3]

    record_complete_solution!(context, sbox)
    sbox[2] = 0

    @test context.solutions == [[0, 1, 2, 3]]
    @test observed == [[0, 1, 2, 3]]
    @test !hasfield(typeof(context), :save_results)
    @test !hasfield(typeof(context), :class_index)
end

@testset "S-box Polynomial Interpolation" begin
    identity_lut = collect(0:7)

    @test string(int_to_field_element(5, Nemo.GF(2, 3, "g"), 3)) == "g^2 + 1"
    @test format_sbox_polynomial(identity_lut, 3) == "x^1"
end

# The n=3 tuple/matrix constants are a generated, git-ignored artifact
# (`make corollary1_n6n7n8 n=3`). Skip the search tests that need them when absent.
_TUPLES3_FILE = joinpath(dirname(@__DIR__), "tuples", "AllTuplesMatrices3.toml")
if !isfile(_TUPLES3_FILE)
    @testset "APN Search (n=3 tuple constants absent)" begin
        @test_skip "generate papers/Beierle_202107/tuples/AllTuplesMatrices3.toml"
    end
else
@testset "APN Search Class Selection" begin
    @test all_precomputed_tuple_class_indices(3) == [1, 2, 3, 4]
    @test normalize_precomputed_tuple_classes(3, "all") == [1, 2, 3, 4]
    @test normalize_precomputed_tuple_classes(3, "[4]") == [4]
    @test normalize_precomputed_tuple_classes(3, "[1, 3]") == [1, 3]
    @test normalize_precomputed_tuple_classes(3, "all", excluded_class_indices = [2, 4]) == [1, 3]
    @test normalize_precomputed_tuple_classes(3, [1, 1]) == [1]
end

@testset "APN Search Batch Classes" begin
    results = APNSearchClasses(
        3,
        [1],
        max_solutions = 1,
        on_solution = (class_index, sbox) -> nothing,
        save_results = false,
    )

    @test sort(collect(keys(results))) == [1]
    @test length(results[1]) == 1
    @test APNSearchClasses(3, "all", excluded_class_indices = [1, 2, 3, 4], save_results = false) == Dict{Int, Vector{Vector{Int}}}()
end

@testset "APN Search Injected Result Persistence" begin
    identity3 = Int[1 0 0; 0 1 0; 0 0 1]
    saved = []

    solutions = APNSearch(
        3,
        identity3,
        identity3,
        max_solutions = 1,
        on_solution = sbox -> nothing,
        save_results = true,
        class_index = 1,
        save_result = (sbox, n, class_index) -> push!(saved, (copy(sbox), n, class_index)),
    )

    @test length(solutions) == 1
    @test saved == [(solutions[1], 3, 1)]
end

@testset "APN Search Matrix Constant Output" begin
    identity3 = Int[1 0 0; 0 1 0; 0 0 1]
    constants_filename = joinpath(dirname(@__DIR__), "tuples", "AllTuplesMatrices3.toml")
    original_text = read(constants_filename, String)

    try
        solutions = APNSearch(
            3,
            identity3,
            identity3,
            max_solutions = 1,
            on_solution = sbox -> nothing,
            save_results = true,
            class_index = 1,
        )

        text = read(constants_filename, String)
        expected_line = "search = [$(join(solutions[1], ", "))]"

        @test length(solutions) == 1
        @test occursin(expected_line, text)
    finally
        write(constants_filename, original_text)
    end
end
end  # if isfile(_TUPLES3_FILE)
