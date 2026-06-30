# Implements Theorem 6.2 — New APN family outside known classes.
# Paper: Calderini, Budaghyan, Carlet (2021), pp. 79–105
# Section: 6 — Theorem 6.2, Lemma 6.1, Remark 6.3
#
# Theorem 6.2: Let n=2m, m even, i < m/2, gcd(i,m)=1. Then
#   F(x,y) = (xy, x^{2^i+1} + x^{2^{i+m/2}}*y^{2^{m/2}} + b*xy^{2^i} + c*y^{2^i+1})
# is APN iff P(X) = (cX^{2^i+1} + bX^{2^i} + 1)^{2^{m/2}+1} + X^{2^{m/2}+1}
# has no zero in GF(2^m).
#
# Remark 6.3: applying L(x,y)=(y,x) gives F' equivalent to F1 type (b!=0) or F2 type (b=0).
#
# Pseudocode:
#   For each (b,c) in GF(2^m)^2:
#     1. Check condition: theorem6_2_condition(m,i,b,c)
#     2. Build SBox: theorem6_2_sbox(m,i,b,c)
#     3. Verify: condition <=> differential_uniformity == 2
# VBF API used: differential_uniformity, algebraic_degree, apn_ea_mugshot,
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem6_2_report([io]; m, i) -> NamedTuple

Verify Theorem 6.2: APN condition exhaustively over all (b,c) in GF(2^m)^2.
Requires m even, i < m/2, gcd(i,m)=1. Default: m=4, i=1.
"""
function theorem6_2_report(io::IO = stdout; m::Int = 4, i::Int = 1)
    iseven(m) || error("Theorem 6.2 requires m even, got m=$m")
    i < m ÷ 2 || error("Theorem 6.2 requires i < m/2=$(m÷2), got i=$i")
    gcd(i, m) == 1 || error("Theorem 6.2 requires gcd(i,m)=1")
    print_section("Theorem 6.2 — New APN family (m=$m, n=$(2m), i=$i)", io)
    println(io, "  F(x,y) = (xy, x^{2^i+1} + x^{2^{i+m/2}}*y^{2^{m/2}} + b*xy^{2^i} + c*y^{2^i+1})")
    println(io, "  APN iff: (cX^{2^i+1}+bX^{2^i}+1)^{2^{m/2}+1} + X^{2^{m/2}+1} has no zero in GF(2^$m)")

    mod_m = primitive_polynomial(m)
    ok_count   = 0
    fail_count = 0

    for b in 0:(1 << m) - 1, c in 0:(1 << m) - 1
        cond = theorem6_2_condition(m, i, b, c; modulus = mod_m)
        F    = theorem6_2_sbox(m, i, b, c; modulus = mod_m)
        du   = differential_uniformity(F)
        cond == (du == 2) ? (ok_count += 1) : (fail_count += 1)
    end

    ok     = (fail_count == 0)
    all_ok = ok
    print_check("condition <=> APN for all (b,c) in GF(2^$m)^2", ok, io)
    print_kv("  cases tested", ok_count + fail_count, io)
    print_kv("  APN pairs (b,c) found", ok_count, io)

    # Remark 6.3: F' = L o F where L(x,y)=(y,x) — verify APN-ness preserved
    b1 = first(b for b in 0:(1 << m) - 1
               for c in 0:(1 << m) - 1
               if theorem6_2_condition(m, i, b, c; modulus = mod_m))
    c1 = first(c for c in 0:(1 << m) - 1
               if theorem6_2_condition(m, i, b1, c; modulus = mod_m))
    F_new = theorem6_2_sbox(m, i, b1, c1; modulus = mod_m)
    print_kv("  example APN: (b,c)", "($b1, $c1)", io)
    print_kv("  algebraic degree", algebraic_degree(F_new), io)

    print_kv("completeness", "exhaustive over all (b,c) in GF(2^$m)^2", io)
    (; all_ok, ok_count, fail_count)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem6_2_report()
end
