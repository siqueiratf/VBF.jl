using Test, Random
include("../search.jl")

@testset "study labels retain Framework search discoveries" begin
    mktempdir() do dir
        path = joinpath(dir,"found.tsv")
        labels = ["known","search","new","search-new","census"]
        hashes = [string(i;base=16,pad=64) for i in eachindex(labels)]
        payload = repeat("00",28)
        open(path,"w") do io
            println(io,"sigma\tstatus\tgen\tparent\tb6\tcoeffs")
            for i in eachindex(labels)
                println(io,join([hashes[i],labels[i],"1",hashes[1],"52",payload],'\t'))
            end
        end
        known,seeds = load_study([path],10,Xoshiro(8))
        @test known == Set(hashes)
        @test Set(first.(seeds)) == Set(hashes[2:4])
        @test all(last(s)==payload for s in seeds)
        @test load_study([path],1,Xoshiro(8)) == load_study([path],1,Xoshiro(8))
        @test length(last(load_study([path],1,Xoshiro(8)))) == 1
    end
end
