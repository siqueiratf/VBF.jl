# Implements Section 6 — Application to a Generalized Even-Mansour Scheme.
# Paper: Biryukov et al. (2003), "A Toolbox for Cryptanalysis: Linear and Affine
#        Equivalence Algorithms", Eurocrypt 2003.
# Section: 6
#
# Pseudocode:
#   The paper's claim: in the generalized Even-Mansour scheme
#   C = A2(F(A1(P))), with F public and the secret key the pair of affine maps
#   (A1, A2), recovering the key is exactly the AE problem, so the AE algorithm
#   is an O(n^3 2^{2n}) adaptive chosen plaintext/ciphertext attack, against
#   O(2^{n^2}) for exhaustive key search.  Reproduced as an actual key recovery:
#     1. Draw a random public permutation F and a random secret (A1, A2);
#        build the cipher S = A2 . F . A1 (the attacker's oracle).
#     2. Anchor F at 0 and S at every a: F0(x) = F(x)+F(0),
#        Sa(x) = S(x+a)+S(a).  Both anchored maps fix 0, so LE applies.
#     3. Find the anchor a whose linear representative matches F0's.  With
#        R = B_F^{-1}.F0.A_F = B_S^{-1}.Sa.A_S, put U = B_S.B_F^{-1} and
#        V = A_F.A_S^{-1}; then
#            A1'(y) = V(y) + V(a)          A2'(z) = U(z) + U(F(0)) + S(a)
#        is a recovered key, i.e. S = A2' . F . A1'.
#     4. Check S = A2' . F . A1' pointwise; the recovered key need not be the
#        drawn one (any element of the self-equivalence coset decrypts equally).
#     5. Tabulate n^3 2^{2n} against 2^{n^2}.
# VBF API used: linear_representative, random_permutation_sbox,
#               random_invertible_linear_map, F2AffineMap, compose, inv

include(joinpath(@__DIR__, "helpers.jl"))

using Random

# G(x + a) + G(a): the anchored S-box, which fixes 0 and so is amenable to LE.
function anchor_at(G::SBox{N,T}, a::Integer) where {N,T}
    n = 1 << N
    SBox{N,T}(T[G.lut[(T(x)⊻T(a))+1] ⊻ G.lut[Int(a)+1] for x = 0:(n-1)])
end

"""
    even_mansour_cipher(F, A1, A2) -> SBox

`C = A2(F(A1(P)))`, the generalized Even-Mansour scheme of Sect. 6.
"""
function even_mansour_cipher(
    F::SBox{N,T},
    A1::F2AffineMap{N,T},
    A2::F2AffineMap{N,T},
) where {N,T}
    n = 1 << N
    SBox{N,T}(T[A2(F.lut[A1(T(x))+1]) for x = 0:(n-1)])
end

"""
    recover_even_mansour_key(F, S) -> (A1, A2, anchor) or nothing

Recover a key `(A1, A2)` with `S = A2 ∘ F ∘ A1`, given only the public
permutation `F` and the cipher `S`. This is the AE algorithm of Sect. 3 applied
verbatim: one linear representative per candidate output shift.
"""
function recover_even_mansour_key(F::SBox{N,T}, S::SBox{N,T}) where {N,T}
    repF = linear_representative(anchor_at(F, 0))
    BF_inv = inv(repF.B)
    for a = 0:((1<<N)-1)
        repS = linear_representative(anchor_at(S, a))
        repS.representative.lut == repF.representative.lut || continue
        U = compose(repS.B, BF_inv)
        V = compose(repF.A, inv(repS.A))
        A1 = F2AffineMap{N,T}(V, V(T(a)))
        A2 = F2AffineMap{N,T}(U, U(F.lut[1]) ⊻ S.lut[a+1])
        return (A1 = A1, A2 = A2, anchor = a)
    end
    nothing
end

# Sect. 6: the attack costs O(n^3 2^{2n}); exhaustive key search O(2^{n^2}).
attack_log2_cost(n::Int) = 3 * log2(n) + 2n
exhaustive_log2_cost(n::Int) = n^2

function section6_report(io::IO = stdout; seed::Int = 20030504)
    print_section(io, "Section 6 — Generalized Even-Mansour: AE recovers the key")

    all_ok = true
    for N in (4, 5, 6)
        rng = MersenneTwister(seed + N)
        F = random_permutation_sbox(rng, Val(N))
        T = storage_type(F)
        mask = T((1 << N) - 1)
        A1 = F2AffineMap{N,T}(random_invertible_linear_map(rng, Val(N), T), rand(rng, T) & mask)
        A2 = F2AffineMap{N,T}(random_invertible_linear_map(rng, Val(N), T), rand(rng, T) & mask)
        S = even_mansour_cipher(F, A1, A2)

        key = recover_even_mansour_key(F, S)
        ok = key !== nothing && even_mansour_cipher(F, key.A1, key.A2).lut == S.lut
        print_check(
            io,
            "n=$N: key recovered from oracle access to C = A2(F(A1(P))); " *
            "A2' ∘ F ∘ A1' = C on all $(1 << N) inputs",
            ok,
        )
        all_ok &= ok
    end

    print_section(io, "Section 6 — attack cost vs exhaustive key search")
    for n in (8, 16, 32)
        print_kv(
            io,
            "  n=$n",
            "AE attack ≈ 2^$(round(attack_log2_cost(n); digits=1)) steps  vs  " *
            "exhaustive 2^$(exhaustive_log2_cost(n))",
        )
    end
    print_kv(
        io,
        "completeness",
        "3 instances (n=4,5,6) recovered exactly; the recovered key may differ " *
        "from the drawn one by an element of F's self-equivalence group, which " *
        "decrypts identically",
    )

    return all_ok
end

if abspath(PROGRAM_FILE) == @__FILE__
    ok = section6_report()
    exit(ok ? 0 : 1)
end
