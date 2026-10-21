@testitem "streaming Walsh spectra preserve exact LAT histograms" begin
    using VBF,Test,Random
    histogram(L)=Spectrum([abs(L[a,b]) for a in axes(L,1) for b in axes(L,2) if a!=1 || b!=1])
    for encoding in 0:255
        F=SBox{2}(UInt8[(encoding>>(2x))&3 for x in 0:3])
        expected=[sum(isodd(count_ones(a&x)+count_ones(b&Int(F.lut[x+1]))) ? -1 : 1 for x in 0:3)
            for a in 0:3,b in 0:3]
        @test lat(F)==expected
        @test absolute_walsh_spectrum(F)==histogram(expected)
    end
    rng=Xoshiro(0x7155)
    for T in (UInt8,UInt16,UInt32,UInt64,UInt128),n in 1:8
        domain=1<<n
        F=SBox{n,T}(T.(rand(rng,0:domain-1,domain)))
        L=lat(F);sp=absolute_walsh_spectrum(F)
        @test sp==histogram(L)
        @test total_mass(sp)==domain^2-1
    end
    for F in (gold_apn(8),SBox{8}(UInt8.(0:255)),SBox{8}(zeros(UInt8,256)))
        @test absolute_walsh_spectrum(F)==histogram(lat(F))
    end
    F=gold_apn(8)
    lat(F);absolute_walsh_spectrum(F)
    table_bytes=@allocated lat(F)
    spectrum_bytes=@allocated absolute_walsh_spectrum(F)
    @test spectrum_bytes<table_bytes÷8
end
