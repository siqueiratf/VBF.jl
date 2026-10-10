# Implements Proposition 3 — the n-odd APN construction via a superfield.
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218-4229.
# Section: II.B — The case n odd.
#
# Proposition 3: n any, K ⊇ GF(2ⁿ), L extended to K. With K=GF(2^{2n}),
#   E = w + GF(2ⁿ) (w ∈ GF(4)\GF(2)): if F(x)=x+L(x³) is INJECTIVE on E then
#   F(x³)=x³+L(x⁹) is APN over GF(2ⁿ).
#
# Pseudocode:
#   in K=GF(2^{2n}): evaluate G(x)=x+L(x³) (L via its linearised polynomial) on
#   the 2ⁿ elements of E=w+GF(2ⁿ); assert all images distinct (injective);
#   then assert x³+L(x⁹) is APN over GF(2ⁿ).
# VBF API used: gf_pow, subfield_elements, differential_uniformity, algebraic_degree
#
# Note: GF(2^{2n}) needs a primitive polynomial of degree 2n (available ≤ 16),
# so the superfield demo runs at n=3 (class2/class3) and n=5,7 (L=trₙ).

include(joinpath(@__DIR__, "helpers.jl"))

"""
    _L_super(cls, y, n, bign; modulus) -> Int

Evaluate the linearised polynomial of the class-`cls` map L at `y` inside the
superfield GF(2^bign): trₙ → Σ y^{2ⁱ}; class2 → trₙ³(y²+y⁴); class3 → trₙ³(y+y²).
"""
function _L_super(cls::Symbol, y::Integer, n::Integer, bign::Integer; modulus::Integer)
    nn = Int(n)
    acc = 0
    if cls === :trace
        for i = 0:(nn-1)
            acc ⊻= gf_pow(y, 1 << i, bign; modulus)
        end
    else
        z =
            cls === :class2 ?
            gf_pow(y, 2, bign; modulus) ⊻ gf_pow(y, 4, bign; modulus) :
            Int(y) ⊻ gf_pow(y, 2, bign; modulus)
        for i = 0:((nn ÷ 3) - 1)
            acc ⊻= gf_pow(z, 8^i, bign; modulus)      # trₙ³ = Σ z^{8ⁱ}
        end
    end
    acc
end

"""
    injective_on_superfield(cls, n) -> Bool

Whether G(x)=x+L(x³) is injective on E = w+GF(2ⁿ) ⊂ GF(2^{2n}).
"""
function injective_on_superfield(cls::Symbol, n::Integer)
    bign = 2 * Int(n)
    mod = primitive_polynomial(bign)
    w4 = subfield_elements(bign, 2; modulus = mod)         # {0,1,w,w²}
    w = first(a for a in w4 if a != 0 && a != 1)
    Fn = subfield_elements(bign, n; modulus = mod)          # GF(2ⁿ) ⊂ K
    E = [w ⊻ a for a in Fn]
    vals = Set{Int}()
    for x in E
        g = Int(x) ⊻ _L_super(cls, gf_pow(x, 3, bign; modulus = mod), n, bign; modulus = mod)
        g in vals && return false
        push!(vals, g)
    end
    true
end

"""
    proposition3_report(io; save_results) -> NamedTuple

Verify the Prop-3 hypothesis (injectivity on E ⊂ GF(2^{2n})) and its APN
conclusion over GF(2ⁿ), for the paper's examples F₁,F₂ (class2/class3) at n=3.
"""
function proposition3_report(io::IO = stdout; save_results::Bool = false)
    print_section("Proposition 3 — n odd: injective on w+GF(2ⁿ)⊂GF(2^{2n}) ⟹ x³+L(x⁹) APN", io)
    all_ok = true
    rows = Tuple{Symbol,Int,Bool,Int}[]
    # The paper's explicit Prop-3 examples F₁,F₂ (class2/class3) for n odd, 3|n.
    # (class, n, small-field APN builder for x³+L(x⁹))
    cases = [
        (:class2, 3, apn_eq7(3, 1)),     # F₁ = x+trₙ³(x⁶+x¹²)
        (:class3, 3, apn_eq8(3, 1)),     # F₂ = x+trₙ³(x³+x⁶)
    ]
    for (cls, n, apnlut) in cases
        inj = injective_on_superfield(cls, n)
        du = differential_uniformity(as_sbox(apnlut, n))
        ok = inj && du == 2
        all_ok &= ok
        print_check("L=$cls n=$n: injective on E=$inj ⟹ x³+L(x⁹) APN (δ=$du)", ok, io)
        push!(rows, (cls, n, inj, du))
    end
    print_kv(
        "completeness",
        "F₁,F₂ at n=3 only — next odd 3|n is n=9 (needs GF(2¹⁸), degree>16 unavailable)",
        io,
    )
    result = (; all_ok, rows)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "proposition3.toml"), "w") do f
            println(f, "# Proposition 3\nall_ok = $all_ok")
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    proposition3_report()
end
