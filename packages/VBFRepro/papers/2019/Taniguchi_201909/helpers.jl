using Dates
using VBF

function print_header(io::IO = stdout)
    print_banner(
        io,
        "Taniguchi (2019), \"On some quadratic APN functions\"",
        "Julia $(VERSION)  |  $(today())";
        width = 70,
    )
    println(io)
    println(io, "Scope:")
    println(io, "  [exact]  Section 2: Carlet Thm 1 + Zhou-Pott Cor 1 (small n)")
    println(io, "  [exact]  Corollary 2: normalization of Carlet Thm 1 to a'∈{0,1}")
    println(io, "  [exact]  Fact (Helleseth-Kholosha): rootless-b count n=5,6,7")
    println(io, "  [exact]  Theorem 3: APN iff P(x) rootless (half=4,5)")
    println(io, "  [exact]  Theorem 3: headline claim — the a≠0 classes are new on F₂⁸")
    println(io, "  [exact]  Theorem 4: F₃(x,y) = F₄(x^{2^{2m}}, y), all (a,b)")
    println(io, "  [exact]  Theorem 5: presemifield no-zero-divisors (GF(2⁴)/GF(2²))")
    println(io, "  [loaded] Γ-ranks 13200/13642/13700/13798 on F₂⁸ (Magma, paper Table)")
    println(io, "  [skip]   Theorem 6: nuclei ≅ K — needs [F:K] ≥ 3, and the only")
    println(io, "           characteristic-2 instance VBF can express has [F:K] = 2;")
    println(io, "           the paper's ≥3 instances are odd-characteristic (p=3),")
    println(io, "           which VBF's GF machinery does not represent.")
    println(io)
end

# ── The paper's one admissibility test, implemented once ──────────────────────
#
# Theorem 1, Corollary 2, Fact 1, Theorem 3, Theorem 4 and Theorem 5 all turn on
# the same question: "does this projective polynomial have a root in GF(2ⁿ)?".
# Carlet's G(x,1) is the general shape; the projective polynomial P(x) of the
# other five is its (i,j,s,u,v,t) = (m,0,1,0,a,b) specialization. Both live here
# so the loop exists exactly once in this directory.
#
# (VBF has a private `_taniguchi_admissible` doing the projective case; promoting
#  it to a public `projective_polynomial_rootless` is the core-library follow-up
#  recorded in the README's "Library-reuse note".)

"""
    carlet_G1_rootless(n, i, j, s, u, v, t; modulus=primitive_polynomial(n)) -> Bool

`true` iff Carlet's `G(x, 1) = s·x^{2^i+2^j} + u·x^{2^i} + v·x^{2^j} + t` has **no**
root in `GF(2ⁿ)` — the APN criterion of Theorem 1.
"""
function carlet_G1_rootless(
    n::Int,
    i::Int,
    j::Int,
    s::Int,
    u::Int,
    v::Int,
    t::Int;
    modulus::Int = primitive_polynomial(n),
)
    E1 = (1 << i) + (1 << j)
    for x = 0:(1<<n)-1
        Gx1 =
            gf_mul(s, gf_pow(x, E1, n; modulus), n; modulus) ⊻
            gf_mul(u, gf_pow(x, 1 << i, n; modulus), n; modulus) ⊻
            gf_mul(v, gf_pow(x, 1 << j, n; modulus), n; modulus) ⊻ t
        Gx1 == 0 && return false
    end
    true
end

"""
    projective_polynomial_rootless(n, m, a, b; modulus=primitive_polynomial(n)) -> Bool

`true` iff the projective polynomial `P(x) = x^{2^m+1} + a·x + b` (Bluher) has **no**
root in `GF(2ⁿ)`. This is the APN criterion shared by Corollary 2, Theorem 3 and
Theorem 4, the counted condition of Fact 1 (`a = 1`), and the presemifield condition
of Theorem 5 (`m = k`, where `σ(x) = x^{2^k}`).

It is literally the `(i,j,s,u,v,t) = (m,0,1,0,a,b)` case of
[`carlet_G1_rootless`](@ref):
`G(x,1) = 1·x^{2^m+2^0} + 0·x^{2^m} + a·x^{2^0} + b = x^{2^m+1} + a·x + b`.
"""
projective_polynomial_rootless(
    n::Int,
    m::Int,
    a::Int,
    b::Int;
    modulus::Int = primitive_polynomial(n),
) = carlet_G1_rootless(n, m, 0, 1, 0, a, b; modulus)
