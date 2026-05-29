@testitem "qam_search" begin
using VBF
using Test

@testset "cyclic position orbits reproduce the reference structure" begin
    orbs = qam_cyclic_orbits(10, 2)
    @test length(orbs) == 9                       # Magma's 9 free vars A..I
    @test all(length(o) == 5 for o in orbs)       # each orbit has length n/m... = 5
    # the orbits partition all off-diagonal unordered pairs
    pairs = Set{Tuple{Int,Int}}()
    for o in orbs, (i, j) in o
        push!(pairs, (i, j))
    end
    @test length(pairs) == 45                     # C(10,2)
    # the leading orbit matches AssignA: {(1,2),(3,4),(5,6),(7,8),(9,10)}
    @test Set(orbs[1]) == Set([(1, 2), (3, 4), (5, 6), (7, 8), (9, 10)])
end

@testset "qam_from_cyclic obeys the Frobenius relation" begin
    n, m = 8, 4
    orbs = qam_cyclic_orbits(n, m)
    vals = [Int(gf_pow(2, 5k + 1, n)) for k in 1:length(orbs)]   # arbitrary nonzero
    M = qam_from_cyclic(n, m, vals)
    @test M == permutedims(M)
    @test all(M[i, i] == 0 for i in 1:n)
    # along each orbit, entry k+1 = (entry k)^(2^m)
    for o in orbs, k in 1:length(o) - 1
        a = M[o[k]...]
        b = M[o[k + 1]...]
        @test b == Int(gf_pow(a, 1 << m, n))
    end
end

@testset "Theorem 1: independent conjugate elements" begin
    for (n, m) in ((4, 2), (6, 3), (6, 2))
        S = independent_conjugate_elements(n, m)
        @test !isempty(S)
        r = n ÷ m
        for a in S[1:min(end, 8)]                  # spot-check the independence property
            conj = UInt[]
            x = a
            for _ in 1:r
                push!(conj, UInt(x))
                x = Int(gf_pow(x, 1 << m, n))
            end
            @test rank_f2(conj; nbits = n) == r
        end
    end
end

@testset "QAM search finds quadratic APN (n=4, m=2)" begin
    sols = search_qam(4, 2)
    @test !isempty(sols)
    @test all(differential_uniformity(S) == 2 for S in sols)
    @test all(algebraic_degree(S) == 2 for S in sols)
    @test all(is_qam(S) for S in sols)
    # n=4 has a single quadratic APN EA-class — Gold x³
    gold = SBox{4}(gf_monomial_lut(4, 3))
    @test any(apn_ea_mugshot(S) == apn_ea_mugshot(gold) for S in sols)
end
end
