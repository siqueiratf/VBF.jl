@testset "GL extension claims" begin
    include(joinpath(@__DIR__, "..", "lemma1.jl"))
    include(joinpath(@__DIR__, "..", "lemma2.jl"))
    include(joinpath(@__DIR__, "..", "lemma3.jl"))
    include(joinpath(@__DIR__, "..", "lemma4.jl"))
    include(joinpath(@__DIR__, "..", "section8.jl"))
    @test gl_lemma1().verified
    @test_throws ArgumentError gl_lemma1([gold_apn(3)])
    @test gl_lemma2().trivial_dimension_checked
    @test !gl_lemma2(max_nodes=0).complete
    @test gl_lemma3().tests.differential_bound==8
    @test gl_lemma4().tests.linearized_consistent
    @test !gl_lemma4(timeout_seconds=0).complete
    f=gl_boolean_anf("ab",2)
    orbit=gl_boolean_orbit(f;max_evaluations=1000)
    @test orbit.complete && orbit.evaluations==24
    @test length(orbit.functions)==1
    @test only(orbit.functions)==f
    @test !gl_boolean_orbit(f;max_evaluations=0).complete
    H=partition_refinement_automorphisms(f;relation=:ea,max_nodes=10000,timeout_seconds=5)
    @test gl_compatible_representatives([f],f,H)==[1]
end
