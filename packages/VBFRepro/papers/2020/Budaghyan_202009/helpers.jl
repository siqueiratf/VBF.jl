# Implements shared helpers for the Budaghyan et al. (2020) reproduction.
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: General — shared utilities
#
# Pseudocode:
#   pi_counts: |Π_F^β(b)| for every b, at a fixed shift β
#   pi_full_multiset: the multiset Π_F = {|Π_F^β(b)| : β, b ∈ F₂ⁿ}
#   compute_m_F: iterate β over F₂ⁿ, compute min pi_multiset key
#   lower_bound_distance: ceil(m_F/3) + 1
# VBF API used: SBox, pi_multiset, sorted_pairs, gold_apn, print_banner,
#               print_section, print_check, print_kv

using VBF

function print_header(io::IO = stdout)
    print_banner(
        io,
        "Budaghyan, Carlet, Helleseth, Kaleyski (2020)",
        "On the Distance Between APN Functions",
        "IEEE Transactions on Information Theory",
    )
end

"""
    apply_modifications(F, U, V) -> SBox

Build G from F by XOR-shifting: G(U[i]) = F(U[i]) ⊕ V[i], G(x) = F(x) otherwise.
U and V are 0-based field elements stored in Julia 1-based arrays.
"""
function apply_modifications(F::SBox{N,T}, U::AbstractVector{<:Integer}, V::AbstractVector{<:Integer}) where {N,T}
    lut = copy(F.lut)
    for (u, v) in zip(U, V)
        lut[Int(u)+1] = lut[Int(u)+1] ⊻ T(v)
    end
    SBox{N,T}(lut)
end

"""
    pi_counts(F, β) -> Vector{Int}

`|Π_F^β(b)|` for every `b ∈ F₂ⁿ`, indexed `pi_counts(F, β)[b+1]`: the number of
derivative directions `a` for which the shifted derivative
`D_a^β F(x) = F(x) ⊕ F(x⊕a) ⊕ F(a⊕β)` takes the value `b` for some `x`.

Core's `pi_multiset(F, β)` returns only the *histogram* of these counts (how many
`b` share a count), which is what Corollary 2 needs. Propositions 3 and 4 relate
counts at *individual* `(β, b)` pairs, so they need the pointwise vector.
`Spectrum(pi_counts(F, β))` is exactly `pi_multiset(F, β)` (tested).
"""
function pi_counts(F::SBox{N,T}, β::Integer) where {N,T}
    n = 1 << N
    lut = F.lut
    b0 = Int(β)
    hits = zeros(Int, n)          # hits[b+1] = #directions a that reach b
    seen = falses(n)
    @inbounds for a = 0:(n-1)
        fill!(seen, false)
        fab = Int(lut[(a ⊻ b0)+1])   # F(a ⊕ β)
        for x = 0:(n-1)
            seen[((Int(lut[x+1]) ⊻ Int(lut[(x ⊻ a)+1])) ⊻ fab)+1] = true
        end
        for b = 0:(n-1)
            seen[b+1] && (hits[b+1] += 1)
        end
    end
    hits
end

"""
    pi_full_multiset(F) -> Vector{Int}

The multiset `Π_F = {|Π_F^β(b)| : β, b ∈ F₂ⁿ}` of Proposition 3, as a sorted
vector of `2^{2n}` counts. Proposition 3 states `Π_F^β(t) = Π_{F'}^{L₁(β,t)}(L₂(β,t))`
for a CCZ map `L = (L₁, L₂)`; since `L` permutes the pairs `(β, t)`, the whole
*multiset* (not merely its support) is CCZ-invariant.
"""
pi_full_multiset(F::SBox{N,T}) where {N,T} =
    sort!(reduce(vcat, (pi_counts(F, β) for β = 0:((1 << N) - 1))))

"""
    compute_m_F(F) -> Int

m_F = min_{β,b ∈ F₂ⁿ} |Π_F^β(b)|: the minimum count over all shifts β and all
output values b. Iterates all β and uses the smallest key from pi_multiset.
"""
function compute_m_F(F::SBox{N,T}) where {N,T}
    n = 1 << N
    m = typemax(Int)
    for β = 0:(n-1)
        sp = pi_multiset(F, β)
        pairs = sorted_pairs(sp)
        isempty(pairs) && continue
        k = pairs[1].first
        k < m && (m = k)
    end
    m
end

"""
    lower_bound_distance(m_F) -> Int

Lower bound d(F, G) ≥ ⌈m_F/3⌉ + 1 from Corollary 2.
"""
lower_bound_distance(m_F::Int) = (m_F + 2) ÷ 3 + 1

"""
    hamming_distance(F, G) -> Int

Number of points where the two functions differ.
"""
hamming_distance(F::SBox{N,T}, G::SBox{N,T}) where {N,T} =
    count(i -> F.lut[i] != G.lut[i], eachindex(F.lut))

"""
    is_primitive_element(b, n; modulus) -> Bool

Whether `b` generates the multiplicative group of GF(2^n), i.e. has order
`2ⁿ − 1`. Checked by ruling out every proper divisor of `2ⁿ − 1` as an order.
Several of the paper's examples are stated "for β primitive" but are in fact
sensitive to *which* primitive element is chosen (paper issue P3), so the
examples pin one and check it here.
"""
function is_primitive_element(b::Integer, n::Integer; modulus::Integer = primitive_polynomial(n))
    b = Int(b)
    b <= 1 && return false
    order = (1 << Int(n)) - 1
    for d = 1:(order-1)
        order % d == 0 || continue
        gf_pow(b, d, Int(n); modulus = Int(modulus)) == 1 && return false
    end
    gf_pow(b, order, Int(n); modulus = Int(modulus)) == 1
end
