# Implements Corollary 2, Propositions 3, 4, 5 (Section IV.B-D)
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: IV.B Lower Bound; IV.C Invariance Properties; IV.D Quadratic Functions
#
# Pseudocode:
#   Prop 3 (CCZ-invariant): Π_F = Π_{F'} (as a multiset) for a CCZ-equivalent pair
#     Genuine CCZ-but-not-EA witness: F' = F⁻¹ (graph swap), which for Gold x³ over
#     F₂⁵ has algebraic degree 3 ≠ 2 = deg F, so it is provably not EA-equivalent.
#     Cross-check: every representative of enumerate_ccz_class(F) shares Π_F.
#   Prop 4 (EA-invariant): |Π_{F'}^β(t)| = |Π_F^{A₂(β)}(A₁⁻¹(t + A(β)))|
#     for F' = A₁ ∘ F ∘ A₂ + A; exercised with a non-trivial A₁ and A.
#   Prop 5 (quadratic): pi_multiset(F,β) = pi_multiset(F,β') for quadratic F
#   Cor 2: d(F,G) ≥ ⌈m_F/3⌉ + 1
# VBF API used: SBox, pi_multiset, sorted_pairs, differential_uniformity,
#               algebraic_degree, compositional_inverse, are_ccz_equivalent,
#               are_ea_equivalent, enumerate_ccz_class, gf_pow, gf_mul,
#               gf_monomial_lut, gold_apn, pi_counts, pi_full_multiset,
#               compute_m_F, lower_bound_distance

include(joinpath(@__DIR__, "helpers.jl"))

"""
    pi_spectrum_union(F) -> Set{Int}

Collect all keys (counts) from pi_multiset(F, β) over all β: the *support* of Π_F.
Weaker than [`pi_full_multiset`](@ref), which keeps the multiplicities.
"""
function pi_spectrum_union(F::SBox{N,T}) where {N,T}
    n = 1 << N
    result = Set{Int}()
    for β = 0:(n-1)
        sp = pi_multiset(F, β)
        for (k, _) in sorted_pairs(sp)
            push!(result, k)
        end
    end
    result
end

"""
    proposition3_ccz_invariance(; io, n) -> NamedTuple

Proposition 3 — the paper's headline claim: Π_F is a **CCZ**-invariant.

Tested on a genuinely CCZ-but-not-EA pair: `F = x³` over `F₂⁵` is a permutation,
so its compositional inverse `F⁻¹ = x²¹` is CCZ-equivalent to it (swap the two
halves of the graph) but has algebraic degree 3 against F's 2 — no EA map can
change the algebraic degree, so the two are EA-inequivalent. An EA-equivalent pair
(what an earlier version of this file used) would only have tested Proposition 4.

The comparison is on the **full multiset** `Π_F = {|Π_F^β(b)| : β,b}` (Prop 3 sends
the pair `(β,t)` to `(L₁(β,t), L₂(β,t))` and `L` is a permutation of `F₂²ⁿ`, so
multiplicities are preserved too), not merely on its support.

Discriminating control: Kasami `x¹⁵` over `F₂⁵` is CCZ-*in*equivalent to `x³` and
has a different Π multiset, so the invariant is not trivially constant.
"""
function proposition3_ccz_invariance(; io::IO = stdout, n::Int = 5)
    F = gold_apn(n, 1)
    Finv = compositional_inverse(F)          # CCZ-equivalent: the graph swap

    print_section("Proposition 3 — CCZ-invariance of Π_F (n=$n)", io)
    print_kv("F", "Gold x³ over F₂^$n (a permutation, deg $(algebraic_degree(F)))", io)
    print_kv("F'", "F⁻¹ (deg $(algebraic_degree(Finv))) — CCZ-equivalent, EA-inequivalent", io)

    ccz_ok = are_ccz_equivalent(F, Finv)
    ea_no = !are_ea_equivalent(F, Finv)
    print_check("are_ccz_equivalent(F, F⁻¹)", ccz_ok, io)
    print_check("NOT are_ea_equivalent(F, F⁻¹) — the pair is CCZ-but-not-EA", ea_no, io)

    ΠF = pi_full_multiset(F)
    ΠFinv = pi_full_multiset(Finv)
    inv_ok = ΠF == ΠFinv
    print_check("Π_F == Π_{F⁻¹} as a full multiset (not just its support)", inv_ok, io)

    # Every EA-class representative of F's CCZ-class carries the same Π_F.
    reps = enumerate_ccz_class(F)
    class_ok = all(pi_full_multiset(r) == ΠF for r in reps)
    print_kv("enumerate_ccz_class(F)", "$(length(reps)) representatives, degrees $(sort(unique(algebraic_degree.(reps))))", io)
    print_check("Π_F constant across the whole CCZ-class", class_ok, io)

    # Control: a CCZ-inequivalent APN function with a different Π.
    K = SBox{n}(gf_monomial_lut(n, 15))      # Kasami x^15, n=5
    sep_ok = !are_ccz_equivalent(F, K) && pi_full_multiset(K) != ΠF
    print_check("control: Π_{x¹⁵} ≠ Π_{x³} and x¹⁵ is CCZ-inequivalent (invariant separates)",
        sep_ok, io)
    print_kv("support(Π_{x³})", sort(collect(Set(ΠF))), io)
    print_kv("support(Π_{x¹⁵})", sort(collect(Set(pi_full_multiset(K)))), io)

    (; all_ok = ccz_ok && ea_no && inv_ok && class_ok && sep_ok, n)
end

"""
    proposition4_ea_invariance(; io, n) -> NamedTuple

Proposition 4: for `F' = A₁ ∘ F ∘ A₂ + A` with `A₁, A₂` affine bijections and `A`
affine,

    |Π_{F'}^β(t)| = |Π_F^{A₂(β)}(A₁⁻¹(t + A(β)))|   for all β, t,

and consequently `Π_{F'}^β = Π_F^{A₂(β)}`.

All three maps are non-trivial here, so the `A₁⁻¹` and the `+ A(β)` are actually
exercised (with `A₁ = id` and `A = 0` — the earlier version — both would drop out):

  * `A₁(x) = x²`   (Frobenius; `A₁⁻¹(y) = y^{2^{n-1}}`)
  * `A₂(x) = x² ⊕ c`, `c = 7`
  * `A(x)  = 3·x`  (multiplication in GF(2ⁿ): F₂-linear)

Checked at **every** `(β, t)` pair, not a sample.
"""
function proposition4_ea_invariance(; io::IO = stdout, n::Int = 5)
    F = gold_apn(n, 1)
    sz = 1 << n
    mod = primitive_polynomial(n)
    c = 7
    λ = 3

    A1(x) = gf_pow(x, 2, n; modulus = mod)
    A1inv(y) = gf_pow(y, 1 << (n - 1), n; modulus = mod)   # inverse Frobenius
    A2(x) = gf_pow(x, 2, n; modulus = mod) ⊻ c
    A(x) = gf_mul(λ, x, n; modulus = mod)

    Fp = SBox{n}([A1(Int(F.lut[A2(x)+1])) ⊻ A(x) for x = 0:(sz-1)])

    print_section("Proposition 4 — EA-invariance of Π_F^β (n=$n)", io)
    print_kv("F'", "A₁∘F∘A₂ + A with A₁(x)=x², A₂(x)=x²⊕$c, A(x)=$λ·x", io)
    ea_ok = are_ea_equivalent(F, Fp) && differential_uniformity(Fp) == 2 && Fp.lut != F.lut
    print_check("F' is APN, EA-equivalent to F, and F' ≠ F", ea_ok, io)

    cntF = [pi_counts(F, β) for β = 0:(sz-1)]
    cntFp = [pi_counts(Fp, β) for β = 0:(sz-1)]

    mismatches = 0
    for β = 0:(sz-1), t = 0:(sz-1)
        lhs = cntFp[β+1][t+1]
        rhs = cntF[A2(β)+1][A1inv(t ⊻ A(β))+1]
        lhs == rhs || (mismatches += 1)
    end
    pointwise_ok = mismatches == 0
    print_check("|Π_{F'}^β(t)| = |Π_F^{A₂(β)}(A₁⁻¹(t+A(β)))| on all $(sz * sz) (β,t) pairs",
        pointwise_ok, io)

    # The A(β) term is load-bearing: dropping it breaks the identity.
    drop_A = count(cntFp[β+1][t+1] != cntF[A2(β)+1][A1inv(t)+1]
                   for β = 0:(sz-1), t = 0:(sz-1))
    print_kv("sanity: mismatches if the +A(β) term is dropped", "$drop_A / $(sz * sz)", io)

    spectrum_ok = all(pi_multiset(Fp, β) == pi_multiset(F, A2(β)) for β = 0:(sz-1))
    print_check("Π_{F'}^β == Π_F^{A₂(β)} for all β (the Proposition's corollary)",
        spectrum_ok, io)

    all_ok = ea_ok && pointwise_ok && spectrum_ok && drop_A > 0
    (; all_ok, n, mismatches)
end

"""
    proposition5_quadratic(; io, n_values) -> NamedTuple

Proposition 5: for quadratic F, Π_F^β is the same for all β.
Verified by checking pi_multiset(F, β) == pi_multiset(F, 0) for all β.
"""
function proposition5_quadratic(; io::IO = stdout, n_values::Vector{Int} = [5, 6])
    print_section("Proposition 5 — Quadratic: Π_F^β shift-independent", io)
    all_ok = true
    for n in n_values
        F = gold_apn(n, 1)
        sz = 1 << n
        sp0 = pi_multiset(F, 0)
        mismatches = 0
        for β = 1:(sz-1)
            pi_multiset(F, β) == sp0 || (mismatches += 1)
        end
        ok = mismatches == 0
        all_ok &= ok
        print_check("Gold x^3 n=$n: Π_F^β constant over all β (mismatches=$mismatches)", ok, io)
    end
    (; all_ok)
end

"""
    corollary2_lower_bounds(; io, n_values) -> NamedTuple

Corollary 2: lower bound d(F,G) ≥ ⌈m_F/3⌉ + 1 for Gold x^3.
Computes m_F and the bound for each n.
"""
function corollary2_lower_bounds(; io::IO = stdout, n_values::Vector{Int} = [3, 4, 5, 6])
    # Expected from Table I
    expected_m = Dict(3 => 3, 4 => 3, 5 => 15, 6 => 27, 7 => 63, 8 => 111)
    expected_bound = Dict(3 => 2, 4 => 2, 5 => 6, 6 => 10, 7 => 22, 8 => 38)

    print_section("Corollary 2 — Lower bounds on APN distance for Gold x^3", io)
    all_ok = true
    for n in n_values
        F = gold_apn(n, 1)
        mF = compute_m_F(F)
        bd = lower_bound_distance(mF)
        exp_m = get(expected_m, n, nothing)
        exp_bd = get(expected_bound, n, nothing)
        ok = (exp_m === nothing || mF == exp_m) && (exp_bd === nothing || bd == exp_bd)
        all_ok &= ok
        print_kv("  n=$n: m_F=$mF, bound=$bd" * (exp_m !== nothing ? " (expected m=$exp_m, bound=$exp_bd)" : ""), ok ? "✓" : "✗", io)
        print_check("n=$n: m_F and bound match Table I", ok, io)
    end
    (; all_ok)
end

function corollary2_report(; io::IO = stdout)
    print_header(io)
    r3 = proposition3_ccz_invariance(; io, n = 5)
    r4 = proposition4_ea_invariance(; io, n = 5)
    r5 = proposition5_quadratic(; io, n_values = [5, 6])
    rc = corollary2_lower_bounds(; io, n_values = [3, 4, 5, 6])
    return (; r3, r4, r5, rc)
end

if abspath(PROGRAM_FILE) == @__FILE__
    corollary2_report()
end
