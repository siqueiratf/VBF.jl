@testitem "ordered echelon back substitution matches full elimination" begin
    using VBF, Test, Random
    rng=MersenneTwister(0xec4e10)
    @test VBF.rref_from_echelon!(UInt32[])==0
    @test_throws ArgumentError VBF.rref_from_echelon!(UInt8[0])
    @test_throws ArgumentError VBF.rref_from_echelon!(UInt8[3,1])
    @test_throws ArgumentError VBF.rref_from_echelon!(UInt8[4,1])
    for T in (UInt8,UInt16,UInt32,UInt64,UInt128), _ in 1:100
        width=8*sizeof(T)
        pivots=sort!(shuffle(rng,collect(0:width-1))[1:rand(rng,0:min(width,31))])
        rows=T[]
        for pivot in pivots
            higher=pivot==width-1 ? zero(T) : (rand(rng,T)>>(pivot+1))<<(pivot+1)
            push!(rows,(one(T)<<pivot)|higher)
        end
        expected=copy(rows)
        rank=gauss_jordan!(expected)
        @test VBF.rref_from_echelon!(rows)==rank==length(pivots)
        @test rows==expected
    end
end
