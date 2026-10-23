@testitem "explicit polar-rank table matches alternating-form ranks" begin
    using VBF,Test
    Q=VBF.QuadraticExtensions
    for n in (2,4,6)
        G=Q.geometry(n);table=Q.PolarRankTable(G)
        @test table.n==n
        @test !ismutabletype(typeof(table))
        @test length(table.ranks)==1<<G.N
        @test table.ranks==UInt8[Q.form_rank_slow(G,UInt32(q)) for q in 0:(1<<G.N)-1]
        @test table.ranks[1]==0
    end
    G=Q.geometry(4);table=Q.PolarRankTable(G)
    @test count(==(0),table.ranks)==1
    @test count(==(2),table.ranks)==35
    @test count(==(4),table.ranks)==28
    @test_throws MethodError Q.PolarRankTable(4,copy(table.ranks))
    invalid_dimension=Q.Geometry(9,36,G.pair,G.pairs,G.flats,G.flatpts,G.rt)
    invalid_geometry=Q.Geometry(4,28,G.pair,G.pairs,G.flats,G.flatpts,G.rt)
    @test_throws ArgumentError Q.PolarRankTable(invalid_dimension)
    @test_throws ArgumentError Q.PolarRankTable(invalid_geometry)
end

@testitem "two-bit polar ranks preserve zero and every small geometry" begin
    using VBF,Test
    Q=VBF.QuadraticExtensions
    for n in 2:6
        G=Q.geometry(n);packed=Q.PackedPolarRankTable(G);byte=Q.PolarRankTable(G)
        @test packed.n==n && !ismutabletype(typeof(packed))
        @test length(packed.codes)==cld(1<<G.N,4)
        @test Q._polar_rank(packed,UInt32(0))==0
        @test [Q._polar_rank(packed,UInt32(q)) for q in 0:(1<<G.N)-1]==Int.(byte.ranks)
    end
    G=Q.geometry(4)
    @test_throws MethodError Q.PackedPolarRankTable(4,zeros(UInt8,16))
    invalid=Q.Geometry(4,28,G.pair,G.pairs,G.flats,G.flatpts,G.rt)
    @test_throws ArgumentError Q.PackedPolarRankTable(invalid)
    invalid=Q.Geometry(9,36,G.pair,G.pairs,G.flats,G.flatpts,G.rt)
    @test_throws ArgumentError Q.PackedPolarRankTable(invalid)
    table=Q.PackedPolarRankTable(G);beta=Q.bent_fourier(G)
    a=Int32[];b=Int32[]
    for V in Q.each_rref(G.N,2)
        @test Q.coset_bent_counts!(a,G,V,beta)==Q.coset_bent_counts!(b,G,V,beta;rank_table=table)
        @test a==b
    end
    @test_throws ArgumentError Q.coset_bent_counts!(b,G,UInt32[1,2],beta;rank_table=Q.PackedPolarRankTable(Q.geometry(2)))
end

@testitem "polar-rank lookup preserves every four-variable two-space bent count" begin
    using VBF,Test
    Q=VBF.QuadraticExtensions;G=Q.geometry(4)
    table=Q.PolarRankTable(G);beta=Q.bent_fourier(G)
    ordinary=Int32[];lookup=Int32[];spaces=Q.each_rref(G.N,2)
    @test length(spaces)==651
    for V in spaces
        expected=Q.coset_bent_counts!(ordinary,G,V,beta)
        actual=Q.coset_bent_counts!(lookup,G,V,beta;rank_table=table)
        @test actual==expected
        @test lookup==ordinary
    end
    wrong=Q.PolarRankTable(Q.geometry(2))
    @test_throws ArgumentError Q.coset_bent_counts!(lookup,G,first(spaces),beta;rank_table=wrong)
end

@testitem "coset rank fill preserves binary coordinates and exact bent counts" begin
    using VBF,Test
    Q=VBF.QuadraticExtensions
    G=Q.geometry(4);beta=Q.bent_fourier(G)
    tables=(nothing,Q.PolarRankTable(G),Q.PackedPolarRankTable(G))
    for table in tables
        buffer=fill(Int32(-9),19)
        metadata=Q.coset_bent_counts!(buffer,G,UInt32[1,2],beta;rank_table=table)
        @test buffer==vcat(Int32[0,0,0,16],fill(Int32(8),12))
        @test metadata.R==UInt32[2,1]
        @test metadata.Qmask==UInt32(0x3c)
        @test metadata.D==4 && metadata.scale==4
    end

    table=last(tables)
    for V in Q.each_rref(G.N,2)
        buffer=Int32[]
        metadata=Q.coset_bent_counts!(buffer,G,V,beta;rank_table=table)
        span=Q.comp_forms(V)
        expected=Int32[metadata.scale*count(w->Q.form_rank(G,Q.lift(UInt32(tau),metadata.Qmask)⊻w)==G.n,span)
            for tau in 0:(1<<metadata.D)-1]
        @test buffer==expected
    end
end

@testitem "zero-dimensional coset fill never converts unused rank weights" begin
    using VBF,Test
    Q=VBF.QuadraticExtensions
    for n in 2:6
        G=Q.geometry(n)
        full=UInt32[UInt32(1)<<j for j in 0:G.N-1]
        beta=vcat(Int[1],fill(typemax(Int),n÷2))
        for table in (nothing,Q.PolarRankTable(G),Q.PackedPolarRankTable(G))
            buffer=Int32[-17,-19]
            metadata=Q.coset_bent_counts!(buffer,G,full,beta;rank_table=table)
            @test buffer==Int32[1]
            @test metadata.D==0 && iszero(metadata.Qmask) && metadata.scale==1
        end
    end
end
