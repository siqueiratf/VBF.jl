@testset "table3_test" begin
    include(joinpath(@__DIR__, "..", "table3.jl"))

    funcs = table3_functions()

    # All listed functions are APN
    for f in funcs
        @test differential_uniformity(f.sbox) == 2
    end

    # C_3 and C_7 have different EA-mugshots
    c3 = first(f.sbox for f in funcs if f.name == "C_3")
    c7 = first(f.sbox for f in funcs if f.name == "C_7")
    @test apn_ea_mugshot(c3) != apn_ea_mugshot(c7)

    # C_3 and C_7 share the same extended Walsh spectrum (same CCZ-spectrum class)
    @test absolute_walsh_spectrum(c3) == absolute_walsh_spectrum(c7)

    # Γ-ranks from Table III (loaded from paper — not computed here)
    gamma_ranks = Dict(f.name => f.gamma_rank_paper for f in funcs)
    @test gamma_ranks["C_3"] == 166068
    @test gamma_ranks["C_7"] == 166168
    @test gamma_ranks["C_3"] != gamma_ranks["C_7"]  # → CCZ-inequivalent
end
