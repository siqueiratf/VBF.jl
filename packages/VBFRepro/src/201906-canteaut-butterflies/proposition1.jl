# Implements Proposition 1 — Helleseth–Kholosha solution counts for x^{2^i+1} + x = a
# Paper: Canteaut, Perrin, Tian (2019), "If a Generalised Butterfly is APN then it Operates on 6 Bits",
#        Cryptography and Communications, 11(6), pp.1147-1164.
# Section: 3 — Useful Results
#
# Pseudocode:
#   For each a ≠ 0 in F_{2^n}: k(a) = #{x : x^{2^i+1} + x = a}
#   assert k(a) ∈ {0, 1, 3}
#   assert |S₀| = (2^n+1)/3, |S₁| = 2^{n-1}-1, |S₃| = (2^{n-1}-1)/3
#   For each solution x of x^{2^i+1} + x = a with a ≠ 0:
#     assert (k(a) = 1) ⟺ Tr((1 + x⁻¹)^τ) = 1
# VBF API used: gf_pow, gf_inv, gf_trace, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

"""
    proposition1_build(n, i; modulus) -> NamedTuple

Brute-force verification of Proposition 1 (Helleseth–Kholosha):
for n odd and gcd(i,n)=1, the map a ↦ #{x : x^{2^i+1}+x=a} over a ≠ 0
takes only the values {0,1,3} with |S₀|=(2^n+1)/3, |S₁|=2^{n-1}-1,
|S₃|=(2^{n-1}-1)/3, and the unique-solution criterion
Tr((1+x⁻¹)^τ)=1 holds exactly on S₁.
Returns (; n, i, s0, s1, s3, sizes_ok, trace_ok).
"""
function proposition1_build(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    e   = (1 << i) + 1
    len = 1 << n
    img = [gf_pow(x, e, n; modulus) ⊻ x for x in 0:len-1]
    counts = zeros(Int, len)            # counts[a+1] = #solutions of x^{2^i+1}+x=a
    for x in 0:len-1
        counts[img[x + 1] + 1] += 1
    end
    sizes = Dict{Int,Int}()
    for a in 1:len-1
        sizes[counts[a + 1]] = get(sizes, counts[a + 1], 0) + 1
    end
    s0 = get(sizes, 0, 0)
    s1 = get(sizes, 1, 0)
    s3 = get(sizes, 3, 0)
    sizes_ok = all(k -> k in (0, 1, 3), keys(sizes)) &&
               s0 == (2^n + 1) ÷ 3 &&
               s1 == 2^(n - 1) - 1 &&
               s3 == (2^(n - 1) - 1) ÷ 3
    # Unique-solution trace criterion: for every solution x of a ≠ 0
    # (x ≠ 0 since a ≠ 0), k(a)=1 ⟺ Tr((1+x⁻¹)^τ)=1.
    tau = tau_exp(n, i)
    trace_ok = all(1:len-1) do x
        a = img[x + 1]
        a == 0 && return true
        pred = gf_trace(gf_pow(1 ⊻ gf_inv(x, n; modulus), tau, n; modulus),
                        n; modulus) == 1
        (counts[a + 1] == 1) == pred
    end
    (; n, i, s0, s1, s3, sizes_ok, trace_ok)
end

function proposition1_report(io::IO = stdout;
                             cases = ((3, 1), (3, 2), (5, 1), (5, 2), (5, 3), (5, 4)))
    print_section("Proposition 1 — solution counts of x^{2^i+1}+x=a", io)
    for (n, i) in cases
        r = proposition1_build(n, i)
        print_check(io,
            "n=$n i=$i: |S₀|,|S₁|,|S₃| = $(r.s0),$(r.s1),$(r.s3) match Helleseth–Kholosha",
            r.sizes_ok)
        print_check(io,
            "n=$n i=$i: unique-solution criterion Tr((1+x⁻¹)^τ)=1",
            r.trace_ok)
    end
    print_kv(io, "completeness",
             "exhaustive over F_{2^n}, all i with gcd(i,n)=1")
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition1_report()
end
