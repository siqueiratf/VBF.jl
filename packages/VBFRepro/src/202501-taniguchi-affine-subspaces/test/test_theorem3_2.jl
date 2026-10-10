@testset "theorem3_2_test" begin
    include(joinpath(@__DIR__, "..", "theorem3_2.jl"))

    # Example 3.3: n=4 → 448 valid L mappings
    @test count_valid_L(4; mod=paper_modulus(4)) == 448

    @test count_valid_L(5; mod=paper_modulus(5)) == 4608
    bounded = count_valid_L_bounded(6; max_evaluations = 100)
    @test bounded.status == :budget_hit
    @test bounded.evaluated == bounded.next_index == 100
    @test !bounded.exhaustive
    @test bounded.total == 1 << 30
    @test_throws ArgumentError count_valid_L(6)
    # Interval continuation has explicit boundaries, without repeating indices.
    first = count_valid_L_bounded(4; max_evaluations = 100)
    rest = count_valid_L_bounded(4; start_index = first.next_index, max_evaluations = typemax(Int))
    @test first.count + rest.count == 448
    @test !rest.exhaustive
    @test rest.interval_exhausted
    # Theorem 3.2: L=0 always valid (G = x^3 is APN)
    for n in [4, 5]
        mod = paper_modulus(n)
        T0 = trace_zero_elements(n, mod)
        e0 = trace_one_element(n, mod)
        @test theorem3_2_check(zeros(Int, n), n, mod, T0, e0)
    end

    # Decode independent coefficient samples and compare the table counter with
    # the original set-based criterion and a direct full DDT of the switched LUT.
    for n in (4, 6)
        mod = paper_modulus(n)
        q = 1 << n
        total = q^(n-1)
        T0 = trace_zero_elements(n, mod)
        e0 = trace_one_element(n, mod)
        indices = unique([0, 1, q-1, q, total-1, total ÷ 7, total ÷ 3, total ÷ 2])
        for index in indices
            coefficients = digits(index; base=q, pad=n)
            coefficients[n] = 0
            value = linearized_poly_eval(coefficients, e0, n, mod)
            denominator = gf_pow(e0, 1 << (n-1), n; modulus=mod)
            coefficients[n] = gf_mul(value, gf_inv(denominator,n;modulus=mod),n;modulus=mod)
            @test linearized_poly_eval(coefficients, e0, n, mod) == 0
            independent = theorem3_2_check(coefficients, n, mod, T0, e0)
            counter = count_valid_L_bounded(n; start_index=index, max_evaluations=1)
            @test counter.count == Int(independent)
            lut = [gf_pow(x,3,n;modulus=mod) ⊻
                   (gf_trace(x,n;modulus=mod) == 0 ? 0 : linearized_poly_eval(coefficients,x,n,mod))
                   for x in 0:q-1]
            @test (differential_uniformity(SBox(lut)) == 2) == independent
        end
    end
end
