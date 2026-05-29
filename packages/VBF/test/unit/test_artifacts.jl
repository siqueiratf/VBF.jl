using VBF
using Test

@testset "list_artifacts returns empty at v0.1" begin
    # The v0.1 package ships no artifacts; the file is purely comments.
    @test list_artifacts() == String[]
end

@testset "have_artifact returns false for any name when none declared" begin
    @test !have_artifact("anything")
    @test !have_artifact("bfa_apn_n7_v1")
end

@testset "artifact_path rejects undeclared names" begin
    @test_throws ArgumentError artifact_path("bfa_apn_n7_v1")
    @test_throws ArgumentError artifact_path("not_a_real_artifact")
end
