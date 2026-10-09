@testitem "partition_refinement_oracle" begin
    using VBF, Test, Random

    # Independent n=3 EA oracle: enumerate GL(3,2) x AGL(3,2), then
    # check that G xor B(F(L(x)+a)) has an affine truth table. No refinement,
    # graph geometry, spectra, partial maps or equivalence helpers are used.
    linear_tables = Vector{Vector{UInt8}}()
    for a in UInt8(1):UInt8(7), b in UInt8(1):UInt8(7), c in UInt8(1):UInt8(7)
        table = UInt8[(isodd(x) ? a : 0) ⊻ (x & 2 != 0 ? b : 0) ⊻
                      (x & 4 != 0 ? c : 0) for x in 0:7]
        length(unique(table)) == 8 && push!(linear_tables, table)
    end
    @test length(linear_tables) == 168

    function oracle(F, G)
        for L in linear_tables, shift in UInt8(0):UInt8(7)
            h = UInt8[F.lut[Int(L[x+1] ⊻ shift)+1] for x in 0:7]
            for B in linear_tables
                r0 = G.lut[1] ⊻ B[Int(h[1])+1]
                r1 = G.lut[2] ⊻ B[Int(h[2])+1] ⊻ r0
                r2 = G.lut[3] ⊻ B[Int(h[3])+1] ⊻ r0
                r4 = G.lut[5] ⊻ B[Int(h[5])+1] ⊻ r0
                good = true
                for x in (3, 5, 6, 7)
                    r = r0 ⊻ (isodd(x) ? r1 : 0) ⊻ (x & 2 != 0 ? r2 : 0) ⊻
                        (x & 4 != 0 ? r4 : 0)
                    if G.lut[x+1] ⊻ B[Int(h[x+1])+1] != r
                        good = false
                        break
                    end
                end
                good && return true
            end
        end
        return false
    end

    rng = Xoshiro(2026940)
    for trial in 1:16
        F, G = random_function_sbox(rng, Val(3)), random_function_sbox(rng, Val(3))
        expected = oracle(F, G)
        @test are_ea_equivalent(F, G; strategy = :partition_refinement,
                                on_inconclusive = :throw) == expected
        @test are_ea_equivalent(F, G; on_inconclusive = :throw) == expected
    end
end
