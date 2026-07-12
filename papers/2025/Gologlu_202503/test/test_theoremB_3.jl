@testset "theoremB_3_test" begin
    include(joinpath(@__DIR__, "..", "theoremB_3.jl"))

    io = IOBuffer()
    r = theoremB_3_report(io; m = 4)
    @test r.tested > 0
    @test all(x -> x.identity_ok, r.results)     # L o C o M + N = ZP, pointwise
    @test all(x -> x.zp_admissible, r.results)
    @test all(x -> x.zp_apn, r.results)
    @test all(x -> x.mugshot_equal, r.results)
    @test r.all_ok

    fld = BiField(4)
    dc = findfirst(x -> carlet_valid(fld, 1, 0, 1, x), 0:15) - 1
    C = carlet(fld, 1, 0, 1, dc)
    @test biprojective_is_apn(C)

    w = carlet_to_zhou_pott(C)
    @test w !== nothing
    # the witness M is invertible and sends g to a scalar multiple of (1,0,0,u)_q
    @test (gmul(fld, w.c1, w.c4) ⊻ gmul(fld, w.c2, w.c3)) != 0
    gc = biproj_compose(fld, C.g, w.c1, w.c2, w.c3, w.c4)
    @test gc.c[2] == 0 && gc.c[3] == 0
    @test !gf_is_dth_power(w.u, 3, 4; modulus = fld.modulus)   # u really is a non-cube

    # the target is an APN Zhou-Pott function (with j = 0 — see the file header)
    ZP = zhou_pott(fld, 1, 0, w.u)
    @test biprojective_is_apn(ZP)
    @test mugshot_of(C) == mugshot_of(ZP)

    # NEGATIVE CONTROL: for m odd every element is a cube, so no non-cube u exists
    # and Theorem B.3's even-m hypothesis is genuinely needed.
    @test isempty(noncubes(BiField(5)))
    @test r.noncubes_m_odd == 0
    @test !isempty(noncubes(fld))            # ...while m = 4 does have non-cubes
end
