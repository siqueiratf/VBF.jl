# Implements Lemma 1 and Theorem 3 (Family F1) from Calderini, Li, Villa (2023).
# Paper: Calderini, Li, Villa (2023), "Extending two families of bivariate APN functions",
#        Finite Fields and Their Applications.
# Section: 3 — A family of biprojective APN functions over F_{2^{2m}}
#
# Pseudocode (theorem3_build):
#   For each (m, k) case:
#     1. Find alpha with phi_{q,alpha} = x^{q+1}+x+alpha having no root in F_{2^m}
#     2. Lemma 1(i): verify alpha^2 also has no root
#     3. Lemma 1(ii): verify L(x)=x^{q2}+x^q+alpha*x is a permutation of F_{2^m}
#     4. Build F1 LUT via family_f1_lut(m, k, alpha)
#     5. Check differential_uniformity(F1) == 2
# VBF API used: gf_mul, gf_pow, gf_trace, is_permutation, differential_uniformity, SBox,
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

const THEOREM3_CASES = [
    (m=3, k=1, note="3|m novel case (Theorem 3 extends Gologlu F1)"),
    (m=4, k=1, note="gcd(3,4)=1 standard case"),
    (m=4, k=3, note="gcd(3,4)=1 different k"),
]

function lemma1_build(m::Int, k::Int, alpha::Int;
                      modulus::Int = primitive_polynomial(m))
    q  = 1 << k
    q2 = 1 << (2 * k)
    mul_(a, b) = gf_mul(a, b, m; modulus = modulus)
    pow_(a, e) = gf_pow(a, e, m; modulus = modulus)

    # (i): alpha^2 also has no root
    alpha2  = mul_(alpha, alpha)
    lem_i   = has_no_root_projective(m, k, alpha; modulus = modulus) &&
               has_no_root_projective(m, k, alpha2; modulus = modulus)

    # (ii): phi no root <=> L(x) = x^{q2}+x^q+alpha*x is a permutation
    len = 1 << m
    L_lut = [pow_(x, q2) ⊻ pow_(x, q) ⊻ mul_(alpha, x) for x in 0:len-1]
    lem_ii = is_permutation(SBox{m}(L_lut))

    (; lem_i, lem_ii, alpha2)
end

function theorem3_build()
    results = NamedTuple[]
    for (; m, k, note) in THEOREM3_CASES
        modulus = primitive_polynomial(m)
        alpha   = find_alpha(m, k; modulus = modulus)
        @assert alpha !== nothing "No valid alpha found for m=$m, k=$k"

        lem = lemma1_build(m, k, alpha; modulus = modulus)
        F   = family_f1_lut(m, k, alpha; modulus = modulus)
        du  = differential_uniformity(F)

        push!(results, (; m, k, alpha, note,
                         lem_i   = lem.lem_i,
                         lem_ii  = lem.lem_ii,
                         alpha2  = lem.alpha2,
                         du,
                         apn     = du == 2))
    end
    results
end

function theorem3_report(io::IO = stdout)
    print_section("Theorem 3 — Family F1 (Section 3)", io)
    println(io, "  Construction: F(x,y)=(x^{q+1}+xy^q+alpha*y^{q+1}, x^{q2+1}+...)")
    println(io, "  Condition: gcd(k,m)=1, phi_{q,alpha} = x^{q+1}+x+alpha has no root in F_{2^m}")
    println(io, "  Extends Gologlu F1 (which required gcd(3k,m)=1) to all m")

    print_section("Lemma 1 verification", io)
    println(io, "  (i): phi_{q,alpha} no-root => phi_{q,alpha^2} no-root")
    println(io, "  (ii): phi_{q,alpha} no-root <=> L(x)=x^{q2}+x^q+alpha*x is permutation")

    results = theorem3_build()
    all_apn = true
    for r in results
        print_kv("m=$(r.m) k=$(r.k) alpha=$(r.alpha)", r.note, io)
        print_check("Lemma 1(i) alpha=$(r.alpha) alpha2=$(r.alpha2) both no-root", r.lem_i, io)
        print_check("Lemma 1(ii) L(x) permutation", r.lem_ii, io)
        print_check("F1 APN (du=2)", r.apn, io)
        all_apn = all_apn && r.apn
    end
    print_check("all F1 cases APN", all_apn, io)
    println(io, "  completeness: exhaustive — all listed (m,k) pairs verified")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_banner()
    theorem3_report()
end
