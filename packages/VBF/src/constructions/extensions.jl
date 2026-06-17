"""
Extensions of quadratic APN functions ([Beierle, Leander and Perrin, 2022](@cite Beierle_202200),
"Trims and extensions of quadratic APN functions").

An **extension** of an `(n-1)`-bit quadratic APN function `G` is an `n`-bit
quadratic APN function `F` of which `G` is a trim. [`extend_quadratic_apn`](@ref)
searches for such `F`. Writing `m = n-1`, an extension has the block form

  * **lower half** `F(x) = G(x) ⊕ (c(x) ≪ m)` for `x < 2ᵐ`, where `c` is a new
    top output coordinate of algebraic degree `≤ 2`; and
  * **upper half** `F(x ⊕ 2ᵐ) = F(x) ⊕ L(x)` for `x < 2ᵐ`, where `L : F₂ᵐ → F₂ⁿ`
    is linear.

`F` then automatically has algebraic degree `≤ 2` (lower half quadratic, `L`
linear), and its lower half is APN because `G` is. APN-ness of the whole `F`
reduces to constraints on `L`: for each lower-half input difference `a`, the set
of achievable output differences and its `L(a)`-shift must stay disjoint, which
prunes the linear part heavily. The search fixes the lower half, precomputes
these per-difference constraints, then backtracks over `L` filling the upper half
under an incremental DDT bound, exactly as in the reference.

The reference samples the space with `mt19937` random restarts (a random `(n-1)`-
bit APN prefix, a random top coordinate `c`, a random `L` order). Per the
project's reproducibility decision this is made **deterministic**: by default the
top coordinate is `c = 0` (the degree-0 choice) and `L` is enumerated in the
natural order, so the search is bit-for-bit reproducible; passing an `rng` draws
a reproducible random top coordinate and `L` order (the reference's
diversification). Every completed candidate is independently re-verified to be
APN and of degree 2 before being returned, so the constraint pruning never lets a
non-extension through.
"""

mutable struct _ExtSearch{n,T}
    m::Int
    half::Int
    full::Int
    sbox::Vector{Int}
    ddt::Matrix{Int}
    possibles::Matrix{Bool}
    L::Vector{Int}
    Lorder::Vector{Vector{Int}}
    limit::Int
    cands::Vector{SBox{n,T}}
end

@inline _evlin(L, x::Int, m::Int) = begin
    y = 0
    @inbounds for i = 0:(m-1)
        ((x >> i) & 1) == 1 && (y ⊻= L[i+1])
    end
    y
end

# Incremental upper-half DDT: fold c against the upper-half points below it.
function _ext_add_ddt!(s::_ExtSearch, c::Int)
    sb = s.sbox
    ddt = s.ddt
    half = s.half
    @inbounds for d = half:(c-1)
        δ = c ⊻ d
        if iseven(count_ones(δ))
            β = sb[c+1] ⊻ sb[d+1]
            ddt[δ+1, β+1] += 2
            ddt[δ+1, β+1] > 2 && return false
        end
    end
    true
end

function _ext_remove_ddt!(s::_ExtSearch, c::Int)
    sb = s.sbox
    ddt = s.ddt
    half = s.half
    @inbounds for d = half:(c-1)
        δ = c ⊻ d
        if iseven(count_ones(δ))
            β = sb[c+1] ⊻ sb[d+1]
            ddt[δ+1, β+1] -= 2
            ddt[δ+1, β+1] == 2 && return false
        end
    end
    true
end

# Set L[depth] = y and check the new L-values against `possibles`.
function _is_potential_L!(s::_ExtSearch, depth::Int, y::Int)
    s.L[depth+1] = y
    x = 1 << depth
    @inbounds for xS = x:((x<<1)-1)
        if !s.possibles[xS, _evlin(s.L, xS, s.m)+1]
            s.L[depth+1] = -1
            return false
        end
    end
    true
end

function _ext_recurse!(s::_ExtSearch{n,T}, depth::Int) where {n,T}
    length(s.cands) >= s.limit && return
    if depth == s.m  # L fully determined → record candidate
        push!(s.cands, SBox{n,T}(T.(s.sbox)))
        return
    end
    x = 1 << depth
    @inbounds for y in s.Lorder[depth+1]
        if _is_potential_L!(s, depth, y)
            ok = true
            last = x - 1
            for xS = x:((x<<1)-1)
                pos = s.half + xS
                s.sbox[pos+1] = _evlin(s.L, xS, s.m) ⊻ s.sbox[xS+1]
                last = xS
                if !_ext_add_ddt!(s, pos)
                    ok = false
                    break
                end
            end
            ok && _ext_recurse!(s, depth + 1)
            for xS = last:-1:x          # undo, in reverse
                _ext_remove_ddt!(s, s.half + xS)
                s.sbox[s.half+xS+1] = -1
            end
            s.L[depth+1] = -1
        end
        length(s.cands) >= s.limit && return
    end
    return
end

"""
    extend_quadratic_apn(G::SBox{M}; limit=1, rng=nothing) -> Vector{SBox{M+1}}

Search for `(M+1)`-bit quadratic APN extensions of the `M`-bit quadratic APN
function `G` ([Beierle, Leander and Perrin, 2022](@cite Beierle_202200)),
returning up to `limit` of
them. Deterministic by default (top coordinate `c = 0`, natural `L` order);
pass an `AbstractRNG` for a reproducible randomised top coordinate and `L` order.

Each returned function is independently re-verified to be APN
(`differential_uniformity == 2`) and of algebraic degree `2`.
"""
function extend_quadratic_apn(
    G::SBox{M};
    limit::Integer = 1,
    rng::Union{Nothing,AbstractRNG} = nothing,
) where {M}
    n = M + 1
    T = _storage_for(n)
    half = 1 << M
    full = 1 << n

    # Lower half: G with a degree-≤2 top coordinate c (0 or random).
    lower = [Int(G(x)) for x = 0:(half-1)]   # top bit 0 (values < 2ᴹ)
    if rng !== nothing
        lower = _ext_random_top_coord(G, M, rng)
    end

    sbox = fill(-1, full)
    @inbounds for x = 0:(half-1)
        sbox[x+1] = lower[x+1]
    end

    # Per-difference constraints on L (extract_betas + remove_impossibles).
    possibles = trues(half, full)
    @inbounds for a = 1:(half-1)
        betas = Int[]
        seen = falses(full)
        for x = 0:(half-1)
            β = lower[x+1] ⊻ lower[(x⊻a)+1]
            if !seen[β+1]
                seen[β+1] = true
                push!(betas, β)
            end
        end
        for β1 in betas, β2 in betas
            possibles[a, (β1⊻β2)+1] = false
        end
    end

    # --- L-order per depth (natural, or reproducibly shuffled) ---
    Lorder = [collect(0:(full-1)) for _ = 1:M]
    if rng !== nothing
        for d = 1:M
            shuffle!(rng, Lorder[d])
        end
    end

    # seed the upper half's base point: F(2ᴹ) = F(0)
    sbox[half+1] = sbox[1]

    s = _ExtSearch{n,T}(
        M,
        half,
        full,
        sbox,
        zeros(Int, half, full),
        possibles,
        fill(-1, M),
        Lorder,
        Int(limit),
        SBox{n,T}[],
    )
    _ext_recurse!(s, 0)

    # independent confirmation: keep only genuine quadratic APN extensions
    filter!(
        F -> differential_uniformity(F) == 2 && algebraic_degree(F) == 2,
        s.cands,
    )
    s.cands
end

# Random degree-≤2 top coordinate c; lower half is G(x) ⊕ (c(x) ≪ M).
function _ext_random_top_coord(G::SBox{M}, m::Int, rng::AbstractRNG) where {M}
    half = 1 << m
    full = 1 << (m + 1)
    lower = fill(-1, half)
    cube_ctr = zeros(Int, full)
    cube_sum = zeros(Int, full)

    adddeg = function (c)
        @inbounds for u = 0:(full-1)
            if count_ones(u) >= 3 && (c & ~u) == 0
                cube_ctr[u+1] += 1
                cube_sum[u+1] ⊻= lower[c+1]
                if cube_ctr[u+1] == (1 << count_ones(u))
                    cube_sum[u+1] != 0 && return false
                end
            end
        end
        true
    end
    remdeg = function (c)
        @inbounds for u = 0:(full-1)
            if count_ones(u) >= 3 && (c & ~u) == 0
                cube_ctr[u+1] -= 1
                cube_sum[u+1] ⊻= lower[c+1]
            end
        end
        nothing
    end

    lower[1] = Int(G(0))                  # c(0) = 0
    adddeg(0)
    function rec(c)
        c == half && return true
        for bit in shuffle!(rng, [0, 1])
            lower[c+1] = Int(G(c)) ⊻ (bit << m)
            if adddeg(c) && rec(c + 1)
                return true
            end
            remdeg(c)
            lower[c+1] = -1
        end
        false
    end
    rec(1)
    lower
end
