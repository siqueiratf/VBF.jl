@testitem "ccz_class_symmetry" begin
using VBF
using Test

# A thickness-free EA-invariant class key. apn_ea_mugshot is the canonical key,
# but for the degree-4 permutation representatives in this CCZ-class it computes
# thickness_spectrum (an n=6 Walsh-zero subspace enumeration) — and with ~440
# representatives across both sides that made this the heaviest item in the suite
# (~75s). The components below are all genuine EA-invariants and need no subspace
# enumeration: algebraic degree, the absolute Walsh spectrum, sigma-multiplicities,
# and the ortho-derivative's spectra for the quadratic representatives. It is
# coarser than the full mugshot, which is sufficient for the symmetry/recovery
# claims here; the exact mugshot is still checked on the quadratic source below.
function classkey(F)
    od = ortho_derivative(F)
    od === nothing ?
        (:nonquadratic, algebraic_degree(F), sort(abs.(vec(lat(F)))),
         sorted_pairs(sigma_multiplicities(F))) :
        (:quadratic, sort(abs.(vec(lat(od)))), sort(vec(ddt(od))))
end

@testset "enumerate_ccz_class: symmetric across a CCZ-class (Kim ↔ Dillon)" begin
    # The Kim function and the Dillon permutation are CCZ-equivalent (n=6). With
    # a Walsh-zero complement completing each subspace, the enumeration recovers
    # the SAME set of EA-classes from either starting point — and in particular
    # the permutation-bearing classes. (An earlier arbitrary-completion version
    # was asymmetric: from kim_apn it produced no permutations and missed the
    # Dillon class.)
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

    # Strong exact check on the quadratic source: each side's CCZ-class has a
    # single quadratic representative, and its full ortho-derivative EA-fingerprint
    # must equal the Kim function's. (apn_ea_mugshot is cheap on quadratic APN —
    # it takes the ortho-derivative path, not thickness.)
    qk = rk[findfirst(r -> ortho_derivative(r) !== nothing, rk)]
    qd = rd[findfirst(r -> ortho_derivative(r) !== nothing, rd)]
    @test apn_ea_mugshot(qk) == apn_ea_mugshot(kim)
    @test apn_ea_mugshot(qd) == apn_ea_mugshot(kim)
end
end
