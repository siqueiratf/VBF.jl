# Implements Table III from Section 3.
# Paper: Budaghyan, Helleseth, Kaleyski (2020), "A New Family of APN Quadrinomials",
#        IEEE Trans. Inf. Theory 66(11):7081–7087
# Section: 3 — Table III (Γ-ranks of all known CCZ-inequivalent APN functions over GF(2^10))
#
# Pseudocode:
#   1. Build every row of Table III over GF(2^10): Gold x^3, Gold x^9, Kasami x^57,
#      Dobbertin x^339, two F3 reps, two F4 reps, six F12 (Taniguchi) reps, the
#      binomial B(x), and the new C_3, C_7
#   2. Verify each is APN, and record its algebraic degree
#   3. Compare C_3 and C_7 against every other row by ortho-derivative mugshot
#   4. Report the paper's Γ-ranks as *transcribed* reference values (n=10 Γ-rank
#      is not computable here — see the note below)
# VBF API used: gold_apn, kasami_apn, dobbertin_apn, taniguchi_apn_representatives,
#               terms_to_lut, gf_trace, gf_pow, gf_mul, differential_uniformity,
#               algebraic_degree, absolute_walsh_spectrum, apn_ea_mugshot, SBox
#
# ── Γ-rank: what we can and cannot do here ───────────────────────────────────
# VBF *does* export `gamma_rank` (packages/VBF/src/invariants/design_ranks.jl:97),
# but it is guarded to n ≤ 7. At n = 10 the incidence matrix of dev(G_F) is
# 2^20 × 2^20 over F₂; dense, that is ~137 GB. So the Γ-ranks below are
# TRANSCRIBED FROM THE PAPER (tex:465-495), NOT COMPUTED. Nothing in this file
# or in test/test_table3.jl treats them as a verified result.
#
# ── Field representation ─────────────────────────────────────────────────────
# The paper pins no primitive polynomial. The F3/F4 rows quote coefficients as
# powers of a primitive α, so they are representation-dependent; we use the repo
# default GF(2^10) = F2[x]/(x^10+x^3+1) (0x409) with α = 2, under which all four
# rows do come out APN (asserted in test_table3.jl). C_3, C_7 and B(x) are stated
# purely in terms of β (the order-3 element), hence representation-independent.

include(joinpath(@__DIR__, "helpers.jl"))
using Printf

const N10 = 10
const MOD10 = primitive_polynomial(N10)

# ── Table III rows over GF(2^10) ─────────────────────────────────────────────

_pow10(x, e) = gf_pow(x, e, N10; modulus = MOD10)
_tr10(x) = gf_trace(x, N10; modulus = MOD10)
_alpha(e) = _pow10(2, e)   # α = 2 is primitive for modulus 0x409

# F3 (Bracken–Byrne–Markin–McGuire trinomials), Table III rows 5-6
_f3_row1() = SBox{N10}(terms_to_lut([(1, 6), (1, 33), (_alpha(31), 192)], N10, MOD10))
_f3_row2() = SBox{N10}(terms_to_lut([(1, 33), (1, 72), (_alpha(31), 258)], N10, MOD10))

# F4 (Bracken–Byrne–Markin–McGuire, trace form), Table III rows 7-8
_f4_row1() = SBox{N10}([_pow10(x, 3) ⊻ _tr10(_pow10(x, 9)) for x in 0:(1 << N10) - 1])
function _f4_row2()
    ainv, a3 = _alpha((1 << N10) - 2), _alpha(3)
    SBox{N10}([
        _pow10(x, 3) ⊻ (_tr10(gf_mul(a3, _pow10(x, 9), N10; modulus = MOD10)) == 1 ? ainv : 0)
        for x in 0:(1 << N10) - 1
    ])
end

# F12 (Taniguchi). `taniguchi_apn_representatives(5)` deduplicates by mugshot and
# returns exactly six classes over GF(2^10) — the same count the paper reports
# ("Family F12 in Table II gives six CCZ-inequivalent representatives", tex:485).
# It costs ~40 s, so memoise it for the process.
const _F12_CACHE = Ref{Union{Nothing,Vector{<:SBox}}}(nothing)
function f12_representatives()
    if _F12_CACHE[] === nothing
        _F12_CACHE[] = [r.sbox for r in taniguchi_apn_representatives(5)]
    end
    _F12_CACHE[]
end

# The five distinct Γ-ranks the paper lists for the six F12 representatives
# (two of them share a rank), tex:487. The paper does not say which rep has which
# rank, so we cannot attach them row-by-row.
const F12_GAMMA_RANKS_PAPER = [162550, 163308, 163398, 163400, 164026]

"""
    table3_functions() -> Vector{NamedTuple}

Every row of Table III over GF(2^10): `(name, family, gamma_rank_paper, sbox)`.
`gamma_rank_paper` is TRANSCRIBED from the paper (tex:465-495) and is `nothing`
for the F12 representatives, whose ranks the paper reports only as an unordered
set of five values (see `F12_GAMMA_RANKS_PAPER`).
"""
function table3_functions()
    rows = Any[
        (; name="x^3",   family="Gold",      gamma_rank_paper=125042, sbox=gold_apn(N10, 1)),
        (; name="x^9",   family="Gold",      gamma_rank_paper=136492, sbox=gold_apn(N10, 3)),
        (; name="x^57",  family="Kasami",    gamma_rank_paper=186416, sbox=kasami_apn(N10, 3)),
        (; name="x^339", family="Dobbertin", gamma_rank_paper=280604, sbox=dobbertin_apn(N10)),
        (; name="F3 #1", family="F3",        gamma_rank_paper=151216, sbox=_f3_row1()),
        (; name="F3 #2", family="F3",        gamma_rank_paper=153896, sbox=_f3_row2()),
        (; name="F4 #1", family="F4",        gamma_rank_paper=153896, sbox=_f4_row1()),
        (; name="F4 #2", family="F4",        gamma_rank_paper=164098, sbox=_f4_row2()),
    ]
    for (j, F) in enumerate(f12_representatives())
        push!(rows, (; name="F12 #$j", family="F12", gamma_rank_paper=nothing, sbox=F))
    end
    push!(rows, (; name="B(x)", family="[16]", gamma_rank_paper=169984,
                 sbox=build_ci_sbox(N10, 3, 2; b=0, c=0)))   # x^3 + β·x^36
    push!(rows, (; name="C_3",  family="new",  gamma_rank_paper=166068,
                 sbox=build_ci_sbox(N10, 3, 2)))
    push!(rows, (; name="C_7",  family="new",  gamma_rank_paper=166168,
                 sbox=build_ci_sbox(N10, 7, 0)))
    rows
end

function table3_report(io::IO = stdout)
    funcs = table3_functions()

    print_section("Table III: all known APN classes over GF(2^10)", io)
    println(io, "  Γ(paper) is TRANSCRIBED from Table III, not computed: VBF's `gamma_rank`")
    println(io, "  is guarded to n ≤ 7 (invariants/design_ranks.jl), and a dense 2^20×2^20")
    println(io, "  F2 incidence matrix at n=10 is ~137 GB. What IS computed below: APN-ness,")
    println(io, "  algebraic degree, and the ortho-derivative mugshot.")
    println(io)
    println(io, "  Function  Family      Γ(paper)   deg  APN")
    for f in funcs
        apn = differential_uniformity(f.sbox) == 2
        rank = f.gamma_rank_paper === nothing ? "  (set)" : @sprintf("%-9d", f.gamma_rank_paper)
        print_check(
            @sprintf("%-8s  %-10s  %-9s  %-3d  %s",
                f.name, f.family, rank, algebraic_degree(f.sbox), apn ? "yes" : "no"),
            apn, io,
        )
    end
    println(io, "  F12 Γ-ranks (paper, unordered, six reps / five values): ",
            join(F12_GAMMA_RANKS_PAPER, ", "))

    novelty_report(io; funcs)
end

"""
    novelty_report(io; funcs)

The paper's central claim: C_3 and C_7 are CCZ-inequivalent to each other and to
every known APN function over GF(2^10), *including B(x)*.
"""
function novelty_report(io::IO = stdout; funcs = table3_functions())
    quads    = [f for f in funcs if algebraic_degree(f.sbox) == 2]
    nonquads = [f for f in funcs if algebraic_degree(f.sbox) != 2]

    print_section("Novelty: C_3, C_7 vs. every quadratic APN class of Table III", io)
    println(io, "  Yoshiara: for QUADRATIC APN functions CCZ-equivalence coincides with")
    println(io, "  EA-equivalence, and the ortho-derivative mugshot is an EA-invariant.")
    println(io, "  So distinct mugshots among quadratics ⇒ CCZ-inequivalent. This part of")
    println(io, "  the claim IS invariant-backed.")

    mugs = [apn_ea_mugshot(f.sbox) for f in quads]
    collisions = [(quads[p].name, quads[q].name)
                  for p in 1:length(quads) - 1 for q in p + 1:length(quads)
                  if mugs[p] == mugs[q]]
    print_check(
        "All $(length(quads)) quadratic rows have pairwise-distinct mugshots " *
        "($(length(Set(mugs)))/$(length(quads)) distinct)",
        isempty(collisions), io,
    )
    for (x, y) in collisions
        print_check("COLLISION: $x and $y share a mugshot", false, io)
    end

    c3 = first(f.sbox for f in funcs if f.name == "C_3")
    c7 = first(f.sbox for f in funcs if f.name == "C_7")
    bx = first(f.sbox for f in funcs if f.name == "B(x)")
    print_check("C_3 ≠ C_7 (mugshots differ)", apn_ea_mugshot(c3) != apn_ea_mugshot(c7), io)
    print_check("C_3 ≠ B(x) and C_7 ≠ B(x) (mugshots differ)",
                apn_ea_mugshot(c3) != apn_ea_mugshot(bx) &&
                apn_ea_mugshot(c7) != apn_ea_mugshot(bx), io)
    println(io, "  Note the mugshot is doing real work here: C_3, C_7 and B(x) all share the")
    println(io, "  SAME extended Walsh spectrum, so that coarser invariant separates none of")
    println(io, "  them — the ortho-derivative does.")

    print_section("Novelty: C_3, C_7 vs. the NON-quadratic rows — NOT invariant-backed here", io)
    println(io, "  Rows: ", join((f.name for f in nonquads), ", "),
            " (degrees ", join((algebraic_degree(f.sbox) for f in nonquads), ", "), ").")
    println(io, "  `apn_ea_mugshot` computes the mugshot from DIFFERENT data for quadratic")
    println(io, "  and non-quadratic F, so a mugshot mismatch across that boundary is decided")
    println(io, "  by a struct tag, not by any invariant. We therefore make NO computational")
    println(io, "  inequivalence claim against these rows. Concretely:")
    aws_c3 = absolute_walsh_spectrum(c3)
    for f in nonquads
        same = aws_c3 == absolute_walsh_spectrum(f.sbox)
        println(io, @sprintf("    extended Walsh spectrum of C_3 vs %-6s : %s",
                             f.name, same ? "IDENTICAL — cannot separate" : "differs"))
    end
    println(io, "  x^57 in particular has the SAME extended Walsh spectrum as C_3 and C_7, so")
    println(io, "  the repo's invariants genuinely cannot tell them apart. Separation rests on")
    println(io, "  two things outside this file: (a) the paper's own Γ-rank computation, which")
    println(io, "  we cannot redo at n=10; (b) Yoshiara's theorem on power APN functions — a")
    println(io, "  power APN CCZ-equivalent to a quadratic APN must be EA-equivalent to a Gold")
    println(io, "  function, which x^57 (deg 4) and x^339 (deg 5) are not. (b) is a literature")
    println(io, "  appeal, not a computation performed here.")
end
