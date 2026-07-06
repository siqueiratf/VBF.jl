"""
Linear equivalence of **canonical 3-to-1 (triplicate) functions**
([Ivković and Kaleyski, 2022](@cite Ivkovic_202200)). A canonical triplicate
has `F(0)=0` and every fibre equal to
an `F₄`-line `{i, βi, β²i}` (β the order-3 element of `GF(2ⁿ)`), all three mapping
to the same value — so `x³` is the prototypical example.

`are_3to1_linear_equivalent(C₁, C₂)` decides whether `C₂ = L₁ ∘ C₁ ∘ L₂` for
invertible F₂-linear `L₁, L₂`, returning one such pair or `nothing`;
`self_3to1_linear_equivalences(C)` returns all `(L₁, L₂)` with `L₁ ∘ C ∘ L₂ = C`.

The search guesses `L₁` on triple-outputs (pairing a `C₁`-output with a
`C₂`-output), configures `L₂` by matching the three preimages of the paired
triples (three rotations × two parities), propagates both maps by linearity, and
backtracks on any contradiction (Ivković–Kaleyski's algorithm).
"""

# ----- canonical-triplicate representation ----------------------------------

struct _Triplicate
    tN::Int
    t::Matrix{Int}     # 4×tN: row 1 = output, rows 2..4 = the three preimages
    ol::Vector{Int}    # ol[y+1] = triple index whose output is y, else 0
end

"""
    canonical_triplicate(F) -> _Triplicate | nothing

Build the canonical-triplicate structure of `F` (fibres `{i, βi, β²i}` with
`β = gf_pow(2, (2ⁿ-1)/3, n)`), or `nothing` if `F` is not a canonical triplicate.
"""
function canonical_triplicate(F::SBox{N,T}) where {N,T}
    n = 1 << N
    (iseven(N) && (n - 1) % 3 == 0) || return nothing
    F.lut[1] == 0 || return nothing
    β = gf_pow(2, (n - 1) ÷ 3, N)
    tN = (n - 1) ÷ 3
    t = zeros(Int, 4, tN)
    ol = zeros(Int, n)
    seen = falses(n)
    seen[1] = true
    j = 0
    @inbounds for i = 1:(n-1)
        seen[i+1] && continue
        y = Int(F.lut[i+1])
        (y == 0 || ol[y+1] != 0) && return nothing
        k = gf_mul(i, β, N)
        ki = k ⊻ i
        (Int(F.lut[k+1]) == y && Int(F.lut[ki+1]) == y) || return nothing
        j += 1
        ol[y+1] = j
        t[1, j] = y
        t[2, j] = i
        t[3, j] = k
        t[4, j] = ki
        seen[i+1] = true
        seen[k+1] = true
        seen[ki+1] = true
    end
    j == tN || return nothing
    _Triplicate(tN, t, ol)
end

# ----- the backtracking search ----------------------------------------------

mutable struct _Lin
    x::Vector{Int}     # x[v+1] : preimage of v  (0 = unset)
    y::Vector{Int}     # y[v+1] : image of v     (0 = unset)
end
_copy(L::_Lin) = _Lin(copy(L.x), copy(L.y))

mutable struct _TEqCtx
    Flut::Vector{Int}
    Glut::Vector{Int}
    Ft::_Triplicate
    Gt::_Triplicate
    NE::Int                       # 2ⁿ
    N::Int
    collect_all::Bool
    sols::Vector{Tuple{Vector{Int},Vector{Int}}}   # (L1.y, L2.y) copies
    stop::Bool
end

# Propagate L1 over the linear span of the configured f-guesses; extend fgs.
function _check!(ctx::_TEqCtx, L1::_Lin, fgs::Vector{Int}, a::Int)
    NE = ctx.NE
    b = 0
    @inbounds while fgs[b+1] != 0
        
        b += 1
    end
    n = b
    k = b
    @inbounds for i = a:(b-1)
        # combine with earlier originals, then with newly-added (b..n)
        for j = 0:(i-1)
            _check_pair!(ctx, L1, fgs, i, j) || return false
            k = _check_absorb!(ctx, L1, fgs, i, j, k)
            k == -1 && return false
        end
        for j = b:(n-1)
            _check_pair!(ctx, L1, fgs, i, j) || return false
            k = _check_absorb!(ctx, L1, fgs, i, j, k)
            k == -1 && return false
        end
        n = k
    end
    return true
end

# consistency-only part of one (i,j) combination
@inline function _check_pair!(
    ctx::_TEqCtx,
    L1::_Lin,
    fgs::Vector{Int},
    i::Int,
    j::Int,
)
    f = fgs[i+1] ⊻ fgs[j+1]
    g = L1.y[fgs[i+1]+1] ⊻ L1.y[fgs[j+1]+1]
    ((f == 0 && g != 0) || (g == 0 && f != 0)) && return false
    (L1.x[g+1] != 0 && L1.x[g+1] != f) && return false
    (L1.y[f+1] != 0 && L1.y[f+1] != g) && return false
    return true
end

# absorb a new (f→g) pair if unset; returns updated k, or -1 on contradiction
@inline function _check_absorb!(
    ctx::_TEqCtx,
    L1::_Lin,
    fgs::Vector{Int},
    i::Int,
    j::Int,
    k::Int,
)
    NE = ctx.NE
    f = fgs[i+1] ⊻ fgs[j+1]
    g = L1.y[fgs[i+1]+1] ⊻ L1.y[fgs[j+1]+1]
    if L1.y[f+1] == 0 && f != 0
        if ctx.Ft.ol[f+1] != 0 && ctx.Gt.ol[g+1] != 0
            fgs[k+1] = f
            k += 1
            L1.y[f+1] = g
            L1.x[g+1] = f
        elseif ctx.Ft.ol[f+1] == 0 && ctx.Gt.ol[g+1] == 0
            fgs[k+1] = f
            fgs[NE+k+1] = 1
            k += 1
            L1.y[f+1] = g
            L1.x[g+1] = f
        else
            return -1
        end
    end
    return k
end

# Configure L2 on the three preimages of triple f↔g (rotation xymc, parity cfg).
function _configure!(
    ctx::_TEqCtx,
    L2::_Lin,
    f::Int,
    g::Int,
    xymc::Int,
    cfg::Int,
)
    Ft = ctx.Ft
    Gt = ctx.Gt
    # rows of Ft.t/Gt.t: 2,3,4 are the three preimages
    a1 = Ft.t[2, f+1]
    a2 = Ft.t[3, f+1]
    a3 = Ft.t[4, f+1]
    b1 = Gt.t[2, g+1]
    b2 = Gt.t[3, g+1]
    b3 = Gt.t[4, g+1]
    # (target preimage of Gt) ← (source preimage of Ft), per the C's six cases
    if cfg == 1
        m =
            xymc == 0 ? ((b1, a1), (b2, a2), (b3, a3)) :
            xymc == 1 ? ((b1, a2), (b2, a3), (b3, a1)) :
            ((b1, a3), (b2, a1), (b3, a2))
    else
        m =
            xymc == 0 ? ((b1, a2), (b2, a1), (b3, a3)) :
            xymc == 1 ? ((b1, a3), (b2, a2), (b3, a1)) :
            ((b1, a1), (b2, a3), (b3, a2))
    end
    @inbounds for (gb, fa) in m
        L2.y[gb+1] = fa
        L2.x[fa+1] = gb
    end
end

# Combine the new x-triple with earlier ones; record products in L2, append xgs.
function _combine!(L2::_Lin, xgs::Vector{Int}, px::Int)
    a = (1 << (2px)) - 1
    b = a + 3
    @inbounds for i = 0:3:(a-1)
        for r = 0:2, s = 0:2
            xa = xgs[a+r+1]
            xi = xgs[i+s+1]
            v = L2.y[xa+1] ⊻ L2.y[xi+1]
            L2.y[(xa⊻xi)+1] = v
            L2.x[v+1] = xa ⊻ xi
        end
        # append the 9 new x-combinations (column-rotated, matching the C)
        xgs[b+3i+1] = xgs[a+1] ⊻ xgs[i+1]
        xgs[b+3i+2] = xgs[a+2] ⊻ xgs[i+2]
        xgs[b+3i+3] = xgs[a+3] ⊻ xgs[i+3]
        xgs[b+3i+4] = xgs[a+1] ⊻ xgs[i+2]
        xgs[b+3i+5] = xgs[a+2] ⊻ xgs[i+3]
        xgs[b+3i+6] = xgs[a+3] ⊻ xgs[i+1]
        xgs[b+3i+7] = xgs[a+1] ⊻ xgs[i+3]
        xgs[b+3i+8] = xgs[a+2] ⊻ xgs[i+1]
        xgs[b+3i+9] = xgs[a+3] ⊻ xgs[i+2]
    end
end

# From the newly-combined L2 x-values, read off and record implied L1 pairs.
function _generate!(
    ctx::_TEqCtx,
    L1::_Lin,
    L2::_Lin,
    fgs::Vector{Int},
    xgs::Vector{Int},
    px::Int,
)
    NE = ctx.NE
    a = (1 << (2px)) + 2
    b = (1 << (2 * (px + 1))) - 1
    n = 0
    @inbounds while fgs[n+1] != 0
        
        n += 1
    end
    j = n
    @inbounds for i = a:3:(b-1)
        xi = xgs[i+1]
        g = ctx.Glut[xi+1]
        f = ctx.Flut[L2.y[xi+1]+1]
        ((f == 0 && g != 0) || (g == 0 && f != 0)) && return 0
        (L1.x[g+1] != 0 && L1.x[g+1] != f) && return 0
        (L1.y[f+1] != 0 && L1.y[f+1] != g) && return 0
        if L1.y[f+1] != 0
            for kk = 0:(n-1)
                if fgs[kk+1] == f
                    fgs[NE+kk+1] = 1
                    break
                end
            end
        else
            fgs[n+1] = f
            fgs[NE+n+1] = 1
            n += 1
            L1.y[f+1] = g
            L1.x[g+1] = f
        end
    end
    return j
end

function _guess!(
    ctx::_TEqCtx,
    L1::_Lin,
    L2::_Lin,
    fgs::Vector{Int},
    xgs::Vector{Int},
    px::Int,
    cfg::Int,
)
    ctx.stop && return
    NE = ctx.NE
    Ft = ctx.Ft
    Gt = ctx.Gt
    n = (1 << (2px)) - 1
    pf = -1
    @inbounds for i = 0:(NE-2)
        if fgs[NE+i+1] == 0
            pf = i
            break
        end
    end
    if pf == -1
        # all f-guesses configured → a complete solution
        push!(ctx.sols, (copy(L1.y), copy(L2.y)))
        ctx.collect_all || (ctx.stop = true)
        return
    end

    if fgs[pf+1] != 0
        f = Ft.ol[fgs[pf+1]+1] - 1
        g = Gt.ol[L1.y[fgs[pf+1]+1]+1] - 1
        l2 = _copy(L2)
        fgss = copy(fgs)
        fgss[NE+pf+1] = 1
        xgs[n+1] = Gt.t[2, g+1]
        xgs[n+2] = Gt.t[3, g+1]
        xgs[n+3] = Gt.t[4, g+1]
        _assign!(ctx, L1, l2, f, g, fgss, xgs, 0, px, cfg)
    else
        f = 0
        while f < Ft.tN && L1.y[Ft.t[1, f+1]+1] != 0
            
            f += 1
        end
        g = 0
        while g < Gt.tN && L1.x[Gt.t[1, g+1]+1] != 0
            
            g += 1
        end
        while g < Gt.tN
            ctx.stop && return
            l1 = _copy(L1)
            fgss = copy(fgs)
            l1.y[Ft.t[1, f+1]+1] = Gt.t[1, g+1]  # pair output f with g
            l1.x[Gt.t[1, g+1]+1] = Ft.t[1, f+1]
            fgss[pf+1] = Ft.t[1, f+1]
            if _check!(ctx, l1, fgss, pf)
                fgss[NE+pf+1] = 1
                l2 = _copy(L2)
                xgs[n+1] = Gt.t[2, g+1]
                xgs[n+2] = Gt.t[3, g+1]
                xgs[n+3] = Gt.t[4, g+1]
                _assign!(ctx, l1, l2, f, g, fgss, xgs, 0, px, cfg)
            end
            g += 1
            while g < Gt.tN && L1.x[Gt.t[1, g+1]+1] != 0
                
                g += 1
            end
        end
    end
    return
end

function _assign!(
    ctx::_TEqCtx,
    L1::_Lin,
    L2::_Lin,
    f::Int,
    g::Int,
    fgs::Vector{Int},
    xgs::Vector{Int},
    xymc::Int,
    px::Int,
    cfg::Int,
)
    while xymc < 3
        ctx.stop && return
        _configure!(ctx, L2, f, g, xymc, cfg)
        l1 = _copy(L1)
        l2 = _copy(L2)
        fgss = copy(fgs)
        _combine!(l2, xgs, px)
        a = _generate!(ctx, l1, l2, fgss, xgs, px)
        if a != 0
            if _check!(ctx, l1, fgss, a)
                _guess!(ctx, l1, l2, fgss, xgs, px + 1, cfg)
            end
        end
        xymc += 1
    end
    return
end

# Linear map LUT (its `.y`) → F2LinearMap via its standard-basis images.
function _lin_to_map(y::Vector{Int}, N::Int)
    F2LinearMap{N}([y[(1<<j)+1] for j = 0:(N-1)])
end

function _run_3to1_equivalence(
    C1::SBox{N,T},
    C2::SBox{N,T},
    collect_all::Bool,
) where {N,T}
    Ft = canonical_triplicate(C1)
    Ft === nothing && return nothing
    Gt = canonical_triplicate(C2)
    Gt === nothing && return nothing
    NE = 1 << N
    ctx = _TEqCtx(
        Int.(C1.lut),
        Int.(C2.lut),
        Ft,
        Gt,
        NE,
        N,
        collect_all,
        Tuple{Vector{Int},Vector{Int}}[],
        false,
    )
    L1 = _Lin(zeros(Int, NE), zeros(Int, NE))
    L2 = _Lin(zeros(Int, NE), zeros(Int, NE))
    fgs = zeros(Int, 2NE)
    xgs = zeros(Int, 16NE + 16)
    f = 0
    g = 0
    @inbounds while g < Gt.tN
        ctx.stop && break
        fill!(L1.x, 0)
        fill!(L1.y, 0)
        L1.y[Ft.t[1, f+1]+1] = Gt.t[1, g+1]        # L1 maps output→output
        L1.x[Gt.t[1, g+1]+1] = Ft.t[1, f+1]
        fill!(fgs, 0)
        fgs[1] = Ft.t[1, f+1]
        fgs[NE+1] = 1
        fill!(xgs, 0)
        xgs[1] = Gt.t[2, g+1]
        xgs[2] = Gt.t[3, g+1]
        xgs[3] = Gt.t[4, g+1]
        fill!(L2.x, 0)
        fill!(L2.y, 0)
        _assign!(ctx, L1, L2, f, g, fgs, xgs, 0, 0, 1)
        ctx.stop && break
        fill!(L2.x, 0)
        fill!(L2.y, 0)
        _assign!(ctx, L1, L2, f, g, fgs, xgs, 0, 0, 2)
        g += 1
    end

    if collect_all
        return [
            (_lin_to_map(y1, N), _lin_to_map(y2, N)) for (y1, y2) in ctx.sols
        ]
    else
        isempty(ctx.sols) && return nothing
        y1, y2 = ctx.sols[1]
        return (_lin_to_map(y1, N), _lin_to_map(y2, N))
    end
end

"""
    are_3to1_linear_equivalent(C1, C2) -> Union{Tuple{F2LinearMap,F2LinearMap}, Nothing}

For canonical 3-to-1 functions `C1, C2`, return `(L₁, L₂)` with
`C₂ = L₁ ∘ C₁ ∘ L₂` (invertible F₂-linear), or `nothing`. Returns `nothing` if
either argument is not a canonical triplicate.
"""
are_3to1_linear_equivalent(C1::SBox{N,T}, C2::SBox{N,T}) where {N,T} =
    _run_3to1_equivalence(C1, C2, false)

"""
    self_3to1_linear_equivalences(C) -> Vector{Tuple{F2LinearMap,F2LinearMap}}

All `(L₁, L₂)` with `L₁ ∘ C ∘ L₂ = C` for a canonical 3-to-1 function `C`
(empty if `C` is not a canonical triplicate).
"""
function self_3to1_linear_equivalences(C::SBox{N,T}) where {N,T}
    r = _run_3to1_equivalence(C, C, true)
    r === nothing ? Tuple{F2LinearMap,F2LinearMap}[] : r
end

# ----- alg2: canonical representative of a (zero-sum) 3-to-1 function --------

# Looser triplicate detector: any zero-sum triple with equal output.
function _zero_sum_triplicate(F::SBox{N,T}) where {N,T}
    n = 1 << N
    (iseven(N) && (n - 1) % 3 == 0) || return nothing
    F.lut[1] == 0 || return nothing
    β = gf_pow(2, (n - 1) ÷ 3, N)
    tN = (n - 1) ÷ 3
    t = zeros(Int, 4, tN)
    ol = zeros(Int, n)
    seen = falses(n)
    seen[1] = true
    j = 0
    @inbounds for i = 1:(n-1)
        seen[i+1] && continue
        y = Int(F.lut[i+1])
        (y == 0 || ol[y+1] != 0) && return nothing
        k = gf_mul(i, β, N)
        if !(Int(F.lut[k+1]) == y && Int(F.lut[(k⊻i)+1]) == y)
            k = 0
            for kk = (i+1):(n-1)
                if Int(F.lut[kk+1]) == y && Int(F.lut[(kk⊻i)+1]) == y
                    k = kk
                    break
                end
            end
            k == 0 && return nothing
        end
        ki = k ⊻ i
        j += 1
        ol[y+1] = j
        t[1, j] = y
        t[2, j] = i
        t[3, j] = k
        t[4, j] = ki
        seen[i+1] = true
        seen[k+1] = true
        seen[ki+1] = true
    end
    j == tN || return nothing
    _Triplicate(tN, t, ol)
end

# Build the canonical β-coset triple structure and the x-guess sequence `xgs`.
function _empty_canonical(N::Int)
    n = 1 << N
    β = gf_pow(2, (n - 1) ÷ 3, N)
    tN = (n - 1) ÷ 3
    t = zeros(Int, 4, tN)
    seen = falses(n)
    seen[1] = true
    j = 0
    @inbounds for i = 1:(n-1)
        seen[i+1] && continue
        k = gf_mul(i, β, N)
        ki = k ⊻ i
        j += 1
        t[2, j] = i
        t[3, j] = k
        t[4, j] = ki
        seen[i+1] = true
        seen[k+1] = true
        seen[ki+1] = true
    end
    xgs = zeros(Int, 16n + 16)
    used = falses(tN)
    @inbounds for kk = 0:(N÷2-1)
        a = (1 << (2kk)) - 1
        b = a + 3
        jj = 0
        while jj < tN && used[jj+1]
            
            jj += 1
        end
        used[jj+1] = true
        xgs[a+1] = t[2, jj+1]
        xgs[a+2] = t[3, jj+1]
        xgs[a+3] = t[4, jj+1]
        for i = 0:3:(a-1)
            xgs[b+3i+1] = xgs[a+1] ⊻ xgs[i+1]
            xgs[b+3i+2] = xgs[a+2] ⊻ xgs[i+2]
            xgs[b+3i+3] = xgs[a+3] ⊻ xgs[i+3]
            xgs[b+3i+4] = xgs[a+1] ⊻ xgs[i+2]
            xgs[b+3i+5] = xgs[a+2] ⊻ xgs[i+3]
            xgs[b+3i+6] = xgs[a+3] ⊻ xgs[i+1]
            xgs[b+3i+7] = xgs[a+1] ⊻ xgs[i+3]
            xgs[b+3i+8] = xgs[a+2] ⊻ xgs[i+1]
            xgs[b+3i+9] = xgs[a+3] ⊻ xgs[i+2]
        end
        a2 = (1 << (2kk)) + 2
        b2 = (1 << (2 * (kk + 1))) - 1
        for i = a2:3:(b2-1)
            v = xgs[i+1]
            jx = 0
            # v is a nonzero field element, so it lies in exactly one β-coset
            # triple; find that column by testing all three members (i, βi, β²i
            # in rows 2,3,4), not just the representative t[2, ·]. v is always
            # found with jx < tN, so the search stays in bounds.
            while jx < tN &&
                  t[2, jx+1] != v && t[3, jx+1] != v && t[4, jx+1] != v
                jx += 1
            end
            used[jx+1] = true
        end
    end
    xgs
end

mutable struct _CanonCtx
    Tlut::Vector{Int}
    Tt::_Triplicate
    NE::Int
    N::Int
    xgs::Vector{Int}
    found::Bool
    Cy::Vector{Int}      # result: canonical C's LUT
    L2y::Vector{Int}     # result: L2's LUT  (C = T ∘ L2)
end

function _canon_configure!(
    ctx::_CanonCtx,
    ygs::Vector{Int},
    f::Int,
    xymc::Int,
    px::Int,
)
    a = (1 << (2px)) - 1
    p1 = ctx.Tt.t[2, f+1]
    p2 = ctx.Tt.t[3, f+1]
    p3 = ctx.Tt.t[4, f+1]
    o =
        xymc == 0 ? (p1, p2, p3) :
        xymc == 1 ? (p2, p3, p1) :
        xymc == 2 ? (p3, p1, p2) :
        xymc == 3 ? (p2, p1, p3) : xymc == 4 ? (p3, p2, p1) : (p1, p3, p2)
    @inbounds ygs[a+1] = o[1]
    ygs[a+2] = o[2]
    ygs[a+3] = o[3]
end

function _canon_combine!(ygs::Vector{Int}, px::Int)
    a = (1 << (2px)) - 1
    b = a + 3
    @inbounds for i = 0:3:(a-1)
        ygs[b+3i+1] = ygs[a+1] ⊻ ygs[i+1]
        ygs[b+3i+2] = ygs[a+2] ⊻ ygs[i+2]
        ygs[b+3i+3] = ygs[a+3] ⊻ ygs[i+3]
        ygs[b+3i+4] = ygs[a+1] ⊻ ygs[i+2]
        ygs[b+3i+5] = ygs[a+2] ⊻ ygs[i+3]
        ygs[b+3i+6] = ygs[a+3] ⊻ ygs[i+1]
        ygs[b+3i+7] = ygs[a+1] ⊻ ygs[i+3]
        ygs[b+3i+8] = ygs[a+2] ⊻ ygs[i+1]
        ygs[b+3i+9] = ygs[a+3] ⊻ ygs[i+2]
    end
end

# Every newly-combined y-triple must be a genuine, not-yet-used T-triple.
function _canon_check!(
    ctx::_CanonCtx,
    tgs::Vector{Int},
    ygs::Vector{Int},
    px::Int,
)
    a = (1 << (2px)) + 2
    b = (1 << (2 * (px + 1))) - 1
    Tl = ctx.Tlut
    ol = ctx.Tt.ol
    @inbounds for i = a:3:(b-1)
        (ygs[i+1] ⊻ ygs[i+2] ⊻ ygs[i+3]) != 0 && return false
        v = Tl[ygs[i+1]+1]
        (Tl[ygs[i+2]+1] != v || Tl[ygs[i+3]+1] != v) && return false
        k = ol[v+1] - 1
        tgs[k+1] == 1 && return false
        tgs[k+1] = 1
    end
    return true
end

function _canon_retrieve!(ctx::_CanonCtx, ygs::Vector{Int})
    Cy = zeros(Int, ctx.NE)
    L2y = zeros(Int, ctx.NE)
    @inbounds for i = 0:(ctx.NE-1)
        L2y[ctx.xgs[i+1]+1] = ygs[i+1]
        Cy[ctx.xgs[i+1]+1] = ctx.Tlut[ygs[i+1]+1]
    end
    ctx.Cy = Cy
    ctx.L2y = L2y
    ctx.found = true
end

function _canon_guess!(
    ctx::_CanonCtx,
    tgs::Vector{Int},
    ygs::Vector{Int},
    px::Int,
)
    ctx.found && return
    tN = ctx.Tt.tN
    t = 0
    @inbounds while t < tN && tgs[t+1] != 0
        
        t += 1
    end
    if t == tN
        _canon_retrieve!(ctx, ygs)
        return
    end
    while t < tN
        ctx.found && return
        tgs[t+1] = 1
        _canon_assign!(ctx, t, tgs, ygs, 0, px)
        ctx.found && return
        tgs[t+1] = 0
        t += 1
        @inbounds while t < tN && tgs[t+1] != 0
            
            t += 1
        end
    end
end

function _canon_assign!(
    ctx::_CanonCtx,
    t::Int,
    tgs::Vector{Int},
    ygs::Vector{Int},
    xymc::Int,
    px::Int,
)
    while xymc < 6
        ctx.found && return
        _canon_configure!(ctx, ygs, t, xymc, px)
        tgss = copy(tgs)
        _canon_combine!(ygs, px)
        if _canon_check!(ctx, tgss, ygs, px)
            _canon_guess!(ctx, tgss, ygs, px + 1)
        end
        xymc += 1
    end
end

"""
    canonical_3to1_representative(T) -> Union{Tuple{SBox, F2LinearMap}, Nothing}

For a zero-sum 3-to-1 function `T`, find a **canonical** triplicate `C` and an
invertible F₂-linear `L` with `C = T ∘ L` (so `C` is the canonical
representative of `T`'s linear-equivalence class), or `nothing` if `T` is not a
zero-sum 3-to-1 function. (Ports Ivković–Kaleyski's `alg2`.)

!!! note "`nothing` for genuine zero-sum 3-to-1 inputs is possible and correct"
    The fibres of a zero-sum 3-to-1 function, each completed with 0, form a
    spread of 2-dimensional subspaces of `F₂ⁿ`. A canonical representative
    `C = T ∘ L` exists **iff** that spread is linearly equivalent to the
    Desarguesian β-coset spread `{ {i, βi, β²i} }`. Non-Desarguesian fibre
    spreads exist: the ortho-derivative of `kim_apn()` is a zero-sum 3-to-1
    function (trivial 0-fibre, all 21 fibres zero-sum) whose spread is *not*
    linearly equivalent to the β-coset spread (verified by exhaustive search
    over basis images), so it has no canonical triplicate representative and
    this function returns `nothing`. To enumerate linear self-equivalences of
    such functions use [`linear_equivalences_general`](@ref) instead of the
    3-to-1 machinery.
"""
function canonical_3to1_representative(T::SBox{N,S}) where {N,S}
    Tt = _zero_sum_triplicate(T)
    Tt === nothing && return nothing
    NE = 1 << N
    xgs = _empty_canonical(N)
    ctx = _CanonCtx(Int.(T.lut), Tt, NE, N, xgs, false, Int[], Int[])
    tgs = zeros(Int, Tt.tN)
    ygs = zeros(Int, 16NE + 16)
    t = 0
    @inbounds while t < Tt.tN
        ctx.found && break
        tgs[t+1] = 1
        _canon_assign!(ctx, t, tgs, ygs, 0, 0)
        ctx.found && break
        tgs[t+1] = 0
        t += 1
    end
    ctx.found || return nothing
    (SBox{N}(ctx.Cy), _lin_to_map(ctx.L2y, N))
end
