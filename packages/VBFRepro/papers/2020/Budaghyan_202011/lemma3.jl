# Implements Lemma 3 from Section 3.
# Paper: Budaghyan, Helleseth, Kaleyski (2020), "A New Family of APN Quadrinomials",
#        IEEE Trans. Inf. Theory 66(11):7081–7087
# Section: 3 — Lemma 3 (tex:244)
#
# Lemma 3: let m, i be positive with gcd(m, i) = 1 and S ∈ GF(2^m) \ {0, 1}. Then
#
#   P(N) = (S^(2^i) + S)·N^(2^(2i)) + (S^(2^(2i)) + S)·N^(2^i) + (S^(2^(2i)) + S^(2^i))·N
#
# has exactly the four roots N ∈ {0, 1, S, S+1}.
#
# Pseudocode:
#   1. For each S ∈ GF(2^m) \ {0,1}, build the coefficients of P
#   2. Enumerate every N ∈ GF(2^m) and collect the roots of P
#   3. Check the root set equals {0, 1, S, S+1} — exactly four, no more, no fewer
# VBF API used: gf_pow, gf_mul, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

"""
    lemma3_roots(m, i, S; modulus) -> Vector{Int}

The roots in GF(2^m) of Lemma 3's linearised polynomial P(N), by exhaustive
evaluation over the whole field.
"""
function lemma3_roots(m::Int, i::Int, S::Int; modulus::Int = primitive_polynomial(m))
    s_i  = gf_pow(S, 1 << i,       m; modulus)
    s_2i = gf_pow(S, 1 << (2 * i), m; modulus)
    c1 = s_i  ⊻ S      # S^(2^i)   + S
    c2 = s_2i ⊻ S      # S^(2^2i)  + S
    c3 = s_2i ⊻ s_i    # S^(2^2i)  + S^(2^i)
    P(N) =
        gf_mul(c1, gf_pow(N, 1 << (2 * i), m; modulus), m; modulus) ⊻
        gf_mul(c2, gf_pow(N, 1 << i,       m; modulus), m; modulus) ⊻
        gf_mul(c3, N, m; modulus)
    [N for N in 0:((1 << m) - 1) if P(N) == 0]
end

"""
    lemma3_holds(m, i; modulus) -> Bool

True iff, for every S ∈ GF(2^m) \\ {0,1}, the root set of P is exactly
{0, 1, S, S+1}. Requires gcd(m, i) = 1 (Lemma 3's hypothesis).
"""
function lemma3_holds(m::Int, i::Int; modulus::Int = primitive_polynomial(m))
    gcd(m, i) == 1 || error("Lemma 3 requires gcd(m,i)=1, got m=$m i=$i")
    all(2:((1 << m) - 1)) do S
        Set(lemma3_roots(m, i, S; modulus)) == Set([0, 1, S, S ⊻ 1])
    end
end

function lemma3_report(io::IO = stdout; ms = (5, 7))
    print_section("Lemma 3: P(N) has exactly the roots {0, 1, S, S+1}", io)
    println(io, "  P(N) = (S^2^i+S)·N^2^2i + (S^2^2i+S)·N^2^i + (S^2^2i+S^2^i)·N")
    println(io, "  over GF(2^m), for gcd(m,i)=1 and S ∉ {0,1}.  [tex:244]")
    for m in ms
        for i in 1:(m - 1)
            gcd(i, m) == 1 || continue
            ok = lemma3_holds(m, i)
            print_check("m=$m, i=$i: all $(2^m - 2) values of S give root set {0,1,S,S+1}",
                        ok, io)
        end
    end
    # Non-vacuity: the count is exactly 4 and P is not the zero polynomial —
    # a P that vanished identically would also "contain" {0,1,S,S+1}.
    m, i, S = 5, 1, 3
    roots = lemma3_roots(m, i, S)
    print_check("Non-vacuity (m=5,i=1,S=3): |roots| = $(length(roots)) = 4 < 2^5 = 32, so P ≢ 0",
                length(roots) == 4, io)
end
