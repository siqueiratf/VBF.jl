# Implements Theorem III.2 — biprojective APN families F1, F2, F3.
# Paper: Gologlu, F. (2022), "Biprojective Almost Perfect Nonlinear Functions",
#        IEEE Transactions on Information Theory
# Section: III.B — The New Biprojective APN Functions; V — Families F1, F2, F3
#
# Pseudocode:
#   F1: [(1,0,1,1)_{2^i}, (1,1,0,1)_{2^{2i}}] on F_{2^m}×F_{2^m}, gcd(3i,m)=1
#   F2: [(1,0,1,1)_{2^i}, (0,1,1,0)_{2^{3i}}] on F_{2^m}×F_{2^m}, gcd(3i,m)=1, m odd
#   F3: [(0,1,1,0)_2, (1,u,u^3,u^13)_{2^3}] on F_{2^5}×F_{2^5}, u=prim. elem.
#
#   Verification: differential_uniformity(F) == 2 for each constructed function.
# VBF API used: biprojective_sbox, differential_uniformity, algebraic_degree,
#               gf_pow, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))
using Dates

"""
    f1_sbox(m, i; modulus) -> SBox{2m}

Family F1: [(1,0,1,1)_{2^i}, (1,1,0,1)_{2^{2i}}] on GF(2^m)×GF(2^m).
Requires gcd(3i, m) = 1.
"""
function f1_sbox(m::Int, i::Int; modulus::Int = primitive_polynomial(m))
    gcd(3i, m) == 1 || throw(ArgumentError("f1_sbox: need gcd(3i, m) = 1, got i=$i, m=$m"))
    biprojective_sbox(m, i, (1, 0, 1, 1), 2i, (1, 1, 0, 1); modulus)
end

"""
    f2_sbox(m, i; modulus) -> SBox{2m}

Family F2: [(1,0,1,1)_{2^i}, (0,1,1,0)_{2^{3i}}] on GF(2^m)×GF(2^m).
Requires gcd(3i, m) = 1 and m odd.
"""
function f2_sbox(m::Int, i::Int; modulus::Int = primitive_polynomial(m))
    isodd(m) || throw(ArgumentError("f2_sbox: m must be odd, got m=$m"))
    gcd(3i, m) == 1 || throw(ArgumentError("f2_sbox: need gcd(3i, m) = 1, got i=$i, m=$m"))
    biprojective_sbox(m, i, (1, 0, 1, 1), 3i, (0, 1, 1, 0); modulus)
end

"""
    f3_sbox(; modulus) -> SBox{10}

Sporadic function F3 on GF(2^5)×GF(2^5), m=5.
u is the primitive element of GF(2^5) (root of x^5+x^2+1).
F3 = [(0,1,1,0)_2, (1,u,u^3,u^13)_{2^3}].
"""
function f3_sbox(; modulus::Int = primitive_polynomial(5))
    m = 5
    u = 2  # primitive element of GF(2^5) with mod x^5+x^2+1
    u3  = gf_pow(u, 3,  m; modulus)   # u^3
    u13 = gf_pow(u, 13, m; modulus)   # u^13
    biprojective_sbox(m, 1, (0, 1, 1, 0), 3, (1, u, u3, u13); modulus)
end

"""
    theorem3_2_report(; io, m_values, limit) -> NamedTuple

Verify Theorem III.2: F1, F2, F3 are APN.
Checks differential_uniformity == 2 and algebraic_degree == 2 for each.
"""
function theorem3_2_report(;
    io::IO = stdout,
    m_values::Vector{Int} = [3, 5],
    limit::Int = typemax(Int),
)
    print_section("Theorem III.2 — APN verification for F1, F2, F3", io)

    all_ok = true
    results = Dict{String,Bool}()

    for m in m_values
        n = 2m
        candidates_i = [i for i = 1:(m-1) if gcd(3i, m) == 1]
        candidates_i = candidates_i[1:min(limit, length(candidates_i))]

        for i in candidates_i
            # Family F1
            F1 = f1_sbox(m, i)
            ok1 = differential_uniformity(F1) == 2 && algebraic_degree(F1) == 2
            label = "F1 m=$m i=$i  APN+quadratic"
            print_check(label, ok1, io)
            results["F1_m$(m)_i$(i)"] = ok1
            all_ok &= ok1

            # Family F2 (m odd only)
            if isodd(m)
                F2 = f2_sbox(m, i)
                ok2 = differential_uniformity(F2) == 2 && algebraic_degree(F2) == 2
                label2 = "F2 m=$m i=$i  APN+quadratic"
                print_check(label2, ok2, io)
                results["F2_m$(m)_i$(i)"] = ok2
                all_ok &= ok2
            end
        end
    end

    # Sporadic F3 (m=5 only)
    F3 = f3_sbox()
    ok3 = differential_uniformity(F3) == 2 && algebraic_degree(F3) == 2
    print_check("F3 m=5  APN+quadratic (verified by computer per paper)", ok3, io)
    results["F3_m5"] = ok3
    all_ok &= ok3

    println(io)
    print_check("All Theorem III.2 instances verified", all_ok, io)
    (; all_ok, results)
end

if abspath(PROGRAM_FILE) == @__FILE__
    include(joinpath(@__DIR__, "helpers.jl"))
    theorem3_2_report()
end
