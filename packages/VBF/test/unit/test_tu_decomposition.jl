using VBF
using Test
using Random

@testset "TU round-trip: literature permutations" begin
    for name in ("PRESENT", "GIFT")
        F = load_literature_sbox(name)
        is_permutation(F) || continue
        tds = get_tu_decompositions(F)
        @test !isempty(tds)
        for td in tds
            @test apply_tu(td) == F
            # every T block is a permutation of its t-bit space
            @test all(VBF._is_perm_lut(Tk) for Tk in td.Tblocks)
            @test length(td.Tblocks) == 1 << (inputbits(F) - td.t)
            @test length(td.Ublocks) == 1 << td.t
        end
        # thickness 1..N all reachable for these 4-bit S-boxes
        @test sort(unique(td.t for td in tds)) == collect(1:inputbits(F))
    end
end

@testset "TU round-trip: APN permutation (n=5 Gold x³)" begin
    F = load_apn_function("n5_Gold_x3")
    @test is_permutation(F)
    tds = get_tu_decompositions(F)
    @test !isempty(tds)
    @test all(apply_tu(td) == F for td in tds)
end

@testset "TU round-trip: random permutations" begin
    rng = MersenneTwister(0x70)
    for N in (3, 4, 5)
        F = random_permutation_sbox(rng, Val(N))
        tds = get_tu_decompositions(F)
        for td in tds
            @test apply_tu(td) == F
            @test 1 ≤ td.t ≤ N
        end
    end
end

@testset "tu_decomposition_from_space_basis matches subspace thickness" begin
    F = load_literature_sbox("PRESENT")
    N = inputbits(F)
    bases = extract_linear_subspaces(walsh_zeroes(F), N; max_bits = 2N)
    for w in bases
        t = thickness(w, N)
        t == 0 && continue
        td = tu_decomposition_from_space_basis(F, w)
        @test td.t == t
        @test apply_tu(td) == F
    end
end

@testset "tu_decomposition_from_space_basis: t = 0 is rejected" begin
    F = load_literature_sbox("PRESENT")          # N = 4
    # A subspace lying entirely in the high N bits has thickness 0.
    zero_thickness = UInt32[0x10, 0x20, 0x40, 0x80]
    @test thickness(zero_thickness, 4) == 0
    @test_throws ArgumentError tu_decomposition_from_space_basis(F, zero_thickness)
end

@testset "core / twist" begin
    F = load_literature_sbox("PRESENT")
    td = first(get_tu_decompositions(F))
    c = core(td)
    tw = twist(td)
    # core strips the outer maps: identity A/B, zero C.
    @test is_linear(c.A) && all(c.A(x) == x for x in 0:15)
    @test all(c.B(x) == x for x in 0:15)
    @test all(c.C(x) == 0 for x in 0:15)
    # core and twist still reconstruct valid S-boxes
    @test apply_tu(c) isa SBox
    @test apply_tu(tw) isa SBox
    # twisting twice returns to the core function
    @test apply_tu(twist(tw)) == apply_tu(c)
end

@testset "get_tu_decompositions: cached bases match" begin
    F = load_literature_sbox("GIFT")
    N = inputbits(F)
    bases = extract_linear_subspaces(walsh_zeroes(F), N; max_bits = 2N)
    a = get_tu_decompositions(F)
    b = get_tu_decompositions(F; bases = bases)
    @test length(a) == length(b)
    @test all(apply_tu(x) == F for x in b)
end

@testset "show smoke test" begin
    td = first(get_tu_decompositions(load_literature_sbox("PRESENT")))
    @test occursin("TUDecomposition", sprint(show, td))
    @test occursin("keyed", sprint(show, MIME"text/plain"(), td))
end
