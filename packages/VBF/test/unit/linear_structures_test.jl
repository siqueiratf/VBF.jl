@testitem "linear_structures" begin
using VBFCatalog
using VBF
using Test

@testset "linear_structures: identity has full set (a, a) for a ≠ 0" begin
    id = SBox(UInt8[0, 1, 2, 3])   # F(x⊕a) ⊕ F(x) = a always
    ls = linear_structures(id)
    @test Set(ls) == Set([(0x1, 0x1), (0x2, 0x2), (0x3, 0x3)])
    @test has_linear_structure(id)
end

@testset "linear_structures: constant function has every (a, 0)" begin
    c = SBox(UInt8[2, 2, 2, 2])   # F(x⊕a) ⊕ F(x) = 0 always
    ls = linear_structures(c)
    @test Set(ls) == Set([(0x1, 0x0), (0x2, 0x0), (0x3, 0x0)])
end

@testset "linear_structures: every literature S-box is structure-free" begin
    # A cryptographically strong S-box has no non-trivial linear structures. Every entry in our catalog is designed for this.
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        @test isempty(linear_structures(s))
        @test !has_linear_structure(s)
    end
end

@testset "linear_structures: count matches DDT 2^N entries" begin
    # Sanity: |linear_structures| equals the count of DDT entries equal to 2^N in rows 2:end (since we exclude row a=0).
    for name in literature_sbox_names()
        s = load_literature_sbox(name)
        d = ddt(s)
        n = 1 << inputbits(s)
        ls_count = count(==(n), view(d, 2:n, 1:n))
        @test length(linear_structures(s)) == ls_count
    end
end

end
