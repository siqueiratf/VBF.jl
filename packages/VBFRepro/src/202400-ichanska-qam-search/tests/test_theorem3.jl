@testset "theorem3_test" begin
    include(joinpath(@__DIR__, "..", "theorem3.jl"))

    @test verify_theorem3(n = 4, m = 1)

    # Verify for m=2 (shift by 2)
    n = 4; m = 2; mod_n = conway_polynomial(n)
    b = find_normal_element(n; modulus = mod_n)
    F = SBox{n}([gf_pow(x, 3, n; modulus = mod_n) for x in 0:(1<<n)-1])
    MF = normal_basis_deriv_matrix(F, b; modulus = mod_n)

    all_ok = true
    for alpha in 1:(1<<n)-1
        r0 = _row_combo_rank(MF, alpha, 0)
        r1 = _row_combo_rank(MF, alpha, m)
        r0 == r1 || (all_ok = false; break)
    end
    @test all_ok
    # Regression: rank must retain field coordinates above bit 7.
    wide=zeros(Int,10,10); wide[1,2]=256; wide[1,3]=512
    @test _row_combo_rank(wide,1,0) == 2
    @test_throws ArgumentError _row_combo_rank(wide,0,0)
    @test_throws ArgumentError _row_combo_rank(fill(1024,10,10),1,0)
    for (n,m) in ((9,3),(10,1),(10,2))
        @test verify_theorem3(;n,m)
    end

end
