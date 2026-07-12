# Implements Lemma 3 and Theorem 4 (Family F2) from Calderini, Li, Villa (2023).
# Paper: Calderini, Li, Villa (2023), "Extending two families of bivariate APN functions",
#        Finite Fields and Their Applications.
# Section: 4 — A family of APN functions from Dillon's method
#
# Pseudocode (theorem4_build):
#   For each m:
#     1. Find alpha with x^3+x+alpha having no root in F_{2^m}  (k=1 always)
#     2. Lemma 3(i): verify tr_m(1/alpha^2) = tr_m(1)
#     3. Lemma 3(ii): verify eq.(5) has unique solution (a,b)=(alpha,1)
#     4. Build F2 LUT via family_f2_lut(m, alpha)
#     5. Check differential_uniformity(F2) == 2
# Pseudocode (lemma2_build):
#   Exhaustively verify Williams' cubic criterion [30] over F_{2^m} (embedded
#   as the subfield of F_{2^{2m}}, where the roots of h(t) live): for all a and
#   b != 0, the root count of f(z)=z^3+az+b matches the trichotomy given by
#   tr_m(a^3/b^2) and the cube-ness of the roots of h(t)=t^2+bt+a^3
# VBF API used: gf_mul, gf_pow, gf_inv, gf_trace, gf_is_dth_power,
#               subfield_elements, differential_uniformity, SBox,
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

const THEOREM4_CASES = [
    (m=3, note="3|m novel case (Theorem 4 extends Li et al. [28])"),
    (m=4, note="gcd(3,4)=1 standard case (same as [28])"),
]

const LEMMA2_CASES = [3, 4, 5]           # odd and even m, kept exhaustive-fast

# Lemma 2 ([30], Williams). For b != 0, f(z) = z^3 + az + b has over F_{2^m}
#   exactly 1 root  iff  tr_m(a^3/b^2) != tr_m(1);
#   3 roots (resp. 0)  iff  tr_m(a^3/b^2) == tr_m(1) and the roots t_1, t_2 of
#     h(t) = t^2 + bt + a^3 are cubes (resp. non-cubes) in F_{2^m} when m is
#     even, in F_{2^{2m}} when m is odd.
# Everything is computed inside F_{2^{2m}}, with F_{2^m} as its subfield (the
# roots of h always lie in F_{2^{2m}}).
function lemma2_build(m::Int; modulus::Int = primitive_polynomial(2 * m))
    n = 2 * m
    mul_(x, y) = gf_mul(x, y, n; modulus = modulus)
    pow_(x, e) = gf_pow(x, e, n; modulus = modulus)
    inv_(x)    = gf_inv(x, n; modulus = modulus)
    # absolute trace of F_{2^m}, evaluated inside the F_{2^{2m}} representation
    function trm(x)
        acc, t = 0, x
        for _ in 1:m
            acc ⊻= t
            t = mul_(t, t)
        end
        acc                              # 0 or 1 for x in the subfield
    end
    # "cube" in the field prescribed by the lemma
    cube(t) = isodd(m) ? gf_is_dth_power(t, 3, n; modulus = modulus) :
              (t == 0 || pow_(t, ((1 << m) - 1) ÷ 3) == 1)

    S = subfield_elements(n, m; modulus = modulus)
    tr1 = m % 2                          # tr_m(1) = m mod 2
    checked, ok = 0, true
    tallies = Dict{Int,Int}(0 => 0, 1 => 0, 3 => 0)
    for a in S, b in S
        b == 0 && continue
        a3 = pow_(a, 3)
        nroots = count(z -> pow_(z, 3) ⊻ mul_(a, z) ⊻ b == 0, S)
        tr = trm(mul_(a3, inv_(mul_(b, b))))
        predicted = if tr != tr1
            1
        else
            hroots = [t for t in 0:(1 << n)-1 if mul_(t, t) ⊻ mul_(b, t) ⊻ a3 == 0]
            all(cube, hroots) ? 3 : 0
        end
        ok &= (nroots == predicted)
        tallies[nroots] = get(tallies, nroots, 0) + 1
        checked += 1
    end
    (; m, checked, ok, tallies)
end

function lemma3_build(m::Int, alpha::Int; modulus::Int = primitive_polynomial(m))
    mul_(a, b) = gf_mul(a, b, m; modulus = modulus)
    pow_(a, e) = gf_pow(a, e, m; modulus = modulus)
    inv_(a)    = gf_inv(a, m; modulus = modulus)

    # Lemma 3(i): tr_m(1/alpha^2) = tr_m(1)
    alpha2     = mul_(alpha, alpha)
    inv_alpha2 = inv_(alpha2)
    tr_inv_a2  = gf_trace(inv_alpha2, m; modulus = modulus)
    tr_1       = gf_trace(1, m; modulus = modulus)
    lem_i = (tr_inv_a2 == tr_1)

    # Lemma 3(ii): equation (5) has only solution (a,b)=(alpha,1) in F_{2^m}^2
    # Eq(5): a^3 + alpha*b*a^2 + (alpha^2*b^2+b^2+1)*a + alpha^3*b^3 + alpha*b^2 + alpha = 0
    alpha3 = mul_(alpha2, alpha)
    len = 1 << m
    solutions = Tuple{Int,Int}[]
    for a in 0:len-1
        a2 = mul_(a, a); a3 = mul_(a2, a)
        for b in 0:len-1
            b2 = mul_(b, b); b3 = mul_(b2, b)
            coeff_a = mul_(alpha2, b2) ⊻ b2 ⊻ 1
            val = a3 ⊻ mul_(alpha, mul_(b, a2)) ⊻ mul_(coeff_a, a) ⊻
                  mul_(alpha3, b3) ⊻ mul_(alpha, b2) ⊻ alpha
            val == 0 && push!(solutions, (a, b))
        end
    end
    lem_ii = (solutions == [(alpha, 1)])

    (; lem_i, lem_ii, tr_inv_a2, tr_1, solutions)
end

function theorem4_build()
    results = NamedTuple[]
    for (; m, note) in THEOREM4_CASES
        modulus = primitive_polynomial(m)
        alpha   = find_alpha(m, 1; modulus = modulus)
        @assert alpha !== nothing "No valid alpha found for m=$m"

        lem = lemma3_build(m, alpha; modulus = modulus)
        F   = family_f2_lut(m, alpha; modulus = modulus)
        du  = differential_uniformity(F)

        push!(results, (; m, alpha, note,
                         lem_i   = lem.lem_i,
                         lem_ii  = lem.lem_ii,
                         tr_inv  = lem.tr_inv_a2,
                         tr_1    = lem.tr_1,
                         du,
                         apn     = du == 2))
    end
    results
end

function theorem4_report(io::IO = stdout)
    print_section("Theorem 4 — Family F2 (Section 4)", io)
    println(io, "  Construction (k=1, q=2): F(x,y)=(x^3+xy+xy^2+a*y^3, x^5+xy+a*x^2y^2+a*x^4y+(1+a)^2*xy^4+a*y^5)")
    println(io, "  Condition: x^3+x+alpha has no root in F_{2^m}")
    println(io, "  Extends Li et al. [28] (which required gcd(3,m)=1) to all m")

    print_section("Lemma 2 verification (Williams [30])", io)
    println(io, "  Root count of z^3+az+b vs tr_m(a^3/b^2) / cube trichotomy,")
    println(io, "  exhaustive over F_{2^m} x F_{2^m}^* for m in $(LEMMA2_CASES)")
    for m in LEMMA2_CASES
        r2 = lemma2_build(m)
        print_check("Lemma 2 m=$m ($(r2.checked) pairs; roots 0/1/3: " *
                    "$(r2.tallies[0])/$(r2.tallies[1])/$(r2.tallies[3]))", r2.ok, io)
    end

    print_section("Lemma 3 verification", io)
    println(io, "  (i): tr_m(1/alpha^2) = tr_m(1)")
    println(io, "  (ii): equation (5) has unique solution (a,b)=(alpha,1)")

    results = theorem4_build()
    all_apn = true
    for r in results
        print_kv("m=$(r.m) alpha=$(r.alpha)", r.note, io)
        print_check("Lemma 3(i) tr(1/a^2)=$(r.tr_inv)==tr(1)=$(r.tr_1)", r.lem_i, io)
        print_check("Lemma 3(ii) eq.(5) unique solution ($(r.alpha),1)", r.lem_ii, io)
        print_check("F2 APN (du=2)", r.apn, io)
        all_apn = all_apn && r.apn
    end
    print_check("all F2 cases APN", all_apn, io)
    println(io, "  completeness: exhaustive — all listed m values verified")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_banner()
    theorem4_report()
end
