# Implements Corollary 2 (two APN functions from Theorem 2, EA-equivalent to Gold).
# Paper: Budaghyan, Carlet, Leander (2009), "Constructing new APN functions from
#        known ones", Finite Fields Appl. 15 (2009) 150–159.
# Section: §2 — Corollary 2
#
# n=2m, m even. With tr_{n/m}(x)=x+x^{2^m}:
#   F(x)  = x³ + tr_{n/m}(x^{2^m+2}) = x³ + x^{2^m+2} + x^{2^{m+1}+1}
#   F'(x) = x³ + (tr_{n/m}(x))³
# are APN, but EA-equivalent to the Gold power G(x)=x^{2^{m-1}+1}:
#   with γ∈F_4\F_2, L1(x)=γ² x^{2^{m+1}} + γ x², L2(x)=γ x^{2^m} + γ² x,
#   G(L1(x)) = L2(F(x)); and F'(x) = (F(x))^{2^m}.
#
# Pseudocode:
#   1. Build F, F' at n=4 (m=2) and n=8 (m=4); check du==2.
#   2. Verify F' = (F)^{2^m} pointwise.
#   3. Verify the Gold witness G∘L1 = L2∘F at n=4.
#
# VBF API used: gf_pow, gf_mul, gf_relative_trace, in_subfield,
#               differential_uniformity, SBox

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem2.jl"))     # reuse x3_plus_reltrace

"""Build F'(x) = x³ + (tr_{n/m}(x))³."""
function x3_plus_reltrace_cubed(n::Integer, m::Integer; modulus::Integer = primitive_polynomial(n))
    nn = Int(n)
    SBox{nn}([
        gf_pow(x, 3, nn; modulus) ⊻ gf_pow(gf_relative_trace(x, nn, m; modulus), 3, nn; modulus)
        for x = 0:((1 << nn) - 1)
    ])
end

"""
    corollary2_report(io; save_results) -> NamedTuple

Verify the two Corollary 2 functions are APN, that F'=(F)^{2^m}, and the Gold
witness G∘L1=L2∘F (n=4). These are APN but EA-equivalent to a power function.
"""
function corollary2_report(io::IO = stdout; save_results::Bool = false)
    print_section("Corollary 2 — F, F' APN but EA-equivalent to Gold power", io)
    rows = NamedTuple[]
    all_ok = true
    for (m, n) in ((2, 4), (4, 8))
        M = primitive_polynomial(n)
        F = x3_plus_reltrace(n, m; modulus = M)
        Fp = x3_plus_reltrace_cubed(n, m; modulus = M)
        duF = differential_uniformity(F)
        duFp = differential_uniformity(Fp)
        # F'(x) = (F(x))^{2^m}
        frob = all(x -> Fp.lut[x + 1] == gf_pow(F.lut[x + 1], 1 << m, n; modulus = M), 0:((1 << n) - 1))
        ok = duF == 2 && duFp == 2 && frob
        all_ok &= ok
        push!(rows, (; n, m, duF, duFp, frob))
        print_check("m=$m,n=$n: F,F' APN (du=$duF,$duFp) and F'=(F)^{2^$m}", ok, io)
    end

    # Gold witness at n=4 (m=2): γ∈F_4\F_2, G(x)=x^{2^{m-1}+1}=x^3.
    m = 2; n = 4; M = primitive_polynomial(n)
    γ = findfirst(x -> in_subfield(x, 2, n; modulus = M) && x > 1, 0:((1 << n) - 1))
    γ = γ === nothing ? 0 : γ - 1
    γ2 = gf_mul(γ, γ, n; modulus = M)
    F = x3_plus_reltrace(n, m; modulus = M)
    L1(x) = gf_mul(γ2, gf_pow(x, 1 << (m + 1), n; modulus = M), n; modulus = M) ⊻
            gf_mul(γ, gf_pow(x, 2, n; modulus = M), n; modulus = M)
    L2(x) = gf_mul(γ, gf_pow(x, 1 << m, n; modulus = M), n; modulus = M) ⊻
            gf_mul(γ2, x, n; modulus = M)
    Gexp = (1 << (m - 1)) + 1                 # = 3
    witness = all(
        x -> gf_pow(L1(x), Gexp, n; modulus = M) == L2(F.lut[x + 1]),
        0:((1 << n) - 1),
    )
    print_check("Gold witness G∘L1 = L2∘F at n=4 (γ∈F₄\\F₂)", witness, io)
    print_kv("γ", γ, io)
    all_ok &= witness

    result = (; rows, γ, witness, all_ok)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "corollary2.toml"), "w") do fh
            println(fh, "# Corollary 2\nwitness = $witness\nall_ok = $all_ok")
            for r in rows
                println(fh, "[[row]]\nn = $(r.n)\nm = $(r.m)\nduF = $(r.duF)\nduFp = $(r.duFp)")
            end
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    corollary2_report()
end
