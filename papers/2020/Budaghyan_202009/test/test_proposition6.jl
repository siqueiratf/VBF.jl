@testset "proposition6_test" begin
    include(joinpath(@__DIR__, "..", "proposition6.jl"))

    # Table I: m_F formula values
    table1 = Dict(3 => 3, 4 => 3, 5 => 15, 6 => 27, 7 => 63, 8 => 111)
    for (n, exp_m) in table1
        @test m_F_formula_gold(n) == exp_m
    end

    # Lower bound from Table I
    table1_bounds = Dict(3 => 2, 4 => 2, 5 => 6, 6 => 10, 7 => 22, 8 => 38)
    for (n, exp_bd) in table1_bounds
        @test lower_bound_distance(m_F_formula_gold(n)) == exp_bd
    end

    # Formula matches pi_multiset numerically for n=5
    N = 5
    F = gold_x3(N)
    sz = 1 << N
    mod = primitive_polynomial(N)
    for β in [0, 1, 3, 7]
        for b in [0, 1, gf_pow(β, 3, N; modulus=mod), 5]
            b >= sz && continue
            formula_val = pi_formula_gold(N, β, b; modulus = mod)
            # Compute directly: count directions a hitting b via shifted derivative
            direct_count = 0
            for a = 0:(sz-1)
                fab = Int(F.lut[(a ⊻ β)+1])
                for x = 0:(sz-1)
                    if Int(F.lut[x+1]) ⊻ Int(F.lut[(x ⊻ a)+1]) ⊻ fab == b
                        direct_count += 1
                        break
                    end
                end
            end
            @test formula_val == direct_count
        end
    end

    # Prop 5: for quadratic Gold n=5, m_F is same via formula and compute_m_F
    @test m_F_formula_gold(5) == compute_m_F(gold_x3(5))
    @test m_F_formula_gold(6) == compute_m_F(gold_x3(6))
end
