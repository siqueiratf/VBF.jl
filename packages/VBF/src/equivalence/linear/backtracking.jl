"""
Linear-equivalence search by propagation-pruned backtracking.

Two S-boxes `F, G : F₂ⁿ → F₂ⁿ` are *linearly equivalent* iff there
exist invertible F₂-linear maps `L₁, L₂` such that

    G = L₁ ∘ F ∘ L₂.

Equivalently, the bijection
``φ : F(L₂(x)) ↦ G(x)``
defined on the image of `F ∘ L₂` (which is all of F₂ⁿ when both are
permutations) must extend to an F₂-linear bijection — i.e., be
closed under the XOR-additive law `φ(a ⊕ b) = φ(a) ⊕ φ(b)`.

# Algorithm
Backtrack over the basis `L₂(e₀), L₂(e₁), …, L₂(e_{N-1})`. At step `i`,
after a tentative assignment of `L₂(e_i)`, propagate the `2^i` new
`(F(L₂(x)), G(x))` pairs through a running reduced basis of `φ` (kept
in Gauss-Jordan form on the *domain* coordinate). Any pair that
reduces to `(0, nonzero)` is a contradiction → backtrack. This is the
classical linear-equivalence guessing construction: try a basis image,
derive constraints, fail on collision.

# Scope
Permutations only at v0.1; non-bijective inputs return `false` for
now. Lifting to general functions is straightforward (drop the
`is_permutation` precondition and accept that some constraints may
involve `φ` being defined on a *subspace* rather than all of F₂ⁿ) and
lands in a later commit.

The exported entry point lives in `equivalence/linear/api.jl`; this
file is the algorithm core.
"""

# φ basis (reduced linear constraint set)

# φ: reduced (a, A) pairs; adding one reduces modulo the basis (a→0 ⇒ A=0).

"""
    _phi_add!(basis::Vector{Tuple{T,T}}, a::T, A::T) -> Bool

Reduce `(a, A)` modulo `basis` (a list of `(b, B)` pairs each with a
unique trailing-zero bit). Returns `true` iff the addition is
consistent — i.e., a contradiction `(0, nonzero)` was *not* observed.
Mutates `basis` (appends a row if the reduced `a` is nonzero).
"""
function _phi_add!(basis::Vector{Tuple{T,T}}, a::T, A::T) where {T<:Unsigned}
    @inbounds for (b, B) in basis
        piv = trailing_zeros(b)
        if ((a >> piv) & T(1)) == T(1)
            a ⊻= b
            A ⊻= B
        end
    end
    if a == zero(T)
        return A == zero(T)
    end
    push!(basis, (a, A))
    true
end

# Backtracking search

"""
    are_linearly_equivalent_perm(F::SBox{N,T}, G::SBox{N,T}) -> Bool

Decide whether the *permutations* `F, G` are linearly equivalent.
Returns `false` for non-permutations.

Exponential in the worst case (the recursion explores at most
`∏_{i=0}^{N-1}(2^N - 2^i)` leaves) but cheap in practice because
the propagation prunes aggressively — most candidate basis sequences
fail at step 1 or 2.

Use `VBF.are_linear_equivalent(F, G)` (in `api.jl`) for the public
entry point that handles dispatch, validates inputs, and chooses a
default strategy.
"""
function are_linearly_equivalent_perm(F::SBox{N,T}, G::SBox{N,T}) where {N,T}
    (is_permutation(F) && is_permutation(G)) || return false
    n_pow = 1 << N

    # Seed φ with (F(0), G(0)); linear maps fix 0, so this also forces φ(0) = 0.
    phi_basis = Tuple{T,T}[]
    _phi_add!(phi_basis, T(F.lut[1]), T(G.lut[1])) || return false

    # L₂ basis images and the running RREF of their span (independence checks).
    l2_imgs = T[]
    span_basis = T[]

    found = Ref(false)

    function recurse(i::Int)
        if i == N
            found[] = true
            return
        end
        @inbounds for c = T(1):T(n_pow-1)
            is_in_span(c, span_basis; nbits = N) && continue

            push!(l2_imgs, c)
            # Snapshot phi for rollback
            phi_snap = length(phi_basis)
            ok = true

            # Add the 2^i new pairs for x_new = x_old ⊕ e_i, x_old in
            # span(e_0..e_{i-1}).
            n_old = 1 << i
            for x_old_idx = 0:(n_old-1)
                l2_x_old = zero(T)
                @inbounds for k = 0:(i-1)
                    ((x_old_idx >> k) & 1) == 1 && (l2_x_old ⊻= l2_imgs[k+1])
                end
                x_new_idx = x_old_idx ⊻ (1 << i)
                a = T(F.lut[(l2_x_old⊻c)+1])
                A = T(G.lut[x_new_idx+1])
                if !_phi_add!(phi_basis, a, A)
                    ok = false
                    break
                end
            end

            if ok
                # Add `c` to the span-basis tracking for cheap candidate checks.
                previous_span = span_basis
                span_basis = linear_basis(vcat(span_basis, c); nbits = N)
                recurse(i + 1)
                found[] && return
                # Reduction can reorder and change every row; restore the
                # previous span rather than removing an arbitrary pivot row.
                span_basis = previous_span
            end

            # Roll back tentative state
            resize!(phi_basis, phi_snap)
            pop!(l2_imgs)
        end
        return
    end

    recurse(0)
    found[]
end
