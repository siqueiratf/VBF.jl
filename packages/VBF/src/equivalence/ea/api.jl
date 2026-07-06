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
  [Canteaut, Couvreur and Perrin (2022)](@cite Canteaut_202205), the
  linear-equivalence class of the ortho-derivative
  `π_F` is an EA-invariant of F. The decision reduces to a single call
  to [`are_linear_equivalent`](@ref) on the ortho-derivatives — orders
  of magnitude faster than `:heggebakk`, and **correct on the monomial
  APN where `:heggebakk` degenerates**.

- `:heggebakk` — Heggebakk's partition-respecting algorithm
  ([Heggebakk, 2022](@cite Heggebakk_202200)):

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

# Soundness guarantee

`are_ea_equivalent` never returns a **silent** wrong answer:

- `true` is always backed by a witness (Heggebakk certificate, verified
  ortho-derivative equivalence, LUT equality, or an affine-equivalence
  witness — affine equivalence implies EA-equivalence).
- `false` is returned when soundly provable: exhaustive (uncapped)
  Heggebakk search, mismatching partition signatures, or a differing
  EA-invariant (algebraic degree for degrees ≥ 2, extended Walsh
  spectrum, component degree spectrum).
- When the partition search is **capped** (degenerate partitions — e.g.
  signature `[2ⁿ-1, 1]` monomial APN, or `[2ⁿ-8, 7, 1]` degree-4 APN
  permutations at n = 6) and no invariant separates the pair and no
  affine witness exists, the decision is *inconclusive*: the function
  emits an `@warn` and returns a best-effort `false`. Earlier versions
  returned this `false` silently, indistinguishable from a proof.
  For pairs inside the CCZ-class of a quadratic APN, the complete
  alternative is the orbit method ([`ea_class_orbits`](@ref)).

Two functions of algebraic degree ≤ 1 are always EA-equivalent
(`G = F ⊕ (G ⊕ F)` with affine drift `G ⊕ F`), and a degree ≤ 1
function is never EA-equivalent to one of degree ≥ 2.
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
    F::SBox,
    G::SBox;
    strategy::Symbol = :auto,
    k::Int = 4,
    max_outer_per_sigma::Int = 10^6,
)
    inputbits(F) == inputbits(G) || return false
    storage_type(F) == storage_type(G) || return false

    s = strategy
    if s === :auto
        # Reflexivity via identity maps, scoped to :auto.
        F.lut == G.lut && return true
        s = _ea_auto_strategy(F, G)
    end
    if s === :heggebakk
        if is_permutation(F) && is_permutation(G)
            capped = Ref(false)
            cert = _ea_search(
                F,
                G;
                k = k,
                max_outer = max_outer_per_sigma,
                want_certificate = false,
                capped = capped,
            )
            cert !== nothing && return true
            # Exhaustive (uncapped) search ⇒ sound negative.
            capped[] || return false
        end
        # Capped search, or non-permutation inputs (Heggebakk inapplicable):
        # decide by sound invariants / witnesses, else warn.
        return _ea_inconclusive_fallback(F, G)
    elseif s === :ortho_derivative
        return _are_ea_equivalent_via_ortho(F, G)
    end
    throw(
        ArgumentError("are_ea_equivalent: unknown strategy $(repr(strategy))"),
    )
end

# Sound decision chain for pairs the Heggebakk search cannot settle.
# Every `false` here is certified by an EA-invariant; every `true` by a
# witness. Only the final warned `false` is best-effort.
function _ea_inconclusive_fallback(F::SBox{N,T}, G::SBox{N,T}) where {N,T}
    dF = algebraic_degree(F)
    dG = algebraic_degree(G)
    # All degree ≤ 1 functions form one EA-class (drift absorbs the difference).
    dF ≤ 1 && dG ≤ 1 && return true
    # Degree is an EA-invariant on {≥ 2} and {≤ 1} is EA-closed.
    (dF ≤ 1) != (dG ≤ 1) && return false
    dF != dG && return false
    # Extended Walsh spectrum and component degree spectrum are EA-invariants
    # of arbitrary functions.
    absolute_walsh_spectrum(F) != absolute_walsh_spectrum(G) && return false
    component_degree_spectrum(F) != component_degree_spectrum(G) && return false
    # Affine equivalence implies EA-equivalence (positive witness).
    are_affine_equivalent(F, G) && return true
    @warn "are_ea_equivalent: inconclusive — the bounded partition search was \
capped and no invariant separates the pair; returning best-effort `false`. \
For members of a quadratic APN's CCZ-class use `ea_class_orbits` for a \
complete decision; otherwise external code-equivalence tooling is required." maxlog = 1
    return false
end

# Quadratic APN uses the ortho-derivative test; else the Heggebakk search.
function _ea_auto_strategy(F::SBox, G::SBox)
    algebraic_degree(F) == 2 && algebraic_degree(G) == 2 || return :heggebakk
    ortho_derivative(F) === nothing && return :heggebakk
    ortho_derivative(G) === nothing && return :heggebakk
    return :ortho_derivative
end

# Ortho-derivative EA test (CCP 2022): F ~_EA G ⇒ π_F ~_L π_G for quadratic APN.
function _are_ea_equivalent_via_ortho(F::SBox, G::SBox)
    π_F = ortho_derivative(F)
    π_F === nothing && return false
    π_G = ortho_derivative(G)
    π_G === nothing && return false
    apn_ea_mugshot(F) == apn_ea_mugshot(G) || return false
    return are_linear_equivalent(π_F, π_G)
end

"""
    ea_equivalence_certificate(F::SBox{N,T}, G::SBox{N,T};
                                strategy = :auto, k = 4,
                                max_outer_per_sigma = 10^6)
        -> NamedTuple{(:L1, :A2, :A_drift), ...} | Nothing

Return an EA-equivalence certificate on success or `nothing` on
failure. `nothing` means *no certificate found*, not a proof of
EA-inequivalence — the bounded search may have been capped (see the
soundness note in the module docstring). The certificate is a named
tuple

  - `L1::F2LinearMap{N,T}` — outer linear bijection.
  - `A2::F2LinearMap{N,T}` — inner linear bijection.
  - `A_drift::SBox{N,T}`   — affine drift function.

satisfying `G(x) == L1(F(A2(x))) ⊕ A_drift(x)` for every `x ∈ F₂ⁿ`.

Same `strategy`, `k`, and `max_outer_per_sigma` semantics as
[`are_ea_equivalent`](@ref).
"""
function ea_equivalence_certificate(
    F::SBox{N,T},
    G::SBox{N,T};
    strategy::Symbol = :auto,
    k::Int = 4,
    max_outer_per_sigma::Int = 10^6,
) where {N,T}
    inputbits(F) == inputbits(G) || return nothing
    storage_type(F) == storage_type(G) || return nothing
    (is_permutation(F) && is_permutation(G)) || return nothing

    s = strategy == :auto ? :heggebakk : strategy
    if s === :heggebakk
        return _ea_search(
            F,
            G;
            k = k,
            max_outer = max_outer_per_sigma,
            want_certificate = true,
        )
    end
    throw(
        ArgumentError(
            "ea_equivalence_certificate: unknown strategy $(repr(strategy))",
        ),
    )
end

function _ea_search(
    F::SBox{N,T},
    G::SBox{N,T};
    k::Int = 4,
    max_outer::Int = 10^6,
    want_certificate::Bool = false,
    capped::Base.RefValue{Bool} = Ref(false),
) where {N,T}
    n_size = 1 << N

    # Signature mismatch ⇒ definitively NOT EA-equivalent
    partF = ea_partition(F, k)
    partG = ea_partition(G, k)
    sort(partF.bucket_sizes) == sort(partG.bucket_sizes) || return nothing

    # Signatures match, so at least one bucket map exists; an empty result
    # can only mean the map count exceeded the cap.
    sigmas = enumerate_bucket_maps(partF, partG; max_maps = max_outer)
    if isempty(sigmas)
        capped[] = true
        return nothing
    end

    for sigma in sigmas
        outers = outer_permutations(partF, partG, sigma, T)
        # Skip σ if the outer count exceeds the cap (guards degenerate
        # searches). The result is then inconclusive, not a proof.
        if length(outers) > max_outer
            capped[] = true
            continue
        end

        for L1_lut in outers
            L1_cols = T[L1_lut[(1<<i)+1] for i = 0:(N-1)]
            L1_map = F2LinearMap{N,T}(L1_cols)
            # Bijectivity is implied by the outer-perm DFS, but be safe.
            is_invertible(L1_map) || continue
            L1_inv = inv(L1_map)

            # currentG = L₁⁻¹ ∘ G
            currentG_lut = T[L1_inv(G.lut[x+1]) for x = 0:(n_size-1)]

            # Enumerate constant shifts for affine drift (the partition is
            # shift-invariant).
            for shift_val = 0:(n_size-1)
                shift = T(shift_val)
                shifted_lut = T[currentG_lut[x+1] ⊻ shift for x = 0:(n_size-1)]
                shifted_G = SBox{N,T}(shifted_lut)
                res = inner_permutation(F, shifted_G)
                res === nothing && continue
                # res.A_drift is the F vs (L₁⁻¹ ∘ G ⊕ shift) drift; apply L₁ to
                # recover G's drift.
                if !want_certificate
                    return (found = true,)
                end
                # Recover the drift in G's coordinates: D(x) = L₁(shift ⊕
                # res.A_drift(x)).
                A2_map = F2LinearMap{N,T}(T[res.A2[(1<<i)+1] for i = 0:(N-1)])
                A_drift_lut =
                    T[L1_map(shift ⊻ res.A_drift[x+1]) for x = 0:(n_size-1)]
                A_drift_sbox = SBox{N,T}(A_drift_lut)
                return (L1 = L1_map, A2 = A2_map, A_drift = A_drift_sbox)
            end
        end
    end
    return nothing
end
