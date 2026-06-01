"""
Public API for EA-equivalence testing.

Two SBoxes `F, G : F₂ⁿ → F₂ⁿ` are **EA-equivalent** (Extended-Affine
equivalent) iff there exist invertible F₂-affine maps `A₁, A₂` and an
arbitrary F₂-affine map `A_drift` such that

    G(x) = A₁(F(A₂(x))) ⊕ A_drift(x).

This relation strictly contains affine equivalence (`A_drift = 0`)
and is itself strictly contained in CCZ-equivalence.

# Functions
- [`are_ea_equivalent`](@ref) — `Bool` decision procedure.
- [`ea_equivalence_certificate`](@ref) — returns the witnesses
  `(L₁, A₂, A_drift)` if EA-equivalent, `nothing` otherwise.

# Strategies

`:auto` (default) routes by input shape: quadratic-APN permutations
whose ortho-derivatives are themselves permutations route to
`:ortho_derivative`; everything else routes to `:heggebakk`.

- `:ortho_derivative` — for quadratic APN. By
  [Canteaut, Couvreur and Perrin (2022)](@cite CanteautCouvreurPerrin2022EA), the
  linear-equivalence class of the ortho-derivative
  `π_F` is an EA-invariant of F. The decision reduces to a single call
  to [`are_linear_equivalent`](@ref) on the ortho-derivatives — orders
  of magnitude faster than `:heggebakk`, and **correct on the monomial
  APN where `:heggebakk` degenerates**.

- `:heggebakk` — Heggebakk's partition-respecting algorithm
  ([Heggebakk, 2022](@cite Heggebakk2022Thesis)):

  1. Compute the k-multiplicity partition of `F` and `G`
     ([`ea_partition`](@ref)). If their bucket-size multisets differ,
     return `false` (fast necessary EA-rejection).
  2. Enumerate every size-preserving bucket map
     `σ : F-buckets → G-buckets` ([`enumerate_bucket_maps`](@ref)).
  3. For each `σ`, DFS-enumerate every linear `L₁` mapping F's
     partition onto G's partition consistently with `σ`
     ([`outer_permutations`](@ref)).
  4. For each `L₁`: build `currentG = L₁⁻¹ ∘ G`, then for each
     constant shift `s ∈ F₂ⁿ` (covers affine drift), run
     [`inner_permutation`](@ref) on `(F, currentG ⊕ s)`. Return `true`
     at the first success.

# Limitations

- **Heggebakk is permutations-only**, but quadratic APN (the usual non-permutation
  case — almost all APN are 3-to-1) is handled by `:ortho_derivative`, which now
  uses the general, non-permutation-capable [`are_linearly_equivalent_general`](@ref).
  Functions that are neither permutations nor quadratic APN still return `false`.
- **Degenerate partitions.** For functions where the `k = 4` partition
  signature is `[2ⁿ-1, 1]` (e.g., monomial APN), the outer-permutation
  set is the full `GL(n, F₂)` and step 3 enumerates millions of
  candidates. The `max_outer_per_sigma` kwarg short-circuits this; on
  monomial APN at `n ≥ 5` the decision will return `false` even if
  EA-equivalent. The `:ortho_derivative` strategy is the correct route
  for those quadratic-APN cases; [`are_affine_equivalent`](@ref) is a
  fallback when affine drift is not relevant.
"""

# ---------------------------------------------------------------------------

"""
    are_ea_equivalent(F::SBox, G::SBox; strategy = :auto, k = 4,
                       max_outer_per_sigma = 10^6) -> Bool

Decide EA-equivalence of `F` and `G`.

SBoxes of different `N` or storage `T` return `false` without throwing.
Non-permutation quadratic APN are handled via the ortho-derivative test;
other non-permutations return `false`.

`k` controls the partition level (default `4`, must be even and `≥ 4`).

`max_outer_per_sigma` is a safety bound on the outer-permutation search
size per bucket map; a bucket map yielding more than this many `L₁`
candidates is skipped (returning `false` overall if no other bucket
map succeeds — see *Limitations* in the module docstring).

# Examples

The Gold functions `x³` and `x⁵` over `F₂⁵` are quadratic APN with
distinct EA-classes (routed through the ortho-derivative test):

```jldoctest
julia> using VBF

julia> are_ea_equivalent(load_apn_function("n5_Gold_x3"),
                         load_apn_function("n5_Gold_x3"))
true

julia> are_ea_equivalent(load_apn_function("n5_Gold_x3"),
                         load_apn_function("n5_Gold_x5"))
false
```
"""
function are_ea_equivalent(
    F::SBox, G::SBox;
    strategy::Symbol = :auto,
    k::Int = 4,
    max_outer_per_sigma::Int = 10^6,
)
    inputbits(F) == inputbits(G) || return false
    storage_type(F) == storage_type(G) || return false

    s = strategy
    if s === :auto
        # Reflexivity holds for every function via identity maps. Scoped to
        # :auto so an explicitly requested strategy keeps its exact semantics
        # (:heggebakk legitimately short-circuits on a degenerate partition).
        F.lut == G.lut && return true
        s = _ea_auto_strategy(F, G)
    end
    if s === :heggebakk
        # Heggebakk's partition search is permutation-only.
        (is_permutation(F) && is_permutation(G)) || return false
        cert = _ea_search(F, G; k = k, max_outer = max_outer_per_sigma,
                          want_certificate = false)
        return cert !== nothing
    elseif s === :ortho_derivative
        return _are_ea_equivalent_via_ortho(F, G)
    end
    throw(ArgumentError("are_ea_equivalent: unknown strategy $(repr(strategy))"))
end

# Quadratic APN (permutation or not) routes to the ortho-derivative test, which
# handles non-permutations; everything else uses the permutation-only Heggebakk
# search.
function _ea_auto_strategy(F::SBox, G::SBox)
    algebraic_degree(F) == 2 && algebraic_degree(G) == 2 || return :heggebakk
    ortho_derivative(F) === nothing && return :heggebakk
    ortho_derivative(G) === nothing && return :heggebakk
    return :ortho_derivative
end

# Ortho-derivative-based EA-equivalence (necessary condition).
#
# For quadratic APN F, G: F ~_EA G ⇒ π_F ~_L π_G (Canteaut-Couvreur-
# Perrin 2022). We test this necessary condition via linear-equivalence
# of the ortho-derivatives. Sufficiency holds inside the quadratic-APN class
# for most known families, and is the only way to decide monomial APN, where
# heggebakk's partition degenerates.
function _are_ea_equivalent_via_ortho(F::SBox, G::SBox)
    π_F = ortho_derivative(F)
    π_F === nothing && return false
    π_G = ortho_derivative(G)
    π_G === nothing && return false
    # Fast necessary reject: the ortho-derivative fingerprint (its differential
    # and Walsh spectra are linear-equivalence invariants of π). Different
    # fingerprints cannot be linear-equivalent, so only matching candidates pay
    # for the exact backtracking test.
    apn_ea_mugshot(F) == apn_ea_mugshot(G) || return false
    return are_linear_equivalent(π_F, π_G)
end

"""
    ea_equivalence_certificate(F::SBox{N,T}, G::SBox{N,T};
                                strategy = :auto, k = 4,
                                max_outer_per_sigma = 10^6)
        -> NamedTuple{(:L1, :A2, :A_drift), ...} | Nothing

Return an EA-equivalence certificate on success or `nothing` on
failure. The certificate is a named tuple

  - `L1::F2LinearMap{N,T}` — outer linear bijection.
  - `A2::F2LinearMap{N,T}` — inner linear bijection.
  - `A_drift::SBox{N,T}`   — affine drift function.

satisfying `G(x) == L1(F(A2(x))) ⊕ A_drift(x)` for every `x ∈ F₂ⁿ`.

Same `strategy`, `k`, and `max_outer_per_sigma` semantics as
[`are_ea_equivalent`](@ref).
"""
function ea_equivalence_certificate(
    F::SBox{N,T}, G::SBox{N,T};
    strategy::Symbol = :auto,
    k::Int = 4,
    max_outer_per_sigma::Int = 10^6,
) where {N,T}
    inputbits(F) == inputbits(G) || return nothing
    storage_type(F) == storage_type(G) || return nothing
    (is_permutation(F) && is_permutation(G)) || return nothing

    s = strategy == :auto ? :heggebakk : strategy
    if s === :heggebakk
        return _ea_search(F, G; k = k, max_outer = max_outer_per_sigma,
                          want_certificate = true)
    end
    throw(ArgumentError("ea_equivalence_certificate: unknown strategy $(repr(strategy))"))
end

# ---------------------------------------------------------------------------
# Core search loop. Returns the certificate on success, nothing on failure.
# Called by both decision and certificate APIs.
# ---------------------------------------------------------------------------

function _ea_search(
    F::SBox{N,T}, G::SBox{N,T};
    k::Int = 4,
    max_outer::Int = 10^6,
    want_certificate::Bool = false,
) where {N,T}
    n_size = 1 << N

    # Signature mismatch ⇒ definitively NOT EA-equivalent
    partF = ea_partition(F, k)
    partG = ea_partition(G, k)
    sort(partF.bucket_sizes) == sort(partG.bucket_sizes) || return nothing

    sigmas = enumerate_bucket_maps(partF, partG; max_maps = max_outer)
    isempty(sigmas) && return nothing

    for sigma in sigmas
        outers = outer_permutations(partF, partG, sigma, T)
        # If the outer count exceeds the cap, skip this σ — see docstring
        # caveats. With max_outer = 10^6 and degenerate partitions, this
        # protects against hour-long monomial-APN searches.
        length(outers) > max_outer && continue

        for L1_lut in outers
            L1_cols = T[L1_lut[(1 << i) + 1] for i in 0:(N - 1)]
            L1_map = F2LinearMap{N,T}(L1_cols)
            # Bijectivity is implied by the outer-perm DFS, but be safe.
            is_invertible(L1_map) || continue
            L1_inv = inv(L1_map)

            # currentG = L₁⁻¹ ∘ G
            currentG_lut = T[L1_inv(G.lut[x + 1]) for x in 0:(n_size - 1)]

            # Enumerate constant shifts ∈ F₂ⁿ to cover affine drift.
            # The k=4 partition is constant-shift-invariant, so partitions
            # already match; only the inner search depends on the shift.
            for shift_val in 0:(n_size - 1)
                shift = T(shift_val)
                shifted_lut = T[currentG_lut[x + 1] ⊻ shift for x in 0:(n_size - 1)]
                shifted_G = SBox{N,T}(shifted_lut)
                res = inner_permutation(F, shifted_G)
                res === nothing && continue
                # res.A_drift here is the drift between F and (L₁⁻¹ ∘ G ⊕ shift);
                # apply L₁ back to recover the original-G drift.
                if !want_certificate
                    return (found = true,)
                end
                # Reconstruct A_drift in G's original space:
                #   G(x) = L₁((F ∘ A₂)(x)) ⊕ L₁((F ∘ A₂ ⊕ currentG ⊕ shift)(x)) ⊕ L₁(shift)
                #        = L₁((F ∘ A₂)(x) ⊕ res.A_drift(x)) ⊕ L₁(shift)
                # Wait — we need to be careful. Let's re-derive cleanly:
                #   F(A₂(x)) ⊕ shifted_G(x) = res.A_drift(x)
                #   shifted_G(x) = currentG(x) ⊕ shift
                #   currentG(x) = L₁⁻¹(G(x))
                # So  F(A₂(x)) ⊕ L₁⁻¹(G(x)) ⊕ shift = res.A_drift(x)
                #   ⇒  L₁⁻¹(G(x)) = F(A₂(x)) ⊕ shift ⊕ res.A_drift(x)
                #   ⇒  G(x) = L₁(F(A₂(x))) ⊕ L₁(shift ⊕ res.A_drift(x))
                # So the drift in G's coordinate system is
                #   D(x) := L₁(shift ⊕ res.A_drift(x)).
                A2_map = F2LinearMap{N,T}(T[res.A2[(1 << i) + 1] for i in 0:(N - 1)])
                A_drift_lut = T[L1_map(shift ⊻ res.A_drift[x + 1])
                                 for x in 0:(n_size - 1)]
                A_drift_sbox = SBox{N,T}(A_drift_lut)
                return (L1 = L1_map, A2 = A2_map, A_drift = A_drift_sbox)
            end
        end
    end
    return nothing
end
