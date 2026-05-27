"""
Inner-permutation search for heggebakk-style EA-equivalence.

Given a **current-G** function (typically `currentG = L₁⁻¹ ∘ G_original`
for some outer linear `L₁` returned by [`outer_permutations`](@ref)),
this searches for an invertible F₂-linear map `A₂` such that

    F ∘ A₂ ⊕ currentG

is affine. If found, we have `currentG = F ∘ A₂ ⊕ A` for some affine
`A`, equivalently the EA-equivalence

    G_original(x) = L₁(F(A₂(x))) ⊕ L₁(A(x)).

# Algorithm

Two phases, mirroring `innerPermutation()` + `dfs()` in heggebakk's
`permutation.c`:

**(1) Domain reduction.** For each basis element `bᵢ = 2ⁱ`, compute
the **3-derivative trail** of `currentG` at `bᵢ`,

    T_i := {currentG(bᵢ) ⊕ currentG(y) ⊕ currentG(bᵢ ⊕ y) : y ∈ F₂ⁿ},

and intersect, over `t ∈ T_i`, the set of inputs `x ∈ F₂ⁿ` that appear
in any `F`-3-derivative equation `F(a) ⊕ F(b) ⊕ F(a ⊕ b) = t`. The
resulting `domains[i]` is the candidate set for `A₂(bᵢ)`.

# A note on linear vs affine drift

The domain reduction assumes `A_drift(0) = 0` (linear drift). With
linear drift, the 3-derivative trails of `F` at `A₂(bᵢ)` and of
`currentG` at `bᵢ` agree *exactly*, so the true `A₂(bᵢ)` is always in
`domains[i]`. With a non-zero constant in `A_drift` the trails are
shifted by `A_drift(0)` and the true `A₂(bᵢ)` may be filtered out.
heggebakk's `createFunction` test generator uses
`randomLinearFunction` (linear drift) precisely for this reason. The
constant-shift enumeration that recovers the full affine-drift case
lives in [`are_ea_equivalent`](@ref).

**(2) DFS.** Loop over each combination
`(A₂(b₀), …, A₂(b_{n-1})) ∈ ∏ᵢ domains[i]`. For each combination:

    1. Reconstruct A₂'s LUT by linearity.
    2. Require A₂ to be an F₂-linear bijection (rank `N` over F₂).
    3. Compute drift = F ∘ A₂ ⊕ currentG.
    4. Return success if drift is affine
       (i.e., second-derivative vanishes everywhere).

# Complexity

Domain reduction is `O(2^{3n})` once. DFS is bounded by `∏ |domains[i]|`
which depends on the partition refinement; for finely-partitioned `F`
this is small. **For monomial APN (degenerate partition), the search
becomes infeasible past n=4** — Phase 10's CCZ-invariants will provide
the necessary additional filtering.
"""

# 3-derivative trail {f(x) ⊕ f(y) ⊕ f(x ⊕ y) : y ∈ F₂ⁿ} as a BitVector
# of length 2ⁿ. Bit `t` is set iff `t` is in the trail.
function _three_derivative_trail(f::Vector{T}, x::Int, n_size::Int) where {T<:Integer}
    out = falses(n_size)
    @inbounds fx = Int(f[x + 1])
    @inbounds for y in 0:(n_size - 1)
        t = fx ⊻ Int(f[y + 1]) ⊻ Int(f[(x ⊻ y) + 1])
        out[t + 1] = true
    end
    return out
end

# Reduce the domain {0..2ⁿ-1} by intersecting tempsets for each target
# t ∈ `targets`. tempset[t] = {x ∈ F₂ⁿ : x ∈ {a, b, a⊕b}
# for some (a, b) with f(a) ⊕ f(b) ⊕ f(a⊕b) = t}.
function _reduce_domain(f::Vector{T}, targets::BitVector, n_size::Int) where {T<:Integer}
    domain = trues(n_size)
    @inbounds for t in 0:(n_size - 1)
        targets[t + 1] || continue
        tempset = falses(n_size)
        for x in 0:(n_size - 1)
            for y in 0:(n_size - 1)
                t_val = Int(f[x + 1]) ⊻ Int(f[y + 1]) ⊻ Int(f[(x ⊻ y) + 1])
                if t_val == t
                    tempset[x + 1] = true
                    tempset[y + 1] = true
                    tempset[(x ⊻ y) + 1] = true
                end
            end
        end
        @simd for i in 1:n_size
            domain[i] &= tempset[i]
        end
    end
    return domain
end

# Reconstruct the LUT of a linear map from its basis images:
#   A(x) = ⊕ᵢ xᵢ · basis_images[i+1] where x = ∑ xᵢ 2ⁱ.
function _reconstruct_linear_lut(basis_images::Vector{T}, N::Int, n_size::Int) where {T<:Integer}
    lut = zeros(T, n_size)
    @inbounds for x in 0:(n_size - 1)
        v = zero(T)
        for i in 0:(N - 1)
            if ((x >> i) & 1) == 1
                v ⊻= basis_images[i + 1]
            end
        end
        lut[x + 1] = v
    end
    return lut
end

# Is the LUT of an F₂-linear bijection? (Basis images are F₂-linearly
# independent, i.e., the matrix of basis-image columns has rank N.)
function _is_basis_invertible(basis_images::Vector{T}, N::Int) where {T<:Integer}
    work = collect(basis_images)
    return rank_f2(work; nbits = N) == N
end

# Check if a function's LUT is affine. Affine functions satisfy
#   f(0) ⊕ f(a) ⊕ f(b) ⊕ f(a ⊕ b) = 0  for all a, b.
# Iterate distinct unordered triples (a, b, a ⊕ b) with a < b < a ⊕ b.
function _is_affine_lut(f::Vector{T}, n_size::Int) where {T<:Integer}
    @inbounds f0 = f[1]
    @inbounds for a in 1:(n_size - 1)
        for b in (a + 1):(n_size - 1)
            ab = a ⊻ b
            ab > b || continue
            if (f0 ⊻ f[a + 1] ⊻ f[b + 1] ⊻ f[ab + 1]) != zero(T)
                return false
            end
        end
    end
    return true
end

# DFS body. Threads `basis_images` and writes the result drift into
# `result_drift` on success.
function _inner_dfs!(
    k::Int, basis_images::Vector{T}, domains::Vector{Vector{Int}},
    F_lut::Vector{T}, G_lut::Vector{T}, N::Int, n_size::Int,
    result_drift::Vector{T},
) where {T<:Integer}
    if k == N
        # Require A₂ to be an F₂-linear bijection.
        _is_basis_invertible(basis_images, N) || return false
        A2_lut = _reconstruct_linear_lut(basis_images, N, n_size)
        drift = Vector{T}(undef, n_size)
        @inbounds for x in 0:(n_size - 1)
            drift[x + 1] = F_lut[A2_lut[x + 1] + 1] ⊻ G_lut[x + 1]
        end
        if _is_affine_lut(drift, n_size)
            copyto!(result_drift, drift)
            return true
        end
        return false
    end
    @inbounds for v in domains[k + 1]
        basis_images[k + 1] = T(v)
        if _inner_dfs!(k + 1, basis_images, domains, F_lut, G_lut, N, n_size, result_drift)
            return true
        end
    end
    return false
end

"""
    inner_permutation(F::SBox{N,T}, currentG::SBox{N,T}) ->
        Union{NamedTuple{(:A2, :A_drift), Tuple{Vector{T}, Vector{T}}}, Nothing}

Search for an invertible F₂-linear `A₂` with `F ∘ A₂ ⊕ currentG`
affine. Returns `(A2 = A₂.lut, A_drift = (F ∘ A₂ ⊕ currentG).lut)` on
success, `nothing` otherwise.

`currentG` is the function obtained by applying `L₁⁻¹` to the original
`G` (for a candidate outer linear map `L₁` from
[`outer_permutations`](@ref)). If `nothing` is returned for every
outer candidate `L₁` across every bucket map, `F` and `G_original`
are not EA-equivalent.

Domain reduction runs once per call (`O(2^{3n})`); the DFS that follows
is bounded by the product of the per-basis-element domain sizes —
which can be large for degenerate partitions.
"""
function inner_permutation(F::SBox{N,T}, currentG::SBox{N,T}) where {N,T}
    n_size = 1 << N
    F_lut = Vector{T}(F.lut)
    G_lut = Vector{T}(currentG.lut)

    # (1) Domain reduction.
    domains = Vector{Vector{Int}}(undef, N)
    @inbounds for i in 0:(N - 1)
        bi = 1 << i
        targets = _three_derivative_trail(G_lut, bi, n_size)
        domain_bits = _reduce_domain(F_lut, targets, n_size)
        domains[i + 1] = Int[v for v in 0:(n_size - 1) if domain_bits[v + 1]]
        isempty(domains[i + 1]) && return nothing
    end

    # (2) DFS.
    basis_images = zeros(T, N)
    result_drift = Vector{T}(undef, n_size)
    found = _inner_dfs!(0, basis_images, domains, F_lut, G_lut, N, n_size, result_drift)
    if found
        A2_lut = _reconstruct_linear_lut(basis_images, N, n_size)
        return (A2 = A2_lut, A_drift = result_drift)
    else
        return nothing
    end
end
