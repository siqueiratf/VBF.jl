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

@testitem "quadratic extension coordinates and shared linear algebra" begin
    using VBF, Test, Random
    Q = VBF.QuadraticExtensions
    rng = MersenneTwister(0x514e)

    @test Q.rref(UInt32[0]) == (UInt32[], Int[])
    @test Q.rref(UInt32[0x80000001, 0xc0000003, 0x40000002]) ==
          (UInt32[0x80000001, 0x40000002], [31, 30])
    # These bases fix the actual coordinates, rather than only checking equal ranks.
    for m in 1:5, r in 0:m, canonical in Q.each_rref(m, r)
        rows = copy(canonical)
        for _ in 1:4
            push!(rows, foldl(⊻, (v for v in canonical if rand(rng, Bool)); init = UInt32(0)))
        end
        shuffle!(rng, rows)
        actual, pivots = Q.rref(rows)
        @test actual == canonical
        @test pivots == [31 - leading_zeros(v) for v in canonical]
        @test Q.span_dim(rows) == r
    end

    # Direct character sums independently fix the sign and coordinate convention.
    for T in (Int16, Int64), n in (1, 2, 4, 8, 16, 64)
        a = T.(rand(rng, -2:2, n))
        expected = T[sum((isodd(count_ones(x & u)) ? -1 : 1) * a[x+1]
                         for x in 0:n-1) for u in 0:n-1]
        work = copy(a)
        @test Q.fwht!(work) === work
        @test work == expected
    end
    @test_throws ArgumentError Q.fwht!(Int16[])
    @test_throws ArgumentError Q.fwht!(zeros(Int16, 7))

    @test Q.solve_ones(UInt32[], 0) == (UInt32(0), UInt32[])
    @test Q.solve_ones(UInt32[0], 0) === nothing
    @test Q.solve_ones(fill(UInt32(3), 80), 3) == (UInt32(1), UInt32[3, 4])
    @test Q.solve_ones(UInt32[3, 5], 3) == (UInt32(1), UInt32[7])
    @test Q.solve_ones(UInt32[3, 5, 6], 3) === nothing
    @test_throws ArgumentError Q.solve_ones(UInt32[], 32)
    @test_throws ArgumentError Q.solve_ones(UInt32[8], 3)
    rows = UInt32[]; pivots = Int[]; kernel = UInt32[]
    for D in 1:5, _ in 1:40
        Z = rand(rng, UInt32(0):UInt32((1 << D)-1), rand(rng, 0:50))
        expected = UInt32[v for v in 0:(1 << D)-1
                          if all(c -> isodd(count_ones(c & UInt32(v))), Z)]
        solution = Q.solve_ones(Z, D, rows, pivots, kernel)
        if isempty(expected)
            @test solution === nothing
        else
            @test solution !== nothing
            v0, K = solution
            @test K === kernel
            enumerated = UInt32[v0 ⊻ foldl(⊻, (K[i] for i in eachindex(K)
                                               if isodd(mask >> (i-1))); init = UInt32(0))
                                for mask in 0:(1 << length(K))-1]
            @test sort!(enumerated) == expected
            @test length(unique(enumerated)) == length(enumerated)
        end
    end
end
