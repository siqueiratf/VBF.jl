@testset "algorithm1_test" begin
    include(joinpath(@__DIR__, "..", "algorithm1.jl"))

    # Gold n=5, K=1: domain size < 32 (filtering is non-trivial)
    F = gold_apn(5, 1)
    sz = 32
    for u in [0, 5, 15, 31]
        domain_sizes, _ = algorithm1_filter(F, [u])
        @test domain_sizes[1] < sz
    end

    # If v_i ∈ D_i is necessary for APN G: check that APN shifts lie in domain
    # Use u=3, check all shifts v=1..31
    u = 3
    _, forbidden_sets = algorithm1_filter(F, [u])
    for v = 1:31
        G = apply_modifications(F, [u], [v])
        if differential_uniformity(G) == 2
            # v must be in domain (not in forbidden set)
            @test v ∉ forbidden_sets[1]
        end
    end

    # Gold n=6, K=1: filtering should reduce from 64 options
    F6 = gold_apn(6, 1)
    domain_sizes6, _ = algorithm1_filter(F6, [7])
    @test domain_sizes6[1] < 64

    # ── Section IV-A, Example (a): U = {α⁰,…,α⁵} over F₂⁵ ────────────────────
    # Filtering empties every domain ⇒ no APN G exists for any shift combination.
    mod5 = primitive_polynomial(5)
    Ua = [gf_pow(2, i, 5; modulus = mod5) for i = 0:5]
    @test Ua == [1, 2, 4, 8, 16, 5]
    Da = algorithm1_domains(F, Ua)
    @test all(isempty, Da)                       # the paper: "no values at all are left"
    @test length(Da) == 6

    # Discriminating control: the same machinery does NOT empty every domain in
    # general — Example (b)'s U leaves a singleton. So `all(isempty, ...)` above is
    # a real property of this U, not a constant of algorithm1_domains.
    Ub = collect(0:7)                            # ⟨1, α, α²⟩
    Db = algorithm1_domains(F, Ub)
    @test !any(isempty, Db)

    # ── Section IV-A, Example (b): singleton domain {α²⁵}, G CCZ-equiv to x⁵ ──
    α25 = gf_pow(2, 25, 5; modulus = mod5)
    @test α25 == 25
    @test all(d == [α25] for d in Db)            # singleton, exactly as the paper says
    G = apply_modifications(F, Ub, fill(α25, 8))
    @test differential_uniformity(G) == 2
    @test hamming_distance(F, G) == 8
    @test are_ccz_equivalent(G, SBox{5}(gf_monomial_lut(5, 5)))     # CCZ-equivalent to x⁵
    # ... and not to x³ itself or to x¹⁵ — so the CCZ check above discriminates.
    @test !are_ccz_equivalent(G, SBox{5}(gf_monomial_lut(5, 15)))
    # α²⁵ is the only uniform shift of U that works.
    @test [v for v = 1:31
           if differential_uniformity(apply_modifications(F, Ub, fill(v, 8))) == 2] == [α25]

    # ── Section IV-A, Example (c): n=6, β pinned (P3 — β = 2 does NOT work) ──
    mod6 = primitive_polynomial(6)
    @test is_primitive_element(7, 6)
    @test is_primitive_element(2, 6)             # β = 2 is primitive but still fails below
    # The pinned default must be a β that reproduces the paper: calling example_c with
    # no β at all has to work (this is what the report does).
    @test example_c(; io = devnull, check_ccz = false).β == 7
    @test example_c(; io = devnull, check_ccz = false).all_ok
    rc = example_c(; io = devnull, β = 7, check_ccz = true)
    @test rc.all_ok
    @test rc.D == [6, 11, 20, 26, 28, 31]        # {β⁷, β¹⁴, β²⁸, β³⁵, β⁴⁹, β⁵⁶}
    @test length(rc.U) == 16
    @test rc.mixed_apn == 0 && rc.mixed_total == 30
    for v in rc.D
        Gc = apply_modifications(F6, rc.U, fill(v, 16))
        @test differential_uniformity(Gc) == 2
        @test hamming_distance(F6, Gc) == 16
    end

    # P3 evidence: with the repo's default β = 2 the very same construction collapses —
    # every domain becomes empty, so the example is genuinely β-sensitive.
    U_beta2 = sort(Int.(span_from_basis(UInt32[
        1, 2, gf_pow(2, 4, 6; modulus = mod6), gf_pow(2, 21, 6; modulus = mod6),
    ])))
    @test all(isempty, algorithm1_domains(F6, U_beta2))
    @test U_beta2 != rc.U

    # Examples (a) and (b) as driver functions.
    @test example_a(; io = devnull).all_ok
    @test example_b(; io = devnull).all_ok
end
