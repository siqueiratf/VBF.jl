# Implements Theorem 3.3 Case iii — new infinite family F15 of APN functions.
# Paper: Zheng, Kan, Li, Peng, Tang (2022), "Constructing new APN functions through
#        relative trace functions", arXiv:2101.11535v1 [cs.IT]
# Section: 3A — Case iii of Theorem 3.3 and Table II (new family F15)
#
# Pseudocode:
#   Choose m odd with gcd(3,m)=1, a ∉ F_{2^m}, b non-cube, c=b³ (c/b³=1∈F*_{2^m}).
#   Build F15: f₃(x) = a·Tr_m^n(b·x³) + a^q·Tr_m^n(b³·x⁹)  [s=3]
#   Verify:
#     1. Parameter conditions from Theorem 3.3 Case iii.
#     2. differential_uniformity(F15) == 2 (APN).  n=10: full DDT; n=14: streaming.
#     3. EA-mugshot ≠ mugshot of any catalog APN function at n=10 (CCZ-inequivalence proxy).
# VBF API used: gf_pow, gf_mul, primitive_polynomial, SBox, differential_uniformity,
#               apn_ea_mugshot, in_subfield, is_cube, f15_sbox,
#               differential_uniformity_rowwise

include(joinpath(@__DIR__, "helpers.jl"))
using VBF
using VBFCatalog

"""
    verify_f15_conditions(m, a, b; modulus) -> NamedTuple

Check all parameter conditions for Theorem 3.3 Case iii (new family F15):
  1. m is odd
  2. gcd(3, m) == 1
  3. a ∉ F_{2^m}  (a is not in the subfield)
  4. b is non-cube in F_{2^n}*  (b^{(2^n-1)/3} ≠ 1)
  5. c/b³ = 1 ∈ F*_{2^m}  (holds by construction c = b³)
"""
function verify_f15_conditions(m::Int, a::Int, b::Int;
                                modulus::Int = primitive_polynomial(2m))
    n  = 2m
    c  = gf_pow(b, 3, n; modulus)
    cond_m_odd    = isodd(m)
    cond_gcd3m    = gcd(3, m) == 1
    cond_a_not_sf = !in_subfield(a, m, n; modulus)
    cond_b_noncube = !is_cube(b, n; modulus)
    # c/b³ = 1 by construction; verify 1 ∈ F*_{2^m}
    cond_ratio_sf = in_subfield(1, m, n; modulus)
    all_ok = cond_m_odd & cond_gcd3m & cond_a_not_sf & cond_b_noncube & cond_ratio_sf
    (; all_ok, cond_m_odd, cond_gcd3m, cond_a_not_sf, cond_b_noncube, cond_ratio_sf, c)
end

"""
    theorem3_3_apn_check(m; a, b, streaming, io) -> NamedTuple

Build F15 at n=2m and verify APN.  For n ≤ 12 uses full DDT; for n ≥ 13 uses
the streaming row-by-row DDT to avoid out-of-memory.
"""
function theorem3_3_apn_check(m::Int;
                               a::Int       = 2,
                               b::Int       = 2,
                               streaming::Bool = (2m >= 13),
                               io::IO       = stdout)
    n       = 2m
    modulus = primitive_polynomial(n)
    F       = f15_sbox(m; a, b, modulus)
    du = streaming ? differential_uniformity_rowwise(F) : differential_uniformity(F)
    method_tag = streaming ? "streaming row-by-row DDT" : "full DDT"
    is_apn = du == 2
    print_kv("n=$(n) differential_uniformity [$(method_tag)]", du, io)
    print_check("F15 is APN at n=$(n)", is_apn, io)
    (; n, du, is_apn, streaming)
end

"""
    table2_mugshot_comparison(m; a, b, io) -> NamedTuple

Compute the EA-mugshot of F15 at n=2m and compare with all catalog quadratic APN
functions at the same n.  A mugshot mismatch is a necessary condition for
CCZ-inequivalence; equal mugshots are inconclusive.
"""
function table2_mugshot_comparison(m::Int;
                                   a::Int  = 2,
                                   b::Int  = 2,
                                   io::IO  = stdout)
    n       = 2m
    modulus = primitive_polynomial(n)
    F15     = f15_sbox(m; a, b, modulus)
    m15     = apn_ea_mugshot(F15)

    db      = load_catalog()
    rows    = filter(r -> r.is_quadratic, list_functions(db; is_apn = true, n = n))
    n_cat   = length(rows)
    n_match = 0
    for r in rows
        G  = load_sbox(db, r.canonical_name)
        mG = apn_ea_mugshot(G)
        mG == m15 && (n_match += 1)
    end
    distinct = n_match == 0
    print_kv("catalog quadratic APN at n=$(n)", n_cat, io)
    print_kv("mugshot matches in catalog", n_match, io)
    print_check(
        "F15 EA-mugshot distinct from all catalog n=$(n) APN [CCZ-inequiv proxy]",
        distinct, io)
    (; distinct_from_all = distinct, n_catalog = n_cat, n_match)
end

"""
    theorem3_3_report(io::IO = stdout; m_values, a, b, save_results) -> NamedTuple

Verify Theorem 3.3 Case iii conditions, APN property, and CCZ-inequivalence
proxy via EA-mugshot comparison with catalog.
"""
function theorem3_3_report(io::IO = stdout;
                            m_values::Vector{Int} = [5, 7],
                            a::Int               = 2,
                            b::Int               = 2,
                            save_results::Bool   = false)
    print_section("Theorem 3.3 Case iii — New infinite family F15", io)
    println(io, "  f₃(x) = a·Tr_m^n(b·x³) + a^q·Tr_m^n(b³·x⁹), s=3, c=b³")

    per_n       = Dict{Int,NamedTuple}()
    all_cond_ok = true
    all_apn_ok  = true

    for m in m_values
        n = 2m
        print_kv("\nn", n, io)
        modulus = primitive_polynomial(n)
        c = gf_pow(b, 3, n; modulus)
        print_kv("  b", b, io)
        print_kv("  c = b³", c, io)

        r_cond = verify_f15_conditions(m, a, b; modulus)
        print_check("Parameter conditions (m odd, gcd(3,m)=1, a∉F_q, b non-cube, c/b³∈F*_q)",
                    r_cond.all_ok, io)
        all_cond_ok &= r_cond.all_ok

        r_apn = theorem3_3_apn_check(m; a, b, io)
        all_apn_ok &= r_apn.is_apn

        per_n[n] = merge(r_cond, r_apn)
    end

    # EA-mugshot / CCZ-inequivalence at n=10 (m=5) only
    r_ccz = nothing
    m_mugshot = 5
    if m_mugshot in m_values
        print_section("Table II — CCZ-inequivalence via EA-mugshot (n=$(2m_mugshot))", io)
        r_ccz = table2_mugshot_comparison(m_mugshot; a, b, io)
    end

    print_section("Theorem 3.3 summary", io)
    print_check("All parameter conditions", all_cond_ok, io)
    print_check("F15 APN at all tested n", all_apn_ok, io)

    println(io, "\n  Scope:")
    println(io, "    exact: APN at n=10 (full DDT)")
    println(io, "    exact: APN at n=14 (streaming DDT, avoids OOM)")
    println(io, "    partial: CCZ-inequivalence via EA-mugshot at n=10")
    println(io, "    out-of-scope: CCZ-inequivalence at n=14 (full sboxU code-isomorphism test)")

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "theorem3_3.toml"), "w") do f
            println(f, "# Theorem 3.3 Case iii (F15) results")
            println(f, "all_conditions_ok = $(all_cond_ok)")
            println(f, "all_apn_ok = $(all_apn_ok)")
            for (n, r) in per_n
                println(f, "n$(n)_du = $(r.du)")
                println(f, "n$(n)_is_apn = $(r.is_apn)")
            end
        end
    end

    (; all_cond_ok, all_apn_ok, per_n, ccz = r_ccz)
end
