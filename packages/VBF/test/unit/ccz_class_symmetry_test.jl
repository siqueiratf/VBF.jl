@testitem "ccz_class_symmetry" begin
using VBF
using Test

function classkey(F)
    od = ortho_derivative(F)
    od === nothing ?
        (:nonquadratic, algebraic_degree(F), sort(abs.(vec(lat(F)))),
         sorted_pairs(sigma_multiplicities(F))) :
        (:quadratic, sort(abs.(vec(lat(od)))), sort(vec(ddt(od))))
end

@testset "enumerate_ccz_class: symmetric across a CCZ-class (Kim ↔ Dillon)" begin
    kim = kim_apn()
    dil = dillon_apn_permutation()
    rk = enumerate_ccz_class(kim)
    rd = enumerate_ccz_class(dil)

    @test any(is_permutation, rk)                 # Kim's class contains permutations
    @test any(is_permutation, rd)

    sk = Set(classkey.(rk))
    sd = Set(classkey.(rd))
    @test sk == sd                                # same EA-classes from either side
    @test classkey(dil) in sk                     # Kim recovers the Dillon class
    @test classkey(kim) in sd                     # Dillon recovers the Kim class

    qk = rk[findfirst(r -> ortho_derivative(r) !== nothing, rk)]
    qd = rd[findfirst(r -> ortho_derivative(r) !== nothing, rd)]
    @test apn_ea_mugshot(qk) == apn_ea_mugshot(kim)
    @test apn_ea_mugshot(qd) == apn_ea_mugshot(kim)
end
end
