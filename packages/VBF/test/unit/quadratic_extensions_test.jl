@testitem "quadratic Fourier extension geometry and brute-force control" begin
    using VBF,Test
    Q=VBF.QuadraticExtensions
    @test_throws ArgumentError Q.geometry(1)
    @test_throws ArgumentError Q.geometry(9)
    G=Q.geometry(4)
    @test length(G.flats)==35
    F=gold_apn(4);a=anf(F)
    c=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:3 for j in i+1:3]
    forms=Q.coord_forms(c,4)
    normalized=UInt8[F(x) ⊻ foldl(⊻,(F(1<<i) for i in 0:3 if isodd(x>>i));init=UInt8(0)) for x in 0:15]
    @test last(Q.function_of(G,forms)).lut==normalized
    U=Q.rref(forms[1:2])[1]
    fast=Q.extensions(G,U,Q.ExtWork(4))
    brute=Q.extensions_bruteforce(G,U)
    @test fast.Ts==brute
    @test !isempty(fast.Ts)
    @test all(fast.Ts) do (u,v)
        S=Q.rref([fast.R;Q.lift(u,fast.Qmask);Q.lift(v,fast.Qmask)])[1]
        differential_uniformity(last(Q.function_of(G,S)))==2
    end
end
