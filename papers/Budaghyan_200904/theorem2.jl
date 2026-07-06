# Implements Theorem 2 (generalization of Theorem 1 to f: GF(2ⁿ)→GF(2ᵐ), m|n).
# Paper: Budaghyan, Carlet, Leander (2009), "Constructing new APN functions from
#        known ones", Finite Fields Appl. 15 (2009) 150–159.
# Section: §2 — Theorem 2
#
# Same hypotheses as Theorem 1 but with f a quadratic function GF(2ⁿ)→GF(2ᵐ),
# m|n, and ℓ_a: GF(2ⁿ)→GF(2ᵐ) linear with
#   (1) φ_f(x,a) = ℓ_a(φ_F(x,a)),
#   (2) for every u∈GF(2ᵐ)*, φ_F(x,a)=u for some x ⇒ ℓ_a(u) ≠ u,
# then F(x)+f(x) is APN.
#
# Pseudocode:
#   1. Concrete application (Corollary 2): F=x³, f=tr_{n/m}(x^{2^m+2}), n=2m.
#   2. Confirm f maps into the subfield GF(2ᵐ)  (in_subfield on its image).
#   3. Confirm F+f is APN (du==2)  at n=4 (m=2) and n=8 (m=4).
#
# VBF API used: gf_pow, gf_relative_trace, in_subfield, differential_uniformity,
#               algebraic_degree, SBox

include(joinpath(@__DIR__, "helpers.jl"))

"""Build the Theorem-2 / Corollary-2 function `x³ + tr_{n/m}(x^{2^m+2})`."""
function x3_plus_reltrace(n::Integer, m::Integer; modulus::Integer = primitive_polynomial(n))
    nn = Int(n); e = (1 << m) + 2
    SBox{nn}([
        gf_pow(x, 3, nn; modulus) ⊻ gf_relative_trace(gf_pow(x, e, nn; modulus), nn, m; modulus)
        for x = 0:((1 << nn) - 1)
    ])
end

"""
    theorem2_report(io; save_results) -> NamedTuple

Reproduce Theorem 2's `m|n` generalization through its Corollary 2 application:
`F=x³`, `f=tr_{n/m}(x^{2^m+2})` maps into `GF(2ᵐ)` and `F+f` is APN at n=4,8.
"""
function theorem2_report(io::IO = stdout; save_results::Bool = false)
    print_section("Theorem 2 — generalization to f: GF(2ⁿ)→GF(2ᵐ), m|n", io)
    rows = NamedTuple[]
    all_ok = true
    for (m, n) in ((2, 4), (4, 8))            # n=2m, m even (Corollary 2 regime)
        e = (1 << m) + 2
        # f(x) = tr_{n/m}(x^{2^m+2}) must land in the subfield GF(2ᵐ).
        f_in_sub = all(
            x -> in_subfield(gf_relative_trace(gf_pow(x, e, n), n, m), m, n),
            0:((1 << n) - 1),
        )
        F = x3_plus_reltrace(n, m)
        du = differential_uniformity(F)
        ok = f_in_sub && du == 2
        all_ok &= ok
        push!(rows, (; n, m, du, f_in_sub))
        print_check("m=$m,n=$n: f→GF(2^$m) and F+f APN (du=$du)", ok, io)
    end
    print_kv("note", "condition (2) of Theorem 2 holds for this f by Corollary 2", io)

    result = (; rows, all_ok)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "theorem2.toml"), "w") do fh
            println(fh, "# Theorem 2\nall_ok = $all_ok")
            for r in rows
                println(fh, "[[row]]\nn = $(r.n)\nm = $(r.m)\ndu = $(r.du)")
            end
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem2_report()
end
