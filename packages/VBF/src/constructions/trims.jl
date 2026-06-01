"""
Trims of a vectorial Boolean function ([Beierle, Leander and Perrin, 2022](@cite BeierleLeanderPerrin2022Trims),
"Trims and extensions of quadratic APN functions").

A **trim** of `F : F₂ⁿ → F₂ⁿ` is an `(n-1)`-bit function obtained by

  * **restricting the domain** to an affine hyperplane `{x : ⟨a, x⟩ = e}`
    (a nonzero linear form `a` and a bit `e ∈ {0, 1}`), identified with
    `F₂ⁿ⁻¹` by a linear isomorphism onto `a^⊥`; and
  * **projecting the codomain** along a nonzero direction `b` onto the quotient
    `F₂ⁿ / ⟨b⟩ ≅ F₂ⁿ⁻¹`.

There are `2·(2ⁿ-1)²` trims (one per `(a, e, b)`). [`trims`](@ref) returns all
of them, [`apn_trims`](@ref) keeps the APN ones, and [`trim_spectrum`](@ref)
returns the multiset of EA-class fingerprints ([`apn_ea_mugshot`](@ref)) of the
APN trims — a linear-equivalence invariant of `F`.

The individual trim lookup tables depend on the linear identifications chosen
for the domain hyperplane and the codomain quotient; this implementation fixes
them with `VBF`'s own (deterministic) `a^⊥` bases. The APN-ness and CCZ/EA-class
of each trim — and hence the trim spectrum — are independent of that choice, so
they reproduce the reference's invariant content exactly.
"""

function _trim_tables(::Val{N}) where {N}
    m = 1 << N
    half = 1 << (N - 1)
    embed = Vector{Vector{Int}}(undef, m - 1)
    embinv = Vector{Vector{Int}}(undef, m - 1)
    not_orth = Vector{Int}(undef, m - 1)
    for a = 1:(m-1)
        basis = kernel_f2([UInt(a)]; nbits = N)       # spans a^⊥ (N-1 vectors)
        lut = Vector{Int}(undef, half)
        inv = fill(-1, m)
        @inbounds for x = 0:(half-1)
            y = 0
            for i = 0:(N-2)
                if (x >> i) & 1 == 1
                    y ⊻= Int(basis[i+1])
                end
            end
            lut[x+1] = y
            inv[y+1] = x
        end
        embed[a] = lut
        embinv[a] = inv
        g = 1
        while f2_dot(g, a) != 1
            g += 1
        end
        not_orth[a] = g
    end
    embed, embinv, not_orth
end

# The single trim of F for direction a, coset bit e, projection b.
function _trim(
    F::SBox{N},
    a::Int,
    e::Int,
    b::Int,
    embed,
    embinv,
    not_orth,
) where {N}
    half = 1 << (N - 1)
    g = not_orth[b]
    Lin = embed[a]
    Lout = embinv[g]
    f = Vector{Int}(undef, half)
    @inbounds for x = 0:(half-1)
        s_xe = Int(F(Lin[x+1] ⊻ e))
        y = f2_dot(s_xe, g) == 1 ? s_xe ⊻ b : s_xe   # project into g^⊥ along b
        f[x+1] = Lout[y+1]
    end
    SBox{N - 1}(f)
end

"""
    trims(F::SBox{N}) -> Vector{SBox{N-1}}

All `2·(2ⁿ-1)²` trims of `F` (domain-hyperplane restriction × output
projection). See also [`apn_trims`](@ref) and [`trim_spectrum`](@ref).
"""
function trims(F::SBox{N}) where {N}
    N >= 2 || throw(ArgumentError("trims: N must be ≥ 2, got $N"))
    m = 1 << N
    embed, embinv, not_orth = _trim_tables(Val(N))
    out = SBox{N - 1,_storage_for(N - 1)}[]
    sizehint!(out, 2 * (m - 1)^2)
    for a = 1:(m-1), e in (0, not_orth[a]), b = 1:(m-1)
        push!(out, _trim(F, a, e, b, embed, embinv, not_orth))
    end
    out
end

"""
    apn_trims(F::SBox{N}) -> Vector{SBox{N-1}}

The trims of `F` that are APN (`differential_uniformity == 2`). May be empty.
"""
function apn_trims(F::SBox{N}) where {N}
    filter!(t -> differential_uniformity(t) == 2, trims(F))
end

"""
    trim_spectrum(F::SBox{N}) -> Dict{APNEAMugshot,Int}

The multiset of EA-class fingerprints ([`apn_ea_mugshot`](@ref)) of the APN
trims of `F`, mapping each distinct fingerprint to how many APN trims realise
it. The fingerprint set (and counts) is invariant under linear — indeed CCZ —
equivalence of `F`, making this a linear-equivalence invariant.
"""
function trim_spectrum(F::SBox{N}) where {N}
    spec = Dict{APNEAMugshot,Int}()
    for t in apn_trims(F)
        m = apn_ea_mugshot(t)
        spec[m] = get(spec, m, 0) + 1
    end
    spec
end
