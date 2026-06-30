# Implements Theorem 3.1 — Hexanomial APN condition.
# Paper: Calderini, Budaghyan, Carlet (2021),
#        "On Known Constructions of APN and AB Functions and Their Relation to Each Other",
#        RAD HAZU, Matematičke Znanosti, Vol. 25 = 546, pp. 79–105
# Section: 3 — Theorem 3.1 (hexanomial APN family from [Budaghyan-Carlet 2008])
#
# Pseudocode:
#   For each valid (m, i, c, d) with gcd(i,m)=1 and d not in GF(2^m):
#     1. cond = (x^{2^i+1} + c*x^{2^i} + c^{2^m}*x + 1 = 0 has no x with x^{2^m+1}=1)
#     2. Build H(x) = d*x^{e1} + x^{e2} + x^{e3} + c*x^{e4} + c^{2^m}*x^{e5}
#     3. Verify: cond = true <=> differential_uniformity(H) == 2
# VBF API used: gf_pow, primitive_polynomial, differential_uniformity,
#               algebraic_degree, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    theorem3_1_report([io]; ms) -> NamedTuple

Verify Theorem 3.1: hexanomial APN iff no-zero on unit circle.
Exhaustive over all (i, c) for n=2m with m in ms.
"""
function theorem3_1_report(io::IO = stdout; ms::Vector{Int} = [2, 3])
    print_section("Theorem 3.1 — Hexanomial APN family", io)
    println(io, "  H(x) = d*x^{2^{m+i}+2^i} + x^{2^i+1} + x^{2^{m+i}+2^m}")
    println(io, "        + c*x^{2^{m+i}+1} + c^{2^m}*x^{2^i+2^m}  over GF(2^{2m})")
    println(io, "  APN condition: x^{2^i+1}+c*x^{2^i}+c^{2^m}*x+1 != 0 for all x with x^{2^m+1}=1")

    all_ok  = true
    results = Dict{Int, NamedTuple}()

    for m in ms
        n     = 2m
        mod_n = primitive_polynomial(n)
        # fixed d not in GF(2^m): the first element whose Frobenius differs from itself
        d = first(x for x in 1:(1 << n) - 1
                  if gf_pow(x, 1 << m, n; modulus = mod_n) != x)
        ok_count   = 0
        fail_count = 0
        for i in 1:(m - 1)
            gcd(i, m) == 1 || continue
            for c in 0:(1 << n) - 1
                cond = hexanomial_condition(m, i, c; modulus = mod_n)
                H    = hexanomial_sbox(m, i, c, d; modulus = mod_n)
                du   = differential_uniformity(H)
                cond == (du == 2) ? (ok_count += 1) : (fail_count += 1)
            end
        end
        ok       = (fail_count == 0)
        all_ok  &= ok
        print_check("m=$m n=$n: condition<=>APN for all (i,c)", ok, io)
        print_kv("    cases tested", ok_count + fail_count, io)
        results[m] = (; ok, ok_count, fail_count)
    end

    print_kv("completeness", "exhaustive over all (i,c) for listed m", io)
    (; all_ok, results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem3_1_report()
end
