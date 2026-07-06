@testset "algorithm1" begin
    include(joinpath(@__DIR__, "..", "algorithm1.jl"))

    # n = 5, s = 3 (as in the original bounded demo)
    F = gold_apn(5)
    G, A0, B0, C0, a_const = _demo_ea_triple(F)

    triple = ea_recovery_quadratic(F, G; s = 3)
    @test triple !== nothing
    triple !== nothing && @test _verify_triple(F, G, triple)

    # Identity EA triple: G = F (A0=I, B0=I, C0=0, a=0)
    triple_id = ea_recovery_quadratic(F, F; s = 3)
    @test triple_id !== nothing
    triple_id !== nothing && @test _verify_triple(F, F, triple_id)

    # Non-EA-equivalent pair at n=5: x³ vs x⁵ (both APN) — exhaustive reject
    @test ea_recovery_quadratic(F, gold_apn(5, 2); s = 3) === nothing

    # n = 7, s = 2 (paper's headline dimension, Example 26 / Table 4)
    F7 = gold_apn(7)
    G7, = _demo_ea_triple(F7)
    triple7 = ea_recovery_quadratic(F7, G7; s = 2)
    @test triple7 !== nothing
    triple7 !== nothing && @test _verify_triple(F7, G7, triple7)

    # n = 9, s = 2 (beyond the old UInt128 cap; multi-word rows)
    F9 = gold_apn(9)
    G9, = _demo_ea_triple(F9)
    triple9 = ea_recovery_quadratic(F9, G9; s = 2)
    @test triple9 !== nothing
    triple9 !== nothing && @test _verify_triple(F9, G9, triple9)
end
