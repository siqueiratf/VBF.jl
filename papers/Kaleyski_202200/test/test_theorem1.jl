@testset "theorem1_test" begin
    include(joinpath(@__DIR__, "..", "theorem1.jl"))

    # e_exponent basic values
    @test e_exponent(2, 1) == 3        # Gold k=1
    @test e_exponent(2, 2) == 5        # Gold k=2
    @test e_exponent(3, 1) == 7
    @test e_exponent(5, 1) == 31
    @test e_exponent(7, 1) == 127

    # Paper bug counterexample: n=2, l=3, k=1
    @test theorem1_printed(3, 1, 2) == true    # printed says OK (wrong)
    @test theorem1_holds(3, 1, 2) == false      # correct says not applicable
    @test is_zero_apn_poly(7, 2) == false       # x^7 NOT 0-APN over GF(4)

    # Theorem 1 (corrected): soundness for small n
    for (l, k) in [(2, 1), (3, 1), (3, 2), (4, 1), (5, 1)]
        e = e_exponent(l, k)
        for n in 1:20
            if theorem1_holds(l, k, n)
                @test is_zero_apn_poly(e, n) == true
            end
        end
    end

    # Cross-validate polynomial vs direct method for small n
    for e in [3, 7, 31]
        for n in 2:14
            @test is_zero_apn_poly(e, n) == is_zero_apn_direct(e, n)
        end
    end

    # Remark 1 ⊆ Theorem 1
    for (l, k) in [(3, 1), (5, 1), (7, 1)]
        for n in 1:50
            if remark1_holds(l, k, n)
                @test theorem1_holds(l, k, n) == true
            end
        end
    end
end
