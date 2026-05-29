@testitem "spectrum" begin
using VBFCatalog
using VBF
using Test

@testset "empty" begin
    s = Spectrum()
    @test isempty(s)
    @test length(s) == 0
    @test total_mass(s) == 0
    @test sorted_pairs(s) == Pair{Int, Int}[]
end

@testset "construct from values" begin
    s = Spectrum([2, 2, 4, 4, 4, 8])
    @test length(s) == 3
    @test total_mass(s) == 6
    @test sorted_pairs(s) == [2 => 2, 4 => 3, 8 => 1]
end

@testset "add!" begin
    s = Spectrum()
    add!(s, 2)
    add!(s, 4, 3)
    add!(s, 2)
    @test sorted_pairs(s) == [2 => 2, 4 => 3]
    @test total_mass(s) == 5

    # chaining
    add!(add!(Spectrum(), 1), 1)
    @test length(s) == 2
end

@testset "merge!" begin
    a = Spectrum([2, 2, 4])
    b = Spectrum([4, 8])
    merge!(a, b)
    @test sorted_pairs(a) == [2 => 2, 4 => 2, 8 => 1]
    @test total_mass(a) == 5
    # src untouched
    @test sorted_pairs(b) == [4 => 1, 8 => 1]
end

@testset "indexing" begin
    s = Spectrum([2, 4, 4])
    @test s[4] == 2
    @test get(s, 8, 0) == 0
    @test haskey(s, 2)
    @test !haskey(s, 99)
end

@testset "equality / hash / copy" begin
    a = Spectrum([2, 2, 4])
    b = Spectrum([4, 2, 2])  # different insertion order
    c = Spectrum([2, 4, 4])

    @test a == b
    @test a != c
    @test hash(a) == hash(b)

    a2 = copy(a)
    add!(a2, 99)
    @test a != a2
    @test !haskey(a, 99)
end

@testset "show" begin
    s = Spectrum([2, 2, 4])
    str = sprint(show, s)
    @test occursin("2 distinct", str)
    @test occursin("mass 3", str)

    plain = sprint(show, MIME"text/plain"(), s)
    @test occursin("2 => 2", plain)
    @test occursin("4 => 1", plain)
end

end
