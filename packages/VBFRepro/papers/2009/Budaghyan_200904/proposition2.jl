# Implements Proposition 2 (trinomial F and G=F+tr(α^… x³) are EA-equivalent).
# Paper: Budaghyan, Carlet, Leander (2009), "Constructing new APN functions from
#        known ones", Finite Fields Appl. 15 (2009) 150–159.
# Section: §2 — Proposition 2
#
# Let m odd, n=2m, α a primitive element of GF(2ⁿ). Then
#   F(x) = x⁶ + x^{2^m+1} + α^{2^m-1} x^{6·2^m}
#   G(x) = F(x) + tr(α^{2^{m-1}+1} x³)
# are EA-equivalent, witnessed by L(x)=x+tr(u x), u = α^{2^{m+1}+1}/(α^{2^m-1}+1),
# with L(F(x)) = G(x).
#
# Pseudocode:
#   1. Build F, G at n=6 (m=3), α = generator 2 (primitive for this modulus).
#   2. Check du(F)=du(G)=2 and are_ea_equivalent(F,G).
#   3. Verify the explicit witness L(F(x)) = G(x) with u.
#
# VBF API used: gf_pow, gf_mul, gf_inv, gf_trace, differential_uniformity,
#               are_ea_equivalent, primitive_polynomial, SBox

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition2_report(io; m, save_results) -> NamedTuple

Reproduce Proposition 2 at `n = 2m` (default m=3, n=6) with primitive element
α = 2. Verifies APN, EA-equivalence, and the explicit L(F)=G witness.
"""
function proposition2_report(io::IO = stdout; m::Integer = 3, save_results::Bool = false)
    print_section("Proposition 2 — F and G=F+tr(α^… x³) are EA-equivalent", io)
    isodd(m) || throw(ArgumentError("Proposition 2 requires m odd, got $m"))
    n = 2m
    M = primitive_polynomial(n)
    α = 2                                    # generator; primitive for this modulus
    ordα = let o = 1, v = 2
        while v != 1; v = gf_mul(v, 2, n; modulus = M); o += 1; end
        o
    end
    α_primitive = ordα == (1 << n) - 1
    print_kv("n=2m", "$n (m=$m)", io)
    print_kv("α=2 primitive (ord=$(ordα))", α_primitive, io)

    coef1 = gf_pow(α, (1 << m) - 1, n; modulus = M)         # α^{2^m-1}
    e2 = (1 << m) + 1
    e3 = 6 * (1 << m)
    F = SBox{n}([
        gf_pow(x, 6, n; modulus = M) ⊻ gf_pow(x, e2, n; modulus = M) ⊻
        gf_mul(coef1, gf_pow(x, e3, n; modulus = M), n; modulus = M)
        for x = 0:((1 << n) - 1)
    ])
    cg = gf_pow(α, (1 << (m - 1)) + 1, n; modulus = M)      # α^{2^{m-1}+1}
    G = SBox{n}([
        F.lut[x + 1] ⊻ gf_trace(gf_mul(cg, gf_pow(x, 3, n; modulus = M), n; modulus = M), n; modulus = M)
        for x = 0:((1 << n) - 1)
    ])

    duF = differential_uniformity(F)
    duG = differential_uniformity(G)
    print_check("F APN (du=$duF) and G APN (du=$duG)", duF == 2 && duG == 2, io)

    ea = are_ea_equivalent(F, G)
    print_check("F and G are EA-equivalent", ea, io)

    # Explicit witness u = α^{2^{m+1}+1} / (α^{2^m-1}+1), L(x)=x+tr(u x).
    num = gf_pow(α, (1 << (m + 1)) + 1, n; modulus = M)
    den = gf_pow(α, (1 << m) - 1, n; modulus = M) ⊻ 1
    u = gf_mul(num, gf_inv(den, n; modulus = M), n; modulus = M)
    witness = all(
        x -> (F.lut[x + 1] ⊻ gf_trace(gf_mul(u, F.lut[x + 1], n; modulus = M), n; modulus = M)) == G.lut[x + 1],
        0:((1 << n) - 1),
    )
    print_check("explicit witness L(F(x))=G(x), L(x)=x+tr(u·x)", witness, io)
    print_kv("u", u, io)

    all_ok = α_primitive && duF == 2 && duG == 2 && ea && witness
    result = (; n, m, u, ea, witness, all_ok)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "proposition2.toml"), "w") do fh
            println(fh, "# Proposition 2\nn = $n\nm = $m\nu = $u\nea = $ea\nwitness = $witness\nall_ok = $all_ok")
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition2_report()
end
