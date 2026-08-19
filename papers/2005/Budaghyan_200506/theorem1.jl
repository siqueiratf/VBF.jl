# Implements Section 5, Theorem 1 — AB polynomials for m > 3 odd.
# Paper: Budaghyan, Carlet, Pott (2006), "New Classes of Almost Bent and Almost
#        Perfect Nonlinear Polynomials", IEEE Trans. IT 52(3), pp. 762–777.
# Section: 5 — New cases of AB and APN functions
#
# Pseudocode:
#   F'(x) = x^{2^i+1} + (x^{2^i} + x) · tr(x^{2^i+1} + x)
#   1. Gold: xgold = x^{2^i+1};  Frobenius: xi = x^{2^i}
#   2. tr_val = tr(xgold ⊕ x) ∈ {0,1}
#   3. F'(x) = xgold ⊕ (tr_val == 1 ? (xi ⊕ x) : 0)
#   4. AB ↔ linearity = 2^{(m+1)/2};  APN ↔ diff_unif = 2
#   5. Prop 4: some c ∈ F*_{2^m} has deg(tr(cF')) = 2 ∉ {0,1,3=deg(F')}
#   6. gcd(i,m) = s > 1 remark (tex, after the Theorem 2 proof): the proofs do
#      not use gcd(i,m)=1; for m/s odd F' has the three-valued Walsh spectrum
#      {0, ±2^{(m+s)/2}} and differential uniformity 2^s. `require_coprime=false`
#      unlocks those parameters; `theorem1_gcd_remark_check` exercises them.
# VBF API used: gf_pow, primitive_polynomial, SBox, differential_uniformity, linearity,
#               absolute_walsh_spectrum, sorted_pairs, algebraic_degree

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem1_lut(m, i; modulus, require_coprime = true) -> Vector{Int}

LUT of F'(x) = x^{2^i+1} + (x^{2^i} + x)·tr(x^{2^i+1} + x) over GF(2^m).
Requires m > 3 odd; `gcd(i, m) = 1` is enforced by default.

Pass `require_coprime = false` for the paper's own `gcd(i,m) = s > 1` remark
(see [`theorem1_gcd_remark_check`](@ref)); the construction itself never uses
the coprimality, only the AB conclusion does.
"""
function theorem1_lut(
    m::Int,
    i::Int;
    modulus::Int = primitive_polynomial(m),
    require_coprime::Bool = true,
)
    m > 3 || throw(ArgumentError("theorem1_lut: need m > 3, got m=$m"))
    m % 2 == 1 || throw(ArgumentError("theorem1_lut: m must be odd, got m=$m"))
    (!require_coprime || gcd(i, m) == 1) ||
        throw(ArgumentError("theorem1_lut: need gcd(i,m)=1, got i=$i, m=$m"))
    0 < i < m || throw(ArgumentError("theorem1_lut: need 0 < i < m, got i=$i, m=$m"))
    gold_exp = (1 << i) + 1
    frob_exp = 1 << i
    N = 1 << m
    out = Vector{Int}(undef, N)
    for x in 0:N-1
        xgold = gf_pow(x, gold_exp, m; modulus = modulus)
        xi = gf_pow(x, frob_exp, m; modulus = modulus)
        tr_val = gf_trace(xgold ⊻ x, m; modulus = modulus)
        out[x+1] = xgold ⊻ (tr_val == 1 ? (xi ⊻ x) : 0)
    end
    out
end

"""
    theorem1_check(; m, i, io, prop4_scan_c) -> NamedTuple

Verify Theorem 1 claims:
- F' is APN and AB
- algebraic degree = 3
- Prop 4: some `c ∈ F*_{2^m}` has deg(tr(cF')) ∉ {0, 1, 3}

`prop4_scan_c` (default: on for m ≤ 10) scans every `c ∈ F*_{2^m}` instead of
only `c = 1`; Proposition 4 is an existential statement over `c`, so `c = 1`
failing would not refute it.
"""
function theorem1_check(;
    m::Int,
    i::Int,
    io::IO = devnull,
    prop4_scan_c::Bool = m <= 10,
)
    modulus = primitive_polynomial(m)
    lut = theorem1_lut(m, i; modulus = modulus)
    s = SBox{m}(lut)

    is_apn = differential_uniformity(s) == 2
    ab_target = 1 << ((m + 1) ÷ 2)
    is_ab = sbox_linearity(s) == ab_target
    deg = algebraic_degree(s)
    tt = trace_component_tt(lut, m; modulus = modulus)
    deg_tr = boolean_alg_degree(tt)
    witnesses = prop4_scan_c ? prop4_witnesses(lut, m, deg; modulus = modulus) : Int[]
    n_witnesses = length(witnesses)
    prop4_ok = prop4_scan_c ? n_witnesses > 0 : deg_tr ∉ (0, 1, deg)

    print_section("Theorem 1 — GF(2^$m), i=$i", io)
    print_check("APN (differential uniformity = 2)", is_apn, io)
    print_check("AB  (linearity = $ab_target)", is_ab, io)
    print_check("algebraic degree = 3", deg == 3, io)
    print_check("Prop 4 at c=1: deg(tr(F')) = $deg_tr ∉ {0,1,$deg}", deg_tr ∉ (0, 1, deg), io)
    if prop4_scan_c
        print_kv("Prop 4 witnesses c ∈ F*_{2^$m}", "$n_witnesses / $((1 << m) - 1)", io)
        print_check("Prop 4 holds for some c (⇒ EA-inequivalent to power functions)", prop4_ok, io)
    end

    (; is_apn, is_ab, deg, deg_tr, prop4_ok, n_witnesses, prop4_scan_c)
end

"""
    theorem1_gcd_remark_check(; m, i, io) -> NamedTuple

The paper's remark right after the Theorem 2 proof: "the proofs of Theorems 1
and 2 do not depend on the condition gcd(i,m) = 1. When gcd(i,m) = s then the
functions F' have the same differential and linear properties as x^{2^i+1} and,
therefore, if m/s is odd they can be considered as the first polynomials with
three valued Walsh spectrum {0, ±2^{(m+s)/2}}, which are EA-inequivalent to
power functions."

Builds Theorem 1's F' with `require_coprime = false` and checks, for m odd:
- `absolute_walsh_spectrum ⊆ {0, 2^{(m+s)/2}}` (three-valued, counting signs)
  exactly when `m/s` is odd;
- differential uniformity `2^s` (that of the Gold function `x^{2^i+1}`);
- Prop 4 still separates F' from the power functions (`deg = 3`, `deg(tr F') = 2`).

`m/s` even is kept as a negative control: the spectrum is then *not* three-valued.
"""
function theorem1_gcd_remark_check(; m::Int, i::Int, io::IO = devnull)
    s = gcd(i, m)
    modulus = primitive_polynomial(m)
    lut = theorem1_lut(m, i; modulus = modulus, require_coprime = false)
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

    print_section("Theorem 1 — gcd(i,m)=s>1 remark (GF(2^$m), i=$i, s=$s, m/s=$(m ÷ s))", io)
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

function theorem1_report(io::IO = stdout)
    print_section("Section 5 — Theorem 1: AB polynomials (m > 3 odd)", io)
    for (m, i) in [(5, 1), (5, 2), (7, 1), (7, 2), (7, 3)]
        theorem1_check(; m = m, i = i, io = io)
    end
    println(io, "  [NOTE] gcd(i,m)=s>1 remark (tex, after the Theorem 2 proof):")
    println(io, "         builders accept those parameters via require_coprime=false.")
    theorem1_gcd_remark_check(; m = 9, i = 3, io = io)   # s=3, m/s=3 odd
    theorem1_gcd_remark_check(; m = 9, i = 6, io = io)   # s=3, m/s=3 odd
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem1_report()
end
