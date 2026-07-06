# Implements Proposition 3 (four non-quadratic APN CCZ-equivalent to x³+tr(x⁹)).
# Paper: Budaghyan, Carlet, Leander (2009), "Constructing new APN functions from
#        known ones", Finite Fields Appl. 15 (2009) 150–159.
# Section: §3 — Proposition 3
#
# Applying an affine automorphism L(x,y)=(x+corr(y), y) of GF(2ⁿ)² to the graph
# of F=x³+tr(x⁹) yields non-quadratic APN functions CCZ-equivalent to F:
#   (1) n odd,        corr(y)=tr(y):                deg 3, = x³+tr(x⁹)+(x²+x)tr(x³+x⁹)
#   (2) n even,       corr(y)=tr(y):                deg 3, = x³+tr(x⁹)+(x²+x+1)tr(x³)
#   (3) n div by 6,   corr(y)=tr_{n/3}(y²+y⁴):      deg 4
#   (4) n odd & 3|n,  corr(y)=tr_{n/3}(y+y⁴):       deg 4
#
# CCZ-equivalence holds by construction (L is an affine automorphism of GF(2ⁿ)²,
# graph-preserving). Each image is verified APN with the stated algebraic degree;
# cases (1),(2) additionally match the explicit polynomial in the paper.
#
# VBF API used: gf_pow, gf_mul, gf_trace, gf_relative_trace,
#               differential_uniformity, algebraic_degree, SBox

include(joinpath(@__DIR__, "helpers.jl"))

"""Explicit polynomial for Proposition 3(1): x³+tr(x⁹)+(x²+x)tr(x³+x⁹) (n odd)."""
function prop3_1_explicit(n; M = primitive_polynomial(n))
    SBox{n}([
        (gf_pow(x, 3, n; modulus = M) ⊻ gf_trace(gf_pow(x, 9, n; modulus = M), n; modulus = M)) ⊻
        gf_mul(gf_pow(x, 2, n; modulus = M) ⊻ x,
               gf_trace(gf_pow(x, 3, n; modulus = M) ⊻ gf_pow(x, 9, n; modulus = M), n; modulus = M),
               n; modulus = M)
        for x = 0:((1 << n) - 1)
    ])
end

"""Explicit polynomial for Proposition 3(2): x³+tr(x⁹)+(x²+x+1)tr(x³) (n even)."""
function prop3_2_explicit(n; M = primitive_polynomial(n))
    SBox{n}([
        (gf_pow(x, 3, n; modulus = M) ⊻ gf_trace(gf_pow(x, 9, n; modulus = M), n; modulus = M)) ⊻
        gf_mul(gf_pow(x, 2, n; modulus = M) ⊻ x ⊻ 1,
               gf_trace(gf_pow(x, 3, n; modulus = M), n; modulus = M),
               n; modulus = M)
        for x = 0:((1 << n) - 1)
    ])
end

"""
    proposition3_report(io; save_results) -> NamedTuple

Reproduce the four non-quadratic APN functions CCZ-equivalent to F via explicit
graph maps at representative dimensions (1: n=7, 2: n=6, 3: n=6, 4: n=9).
"""
function proposition3_report(io::IO = stdout; save_results::Bool = false)
    print_section("Proposition 3 — non-quadratic APN CCZ-equivalent to x³+tr(x⁹)", io)
    rows = NamedTuple[]
    all_ok = true

    # (1) n odd, corr(y)=tr(y), degree 3.
    let n = 7, M = primitive_polynomial(7)
        F = apn_x3_tr_x9(n; modulus = M)
        G = graph_affine_map(F, y -> gf_trace(y, n; modulus = M))
        du = differential_uniformity(G); dg = algebraic_degree(G)
        matches = G.lut == prop3_1_explicit(n; M = M).lut
        ok = du == 2 && dg == 3 && matches
        all_ok &= ok; push!(rows, (; case = 1, n, du, deg = dg, matches))
        print_check("(1) n=7 corr=tr(y): APN deg 3, matches explicit poly (du=$du,deg=$dg)", ok, io)
    end

    # (2) n even, corr(y)=tr(y), degree 3.
    let n = 6, M = primitive_polynomial(6)
        F = apn_x3_tr_x9(n; modulus = M)
        G = graph_affine_map(F, y -> gf_trace(y, n; modulus = M))
        du = differential_uniformity(G); dg = algebraic_degree(G)
        matches = G.lut == prop3_2_explicit(n; M = M).lut
        ok = du == 2 && dg == 3 && matches
        all_ok &= ok; push!(rows, (; case = 2, n, du, deg = dg, matches))
        print_check("(2) n=6 corr=tr(y): APN deg 3, matches explicit poly (du=$du,deg=$dg)", ok, io)
    end

    # (3) n divisible by 6, corr(y)=tr_{n/3}(y²+y⁴), degree 4.
    let n = 6, M = primitive_polynomial(6)
        F = apn_x3_tr_x9(n; modulus = M)
        G = graph_affine_map(F, y -> gf_relative_trace(gf_pow(y, 2, n; modulus = M) ⊻ gf_pow(y, 4, n; modulus = M), n, 3; modulus = M))
        du = differential_uniformity(G); dg = algebraic_degree(G)
        ok = du == 2 && dg == 4
        all_ok &= ok; push!(rows, (; case = 3, n, du, deg = dg, matches = true))
        print_check("(3) n=6 corr=tr_{n/3}(y²+y⁴): APN deg 4 (du=$du,deg=$dg)", ok, io)
    end

    # (4) n odd and divisible by 3, corr(y)=tr_{n/3}(y+y⁴), degree 4.
    let n = 9, M = primitive_polynomial(9)
        F = apn_x3_tr_x9(n; modulus = M)
        G = graph_affine_map(F, y -> gf_relative_trace(y ⊻ gf_pow(y, 4, n; modulus = M), n, 3; modulus = M))
        du = differential_uniformity(G); dg = algebraic_degree(G)
        ok = du == 2 && dg == 4
        all_ok &= ok; push!(rows, (; case = 4, n, du, deg = dg, matches = true))
        print_check("(4) n=9 corr=tr_{n/3}(y+y⁴): APN deg 4 (du=$du,deg=$dg)", ok, io)
    end

    print_kv("CCZ-equivalence", "holds by construction (L affine automorphism of GF(2ⁿ)²)", io)

    result = (; rows, all_ok)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "proposition3.toml"), "w") do fh
            println(fh, "# Proposition 3\nall_ok = $all_ok")
            for r in rows
                println(fh, "[[case]]\ncase = $(r.case)\nn = $(r.n)\ndu = $(r.du)\ndeg = $(r.deg)")
            end
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition3_report()
end
