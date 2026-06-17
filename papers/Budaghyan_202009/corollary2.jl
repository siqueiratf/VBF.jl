# Implements Corollary 2, Propositions 3, 4, 5 (Section IV.B-D)
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: IV.B Lower Bound; IV.C Invariance Properties; IV.D Quadratic Functions
#
# Pseudocode:
#   Prop 3 (CCZ-invariant): Π_F = Π_{F'} for CCZ-equiv pair
#     Build F' EA-equiv to F; collect all pi_multiset keys across β
#   Prop 4 (EA-invariant): |Π_{F'}^β(t)| = |Π_F^{A₂(β)}(·)|
#     F'(x) = F(x⊕c) ⊕ d (shift by c), so A₂(β) = β⊕c
#     Check Π_{F'}^β == Π_F^{β⊕c}
#   Prop 5 (quadratic): pi_multiset(F,β) = pi_multiset(F,β') for quadratic F
#   Cor 2: d(F,G) ≥ ⌈m_F/3⌉ + 1
# VBF API used: SBox, pi_multiset, sorted_pairs, differential_uniformity,
#               are_ea_equivalent, compute_m_F, lower_bound_distance

include(joinpath(@__DIR__, "helpers.jl"))

"""
    pi_spectrum_union(F) -> Set{Int}

Collect all keys (counts) from pi_multiset(F, β) over all β.
This is the multiset Π_F restricted to its support values.
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

Proposition 3: Π_F is CCZ-invariant. Tested via an EA-equivalent pair
(EA-equivalence implies CCZ-equivalence), comparing Π_F and Π_{F'}.
"""
function proposition3_ccz_invariance(; io::IO = stdout, n::Int = 5)
    F = gold_x3(n)
    sz = 1 << n
    # EA-equiv: F'(x) = F(x ⊕ 3) ⊕ 5 (affine output shift)
    c2 = 3
    d = 5
    lut = UInt8[F.lut[(x ⊻ c2)+1] ⊻ UInt8(d) for x = 0:(sz-1)]
    Fp = SBox{n,UInt8}(lut)

    print_section("Proposition 3 — CCZ-invariance of Π_F (n=$n)", io)
    print_kv("F", "Gold x^3 over F₂^$n", io)
    print_kv("F'(x)", "F(x⊕$c2) ⊕ $d  (EA-equivalent to F)", io)

    ea_ok = are_ea_equivalent(F, Fp)
    print_check("are_ea_equivalent(F, F')", ea_ok, io)

    # Collect {(β, k)} pairs for both
    F_keys = pi_spectrum_union(F)
    Fp_keys = pi_spectrum_union(Fp)
    inv_ok = (F_keys == Fp_keys)
    print_check("Π_F key-set == Π_{F'} key-set (CCZ-invariance)", inv_ok, io)

    (; all_ok = ea_ok && inv_ok, n)
end

"""
    proposition4_ea_invariance(; io, n) -> NamedTuple

Proposition 4: for F'(x) = F(x ⊕ c) (input shift by c), A₂(β) = β ⊕ c,
so Π_{F'}^β = Π_F^{β⊕c}. Verified for several β values.
"""
function proposition4_ea_invariance(; io::IO = stdout, n::Int = 5)
    F = gold_x3(n)
    sz = 1 << n
    c = 7  # input shift (A₂(x) = x ⊕ c, so A₂(β) = β ⊕ c)
    lut = UInt8[F.lut[(x ⊻ c)+1] for x = 0:(sz-1)]
    Fp = SBox{n,UInt8}(lut)

    print_section("Proposition 4 — EA-invariance of Π_F^β (n=$n, shift c=$c)", io)

    test_betas = [0, 1, 3, 7, 15]
    mismatches = 0
    for β in test_betas
        β >= sz && continue
        # Π_{F'}^β == Π_F^{β⊕c}
        sp_Fp_beta = pi_multiset(Fp, β)
        sp_F_A2beta = pi_multiset(F, β ⊻ c)
        sp_Fp_beta == sp_F_A2beta || (mismatches += 1)
    end
    all_ok = mismatches == 0
    print_check("Π_{F'}^β == Π_F^{β⊕c} for $(length(test_betas)) test β values", all_ok, io)
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
        F = gold_x3(n)
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
        F = gold_x3(n)
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
