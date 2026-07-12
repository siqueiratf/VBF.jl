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

`:auto` (default) routes by input shape: quadratic APN whose
ortho-derivatives exist route to `:ortho_derivative`; everything else
routes to `:heggebakk`. Within `:heggebakk`, permutation pairs use the
partition search, while pairs with a non-permutation input use the
complete inner-affine enumeration below (Heggebakk follows the
functional inverse and cannot handle non-bijective inputs).

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
  affine witness exists, the decision is *inconclusive* and the function
  **throws** [`InconclusiveEquivalence`](@ref) rather than answering.
  Earlier versions returned a best-effort `false` here — first silently,
  then with a warning — but callers act on the `Bool`, and a novelty check
  reading that `false` as "inequivalent" manufactures a discovery. Pass
  `on_inconclusive = :best_effort` to restore it, or `:missing` to
  propagate the uncertainty. For pairs inside the CCZ-class of a quadratic
  APN the complete alternative is the orbit method
  ([`ea_class_orbits`](@ref)); for two quadratic APN,
  [`ea_mappings_from_ortho_derivative`](@ref) decides exactly.

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
all other non-permutation (and mixed permutation/non-permutation) pairs
are decided by a complete enumeration of the inner affine map, exact up
to the `max_inner_affine` cap (see below).

`k` controls the partition level (default `4`, must be even and `≥ 4`).

`max_inner_affine` bounds the inner-affine enumeration used for
non-permutation inputs; an exhausted (uncapped) enumeration is a sound
negative, whereas hitting the cap is *undecided* and throws
[`InconclusiveEquivalence`](@ref). The default `10^7` decides every
`n ≤ 4` pair exhaustively.

`on_inconclusive` controls what an undecided query does: `:throw`
(default), `:best_effort` (the old `false` — use only where a false
negative is harmless), or `:missing`.

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
    max_inner_affine::Int = 10^7,
    on_inconclusive::Symbol = :throw,
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
            # Capped permutation search: decide by sound invariants / witnesses.
            return _ea_inconclusive_fallback(F, G; on_inconclusive = on_inconclusive)
        end
        # At least one input is a non-permutation: Heggebakk (which follows the
        # functional inverse) does not apply. Decide by the complete
        # inner-affine enumeration, which handles arbitrary functions.
        return _ea_nonperm_decide(
            F,
            G;
            max_inner = max_inner_affine,
            on_inconclusive = on_inconclusive,
        )
    elseif s === :ortho_derivative
        return _are_ea_equivalent_via_ortho(F, G)
    end
    throw(
        ArgumentError("are_ea_equivalent: unknown strategy $(repr(strategy))"),
    )
end

"""
    InconclusiveEquivalence <: Exception

Thrown when an equivalence query cannot be decided: the bounded search was capped
without finding a witness, and no invariant separates the pair. Neither `true` nor
`false` is justified.

This exists because the alternative — reporting "don't know" as `false` — is a
false negative, and a false negative in a novelty check manufactures a discovery.
Catch it, or pass `on_inconclusive = :best_effort` to opt back into the old best-effort
behaviour.
"""
struct InconclusiveEquivalence <: Exception
    msg::String
end
Base.showerror(io::IO, e::InconclusiveEquivalence) =
    print(io, "InconclusiveEquivalence: ", e.msg)

# Sound decision chain for pairs the Heggebakk search cannot settle.
# Every `false` here is certified by an EA-invariant; every `true` by a witness.
# The final case is genuinely undecided and says so — see `on_inconclusive`.
function _ea_inconclusive_fallback(
    F::SBox{N,T},
    G::SBox{N,T};
    on_inconclusive::Symbol = :throw,
) where {N,T}
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

    msg = "the bounded partition search was capped and no invariant separates \
the pair, so equivalence is undecided. Do not read this as inequivalence. For \
members of a quadratic APN's CCZ-class use `ea_class_orbits` (or \
`ea_mappings_from_ortho_derivative`, which is complete for quadratic APN) for an \
exact decision; otherwise external code-equivalence tooling is required. Pass \
`on_inconclusive = :best_effort` to restore the old best-effort `false`, or \
`:missing` to propagate the uncertainty."
    on_inconclusive === :throw && throw(InconclusiveEquivalence(msg))
    on_inconclusive === :missing && return missing
    on_inconclusive === :best_effort && return false
    throw(ArgumentError("are_ea_equivalent: unknown on_inconclusive = \
$(repr(on_inconclusive)) (expected :throw, :best_effort or :missing)"))
end

# ---------------------------------------------------------------------------
# Complete EA decision for arbitrary (possibly non-permutation) functions.
#
# F ~_EA G  ⟺  ∃ invertible affine A₂(x) = L₂x ⊕ c₂, invertible linear L₁ and
# affine drift D with  G(x) = L₁(F(A₂(x))) ⊕ D(x).  The map `F ↦ L₁∘F∘A₂`
# preserves the algebraic-degree decomposition, and the affine drift D can only
# alter the degree-≤1 part; so, for a *fixed* inner A₂, an invertible outer L₁
# with a suitable affine drift exists iff a single invertible linear L₁ carries
# the degree-≥2 ANF of F∘A₂ onto that of G, coordinate-wise. That outer test is
# a closed-form linear-algebra check (`_ea_outer_exists`), so the decision
# reduces to enumerating the inner affine map A₂. The enumeration is exhaustive
# up to `max_inner` inner maps (a sound negative); beyond it the answer is
# reported as inconclusive rather than a silent `false`.
#
# Unlike Heggebakk this makes no bijectivity assumption, and it is exact for
# non-permutation / non-quadratic inputs (e.g. the degree-3 non-permutation APN
# at n = 4). It is not restricted to n = 4.
function _ea_nonperm_decide(
    F::SBox{N,T},
    G::SBox{N,T};
    max_inner::Int,
    on_inconclusive::Symbol = :throw,
) where {N,T}
    res = _ea_nonperm_search(F, G; max_inner = max_inner)
    res === :yes && return true
    res === :no && return false            # exhaustive enumeration ⇒ sound `false`
    # :capped ⇒ undecided; do not launder it into a negative
    return _ea_inconclusive_fallback(F, G; on_inconclusive = on_inconclusive)
end

# Does an invertible linear L₁ carry the degree-≥2 ANF of F∘A₂ (packed table
# `fp`) onto that of G (packed table `anfG`), coordinate-wise? Each monomial
# `m` of degree ≥ 2 contributes the linear constraint L₁(fp[m+1]) = anfG[m+1]
# (bit `j` of `fp[m+1]` is the coefficient of `m` in output coordinate `j`, and
# L₁ acts on the packed output coordinates). Fold every constraint into a
# partial linear map kept in reduced form; the constraints are realised by some
# invertible L₁ iff they are consistent and the map is injective on their span
# (`rank(bout) == length(bin)`), which always extends to an invertible map. The
# residual degree-≤1 part is then absorbed by the affine drift.
function _ea_outer_exists(
    fp::Vector{T},
    anfG::Vector{T},
    himons::Vector{Int},
    ::Val{N},
) where {N,T}
    bin = Int[]
    bout = Int[]
    @inbounds for m in himons
        _lin_add!(bin, bout, fp[m+1], anfG[m+1]) || return false
    end
    return rank_f2(UInt32.(bout); nbits = N) == length(bin)
end

# Enumerate every invertible inner affine map A₂ and run the outer test.
# Returns :yes (EA-equivalent, witnessed by A₂ + a fitting L₁), :no (exhaustive
# search found none), or :capped (enumeration hit `max_inner`).
function _ea_nonperm_search(F::SBox{N,T}, G::SBox{N,T}; max_inner::Int) where {N,T}
    # Sound early negatives via EA-invariants (equal for EA-equivalent pairs).
    dF = algebraic_degree(F)
    dG = algebraic_degree(G)
    # All functions of degree ≤ 1 form a single EA-class (drift absorbs them).
    (dF ≤ 1 && dG ≤ 1) && return :yes
    (dF ≤ 1) != (dG ≤ 1) && return :no
    dF != dG && return :no
    absolute_walsh_spectrum(F) != absolute_walsh_spectrum(G) && return :no
    component_degree_spectrum(F) != component_degree_spectrum(G) && return :no

    NN = 1 << N
    himons = Int[m for m = 0:(NN-1) if count_ones(UInt(m)) ≥ 2]
    anfG = mobius(G.lut)
    Fl = F.lut

    cols = Vector{T}(undef, N)   # columns (basis images) of the inner linear L₂
    used = Int[]                 # chosen columns, for the independence test
    count = Ref(0)
    capped = Ref(false)
    found = Ref(false)

    # Is `v` independent of the columns chosen so far (keeps L₂ invertible)?
    indep = function (v::Int)
        v == 0 && return false
        r = v
        @inbounds for u in used
            hb = 1 << (8 * sizeof(Int) - 1 - leading_zeros(u))
            (r & hb) != 0 && (r ⊻= u)
        end
        r != 0
    end

    rec = function (i::Int)
        (found[] || capped[]) && return
        if i == N
            # L₂ fully chosen; precompute L₂x, then sweep the input shift c₂.
            lx = Vector{T}(undef, NN)
            @inbounds for x = 0:(NN-1)
                y = zero(T)
                xi = x
                j = 0
                while xi != 0
                    (xi & 1) == 1 && (y ⊻= cols[j+1])
                    xi >>= 1
                    j += 1
                end
                lx[x+1] = y
            end
            fp = Vector{T}(undef, NN)
            @inbounds for c2 = 0:(NN-1)
                count[] += 1
                if count[] > max_inner
                    capped[] = true
                    return
                end
                cc = T(c2)
                for x = 0:(NN-1)
                    fp[x+1] = Fl[(lx[x+1]⊻cc)+1]
                end
                mobius!(fp)                       # packed ANF of F∘A₂
                if _ea_outer_exists(fp, anfG, himons, Val(N))
                    found[] = true
                    return
                end
            end
            return
        end
        @inbounds for img = 1:(NN-1)
            indep(img) || continue
            cols[i+1] = T(img)
            push!(used, img)
            rec(i + 1)
            pop!(used)
            (found[] || capped[]) && return
        end
    end
    rec(0)

    found[] && return :yes
    capped[] && return :capped
    return :no
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
