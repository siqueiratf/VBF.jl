# Implements Proposition 6 and Table I (Section IV.E)
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: IV.E — Examples and Computation Results
#
# Pseudocode (Proposition 6):
#   For Gold F(x)=x³ over F₂ⁿ, β, b ∈ F₂ⁿ:
#     if b = β³:                              |Π_F^β(b)| = 2^{n-1}
#     elif n odd:                             |Π_F^β(b)| = 2^{n-1} - 1
#     elif n/2 odd and b+β³ is cube:         |Π_F^β(b)| = 2^{n-1} + 2^{n/2-1}
#     elif n/2 odd and b+β³ not cube:        |Π_F^β(b)| = 2^{n-1} - 2^{n/2-1} - 1
#     elif n/2 even and b+β³ is cube:        |Π_F^β(b)| = 2^{n-1} - 2^{n/2} - 1
#     else (n/2 even, not cube):             |Π_F^β(b)| = 2^{n-1} + 2^{n/2} - 1
# VBF API used: SBox, pi_multiset, sorted_pairs, gf_pow, is_cube_gf, compute_m_F

include(joinpath(@__DIR__, "helpers.jl"))

"""
    pi_formula_gold(N, β, b; modulus) -> Int

Proposition 6: exact formula for |Π_F^β(b)| when F(x) = x³ over GF(2^N).

NOTE: The published TeX has two typos verified against pi_multiset:
  1. b=β³ case: paper writes 2^{N-1}; correct value is 2^N.
  2. N even, N/2 odd, cube: paper writes 2^{N-1}+2^{N/2-1}; correct is 2^{N-1}+2^{N/2}-1.
  3. N even, N/2 even, not-cube: paper writes 2^{N-1}+2^{N/2}-1; correct is 2^{N-1}+2^{N/2-1}-1.
  m_F values (Table I) are correct since they depend only on the minimum, not the b=β³ case.
"""
function pi_formula_gold(
    N::Int,
    β::Integer,
    b::Integer;
    modulus::Integer = primitive_polynomial(N),
)
    n_half = 1 << (N - 1)  # 2^{N-1}
    β3 = gf_pow(Int(β), 3, N; modulus = Int(modulus))

    # b = β³: all 2^N directions a reach this value (paper typo: says 2^{N-1})
    Int(b) == β3 && return 1 << N

    if N % 2 == 1  # N odd
        return n_half - 1
    end

    # N even
    diff = Int(b) ⊻ β3  # b + β³ in GF(2^N)
    cube = is_cube_gf(N, diff; modulus = Int(modulus))
    half_n = N ÷ 2

    if half_n % 2 == 1  # N/2 odd (paper typo in cube branch: 2^{N/2-1} → 2^{N/2})
        return cube ? n_half + (1 << half_n) - 1 : n_half - (1 << (half_n - 1)) - 1
    else  # N/2 even (paper typo in not-cube branch: 2^{N/2} → 2^{N/2-1})
        return cube ? n_half - (1 << half_n) - 1 : n_half + (1 << (half_n - 1)) - 1
    end
end

"""
    m_F_formula_gold(N) -> Int

The minimum m_F for Gold x^3 from Proposition 6.
"""
function m_F_formula_gold(N::Int)
    n_half = 1 << (N - 1)
    N % 2 == 1 && return n_half - 1
    half_n = N ÷ 2
    half_n % 2 == 1 && return n_half - (1 << (half_n - 1)) - 1
    return n_half - (1 << half_n) - 1
end

"""
    proposition6_table1(; io, n_range) -> NamedTuple

Verify Table I: m_F and lower bounds for Gold x^3, using Proposition 6 formula.
For n ≤ 7, also verify formula against pi_multiset numerically.
"""
function proposition6_table1(; io::IO = stdout, n_range = 3:10)
    # Table I expected values
    expected = Dict(
        1 => (0, 1),
        2 => (0, 1),
        3 => (3, 2),
        4 => (3, 2),
        5 => (15, 6),
        6 => (27, 10),
        7 => (63, 22),
        8 => (111, 38),
        9 => (255, 86),
        10 => (495, 166),
    )

    print_section("Proposition 6 + Table I — Gold x^3 m_F and distance bounds", io)
    println(io, "  n   m_F(formula)   lower bound   match Table I")
    all_ok = true
    for N in n_range
        mF = m_F_formula_gold(N)
        bd = lower_bound_distance(mF)
        exp = get(expected, N, nothing)
        ok = exp === nothing || (mF == exp[1] && bd == exp[2])
        all_ok &= ok
        marker = ok ? "✓" : "✗ (exp $(exp))"
        println(io, "  $N   $mF   $bd   $marker")
    end
    print_check("Table I: all m_F values match paper (Table I is correct; Prop 6 full formula has typos)", all_ok, io)

    # Numeric verification for small n
    print_section("Proposition 6 — Formula vs pi_multiset (numeric, n ≤ 7)", io)
    num_ok = true
    for N in 3:min(maximum(n_range), 7)
        mod = primitive_polynomial(N)
        F = gold_x3(N)
        sz = 1 << N
        # Check a few (β, b) pairs
        test_cases = [(0, 0), (0, 1), (1, gf_pow(1, 3, N; modulus=mod)),
                      (3, gf_pow(3, 3, N; modulus=mod)), (5, 2)]
        mismatches = 0
        for (β, b) in test_cases
            (β >= sz || b >= sz) && continue
            formula_val = pi_formula_gold(N, β, b; modulus = mod)
            # Compute from pi_multiset: count directions a reaching b for this β
            sp = pi_multiset(F, β)
            # The formula gives |{a : b ∈ image(D_a^β F)}|, which is a key in pi_multiset
            # We need to verify the formula matches the actual count for this specific b
            # Recompute directly:
            direct_count = 0
            for a = 0:(sz-1)
                fab = Int(F.lut[(a ⊻ β)+1])
                hit = false
                for x = 0:(sz-1)
                    val = Int(F.lut[x+1]) ⊻ Int(F.lut[(x ⊻ a)+1]) ⊻ fab
                    val == b && (hit = true; break)
                end
                hit && (direct_count += 1)
            end
            formula_val != direct_count && (mismatches += 1)
        end
        ok = mismatches == 0
        num_ok &= ok
        print_check("n=$N: formula matches direct count ($(length(test_cases)) cases)", ok, io)
    end

    (; all_ok = all_ok && num_ok, formula_ok = all_ok, numeric_ok = num_ok)
end

function proposition6_report(; io::IO = stdout)
    print_header(io)
    r = proposition6_table1(; io)
    return r
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition6_report()
end
