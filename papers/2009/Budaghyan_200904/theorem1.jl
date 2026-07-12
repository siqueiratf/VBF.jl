# Implements Theorem 1 (new quadratic APN F+f via linear ℓ_a conditions) + Remarks 1,2.
# Paper: Budaghyan, Carlet, Leander (2009), "Constructing new APN functions from
#        known ones", Finite Fields Appl. 15 (2009) 150–159.
# Section: §2 — Construction of new quadratic APN functions
#
# Theorem 1. Let F be quadratic APN and f a quadratic Boolean function, with
#   φ_F(x,a) = F(x)+F(x+a)+F(a)+F(0),  φ_f(x,a) = f(x)+f(x+a)+f(a)+f(0).
# If for every nonzero a there is a linear Boolean ℓ_a with
#   (1) φ_f(x,a) = ℓ_a(φ_F(x,a))  for all x,
#   (2) φ_F(x,a)=1 for some x  ⇒  ℓ_a(1)=0,
# then F(x)+f(x) is APN.
#
# Pseudocode:
#   1. For each nonzero a: compute φ_F(·,a), φ_f(·,a).
#   2. Check (1) φ_f(x,a) == ℓ_a(φ_F(x,a)) ∀x, and (2) ℓ_a(1)=0 when 1 ∈ Im φ_F(·,a).
#   3. Confirm F+f is APN (differential_uniformity == 2).
#   Concrete instance (Corollary 1 proof): F=x³, f=tr(x⁹),
#     ℓ_a(y)=tr(a⁶y + a³y² + a⁻³y⁴).
#   Remark 2 (Dillon): trivial consequence F+ℓ∘F, ℓ(1)=0, is APN & affine-equiv F.
#
# VBF API used: gf_pow, gf_mul, gf_inv, gf_trace, differential_uniformity,
#               algebraic_degree, are_ea_equivalent, gold_apn, SBox

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem1_conditions(F, f_lut, ell; n) -> (cond1, cond2)

Check Theorem 1's two hypotheses on `ℓ_a`. `f_lut` is the 0/1 vector of the
Boolean function `f`; `ell(a, y)` evaluates the linear Boolean form `ℓ_a` at the
field element `y` (returning 0/1). Returns whether (1) and (2) hold for *every*
nonzero `a`.
"""
function theorem1_conditions(F::SBox{N}, f_lut::Vector{Int}, ell; n::Integer = N) where {N}
    len = 1 << N
    cond1 = true
    cond2 = true
    for a = 1:(len - 1)
        φF = phi(F, a)
        # φ_f(x,a) = f(x)+f(x+a)+f(a)+f(0)
        fa = f_lut[a + 1]; f0 = f_lut[1]
        one_in_image = false
        for x = 0:(len - 1)
            φf = f_lut[x + 1] ⊻ f_lut[(x ⊻ a) + 1] ⊻ fa ⊻ f0
            if ell(a, φF[x + 1]) != φf
                cond1 = false
            end
            φF[x + 1] == 1 && (one_in_image = true)
        end
        if one_in_image && ell(a, 1) != 0
            cond2 = false
        end
    end
    (cond1, cond2)
end

"""Concrete ℓ_a for the Gold `x³` / `tr(x⁹)` instance: ℓ_a(y)=tr(a⁶y+a³y²+a⁻³y⁴)."""
function ell_gold_x9(n::Integer; modulus::Integer = primitive_polynomial(n))
    nn = Int(n)
    (a, y) -> begin
        a6 = gf_pow(a, 6, nn; modulus)
        a3 = gf_pow(a, 3, nn; modulus)
        am3 = gf_inv(gf_pow(a, 3, nn; modulus), nn; modulus)
        y2 = gf_pow(y, 2, nn; modulus)
        y4 = gf_pow(y, 4, nn; modulus)
        gf_trace(
            gf_mul(a6, y, nn; modulus) ⊻ gf_mul(a3, y2, nn; modulus) ⊻
            gf_mul(am3, y4, nn; modulus),
            nn; modulus,
        )
    end
end

"""
    theorem1_report(io; n_max, save_results) -> NamedTuple

Reproduce Theorem 1's mechanism on the Gold instance F=x³, f=tr(x⁹) for
n=3..n_max, plus the Remark 2 trivial linear consequence F+ℓ∘F.
"""
function theorem1_report(io::IO = stdout; n_max::Integer = 6, save_results::Bool = false)
    print_section("Theorem 1 — F+f APN via linear ℓ_a conditions", io)
    all_ok = true
    for n = 3:n_max
        F = gold_apn(n, 1)                                   # F = x³ (Gold)
        f_lut = [gf_trace(gf_pow(x, 9, n), n) for x = 0:((1 << n) - 1)]  # f = tr(x⁹)
        c1, c2 = theorem1_conditions(F, f_lut, ell_gold_x9(n); n)
        Ff = apn_x3_tr_x9(n)                                 # F(x)+f(x)
        du = differential_uniformity(Ff)
        ok = c1 && c2 && du == 2
        all_ok &= ok
        print_check("n=$n: cond(1) φ_f=ℓ_a∘φ_F | cond(2) ℓ_a(1)=0 | F+f APN", ok, io)
        print_kv("  n=$n", "cond1=$c1 cond2=$c2 du(F+f)=$du", io)
    end

    print_section("Remark 2 — trivial consequence F+ℓ∘F (ℓ(1)=0) is APN & affine-equiv F", io)
    n = 5
    F = gold_apn(n, 1)
    # ℓ(y)=tr(γy) with tr(γ)=0 ⇒ ℓ(1)=tr(γ)=0; L(x)=x+ℓ(x) is a permutation.
    γ = findfirst(g -> gf_trace(g, n) == 0 && g != 0, 0:((1 << n) - 1))
    γ = γ === nothing ? 0 : γ - 1
    H = SBox{n}([F.lut[x + 1] ⊻ gf_trace(gf_mul(γ, F.lut[x + 1], n), n) for x = 0:((1 << n) - 1)])
    ea = are_ea_equivalent(H, F)
    du = differential_uniformity(H)
    print_kv("γ (tr(γ)=0)", γ, io)
    print_check("F+ℓ∘F is APN", du == 2, io)
    print_check("F+ℓ∘F EA-equivalent to F (Remark 2)", ea, io)
    print_kv("Remark 1", "ker φ_F = {0,a} ⊆ ker φ_f ⇒ ℓ_a always exists (structural)", io)
    all_ok &= (du == 2 && ea)

    result = (; n_max, all_ok)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "theorem1.toml"), "w") do fh
            println(fh, "# Theorem 1")
            println(fh, "n_max = $n_max")
            println(fh, "all_ok = $all_ok")
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem1_report()
end
