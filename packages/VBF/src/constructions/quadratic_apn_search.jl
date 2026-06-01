"""
Tree search for quadratic APN functions ([Beierle and Leander, 2022](@cite BeierleLeander2022)).

[`search_quadratic_apn`](@ref) constructs APN functions `F : F₂ⁿ → F₂ⁿ` of
algebraic degree ≤ 2 by depth-first backtracking over the lookup table. The
table is filled one position at a time (with `F(0) = 0` fixed), pruning a
partial branch as soon as either of two necessary conditions is violated:

  * **APN.** The partial difference distribution table is maintained
    incrementally; a branch dies the moment any entry would exceed `2` (an APN
    function has all DDT entries `≤ 2`). Only even-Hamming-weight input
    differences need to be tracked during construction.
  * **Degree ≤ 2.** Algebraic degree `≤ d` is equivalent to every affine cube
    of dimension `> d` summing to zero. The search incrementally accumulates,
    for each monomial support `u` with `|u| ≥ 3`, the XOR over the points of the
    `u`-cube; when a cube completes, a nonzero sum kills the branch.

The upstream samples the search space with time-bounded random restarts
(`mt19937` Fisher–Yates), so its output is not reproducible. This
implementation instead runs a single, **deterministic** depth-first search: the
value order tried at each position is the natural order `0, 1, …, 2ⁿ-1` by
default, making the enumeration bit-for-bit reproducible. A reproducible
*randomised* order may be requested by passing an `rng` (the per-position value
orders are then drawn from it once, up front), recovering the upstream's
restart-style diversification without sacrificing reproducibility.

Each completed candidate is verified by an independent full APN + degree-2
check before being returned, so every element of the result is a genuine
quadratic APN function. The search returns as soon as `limit` solutions are
found; the default `limit = 1` yields the first quadratic APN with `F(0) = 0`
in the search order.
"""

using Random

# Backtracking state for a single `search_quadratic_apn` invocation. The
# partial S-box `sbox` uses `-1` for unset positions; `ddt[a+1, d+1]` is the
# running count for input difference `a` and output difference `d` (incremented
# in steps of 2, one per ordered pair); `cube_ctr`/`cube_sum` track, per
# monomial support `u`, how many points of the `u`-cube are set and their XOR.
struct _QApnSearch{N, T}
    n::Int                      # 2ⁿ
    evens::Vector{Int}          # nonzero even-Hamming-weight input differences
    hw::Vector{Int}             # popcount of 0:2ⁿ-1
    order::Vector{Vector{Int}}  # per-depth value order to try
    sbox::Vector{Int}
    ddt::Matrix{Int}
    cube_ctr::Vector{Int}
    cube_sum::Vector{Int}
    limit::Int
    sols::Vector{SBox{N, T}}
end

# Incrementally fold position `c` into the partial DDT. Returns `false` (and
# leaves the partially-applied increments in place, to be undone by
# `_remove_ddt!`) the moment an entry would exceed 2 — i.e. the branch cannot be
# APN.
function _add_ddt!(s::_QApnSearch, c::Int)
    sb = s.sbox; ddt = s.ddt
    @inbounds for a in s.evens
        cn = c ⊻ a
        if sb[cn + 1] != -1
            d = sb[c + 1] ⊻ sb[cn + 1]
            ddt[a + 1, d + 1] += 2
            ddt[a + 1, d + 1] > 2 && return false
        end
    end
    true
end

# Undo `_add_ddt!(c)`. Mirrors the add loop in the same order and stops at the
# entry the add stopped on (the one that reached 4, now back to 2), so that
# increments the add never made are not decremented.
function _remove_ddt!(s::_QApnSearch, c::Int)
    sb = s.sbox; ddt = s.ddt
    @inbounds for a in s.evens
        cn = c ⊻ a
        if sb[cn + 1] != -1
            d = sb[c + 1] ⊻ sb[cn + 1]
            ddt[a + 1, d + 1] -= 2
            ddt[a + 1, d + 1] == 2 && return false
        end
    end
    true
end

# Fold position `c` into the per-cube accumulators. A completed cube (all
# `2^{|u|}` points set) of dimension ≥ 3 must sum to zero for degree ≤ 2.
function _add_degree!(s::_QApnSearch, c::Int)
    sb = s.sbox; ctr = s.cube_ctr; sum = s.cube_sum; hw = s.hw
    @inbounds for u in 0:s.n - 1
        if hw[u + 1] >= 3 && (c & ~u) == 0
            ctr[u + 1] += 1
            sum[u + 1] ⊻= sb[c + 1]
            if ctr[u + 1] == (1 << hw[u + 1])
                sum[u + 1] != 0 && return false
            end
        end
    end
    true
end

# Undo `_add_degree!(c)`, mirroring its early stop at the offending cube.
function _remove_degree!(s::_QApnSearch, c::Int)
    sb = s.sbox; ctr = s.cube_ctr; sum = s.cube_sum; hw = s.hw
    @inbounds for u in 0:s.n - 1
        if hw[u + 1] >= 3 && (c & ~u) == 0
            ctr[u + 1] -= 1
            sum[u + 1] ⊻= sb[c + 1]
            if ctr[u + 1] == (1 << hw[u + 1]) - 1
                sum[u + 1] != sb[c + 1] && return false
            end
        end
    end
    true
end

# Add position `c`: APN-prune first, then degree-prune. Returns whether the
# branch survives.
_add_point!(s::_QApnSearch, c::Int) = _add_ddt!(s, c) ? _add_degree!(s, c) : false

# Undo `_add_point!(c)`. When the DDT add failed, the degree info was never
# applied (and `_remove_ddt!` early-returned), so the degree undo is skipped.
function _remove_point!(s::_QApnSearch, c::Int)
    _remove_ddt!(s, c) && _remove_degree!(s, c)
    nothing
end

function _qapn_recurse!(s::_QApnSearch{N, T}, depth::Int) where {N, T}
    length(s.sols) >= s.limit && return
    if depth == s.n - 1                     # every position assigned
        push!(s.sols, SBox{N, T}(T.(s.sbox)))
        return
    end
    x = depth + 1                           # next free position
    ord = s.order[depth + 1]
    @inbounds for y in ord
        s.sbox[x + 1] = y
        if _add_point!(s, x)
            _qapn_recurse!(s, depth + 1)
        end
        _remove_point!(s, x)
        s.sbox[x + 1] = -1
        length(s.sols) >= s.limit && return
    end
    return
end

"""
    search_quadratic_apn(::Val{N}; limit=1, rng=nothing) -> Vector{SBox{N}}

Search for quadratic APN functions of dimension `N` (with `F(0) = 0`) by the
degree- and DDT-pruned backtracking of [Beierle and Leander (2022)](@cite BeierleLeander2022),
returning up to `limit` of them. The search is deterministic by default; pass an
`AbstractRNG` as `rng` to draw a reproducible random per-position value order
(the upstream's restart-style diversification) instead of the natural order.

Every returned function is independently re-verified to be APN
(`differential_uniformity == 2`) and of algebraic degree `2`.
"""
function search_quadratic_apn(::Val{N}; limit::Integer = 1,
                              rng::Union{Nothing, AbstractRNG} = nothing) where {N}
    N >= 1 || throw(ArgumentError("search_quadratic_apn: N must be ≥ 1, got $N"))
    T = _storage_for(N)
    n = 1 << N
    evens = Int[a for a in 1:n - 1 if iseven(count_ones(a))]
    hw = Int[count_ones(u) for u in 0:n - 1]
    order = [collect(0:n - 1) for _ in 1:n]
    if rng !== nothing
        for d in 1:n
            shuffle!(rng, order[d])
        end
    end
    sbox = fill(-1, n)
    sbox[1] = 0
    s = _QApnSearch{N, T}(n, evens, hw, order, sbox, zeros(Int, n, n),
                         zeros(Int, n), zeros(Int, n), Int(limit), SBox{N, T}[])
    _add_point!(s, 0) || return s.sols       # seed F(0) = 0
    _qapn_recurse!(s, 0)
    # Independent confirmation: keep only genuine quadratic APN functions.
    filter!(F -> differential_uniformity(F) == 2 && algebraic_degree(F) == 2, s.sols)
    s.sols
end
