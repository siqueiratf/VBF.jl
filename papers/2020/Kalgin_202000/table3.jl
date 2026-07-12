# Implements §6 — Using quadratic functions to search for APN functions of
# higher algebraic degree (Table 3 examples: stacked APN functions).
# Paper: Kalgin, Idrisova (2020), "The classification of quadratic APN functions
#        in 7 variables", Cryptography and Communications 14, pp. 691–715.
# Section: §6.1 — Definition 1 (stacked APN), Table 3 examples.
#
# Pseudocode:
#   1. Definition 1: F = F^{(2)} + ... + F^{(d)} is stacked APN iff
#      F - F^{(d)}, F - F^{(d)} - F^{(d-1)}, ..., F^{(2)} are all APN.
#   2. For d=3: F is stacked APN iff both F and F^{(2)} are APN.
#   3. Table 3 gives examples for n=4,5,6: verify F is APN (deg 3),
#      F^{(2)} is APN (deg 2), and F ≠ F^{(2)}.
#
# VBF API used: SBox, differential_uniformity, algebraic_degree, quadratic_part (helpers)

include(joinpath(@__DIR__, "helpers.jl"))

# ── Table 3 data ─────────────────────────────────────────────────────────────

"""
    stacked_n4() -> SBox{4}

Table 3 n=4 example: cubic stacked APN function F (deg 3).
"""
stacked_n4() = SBox{4}([0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 6, 3, 8, 14, 11, 12])

"""
    stacked_n4_quadpart() -> SBox{4}

Table 3 n=4 example: quadratic part F^{(2)} (deg 2, APN).
"""
stacked_n4_quadpart() = SBox{4}([0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 6, 3, 8, 14, 10, 13])

"""
    stacked_n5() -> SBox{5}

Table 3 n=5 example: cubic stacked APN function F (deg 3).
"""
stacked_n5() = SBox{5}([
    0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 10, 15, 19, 21, 28, 27,
    0, 8, 16, 25, 11, 1, 29, 22, 15, 3, 17, 28, 31, 17, 6, 9,
])

"""
    stacked_n5_quadpart() -> SBox{5}

Table 3 n=5 example: quadratic part F^{(2)} (deg 2, APN).
"""
stacked_n5_quadpart() = SBox{5}([
    0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 10, 15, 19, 21, 29, 26,
    0, 8, 16, 25, 11, 1, 31, 20, 15, 3, 21, 24, 23, 25, 9, 6,
])

"""
    stacked_n6() -> SBox{6}

Table 3 n=6 example: cubic stacked APN function F (deg 3).
"""
stacked_n6() = SBox{6}([
    0, 0, 0, 1, 0, 2, 4, 13, 0, 4, 8, 7, 16, 22, 28, 27,
    0, 8, 16, 19, 9, 3, 29, 22, 45, 33, 53, 56, 52, 58, 40, 45,
    0, 16, 60, 45, 26, 8, 34, 59, 55, 35, 3, 28, 61, 43, 13, 26,
    5, 29, 41, 58, 22, 12, 62, 37, 31, 3, 59, 38, 28, 2, 60, 41,
])

"""
    stacked_n6_quadpart() -> SBox{6}

Table 3 n=6 example: quadratic part F^{(2)} (deg 2, APN).
"""
stacked_n6_quadpart() = SBox{6}([
    0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 8, 13, 16, 22, 28, 27,
    0, 8, 16, 25, 9, 3, 29, 22, 45, 33, 53, 56, 52, 58, 40, 39,
    0, 16, 60, 45, 26, 8, 34, 49, 55, 35, 3, 22, 61, 43, 13, 26,
    5, 29, 41, 48, 22, 12, 62, 37, 31, 3, 59, 38, 28, 2, 60, 35,
])

# ── §6.1 — quadratic parts of non-quadratic APN functions ────────────────────

"""
    quadratic_part_claims_6_1() -> Vector{NamedTuple}

§6.1's three explicit claims about the quadratic part of *non-quadratic* APN
functions ("For the Dillon APN permutation P of F₂⁶ the value Δ_{P⁽²⁾} is equal to
8. When n = 8, 9 there also exist APN functions F (e.g. the Kasami power functions
for n = 8 and the inverse function for n = 9) such that Δ_{F⁽²⁾} = 8.")

Each entry gives the function, its own (Δ, deg), and the (Δ, deg) of `F⁽²⁾`.
Note `Δ(F⁽²⁾)` is well defined independently of the field representation: a change
of GF(2ⁿ) basis is a linear change of coordinates, and linear maps preserve the
degree-2 homogeneous part (`(L∘F∘L')⁽²⁾ = L∘F⁽²⁾∘L'`).

The Kasami exponent for n = 8 needs `gcd(k, 8) = 1`, so `k = 3` (d = 57); VBF's
default `k = 2` is invalid there.
"""
function quadratic_part_claims_6_1()
    out = NamedTuple[]
    for (label, F, expected) in (
        ("Dillon APN permutation (n=6)", dillon_apn_permutation(), 8),
        ("Kasami x^57 (n=8)", kasami_apn(8, 3), 8),
        ("Inverse x^510 (n=9)", inverse_apn(9), 8),
    )
        Q = quadratic_part(F)
        push!(
            out,
            (;
                label = label,
                du_F = differential_uniformity(F),
                deg_F = algebraic_degree(F),
                du_Q = differential_uniformity(Q),
                deg_Q = algebraic_degree(Q),
                expected_du_Q = expected,
            ),
        )
    end
    out
end

# ── §6.2 — explicit n=6 example C = F + h·e₁ ─────────────────────────────────

"""
    switching_example_n6() -> SBox{6}

§6.2's explicit n=6 function `C = F + h·e₁`, where `F` is APN and `h` is a
homogeneous cubic with a single ANF term (here `x₂x₃x₅`, riding on `c₁`):

    c₁ = x₁x₂ + x₄x₆ + x₅x₆ + x₂x₃x₅
    c₂ = x₁x₃ + x₃x₅ + x₄x₅ + x₂x₆ + x₅x₆
    c₃ = x₂x₃ + x₁x₄ + x₄x₅ + x₅x₆
    c₄ = x₂x₄ + x₁x₅ + x₃x₅ + x₂x₆ + x₃x₆ + x₄x₆ + x₅x₆
    c₅ = x₃x₄ + x₂x₅ + x₃x₅ + x₄x₅ + x₁x₆ + x₂x₆ + x₃x₆ + x₅x₆
    c₆ = x₃x₅ + x₂x₆ + x₅x₆

Convention (matching VBF's QAM/`qam_to_sbox`): `xᵢ` is bit `i-1` of the input,
`c_k` is bit `k-1` of the output. The paper's claim is that `C` is a *cubic* APN
function whose quadratic part is again APN — i.e. another stacked cubic APN,
obtained by the switching method rather than from Table 3.
"""
function switching_example_n6()
    lut = zeros(Int, 64)
    @inbounds for X = 0:63
        x = ntuple(i -> (X >> (i - 1)) & 1, 6)
        c1 = x[1] * x[2] ⊻ x[4] * x[6] ⊻ x[5] * x[6] ⊻ x[2] * x[3] * x[5]
        c2 = x[1] * x[3] ⊻ x[3] * x[5] ⊻ x[4] * x[5] ⊻ x[2] * x[6] ⊻ x[5] * x[6]
        c3 = x[2] * x[3] ⊻ x[1] * x[4] ⊻ x[4] * x[5] ⊻ x[5] * x[6]
        c4 =
            x[2] * x[4] ⊻ x[1] * x[5] ⊻ x[3] * x[5] ⊻ x[2] * x[6] ⊻ x[3] * x[6] ⊻
            x[4] * x[6] ⊻ x[5] * x[6]
        c5 =
            x[3] * x[4] ⊻ x[2] * x[5] ⊻ x[3] * x[5] ⊻ x[4] * x[5] ⊻ x[1] * x[6] ⊻
            x[2] * x[6] ⊻ x[3] * x[6] ⊻ x[5] * x[6]
        c6 = x[3] * x[5] ⊻ x[2] * x[6] ⊻ x[5] * x[6]
        lut[X+1] = c1 | (c2 << 1) | (c3 << 2) | (c4 << 3) | (c5 << 4) | (c6 << 5)
    end
    SBox{6}(lut)
end

# ── Verification ─────────────────────────────────────────────────────────────

"""
    verify_stacked_cubic(F, F2, io; label) -> NamedTuple

Verify the stacked APN property for a cubic APN F and its quadratic part F^{(2)}:
- F is APN (differential_uniformity = 2)
- F has algebraic_degree = 3
- F^{(2)} is APN
- F^{(2)} has algebraic_degree = 2
- quadratic_part(F) == F2 (matches the provided quadratic part)
- F ≠ F^{(2)} (they differ somewhere)
"""
function verify_stacked_cubic(F::SBox{N}, F2_ref::SBox{N}, io::IO = stdout; label::String = "") where N
    tag = isempty(label) ? "" : " ($label)"
    du_F  = differential_uniformity(F)
    deg_F = algebraic_degree(F)
    du_F2 = differential_uniformity(F2_ref)
    deg_F2 = algebraic_degree(F2_ref)
    F2_computed = quadratic_part(F)
    F2_match = F2_computed == F2_ref
    not_equal = F != F2_ref

    print_check("F$tag: APN (du=2)", du_F == 2, io)
    print_check("F$tag: cubic (deg=3)", deg_F == 3, io)
    print_check("F^(2)$tag: APN (du=2)", du_F2 == 2, io)
    print_check("F^(2)$tag: quadratic (deg=2)", deg_F2 == 2, io)
    print_check("quadratic_part(F)$tag == F^(2) from paper", F2_match, io)
    print_check("F$tag ≠ F^(2)$tag", not_equal, io)

    (;
        du_F, deg_F, du_F2, deg_F2,
        F2_match, not_equal,
        ok = du_F == 2 && deg_F == 3 && du_F2 == 2 && deg_F2 == 2 && F2_match && not_equal,
    )
end

# ── Section report ───────────────────────────────────────────────────────────

"""
    table3_report(io; save_results) -> NamedTuple

§6 Table 3 reproduction: verify all three stacked APN examples.
"""
function table3_report(io::IO = stdout; save_results::Bool = false) :: NamedTuple
    print_section("§6 — Stacked APN functions (Table 3)", io)

    print_kv(
        "Definition 1 (stacked APN)",
        "F = F^{(2)}+...+F^{(d)} is stacked APN iff all truncations are APN",
        io,
    )
    print_kv("Table 3 scope", "cubic stacked APN (d=3): both F and F^{(2)} are APN", io)

    print_section("n=4 example", io)
    r4 = verify_stacked_cubic(stacked_n4(), stacked_n4_quadpart(), io; label = "n=4")

    print_section("n=5 example", io)
    r5 = verify_stacked_cubic(stacked_n5(), stacked_n5_quadpart(), io; label = "n=5")

    print_section("n=6 example", io)
    r6 = verify_stacked_cubic(stacked_n6(), stacked_n6_quadpart(), io; label = "n=6")

    # §6.1 — quadratic parts of non-quadratic APN functions
    print_section("§6.1 — Δ of the quadratic part of non-quadratic APN functions", io)
    claims = quadratic_part_claims_6_1()
    q61_ok = true
    for c in claims
        print_kv(c.label, "Δ_F=$(c.du_F), deg F=$(c.deg_F) → Δ_F⁽²⁾=$(c.du_Q), deg F⁽²⁾=$(c.deg_Q)", io)
        ok = c.du_F == 2 && c.deg_F > 2 && c.du_Q == c.expected_du_Q && c.deg_Q == 2
        q61_ok &= ok
        print_check("  $(c.label): APN, non-quadratic, Δ(F⁽²⁾) = $(c.expected_du_Q)", ok, io)
    end
    # Proposition 4: every APN F on F_2^4 has Δ_{F^(2)} <= 4 (spot-checked here;
    # the paper states it from an exhaustive computation).
    p4_ok = differential_uniformity(quadratic_part(gold_apn(4))) <= 4 &&
            differential_uniformity(quadratic_part(stacked_n4())) <= 4
    print_check("Proposition 4 (spot-check): Δ(F⁽²⁾) ≤ 4 for n=4 APN examples", p4_ok, io)

    # §6.2 — the explicit n=6 switching example C = F + h·e_1
    print_section("§6.2 — explicit n=6 example C = F + h·e₁ (h a single cubic term)", io)
    C = switching_example_n6()
    CQ = quadratic_part(C)
    du_C, deg_C = differential_uniformity(C), algebraic_degree(C)
    du_CQ, deg_CQ = differential_uniformity(CQ), algebraic_degree(CQ)
    print_kv("C", "Δ=$(du_C), deg=$(deg_C)", io)
    print_kv("C⁽²⁾", "Δ=$(du_CQ), deg=$(deg_CQ)", io)
    c62_ok = du_C == 2 && deg_C == 3 && du_CQ == 2 && deg_CQ == 2
    print_check("§6.2 example: C is a cubic APN whose quadratic part is APN " *
                "(i.e. a stacked cubic APN obtained by switching)", c62_ok, io)

    print_section("Summary", io)
    all_ok = r4.ok && r5.ok && r6.ok && q61_ok && p4_ok && c62_ok
    print_check("all three Table 3 examples verified as stacked cubic APN",
                r4.ok && r5.ok && r6.ok, io)
    print_check("§6.1 and §6.2 claims verified", q61_ok && p4_ok && c62_ok, io)

    result = (;
        n4_ok = r4.ok,
        n5_ok = r5.ok,
        n6_ok = r6.ok,
        sec61_ok = q61_ok,
        prop4_ok = p4_ok,
        sec62_ok = c62_ok,
        all_ok,
    )

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "table3.toml"), "w") do f
            println(f, "# table3 results")
            for (k, v) in pairs(result)
                println(f, "$k = $v")
            end
        end
    end

    result
end
