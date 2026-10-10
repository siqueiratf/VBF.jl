@testset "lemmaA_1_test" begin
    include(joinpath(@__DIR__, "..", "lemmaA_1.jl"))

    io = IOBuffer()
    r = lemmaA_1_report(io; m_values = (3, 4), include_f4 = true)
    @test r.index_ok
    @test r.condition_c_ok
    @test r.f4_index_ok
    @test r.f4_structure_ok
    @test r.all_ok

    # Both index values predicted by Lemma A.1 actually occur in the corpus —
    # so "index matches" is not a test that a constant would pass.
    idxs = Set(row.index for row in r.rows)
    @test 1 in idxs
    @test 3 in idxs

    fld = BiField(5)
    # Taniguchi: C_F = Z^{(q,r)}, index 1
    d = findfirst(x -> taniguchi_valid(fld, 1, x), 0:31) - 1
    @test centralizer_index(taniguchi(fld, 1, d)) == 1
    # F1, F2: index 3
    @test centralizer_index(family_f1(fld, 1)) == 3
    @test centralizer_index(family_f2(fld, 1)) == 3

    # F4 at m = 6: index 3, and the three classes are exactly the Z_omega
    f6 = BiField(6)
    F = family_f4(f6, 1, 2, 1)
    cls = centralizer_classes(F)
    @test length(cls) == 3
    @test f4_classes_are_Z_omega(F, cls)
    # each class rep is diag(1, omega) with omega a cube root of unity
    @test Set(c[4] for c in cls) == Set(f4star(f6))

    # negative control: suppressing the N-part collapses the Carlet index 3 -> 1
    @test r.carlet_N_control == (3, 1)

    # condition (C): p never divides the index
    for row in r.rows
        row.p === nothing && continue
        @test row.index % row.p != 0
    end
end
