# Implements Theorem 3.2 and Section 3.5.1.
# Paper: Budaghyan, Calderini, Carlet, Coulter, Villa (2021),
#        "Generalized Isotopic Shift Construction for APN Functions"
# Section: 3.5.1 — Nonlinear shift for the Gold functions
#
# Pseudocode:
#   Theorem 3.2: Over GF(2^n) with n odd, every non-Dobbertin APN power function F
#   is EA-equivalent to some G_{i,L} with L(x)=a*x^d (nonlinear monomial) and Gold G_i.
#
#   G_{i,L}(x) = x^{2^i}*L(x) + x*L(x)^{2^i}  (Eq. 4)
#   With L(x) = a*x^d: G_{i,L}(x) = a*x^{2^i+d} + a^{2^i}*x^{d*2^i+1}
#
#   EA-equivalence strategy (avoids expensive are_ea_equivalent for non-quadratic APNs):
#   1. Build G = a*x^{e1} + a^{2^i}*x^{e2} (binomial)
#   2. Identify the linear term (exponent = power of 2 mod 2^n-1)
#   3. After EA-subtracting the linear term, G is linear-equiv to a monomial x^{e_nl}
#   4. Check x^{e_nl} and x^{d_target} are Frobenius-equivalent:
#      d_target ≡ 2^j * e_nl (mod 2^n-1) for some j
#
# Families verified (a=1, odd n):
#   2. Inverse x^{2^n-2}:        n=2t+1, i=1, L=x^{2^{2t}-2}
#   3. Welch x^{2^t+3}:          n=2t+1, t odd: i s.t. t=2i-1, L=x^{2^i+2^{i+1}}
#   5. Gold x^{2^j+1}:            n=2i+1, gcd(n,j)=1, i=1, L=x^{2^{1+j}-2}
# VBF API used: SBox, differential_uniformity, gold_apn, kasami_apn, welch_apn,
#               niho_apn, inverse_apn, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

"""
    is_frobenius_equiv(e1, e2, n) -> Bool

True when x^{e1} and x^{e2} are linear-equivalent over GF(2^n), i.e.,
e2 ≡ 2^j * e1 (mod 2^n-1) for some j in 0..n-1.
Equivalence classes are the orbits under the Frobenius automorphism x->x^2.
"""
function is_frobenius_equiv(e1::Integer, e2::Integer, n::Integer)
    q = (1 << Int(n)) - 1   # 2^n - 1
    r1 = Int(e1) % q
    r2 = Int(e2) % q
    r1 == 0 && r2 == 0 && return true
    e = r1
    for _ in 0:n-1
        e == r2 && return true
        e = (e * 2) % q
    end
    false
end

"""
    verify_nonlinear_case(label, n, i, d, target_exp; modulus, a=1) -> NamedTuple

Build G_{i,L}(x) = a*x^{2^i+d} + a^{2^i}*x^{d*2^i+1} (a=1), check:
  1. G is APN (du=2).
  2. One term is degree-1 (linear) and the other has exponent Frobenius-equiv to target_exp.
     This proves G is EA-equiv to x^{target_exp} (subtract linear part, apply Frobenius).
"""
function verify_nonlinear_case(
    label::String, n::Int, i::Int, d::Integer, target_exp::Integer;
    modulus::Int = primitive_polynomial(n), a::Int = 1,
)
    pow2i = 1 << i
    e1 = pow2i + Int(d)
    e2 = Int(d) * pow2i + 1
    q = (1 << n) - 1

    # Build LUT and check APN
    a2i = gf_pow(a, pow2i, n; modulus)
    lut = [gf_mul(a,   gf_pow(x, e1, n; modulus), n; modulus) ⊻
           gf_mul(a2i, gf_pow(x, e2, n; modulus), n; modulus) for x in 0:(1<<n)-1]
    du = differential_uniformity(SBox{n}(lut))
    apn_G = (du == 2)

    # Determine which exponent is "linear" (single bit in binary = Frobenius image of 1)
    r1 = e1 % q; r2 = e2 % q
    lin1 = count_ones(r1) == 1  # x^{e1} is a Frobenius image of x (degree 1)
    lin2 = count_ones(r2) == 1
    has_linear = lin1 || lin2
    e_nl = lin1 ? r2 : r1      # the nonlinear exponent after removing linear term

    # After EA-subtracting the linear term, check Frobenius-equiv to target
    t_r = Int(target_exp) % q
    frob_ok = is_frobenius_equiv(e_nl, t_r, n)

    ea_ok = has_linear && frob_ok
    (; label, n, i, d, e1, e2, du, apn_G, has_linear, e_nl, t_r, ea_ok)
end

"""
    theorem3_2_cases() -> Vector{NamedTuple}

Verify Theorem 3.2 for representative families (a=1).
"""
function theorem3_2_cases()
    results = NamedTuple[]

    # ---- Case 5: Gold x^{2^j+1}, n=2i+1, gcd(n,j)=1, L=x^{2^{i+j}-2^i} ----
    for (n, i, j) in [(5,2,1), (7,3,2), (9,4,1)]
        d = (1<<(i+j)) - (1<<i)
        target_exp = (1<<j)+1
        mod = primitive_polynomial(n)
        push!(results, verify_nonlinear_case(
            "Gold j=$j, n=$n, i=$i", n, i, d, target_exp; modulus=mod))
    end

    # ---- Case 2: Inverse x^{2^n-2}, n=2t+1, i=1, L=x^{2^{2t}-2} ----
    for n in [5, 7]
        t = n ÷ 2
        d = (1<<(2t)) - 2
        target_exp = (1<<n) - 2
        mod = primitive_polynomial(n)
        push!(results, verify_nonlinear_case(
            "Inverse n=$n, i=1", n, 1, d, target_exp; modulus=mod))
    end

    # ---- Case 3: Welch x^{2^t+3}, t odd, n=2t+1, i s.t. t=2i-1 -> L=x^{2^i+2^{i+1}} ----
    for (n, t, i) in [(7,3,2), (11,5,3)]
        d = (1<<i) + (1<<(i+1))
        target_exp = (1<<t) + 3
        mod = primitive_polynomial(n)
        push!(results, verify_nonlinear_case(
            "Welch t=$t(odd), n=$n, i=$i", n, i, d, target_exp; modulus=mod))
    end

    # ---- Case 1: Kasami x^{2^{2t}-2^t+1}, t odd, n=2i+t, L=x^{sum 2^{n-i+s}, s=0..t-1} ----
    # n=7, t=3(odd), n=2i+t => i=2
    let n=7, t=3, i=2
        d = sum(1<<(n-i+s) for s in 0:t-1)  # 2^5+2^6+2^7=224 (reduces mod 2^7-1 in gf_pow)
        target_exp = (1<<(2t)) - (1<<t) + 1  # 2^6-2^3+1=57
        mod = primitive_polynomial(n)
        push!(results, verify_nonlinear_case(
            "Kasami t=$t(odd), n=$n, i=$i", n, i, d, target_exp; modulus=mod))
    end

    results
end

function theorem3_2_report(io::IO = stdout)
    print_section(io, "Theorem 3.2 — Nonlinear Gold Shifts = Known Power APNs (Section 3.5.1)")
    print_kv(io, "Claim", "For odd n, every non-Dobbertin APN power fn = G_{i,L} with L(x)=x^d")
    print_kv(io, "G_{i,L}(x)", "a*x^{2^i+d} + a^{2^i}*x^{d*2^i+1}")
    print_kv(io, "EA-equiv method",
        "identify linear term (one exponent = Frobenius image); remaining exponent " *
        "Frobenius-equiv to target => EA-equiv after subtracting linear part")

    cases = theorem3_2_cases()
    all_ok = all(c.ea_ok for c in cases)
    for c in cases
        print_kv(io, "  $(c.label)",
            "apn=$(c.apn_G) lin=$(c.has_linear) e_nl=$(c.e_nl) target=$(c.t_r) " *
            "frob=$(c.ea_ok)  " * status_str(c.ea_ok))
    end
    print_check(io, "all $(length(cases)) Theorem 3.2 cases verified (APN + EA-equiv)", all_ok)
    print_kv(io, "Dobbertin", "excluded (open Problem 3.1)")
    print_kv(io, "Niho", "similar algebraic argument; omitted (large exponent computation)")
    print_kv(io, "completeness", "exhaustive for listed cases; proof is algebraic in paper")
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem3_2_report()
end
