@testitem "dense differential frequencies preserve DDT histograms" begin
    using VBF,Test,Random
    histogram(D)=Spectrum([D[a,b] for a in 2:size(D,1) for b in axes(D,2)])
    for encoding in 0:255
        F=SBox{2}(UInt8[(encoding>>(2x))&3 for x in 0:3])
        @test differential_spectrum(F)==histogram(ddt(F))
    end
    rng=Xoshiro(0xd1ff)
    for T in (UInt8,UInt16,UInt32,UInt64,UInt128),n in 1:8
        domain=1<<n
        F=SBox{n,T}(T.(rand(rng,0:domain-1,domain)))
        sp=differential_spectrum(F)
        @test sp==histogram(ddt(F))
        @test total_mass(sp)==domain*(domain-1)
        @test maximum(first,sp)==differential_uniformity(F)
    end
    for F in (gold_apn(8),SBox{8}(UInt8.(0:255)),SBox{8}(zeros(UInt8,256)))
        @test differential_spectrum(F)==histogram(ddt(F))
    end
end
