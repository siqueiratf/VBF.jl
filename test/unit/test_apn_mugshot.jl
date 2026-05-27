using BFA
using Test

@testset "apn_ea_mugshot: quadratic APN dispatch" begin
    F = load_apn_function("n5_Gold_x3")
    @test algebraic_degree(F) == 2
    m = apn_ea_mugshot(F)
    @test m.kind == :quadratic
    @test haskey(m.fields, :walsh)
    @test haskey(m.fields, :ddt)
end

@testset "apn_ea_mugshot: non-quadratic dispatch" begin
    F = load_apn_function("n5_Kasami_x15")
    @test algebraic_degree(F) > 2
    m = apn_ea_mugshot(F)
    @test m.kind == :non_quadratic
    @test haskey(m.fields, :abs_walsh)
    @test haskey(m.fields, :degree)
    @test haskey(m.fields, :sigma)
    @test haskey(m.fields, :thickness)
end

@testset "apn_ea_mugshot: reflexivity" begin
    for name in ("n5_Gold_x3", "n5_Gold_x5", "n5_Kasami_x15")
        F = load_apn_function(name)
        @test apn_ea_mugshot(F) == apn_ea_mugshot(F)
    end
end

@testset "apn_ea_mugshot: necessary, not sufficient" begin
    # For quadratic APN F, G: F ~_EA G ⇒ mugshot equal. The converse
    # is not always true — the mugshot hashes the SPECTRA (walsh, DDT)
    # of the ortho-derivative, which can collide even when the
    # ortho-derivatives themselves are linearly INequivalent.
    # n5_Gold_x3 vs n5_Gold_x5 is an empirical example of mugshot
    # collision despite EA-INequivalence; pin this here so the
    # not-sufficient property is visible regression evidence.
    F3 = load_apn_function("n5_Gold_x3")
    F5 = load_apn_function("n5_Gold_x5")
    @test apn_ea_mugshot(F3) == apn_ea_mugshot(F5)
    # The are_ea_equivalent ortho-derivative strategy DOES distinguish them.
    @test !are_ea_equivalent(F3, F5; strategy = :ortho_derivative)
end

@testset "apn_ea_mugshot: EA-equivalent inputs share mugshots" begin
    using Random
    rng = MersenneTwister(0xBFA_A2)
    F = load_apn_function("n5_Gold_x3")
    N, T = 5, UInt8
    mask = T(0x1F)
    m_F = apn_ea_mugshot(F)
    for _ in 1:3
        local cols1 = T[]; local bs1 = T[]
        while length(cols1) < N
            v = rand(rng, T) & mask
            v == 0 && continue
            is_in_span(v, bs1; nbits = N) && continue
            push!(cols1, v); push!(bs1, v)
            bs1 = linear_basis(bs1; nbits = N)
        end
        L1 = F2LinearMap{N, T}(cols1)
        local cols2 = T[]; local bs2 = T[]
        while length(cols2) < N
            v = rand(rng, T) & mask
            v == 0 && continue
            is_in_span(v, bs2; nbits = N) && continue
            push!(cols2, v); push!(bs2, v)
            bs2 = linear_basis(bs2; nbits = N)
        end
        L2 = F2LinearMap{N, T}(cols2)
        G = L1 ∘ (F ∘ L2)
        @test apn_ea_mugshot(G) == m_F
    end
end

@testset "apn_ea_mugshot: non-quadratic-APN path handles permutations" begin
    # For non-quadratic APN with thickness defined (i.e., a permutation),
    # the mugshot's thickness field is populated.
    F = load_apn_function("n5_Kasami_x15")
    @test is_permutation(F)
    @test algebraic_degree(F) > 2
    m = apn_ea_mugshot(F)
    @test m.kind == :non_quadratic
    @test !isempty(m.fields.thickness)
    @test all(0 ≤ t ≤ inputbits(F) for t in m.fields.thickness)
end
