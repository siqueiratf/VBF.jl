# Implements Theorem 10 — multiplier-group divisibility criteria.
# Paper: Edel, Pott (2009), "A new almost perfect nonlinear function which is
#        not quadratic", Adv. Math. Commun. 3(1):59-81.
# Section: 4 — Computational results (Theorem 10; used in the Theorem 11 proof).
#
# Theorem 10. Let v = |M(G_F)|. Then
#   (1) F CCZ-quadratic          ⇒ 2^n         | v
#   (2) F CCZ-equiv to power map ⇒ n·(2^n − 1) | v
#   (3) F CCZ-equiv to F_2[x]    ⇒ n           | v
#
# The multiplier order v = |Aut(dev(G_F))| / 2^{2n} is computed with MAGMA on the
# extended code C_F^ext — NOT reproduced here (no MAGMA in this repo). Instead we
# load the paper's published Table-6 orders and run the contrapositive tests, so
# the *reasoning* of Theorem 10 / the Theorem 11 non-power argument is reproduced.
#
# VBF API used: print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

# Published |M(G_F)| = Table-6 column |Aut(dev(G_F))|/2^{2n}  (MAGMA, not executed).
const EP_MULTIPLIER_ORDER_N6 = Dict(
    "1.1" => 2^7 * 3^3 * 7,   # 24192
    "1.2" => 2^6 * 3^2 * 7,   # 4032
    "2.1" => 2^7 * 7,         # 896
    "2.2" => 2^6,             # 64
    "2.3" => 2^6,
    "2.4" => 2^6,
    "2.5" => 2^6 * 5,         # 320
    "2.6" => 2^6 * 5,
    "2.7" => 2^6,
    "2.8" => 2^6,
    "2.9" => 2^6,
    "2.10" => 2^6,
    "2.11" => 2^3,            # 8  — the "too small" multiplier group
    "2.12" => 2^6 * 7,        # 448
)

"""
    theorem10_report(io = stdout; save_results = false) -> NamedTuple

Reproduce the Theorem 10 divisibility *reasoning* for the `n = 6` classes using
the paper's published multiplier orders (the orders themselves are MAGMA-only).
The headline consequence, for entry 2.11: `v = 8` is divisible by neither
`2⁶ = 64` (⇒ not CCZ-quadratic, Theorem 4) nor `2⁶−1 = 63` (⇒ not a power map).
"""
function theorem10_report(io::IO = stdout; save_results::Bool = false)
    print_section("Theorem 10 — multiplier-group divisibility (from published |M|)", io)
    print_kv("|M(G_F)| source", "Edel–Pott Table 6 (MAGMA on C_F^ext) — NOT executed here", io)

    n = EP_N
    quad_div  = 1 << n                 # 2^n = 64
    power_div = n * ((1 << n) - 1)     # n(2^n-1) = 378
    poly_div  = n                      # 6

    focus = NamedTuple[]
    for name in ("1.1", "2.11")
        v = EP_MULTIPLIER_ORDER_N6[name]
        may_quad  = v % quad_div == 0
        may_power = v % power_div == 0
        may_poly  = v % poly_div == 0
        push!(focus, (; name, v, may_quad, may_power, may_poly))
        print_kv("F$name  |M| = $v", "quad-possible=$may_quad  " *
            "power-possible=$may_power  poly-possible=$may_poly", io)
    end

    v211 = EP_MULTIPLIER_ORDER_N6["2.11"]
    print_check("Theorem 10(2): 2^6−1=63 ∤ |M(2.11)|=$v211 ⇒ 2.11 is NOT a power map",
        v211 % ((1 << n) - 1) != 0, io)
    print_check("Theorem 4/10(1): 2^6=64 ∤ |M(2.11)|=$v211 ⇒ 2.11 is NOT CCZ-quadratic",
        v211 % quad_div != 0, io)

    v11 = EP_MULTIPLIER_ORDER_N6["1.1"]
    print_check("consistency: x^3 (1.1) is a power map ⇒ n(2^n−1)=$power_div | |M|=$v11",
        v11 % power_div == 0, io)

    print_kv("status", "reasoning reproduced; |M(G_F)| computation is MAGMA-only " *
        "(not executed)", io)

    result = (; focus, v211_not_power = v211 % ((1 << n) - 1) != 0,
        v211_not_quad = v211 % quad_div != 0)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "theorem10.toml"), "w") do f
            println(f, "# Edel–Pott (2009) Theorem 10 — divisibility reasoning (published |M|)")
            println(f, "v_2_11 = $v211")
            println(f, "not_power_map = $(v211 % ((1 << n) - 1) != 0)")
            println(f, "not_quadratic = $(v211 % quad_div != 0)")
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem10_report()
end
