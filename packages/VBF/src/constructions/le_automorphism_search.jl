"""
LE-automorphism-constrained search for quadratic APN functions — Beierle–Leander,
"New Instances of Quadratic APN Functions" (IEEE-IT 2022).

The plain tree search [`search_quadratic_apn`](@ref) explodes past `n ≈ 6`. BL22's
`n = 7, 8` search instead fixes a **linear self-equivalence**: for canonical
`F₂`-linear maps `A, B`, it looks only for quadratic APN `F` with `A∘F = F∘B`.
Setting `F` at one point then *forces* the whole orbit, `F(B(x)) = A(F(x))`, which
prunes the tree to a feasible size — the only thing that makes those dimensions
tractable.

[`search_quadratic_apn_le`](@ref) fills the orbit representatives `pos` (one per
`B`-orbit; `fix` lists nonzero fixed points to also search), propagating each
assignment along its orbit and reusing the same incremental DDT- and degree-2
pruning as the unconstrained search ([`_add_point!`](@ref)/[`_remove_point!`](@ref)).
Each completed candidate is independently re-verified (`du == 2 && deg == 2`).
`A`, `B` are the length-`2ⁿ` lookup tables of the linear maps (the canonical-class
tuples of BL22). The n=7 canonical classes 1, 7, 16, 19 each yield quadratic APN,
reproducing the paper.

This is the per-class driver; it does not yet include the `is_smallest_in_class`
canonical-minimum filter (used to count *distinct* classes) — it certifies that a
class admits a quadratic APN, which is the n≤7 validation target.
"""
function search_quadratic_apn_le(A::AbstractVector{<:Integer}, B::AbstractVector{<:Integer};
                                 pos::AbstractVector{<:Integer},
                                 fix::AbstractVector{<:Integer} = Int[],
                                 limit::Integer = 1)
    length(A) == length(B) ||
        throw(ArgumentError("search_quadratic_apn_le: A and B must have equal length"))
    n = trailing_zeros(length(A))
    1 << n == length(A) ||
        throw(ArgumentError("search_quadratic_apn_le: length(A) must be a power of two"))
    n <= 8 || throw(ArgumentError("search_quadratic_apn_le: supports n ≤ 8, got n = $n"))
    _search_le(Val(n), Vector{Int}(A), Vector{Int}(B),
               Vector{Int}(pos), Vector{Int}(fix), Int(limit))
end

function _search_le(::Val{N}, A::Vector{Int}, B::Vector{Int},
                    pos::Vector{Int}, fix::Vector{Int}, limit::Int) where {N}
    N2 = 1 << N
    evens = [a for a in 1:N2 - 1 if iseven(count_ones(a))]
    hw = [count_ones(u) for u in 0:N2 - 1]
    s = _QApnSearch{N, UInt8}(N2, evens, hw, Vector{Int}[], fill(-1, N2),
                              zeros(Int, N2, N2), zeros(Int, N2), zeros(Int, N2),
                              limit, SBox{N, UInt8}[])
    s.sbox[1] = 0; _add_point!(s, 0)                       # F(0) = 0
    targets = vcat(pos, [f for f in fix if f != 0])

    # Set F along the B-orbit of `x` (with the output following the A-orbit of
    # `y`), DDT-/degree-pruning each forced point. Returns the list of newly-set
    # positions, or `nothing` on a value conflict or a pruned branch (leaving the
    # state restored in the latter case).
    set_orbit! = function (x::Int, y::Int)
        setp = Int[]; cx = x; cy = y
        while true
            cur = s.sbox[cx + 1]
            if cur == -1
                s.sbox[cx + 1] = cy
                if !_add_point!(s, cx)
                    _remove_point!(s, cx); s.sbox[cx + 1] = -1
                    for p in Iterators.reverse(setp); _remove_point!(s, p); s.sbox[p + 1] = -1; end
                    return nothing
                end
                push!(setp, cx)
            elseif cur != cy
                for p in Iterators.reverse(setp); _remove_point!(s, p); s.sbox[p + 1] = -1; end
                return nothing
            end
            nx = B[cx + 1]
            nx == x && break                                  # orbit closed
            cx = nx; cy = A[cy + 1]
        end
        setp
    end

    recurse! = function (pi::Int)
        length(s.sols) >= limit && return
        if pi > length(targets)
            all(v -> v != -1, s.sbox) && push!(s.sols, SBox{N, UInt8}(UInt8.(s.sbox)))
            return
        end
        x = targets[pi]
        if s.sbox[x + 1] != -1                                # already forced
            recurse!(pi + 1); return
        end
        for y in 0:N2 - 1
            setp = set_orbit!(x, y)
            if setp !== nothing
                recurse!(pi + 1)
                for p in Iterators.reverse(setp); _remove_point!(s, p); s.sbox[p + 1] = -1; end
            end
            length(s.sols) >= limit && return
        end
    end

    recurse!(1)
    filter!(F -> differential_uniformity(F) == 2 && algebraic_degree(F) == 2, s.sols)
end
