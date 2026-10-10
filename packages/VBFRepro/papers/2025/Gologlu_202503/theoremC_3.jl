# Implements Theorem C.3 (and the criterion C.2) — F₄ is 3-to-1 with the
# classical Walsh spectrum.
# Paper: Göloğlu, Kölsch (2025), Electron. J. Combin.
# Section: Appendix C — Walsh spectra of biprojective APN functions
#
#   Theorem C.2 ([KKK23]). n even, F quadratic APN, F(0)=0, and every
#   y ∈ Im(F)∖{0} has ≥ 3 preimages ⇒ F is 3-to-1 and has classical Walsh
#   spectrum.
#   Theorem C.3. All F ∈ F₄ are 3-to-1 and have classical Walsh spectrum.
#   Proof idea: F(x,y) = F(ωx, ω²y) for ω ∈ F₄^×, since qQ = 2^{k+m/2} with
#   k + m/2 even, hence ω^{qQ} = ω.
#
# Pseudocode:
#   1. Check the proof's key identity F(x,y) = F(ωx, ω²y) for every ω ∈ F₄^×.
#   2. Check `is_3_to_1` on the lifted SBox (core).
#   3. Compute the extended Walsh spectrum from `lat` restricted to b ∈ F^×
#      and compare with (i) the paper's printed multiplicities and (ii) the
#      corrected ones.
#
# PAPER BUG (Appendix C, paragraph after Definition C.1). The paper states the
# classical extended Walsh spectrum as
#     0            with multiplicity (2ⁿ−1)·2^{n−2}
#     2^{n/2}      with multiplicity (2ⁿ−1)·2^{n+1}/3
#     2^{(n+2)/2}  with multiplicity (2ⁿ−1)·2ⁿ/3        ← WRONG
# The three multiplicities sum to 5·2^{n−2}(2ⁿ−1), but there are only
# 2ⁿ(2ⁿ−1) = 4·2^{n−2}(2ⁿ−1) pairs (b,a) with b ≠ 0 — the printed multiset is
# internally inconsistent. The correct last entry is
#     2^{(n+2)/2}  with multiplicity (2ⁿ−1)·2^{n−2}/3,
# which then sums exactly to 2ⁿ(2ⁿ−1). This file verifies the corrected form on
# a Gold function (the canonical "classical" spectrum) and on F₄ at n = 12, and
# reports the paper's printed form as failing.
#
# VBF API used: lat, is_3_to_1, image_set, algebraic_degree,
#               differential_uniformity, gold_apn, print_section/check/kv

include(joinpath(@__DIR__, "helpers.jl"))

using VBF

"""
    extended_walsh_spectrum(S) -> Dict{Int,Int}

The multiset `{{ |W_F(b, a)| : b ∈ F^×, a ∈ F }}` of Definition C.1.

`lat(S)[a+1, b+1] = W_F(b, a)` with `b` the **output** mask, so the `b = 0`
column is dropped in full. (`VBF.absolute_walsh_spectrum` drops only the single
entry `(0,0)` and would therefore contribute `2ⁿ − 1` spurious zeros here.)
"""
function extended_walsh_spectrum(S::SBox)
    L = lat(S)
    spec = Dict{Int,Int}()
    @inbounds for b = 2:size(L, 2), a = 1:size(L, 1)
        v = abs(L[a, b])
        spec[v] = get(spec, v, 0) + 1
    end
    spec
end

"""Multiplicities of the classical spectrum **as printed** in Appendix C."""
classical_spectrum_paper(n::Integer) = Dict(
    0 => ((1 << n) - 1) * (1 << (n - 2)),
    1 << (n ÷ 2) => ((1 << n) - 1) * (1 << (n + 1)) ÷ 3,
    1 << ((n + 2) ÷ 2) => ((1 << n) - 1) * (1 << n) ÷ 3,
)

"""Multiplicities of the classical spectrum **corrected** (see the header)."""
classical_spectrum_corrected(n::Integer) = Dict(
    0 => ((1 << n) - 1) * (1 << (n - 2)),
    1 << (n ÷ 2) => ((1 << n) - 1) * (1 << (n + 1)) ÷ 3,
    1 << ((n + 2) ÷ 2) => ((1 << n) - 1) * (1 << (n - 2)) ÷ 3,
)

"""
    f4_triplicate_identity(F) -> Bool

Theorem C.3's key step: `F(x, y) = F(ωx, ω²y)` for every `ω ∈ F₄^×`.
"""
function f4_triplicate_identity(F::BiPair)
    fld = F.fld
    for ω in f4star(fld)
        ω == 1 && continue
        ω2 = gmul(fld, ω, ω)
        for x = 0:(order(fld)-1), y = 0:(order(fld)-1)
            bipair_eval(F, x, y) ==
            bipair_eval(F, gmul(fld, ω, x), gmul(fld, ω2, y)) || return false
        end
    end
    true
end

"""
    theoremC_3_report(io = stdout; m = 6, sample_size = 3) -> NamedTuple

Verify Theorem C.3 for `F₄` at `m = 6` (n = 12) and cross-check the "classical"
spectrum definition against a Gold function at n = 6.
"""
function theoremC_3_report(io::IO = stdout; m::Int = 6, sample_size::Int = 3)
    print_section("Theorem C.3 — F₄ is 3-to-1 with classical Walsh spectrum", io)
    fld = BiField(m)
    n = 2m

    # ── calibration: Gold at n = 6 has the classical spectrum by definition ──
    gold6 = gold_apn(6, 1)
    sp_gold = extended_walsh_spectrum(gold6)
    gold_paper = sp_gold == classical_spectrum_paper(6)
    gold_fixed = sp_gold == classical_spectrum_corrected(6)
    print_kv("calibration: Gold x³ on F_2^6, extended Walsh spectrum", sort(collect(sp_gold)), io)
    print_check("  matches the CORRECTED multiplicities (see file header)", gold_fixed, io)
    print_check(
        "  PAPER BUG CONFIRMED: does NOT match the multiplicities printed in Appendix C",
        !gold_paper,
        io,
    )
    if !gold_paper && gold_fixed
        println(
            io,
            "    [PAPER BUG] Appendix C states 2^{(n+2)/2} with multiplicity ",
            "(2ⁿ−1)2ⁿ/3; the correct value is (2ⁿ−1)2^{n−2}/3. The printed",
        )
        println(
            io,
            "               multiset sums to 5·2^{n−2}(2ⁿ−1) > 2ⁿ(2ⁿ−1) = #{(b≠0,a)}, ",
            "so it cannot be right for any function.",
        )
    end

    # ── F₄ at m = 6 ─────────────────────────────────────────────────────────
    params = f4_parameters(fld)
    sample = params[1:min(sample_size, length(params))]
    ident_ok = true
    three_ok = true
    img_ok = true
    walsh_paper = 0
    walsh_fixed = 0
    for (k, B, a) in sample
        F = family_f4(fld, k, B, a)
        f4_triplicate_identity(F) || (ident_ok = false)
        S = bipair_sbox(F)
        is_3_to_1(S) || (three_ok = false)
        length(image_set(S)) == ((1 << n) - 1) ÷ 3 + 1 || (img_ok = false)
        sp = extended_walsh_spectrum(S)
        sp == classical_spectrum_paper(n) && (walsh_paper += 1)
        sp == classical_spectrum_corrected(n) && (walsh_fixed += 1)
    end
    ns = length(sample)
    print_kv("F₄ instances sampled at m=$m (n=$n)", ns, io)
    print_check("proof step: F(x,y) = F(ωx, ω²y) for ω ∈ F₄^×", ident_ok, io)
    print_check("is_3_to_1 (core) holds", three_ok, io)
    print_check("image size = (2ⁿ−1)/3 + 1 = $(((1 << n) - 1) ÷ 3 + 1)", img_ok, io)
    print_check(
        "extended Walsh spectrum = CORRECTED classical ($walsh_fixed/$ns)",
        walsh_fixed == ns,
        io,
    )
    print_check(
        "PAPER BUG CONFIRMED: no F₄ instance matches Appendix C as printed " *
        "($(ns - walsh_paper)/$ns mismatch)",
        walsh_paper == 0,
        io,
    )
    print_kv("completeness", "budget-limited ($ns of $(length(params)) instances)", io)

    (;
        m = m,
        n = n,
        sampled = ns,
        triplicate_identity = ident_ok,
        three_to_one = three_ok,
        image_ok = img_ok,
        walsh_matches_corrected = walsh_fixed,
        walsh_matches_paper = walsh_paper,
        gold_calibration_corrected = gold_fixed,
        gold_calibration_paper = gold_paper,
        # The paper's printed spectrum is expected NOT to match: that is the bug.
        all_ok = ident_ok &&
                 three_ok &&
                 img_ok &&
                 walsh_fixed == ns &&
                 gold_fixed &&
                 !gold_paper &&
                 walsh_paper == 0,
    )
end
