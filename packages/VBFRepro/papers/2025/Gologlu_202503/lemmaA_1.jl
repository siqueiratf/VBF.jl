# Implements Lemma A.1 — the centralizer C_F and condition (C).
# Paper: Göloğlu, Kölsch (2025), Electron. J. Combin.
# Section: Appendix A — The centralizer condition
#
#   Lemma A.1. Let m > 2, m ≠ 6 and F a (q = 2^k, r = 2^l)-biprojective pair with
#   l ∉ {0, m/2} and k ≢ ±l (mod m). Let C_F be the centralizer of Z_P^{(q,r)} in
#   Aut_EL(F). Then
#     • Zhou–Pott with j ≠ 0, or F ∈ F₄  →  C_F = ⋃_{ω ∈ F₄^×} Z_ω^{(q,r)}   (index 3)
#     • Taniguchi                        →  C_F = Z^{(q,r)}                   (index 1)
#     • F ∈ F₁ or F₂                     →  C_F = Z^{(q,r)} ∪ A ∪ B           (index 3)
#     • Carlet, m odd                    →  Z^{(q,r)} has index 3 in C_F
#   In all cases the index is 1 or 3, so p ∤ [C_F : Z^{(q,r)}] and condition (C)
#   of Theorem 4.8 holds.
#
# Pseudocode:
#   1. Enumerate C_F/Z^{(q,r)} projectively (see `centralizer_classes` in
#      helpers.jl) — this yields the index I directly.
#   2. Compare I against the family-specific prediction above.
#   3. Check condition (C): p ∤ I, where p = primitive prime divisor of 2^m − 1.
#   4. Structural check for F₄: the index-3 classes should be exactly the
#      Z_ω^{(q,r)} of the lemma, i.e. M = diag(c, ωc) with ω ∈ F₄^×.
#   5. NEGATIVE CONTROL: with the `N`-part suppressed, the Carlet index drops
#      from 3 to 1 — showing the check is sensitive to the algebra and that the
#      `k ≡ 0 (mod m)` caveat in the lemma is load-bearing.
#
# VBF API used: gf_mul/gf_pow (via helpers), print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

using VBF

"""Lemma A.1's predicted index `[C_F : Z^{(q,r)}]` per family tag."""
predicted_index(tag::Symbol) =
    tag === :taniguchi ? 1 :
    tag in (:zhou_pott, :f1, :f2, :f4, :carlet) ? 3 :
    error("predicted_index: unknown family $tag")

"""
    lemmaA_1_corpus(m) -> Vector{Tuple{Symbol,BiPair}}

One admissible instance of each family Lemma A.1 covers, on `M = F_{2^m}`.
Gold is excluded: it has `k ≡ l`, which the lemma's hypothesis `k ≢ ±l (mod m)`
rules out.
"""
function lemmaA_1_corpus(m::Integer)
    fld = BiField(m)
    N = order(fld)
    out = Tuple{Symbol,BiPair}[]
    for k = 1:(m-1)
        gcd(k, m) == 1 || continue
        d = findfirst(x -> taniguchi_valid(fld, k, x), 0:(N-1))
        d === nothing || push!(out, (:taniguchi, taniguchi(fld, k, d - 1)))
        dc = findfirst(x -> carlet_valid(fld, k, 0, 1, x), 0:(N-1))
        dc === nothing || push!(out, (:carlet, carlet(fld, k, 0, 1, dc - 1)))
        if iseven(m)
            for j = 1:(m-1)
                j == 0 && continue                      # lemma needs j ≠ 0
                ex = zhou_pott_excluded_d(fld, k, j)
                dz = findfirst(x -> x != 0 && !(x in ex), 0:(N-1))
                dz === nothing || push!(out, (:zhou_pott, zhou_pott(fld, k, j, dz - 1)))
            end
        end
        f1_valid(fld, k) && push!(out, (:f1, family_f1(fld, k)))
        f2_valid(fld, k) && push!(out, (:f2, family_f2(fld, k)))
    end
    for (k, B, a) in f4_parameters(fld)
        push!(out, (:f4, family_f4(fld, k, B, a)))
        break                                            # one F₄ instance is enough here
    end
    out
end

"""
    f4_classes_are_Z_omega(F, classes) -> Bool

Lemma A.1's structural claim for `F₄` (and Zhou–Pott): the three classes of
`C_F/Z^{(q,r)}` are the `Z_ω^{(q,r)}` — i.e. every representative matrix is
`diag(1, ω)` with `ω ∈ F₄^×` (after the projective normalisation `c₁ = 1`).
"""
function f4_classes_are_Z_omega(F::BiPair, classes)
    fld = F.fld
    ω4 = Set(f4star(fld))
    length(classes) == 3 || return false
    for (c1, c2, c3, c4) in classes
        (c2 == 0 && c3 == 0 && c1 == 1) || return false
        c4 in ω4 || return false
    end
    true
end

"""
    lemmaA_1_report(io = stdout; m_values = (3, 4, 5), include_f4 = true) -> NamedTuple
"""
function lemmaA_1_report(io::IO = stdout; m_values = (3, 4, 5), include_f4::Bool = true)
    print_section("Lemma A.1 — the centralizer C_F and condition (C)", io)
    rows = NamedTuple[]
    idx_ok = true
    cond_c_ok = true
    for m in m_values
        p = primitive_prime_divisor(m)
        for (tag, F) in lemmaA_1_corpus(m)
            carlet_f = tag === :carlet
            I = centralizer_index(F; carlet_f = carlet_f)
            want = predicted_index(tag)
            I == want || (idx_ok = false;
            println(io, "    [FAIL] $(F.name): index $I, Lemma A.1 predicts $want"))
            # condition (C): p ∤ I
            p === nothing || (I % p != 0) || (cond_c_ok = false)
            push!(rows, (; m, tag, name = F.name, index = I, predicted = want, p))
        end
    end
    for m in m_values
        n = count(r -> r.m == m, rows)
        print_kv("m=$m: instances checked", n, io)
    end
    print_check("[C_F : Z^{(q,r)}] matches Lemma A.1 for every instance", idx_ok, io)
    print_check("condition (C): p ∤ [C_F : Z^{(q,r)}] (index ∈ {1,3}, p ≥ 5)", cond_c_ok, io)

    # ── F₄ (m = 6, the smallest dimension the family exists in) ─────────────
    f4_ok = true
    f4_struct = true
    f4_rows = NamedTuple[]
    if include_f4
        fld = BiField(6)
        for (k, B, a) in f4_parameters(fld)[1:3]
            F = family_f4(fld, k, B, a)
            cls = centralizer_classes(F)
            length(cls) == 3 || (f4_ok = false)
            f4_classes_are_Z_omega(F, cls) || (f4_struct = false)
            push!(f4_rows, (; k, B, a, index = length(cls)))
        end
        print_check("F₄ at m=6: [C_F : Z^{(q,r)}] = 3 (Lemma A.1)", f4_ok, io)
        print_check(
            "F₄ at m=6: the three classes are exactly Z_ω^{(q,r)}, ω ∈ F₄^× " *
            "(M = diag(c, ωc))",
            f4_struct,
            io,
        )
        println(
            io,
            "  [NOTE] m = 6 has NO primitive prime divisor of 2⁶−1 = 63, so condition (C)",
        )
        println(
            io,
            "         is not even stateable there; Lemma A.1's index computation still",
        )
        println(io, "         goes through, and gives the predicted 3.")
    end

    # ── negative control: the Carlet N-part is load-bearing ─────────────────
    fld5 = BiField(5)
    dc = findfirst(x -> carlet_valid(fld5, 1, 0, 1, x), 0:(order(fld5)-1))
    C = carlet(fld5, 1, 0, 1, dc - 1)
    i_with_N = centralizer_index(C; carlet_f = true)
    i_without_N = centralizer_index(C; carlet_f = false)
    print_check(
        "negative control: suppressing the N-part collapses the Carlet index " *
        "from $i_with_N to $i_without_N (so the k ≡ 0 mod m caveat is load-bearing)",
        i_with_N == 3 && i_without_N == 1,
        io,
    )
    print_kv("completeness", "exhaustive over C_F (projective enumeration of GL(2,M))", io)

    (;
        rows = rows,
        f4_rows = f4_rows,
        index_ok = idx_ok,
        condition_c_ok = cond_c_ok,
        f4_index_ok = f4_ok,
        f4_structure_ok = f4_struct,
        carlet_N_control = (i_with_N, i_without_N),
        all_ok = idx_ok &&
                 cond_c_ok &&
                 (!include_f4 || (f4_ok && f4_struct)) &&
                 i_with_N == 3 &&
                 i_without_N == 1,
    )
end
