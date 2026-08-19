# Implements Section 5, Theorem 2 — APN polynomials for m ≥ 4 even.
# Paper: Budaghyan, Carlet, Pott (2006), "New Classes of Almost Bent and Almost
#        Perfect Nonlinear Polynomials", IEEE Trans. IT 52(3), pp. 762–777.
# Section: 5 — New cases of AB and APN functions
#
# Pseudocode:
#   F'(x) = x^{2^i+1} + (x^{2^i} + x + 1) · tr(x^{2^i+1})
#   1. Gold: xgold = x^{2^i+1};  Frobenius: xi = x^{2^i}
#   2. tr_val = tr(xgold) ∈ {0,1}
#   3. F'(x) = xgold ⊕ (tr_val == 1 ? (xi ⊕ x ⊕ 1) : 0)
#   4. APN ↔ diff_unif = 2  (not AB — m even)
#   5. Prop 4: some c ∈ F*_{2^m} has deg(tr(cF')) = 2 ∉ {0,1,deg(F')}
#   6. gcd(i,m) = s > 1 remark (tex, after this theorem's proof): the proof does
#      not use gcd(i,m)=1; for m/s odd F' has the three-valued Walsh spectrum
#      {0, ±2^{(m+s)/2}} and differential uniformity 2^s. `require_coprime=false`
#      unlocks those parameters; `theorem2_gcd_remark_check` exercises them.
# VBF API used: gf_pow, primitive_polynomial, SBox, differential_uniformity,
#               absolute_walsh_spectrum, sorted_pairs, algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem2_lut(m, i; modulus, require_coprime = true) -> Vector{Int}

LUT of F'(x) = x^{2^i+1} + (x^{2^i} + x + 1)·tr(x^{2^i+1}) over GF(2^m).
Requires m ≥ 4 even; `gcd(i, m) = 1` is enforced by default.

Pass `require_coprime = false` for the paper's own `gcd(i,m) = s > 1` remark
(see [`theorem2_gcd_remark_check`](@ref)).
"""
function theorem2_lut(
    m::Int,
    i::Int;
    modulus::Int = primitive_polynomial(m),
    require_coprime::Bool = true,
)
    m >= 4 || throw(ArgumentError("theorem2_lut: need m ≥ 4, got m=$m"))
    m % 2 == 0 || throw(ArgumentError("theorem2_lut: m must be even, got m=$m"))
    (!require_coprime || gcd(i, m) == 1) ||
        throw(ArgumentError("theorem2_lut: need gcd(i,m)=1, got i=$i, m=$m"))
    0 < i < m || throw(ArgumentError("theorem2_lut: need 0 < i < m, got i=$i, m=$m"))
    gold_exp = (1 << i) + 1
    frob_exp = 1 << i
    N = 1 << m
    out = Vector{Int}(undef, N)
    for x in 0:N-1
        xgold = gf_pow(x, gold_exp, m; modulus = modulus)
        xi = gf_pow(x, frob_exp, m; modulus = modulus)
        tr_val = gf_trace(xgold, m; modulus = modulus)
        out[x+1] = xgold ⊻ (tr_val == 1 ? (xi ⊻ x ⊻ 1) : 0)
    end
    out
end

"""
    theorem2_check(; m, i, io, prop4_scan_c) -> NamedTuple

Verify Theorem 2 claims:
- F' is APN
- algebraic degree = 3
- Prop 4: some `c ∈ F*_{2^m}` has deg(tr(cF')) ∉ {0, 1, 3}

`prop4_scan_c` (default: on for m ≤ 10) scans every `c ∈ F*_{2^m}`; Proposition 4
is existential in `c`, so a failure at `c = 1` alone would not refute it.
"""
function theorem2_check(;
    m::Int,
    i::Int,
    io::IO = devnull,
    prop4_scan_c::Bool = m <= 10,
)
    modulus = primitive_polynomial(m)
    lut = theorem2_lut(m, i; modulus = modulus)
    s = SBox{m}(lut)

    is_apn = differential_uniformity(s) == 2
    deg = algebraic_degree(s)
    tt = trace_component_tt(lut, m; modulus = modulus)
    deg_tr = boolean_alg_degree(tt)
    witnesses = prop4_scan_c ? prop4_witnesses(lut, m, deg; modulus = modulus) : Int[]
    n_witnesses = length(witnesses)
    prop4_ok = prop4_scan_c ? n_witnesses > 0 : deg_tr ∉ (0, 1, deg)

    print_section("Theorem 2 — GF(2^$m), i=$i", io)
    print_check("APN (differential uniformity = 2)", is_apn, io)
    print_check("algebraic degree = 3", deg == 3, io)
    print_check("Prop 4 at c=1: deg(tr(F')) = $deg_tr ∉ {0,1,$deg}", deg_tr ∉ (0, 1, deg), io)
    if prop4_scan_c
        print_kv("Prop 4 witnesses c ∈ F*_{2^$m}", "$n_witnesses / $((1 << m) - 1)", io)
        print_check("Prop 4 holds for some c (⇒ EA-inequivalent to power functions)", prop4_ok, io)
    end

    (; is_apn, deg, deg_tr, prop4_ok, n_witnesses, prop4_scan_c)
end

"""
    theorem2_gcd_remark_check(; m, i, io) -> NamedTuple

Even-`m` half of the paper's `gcd(i,m) = s > 1` remark (see
[`theorem1_gcd_remark_check`](@ref) for the statement). For `m/s` odd the Walsh
spectrum of Theorem 2's F' must be `{0, ±2^{(m+s)/2}}` and its differential
uniformity `2^s`; `m/s` even is kept as a negative control.
"""
function theorem2_gcd_remark_check(; m::Int, i::Int, io::IO = devnull)
    s = gcd(i, m)
    modulus = primitive_polynomial(m)
    lut = theorem2_lut(m, i; modulus = modulus, require_coprime = false)
    sb = SBox{m}(lut)

    walsh_values = sort!([v for (v, _) in sorted_pairs(absolute_walsh_spectrum(sb))])
    ms_odd = isodd(m ÷ s)
    peak = 1 << ((m + s) ÷ 2)          # 2^{(m+s)/2}; integral because m ≡ s (mod 2)
    three_valued = ms_odd && walsh_values == [0, peak]
    du = differential_uniformity(sb)
    deg = algebraic_degree(sb)
    tt = trace_component_tt(lut, m; modulus = modulus)
    deg_tr = boolean_alg_degree(tt)
    prop4_ok = deg_tr ∉ (0, 1, deg)

    print_section("Theorem 2 — gcd(i,m)=s>1 remark (GF(2^$m), i=$i, s=$s, m/s=$(m ÷ s))", io)
    print_kv("absolute Walsh spectrum support", walsh_values, io)
    if ms_odd
        print_check("three-valued spectrum {0, ±2^{(m+s)/2}} = {0, ±$peak}", three_valued, io)
        print_check("differential uniformity = 2^s = $(1 << s)", du == 1 << s, io)
        print_check("Prop 4: deg(tr F') = $deg_tr ∉ {0,1,$deg}", prop4_ok, io)
    else
        print_check("m/s even ⇒ NOT three-valued (negative control)", length(walsh_values) > 2, io)
    end

    (; s, ms_odd, walsh_values, peak, three_valued, du, deg, deg_tr, prop4_ok)
end

function theorem2_report(io::IO = stdout)
    print_section("Section 5 — Theorem 2: APN polynomials (m ≥ 4 even)", io)
    for (m, i) in [(4, 1), (4, 3), (6, 1), (6, 5), (8, 1), (8, 3)]
        theorem2_check(; m = m, i = i, io = io)
    end
    println(io, "  [NOTE] gcd(i,m)=s>1 remark (tex, right after this proof):")
    theorem2_gcd_remark_check(; m = 6, i = 2, io = io)    # s=2, m/s=3 odd
    theorem2_gcd_remark_check(; m = 10, i = 2, io = io)   # s=2, m/s=5 odd
    theorem2_gcd_remark_check(; m = 6, i = 3, io = io)    # s=3, m/s=2 even (control)
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem2_report()
end
