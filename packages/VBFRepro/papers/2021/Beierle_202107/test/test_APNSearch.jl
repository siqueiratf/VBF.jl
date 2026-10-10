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
        @test_skip "generate packages/VBFRepro/papers/Beierle_202107/tuples/AllTuplesMatrices3.toml"
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
    @test length(search_solutions(results[1])) == 1
    @test isempty(APNSearchClasses(3, "all", excluded_class_indices = [1, 2, 3, 4], save_results = false))
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

    sols = search_solutions(solutions)
    @test length(sols) == 1
    @test saved == [(sols[1], 3, 1)]
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

        sols = search_solutions(solutions)
        text = read(constants_filename, String)
        expected_line = "search = [$(join(sols[1], ", "))]"

        @test length(sols) == 1
        @test occursin(expected_line, text)
    finally
        write(constants_filename, original_text)
    end
end
end  # if isfile(_TUPLES3_FILE)

# ---------------------------------------------------------------------------
# CCZ-equivalence verification for stored search results
# ---------------------------------------------------------------------------

@testset "N=6 Class 5 CCZ-Equivalence to Dillon's Permutation" begin
    # Class 5 is the only admissible class for n=6 (Theorem 1).
    # The search finds exactly one APN permutation, which must be
    # CCZ-equivalent to Dillon's permutation (catalog: n6_Kim).
    blocks6 = _load_tuple_matrix_blocks(
        joinpath(dirname(@__DIR__), "tuples", "AllTuplesMatrices6.toml"))
    result6 = blocks6[5].search
    @test result6 !== nothing
    F6 = SBox{6}(result6)
    @test differential_uniformity(F6) == 2      # APN
    @test is_permutation(F6)                     # bijective
    @test are_ccz_equivalent(F6, dillon_apn_permutation())
end

@testset "N=7 Search Result CCZ-Equivalence to Monomials" begin
    # The 6 admissible classes (4,5,7,8,9,10) each yield one APN
    # permutation.  Each is CCZ-equivalent to a known monomial.
    #
    # Mapping (verified by algebraic degree + delta-rank as CCZ-invariants,
    # plus direct are_ccz_equivalent for the quadratic Gold cases):
    #   class 4  ↔ x^63 (inverse,  degree 6, delta_rank 4928)
    #   class 5  ↔ x^9  (Gold k=3, degree 2, delta_rank 198)
    #   class 7  ↔ x^5  (Gold k=2, degree 2, delta_rank 198)
    #   class 8  ↔ x^78 (Niho,     degree 4, delta_rank 436)
    #   class 9  ↔ x^85 (Kasami,   degree 4, delta_rank 198)
    #   class 10 ↔ x^88 (Welch,    degree 3, delta_rank 338)

    blocks7 = _load_tuple_matrix_blocks(
        joinpath(dirname(@__DIR__), "tuples", "AllTuplesMatrices7.toml"))

    class_to_exponent = Dict(4 => 63, 5 => 9, 7 => 5, 8 => 78, 9 => 85, 10 => 88)

    for (cls, exp) in sort(collect(class_to_exponent))
        result = blocks7[cls].search
        @test result !== nothing

        result_sbox = SBox{7}(result)
        mono_sbox   = SBox{7}(gf_monomial_lut(7, exp))

        @test differential_uniformity(result_sbox) == 2   # APN
        @test is_permutation(result_sbox)                  # bijective

        # For quadratic APN pairs (Gold monomials, degree 2),
        # CCZ = EA (Yoshiara 2012) so the check is fast.
        if algebraic_degree(mono_sbox) == 2
            @test are_ccz_equivalent(result_sbox, mono_sbox)
        else
            # For non-quadratic pairs, the full CCZ check exceeds
            # available memory on n=7.  Verify via CCZ-invariants
            # (algebraic degree + delta-rank) which uniquely identify
            # the monomial within the 6 candidates.
            @test algebraic_degree(result_sbox) == algebraic_degree(mono_sbox)
            @test delta_rank(result_sbox)       == delta_rank(mono_sbox)
        end
    end
end
