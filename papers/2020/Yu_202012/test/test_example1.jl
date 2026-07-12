@testset "example1_test" begin
    include(joinpath(@__DIR__, "..", "example1.jl"))
    result = example1_verify()
    for (desc, ok) in result.checks
        @test ok
    end

    # The paper's Example 1, stated concretely: three free variables a, b, c, whose
    # Frobenius orbits have lengths 6, 6, 3.
    @test sort(result.orbit_lengths) == [3, 6, 6]
    @test result.c_values == 8                 # c = c^{2³} ⟹ c ∈ GF(2³), 8 elements
    @test result.search_space == 1 << 15       # 64 · 64 · 8 = 2¹⁵
    @test result.iff_violations == 0

    # The iff is not one-sided: a c OUTSIDE GF(2³) must genuinely BREAK the structure,
    # otherwise the "c ∈ GF(2³)" constraint would be vacuous. Check both directions on
    # explicit values.
    orbits = qam_cyclic_orbits(6, 1)
    i3 = findfirst(o -> length(o) == 3, orbits)
    others = [k for k = 1:3 if k != i3]
    sub3 = subfield_gf8_of_gf64()

    good = zeros(Int, 3)
    good[others[1]] = 7
    good[others[2]] = 11
    good[i3] = sub3[3]                                     # c ∈ GF(2³)
    @test has_f2_cyclic_structure(qam_from_cyclic(6, 1, good), 6)

    c_out = first(c for c = 0:63 if !(c in sub3))          # c ∉ GF(2³)
    bad = copy(good)
    bad[i3] = c_out
    @test !has_f2_cyclic_structure(qam_from_cyclic(6, 1, bad), 6)
end
