@testitem "ccz_class_symmetry" begin
using VBF
using Test

@testset "enumerate_ccz_class: symmetric across a CCZ-class (Kim ↔ Dillon)" begin
    # The Kim function and the Dillon permutation are CCZ-equivalent (n=6).
    # With a Walsh-zero complement completing each subspace, the enumeration
    # recovers the SAME set of EA-classes from either starting point — and in
    # particular recovers the permutation-bearing classes. (An earlier
    # arbitrary-completion version was asymmetric: from kim_apn it produced no
    # permutations and missed the Dillon class.)
    #
    # This is the heaviest item in the suite: it computes apn_ea_mugshot for
    # every representative on both sides, and each mugshot of a degree-4
    # permutation rep enumerates n=6 Walsh-zero subspaces. It lives in its own
    # @testitem so it parallelises against the rest of the suite.
    kim = kim_apn()
    dil = dillon_apn_permutation()
    rk = enumerate_ccz_class(kim)
    rd = enumerate_ccz_class(dil)
    @test any(is_permutation, rk)                 # Kim's class contains permutations
    @test any(is_permutation, rd)
    sk = Set(apn_ea_mugshot.(rk))
    sd = Set(apn_ea_mugshot.(rd))
    @test sk == sd                                # same EA-classes from either side
    @test apn_ea_mugshot(dil) in sk               # Kim recovers the Dillon class
    @test apn_ea_mugshot(kim) in sd               # Dillon recovers the Kim class
end
end
