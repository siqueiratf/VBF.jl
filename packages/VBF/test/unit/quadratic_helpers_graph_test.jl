@testitem "quadratic_helpers_graph" begin
using VBFCatalog
using VBF
using Test
using Random

@testset "automorphisms_from_ortho_derivative: empty for non-quadratic-APN" begin
    @test isempty(automorphisms_from_ortho_derivative(load_apn_function("n5_Kasami_x15")))  # alg-deg 4
    @test isempty(automorphisms_from_ortho_derivative(load_literature_sbox("PRESENT")))     # not APN
end

@testset "automorphisms_from_ortho_derivative: empty when ortho-deriv non-permutation" begin
    # x³ over GF(2⁴) is a quadratic APN but non-bijective; its
    # ortho-derivative is many-to-one, so the permutation-only
    # linear-equivalence search yields nothing (documented limitation).
    F = load_apn_function("n4_Gold_x3")
    @test !is_permutation(ortho_derivative(F))
    @test isempty(automorphisms_from_ortho_derivative(F))
end

@testset "automorphisms_from_ortho_derivative: every map fixes the graph" begin
    for name in ("n5_Gold_x3", "n5_Gold_x5")
        F = load_apn_function(name)
        @test is_permutation(ortho_derivative(F))
        auts = automorphisms_from_ortho_derivative(F)
        @test !isempty(auts)
        G = FunctionGraph(F)
        for L in auts[1:min(end, 50)]
            @test !isempty(graph_xor_equivalence(G, graph_image_by(G, L)))
        end
    end
end

@testset "ea_mappings_from_ortho_derivative: self == automorphisms" begin
    F = load_apn_function("n5_Gold_x3")
    @test length(ea_mappings_from_ortho_derivative(F, F)) ==
          length(automorphisms_from_ortho_derivative(F))
end

@testset "ea_mappings_from_ortho_derivative: detects EA-equivalence" begin
    rng = MersenneTwister(0xBFA_C2)
    F = load_apn_function("n5_Gold_x3")
    N, T = 5, UInt8
    mask = T(0x1F)
    # Conjugate by a random invertible linear map: linearly (hence EA)
    # equivalent, and still a quadratic APN.
    gen = let
        local cols = T[]; local bs = T[]
        while length(cols) < N
            v = rand(rng, T) & mask
            v == 0 && continue
            is_in_span(v, bs; nbits = N) && continue
            push!(cols, v); push!(bs, v); bs = linear_basis(bs; nbits = N)
        end
        F2LinearMap{N, T}(cols)
    end
    Gc = gen ∘ (F ∘ inv(gen))
    @test is_quadratic_apn(Gc)
    maps = ea_mappings_from_ortho_derivative(F, Gc)
    @test !isempty(maps)
    G_F = FunctionGraph(F); G_Gc = FunctionGraph(Gc)
    for L in maps[1:min(end, 30)]
        @test !isempty(graph_xor_equivalence(G_F, graph_image_by(G_Gc, L)))
    end
end

@testset "ea_mappings_from_ortho_derivative: rejects EA-inequivalent" begin
    # Gold x³ and x⁵ at n=5 are in distinct Frobenius orbits → NOT
    # EA-equivalent → no ortho-derivative EA mappings.
    F3 = load_apn_function("n5_Gold_x3")
    F5 = load_apn_function("n5_Gold_x5")
    @test isempty(ea_mappings_from_ortho_derivative(F3, F5))
end

@testset "enumerate_ea_classes_apn_quadratic: distinct, all quadratic APN" begin
    F = load_apn_function("n5_Gold_x3")
    classes = enumerate_ea_classes_apn_quadratic(F)
    @test !isempty(classes)
    for c in classes
        @test algebraic_degree(c) == 2
        @test differential_uniformity(c) == 2
    end
    # The representatives are pairwise EA-INequivalent.
    for i in eachindex(classes), j in (i + 1):lastindex(classes)
        @test isempty(ea_mappings_from_ortho_derivative(classes[i], classes[j]))
    end
end

end
