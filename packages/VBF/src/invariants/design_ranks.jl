"""
Design 2-ranks of APN functions — the Γ-rank and Δ-rank ([Edel and Pott, 2009](@cite Edel_200900)).

For an APN function `F : F₂ⁿ → F₂ⁿ`, two CCZ-invariant integers come from the
`F₂`-rank of the incidence matrices of designs developed from its graph:

  * the **graph** `G_F = {(x, F(x)) : x ∈ F₂ⁿ} ⊆ F₂ⁿ × F₂ⁿ`, and
  * the **difference support** `D_F = {(a, b) : a ≠ 0, DDT_F[a,b] = 2}` (from
    `G_F · G_F = 2ⁿ·(0,0) + 2·D_F`, Edel–Pott Lemma 1).

The development `dev(S)` of a set `S ⊆ F₂^{2n}` takes the translates `S + v` as
blocks; its incidence matrix over `F₂^{2n}` is `B[p, q] = [p ⊕ q ∈ S]`. The
**Γ-rank** is `rank_{F₂} B` for `S = G_F`, the **Δ-rank** for `S = D_F`. Both are
invariant under CCZ-equivalence, and `Δ-rank ≤ 2^{n+1}`. Their value is that they
are CCZ-invariants of *arbitrary* APN functions, so they can separate classes
that the cheaper spectral invariants cannot: the differential and Walsh spectra
are not complete CCZ-invariants, and [`apn_ea_mugshot`](@ref) only certifies
*EA*-inequivalence (see its docstring — a mugshot mismatch does **not** imply
CCZ-inequivalence).

Taniguchi's two new `F₂⁸` families are reported with Γ-ranks 13700 and 13798
([Taniguchi, 2019](@cite Taniguchi_201909)); note that those two families are
*also* separated by their ortho-derivative fingerprints, so they are not an
example of a pair that needs the design ranks.

The matrix is `2^{2n} × 2^{2n}`, so the rank is tractable for `n ≤ 6` (instant to
seconds), heavy for `n = 7`, and feasible but expensive at `n = 8`.
Historical n=8 Gamma probes used about 1 GB peak and 170 seconds on one machine;
this is not a runtime guarantee. n=8 is opt-in with explicit storage/time budgets.
"""

# Bit-packed F₂ Gaussian elimination of wide rows → rank (rows mutated).
function _f2_rank_wide!(rows::Vector{Vector{UInt64}}, ncols::Int; deadline=typemax(UInt64))
    nwords = cld(ncols, 64)
    nrows = length(rows)
    r = 1
    rk = 0
    @inbounds for col = 0:(ncols-1)
        _design_check_time(deadline)
        w = (col >> 6) + 1
        b = col & 63
        sel = 0
        for i = r:nrows
            if (rows[i][w] >> b) & 1 == 1
                sel = i
                break
            end
        end
        sel == 0 && continue
        rows[r], rows[sel] = rows[sel], rows[r]
        for i = (r+1):nrows
            if (rows[i][w] >> b) & 1 == 1
                for k = 1:nwords
                    rows[i][k] ⊻= rows[r][k]
                end
            end
        end
        r += 1
        rk += 1
        r > nrows && break
    end
    rk
end

# F₂-rank of the incidence matrix `B[p,q] = [p ⊕ q ∈ points]` on F₂^m.
function _design_2rank(points::Vector{Int}, m::Int;deadline=typemax(UInt64))
    M = 1 << m
    nwords = cld(M, 64)
    _design_check_time(deadline)
    rows = Vector{Vector{UInt64}}(undef,M)
    for p in 1:M
        _design_check_time(deadline)
        rows[p]=zeros(UInt64,nwords)
    end
    @inbounds for p = 0:(M-1)
        _design_check_time(deadline)
        for s in points
            q = p ⊻ s
            rows[p+1][(q>>6)+1] |= (UInt64(1) << (q & 63))
        end
    end
    _f2_rank_wide!(rows, M;deadline)
end

"""
    DesignRankBudgetHit

A design-rank time or working-storage budget was reached. No rank is returned:
an incomplete elimination must never be interpreted as an invariant.
"""
struct DesignRankBudgetHit <: Exception
    reason::Symbol
    detail::String
end
Base.showerror(io::IO,e::DesignRankBudgetHit)=print(io,"design rank budget hit (",e.reason,"): ",e.detail)

_design_check_time(deadline)=time_ns()>=deadline ? throw(DesignRankBudgetHit(:time,"timeout_seconds reached")) : nothing
function _design_rank_guard(N;allow_large=false,max_memory_bytes=256*1024^2,timeout_seconds=Inf)
    1<=N<=8 || throw(ArgumentError("design ranks support dimensions 1:8; n8 requires explicit opt-in"))
    N<=7 || allow_large || throw(ArgumentError("n8 design ranks require allow_large=true and explicit storage/time budgets"))
    max_memory_bytes>=0 || throw(ArgumentError("max_memory_bytes must be nonnegative"))
    timeout_seconds>=0 || throw(ArgumentError("timeout_seconds must be nonnegative"))
    N<=7 || isfinite(timeout_seconds) || throw(ArgumentError("n8 design ranks require a finite timeout_seconds"))
    M=BigInt(1)<<(2N)
    # Conservative algorithm working-storage estimate; not an OS/RSS guarantee.
    estimated=2M*cld(M,64)*8+M*256
    estimated<=max_memory_bytes || throw(DesignRankBudgetHit(:memory,
        "estimated working storage $estimated bytes exceeds max_memory_bytes=$max_memory_bytes"))
    isfinite(timeout_seconds) ? time_ns()+UInt64(ceil(min(Float64(timeout_seconds),Float64(typemax(UInt64)÷2)/1e9)*1e9)) : typemax(UInt64)
end

"""
    gamma_rank(F::SBox{N}; allow_large=false, max_memory_bytes=256*1024^2, timeout_seconds=Inf) -> Int

The Γ-rank of APN `F`: the `F₂`-rank of the incidence matrix of `dev(G_F)` (the
development of the graph), a CCZ-invariant. Defaults to `n ≤ 7`.
For n=8 pass `allow_large=true`, a sufficient `max_memory_bytes` (e.g. 2 GiB),
and finite `timeout_seconds`. The memory bound checks a conservative working
storage estimate, not process RSS; cooperative time checks occur during matrix
construction and elimination, with at most one row/column step between checks.
A budget hit throws [`DesignRankBudgetHit`](@ref), never a partial rank.

# Examples
```jldoctest
julia> using VBF

julia> gamma_rank(gold_apn(5, 1))
330
```
"""
function gamma_rank(F::SBox{N};allow_large=false,max_memory_bytes=256*1024^2,timeout_seconds=Inf) where {N}
    deadline=_design_rank_guard(N;allow_large,max_memory_bytes,timeout_seconds)
    _design_check_time(deadline)
    pts = [Int(x) | (Int(F.lut[x+1]) << N) for x = 0:((1<<N)-1)]
    _design_2rank(pts, 2N;deadline)
end

"""
    delta_rank(F::SBox{N}; allow_large=false, max_memory_bytes=256*1024^2, timeout_seconds=Inf) -> Int

The Δ-rank of APN `F`: the `F₂`-rank of the incidence matrix of `dev(D_F)` with
`D_F = {(a,b) : a ≠ 0, DDT[a,b] = 2}`, a CCZ-invariant with `Δ-rank ≤ 2^{n+1}`.
Uses the same opt-in and storage/time budgets as [`gamma_rank`](@ref).
Its DDT construction is not interruptible; checks resume immediately afterward.

# Examples
```jldoctest
julia> using VBF

julia> delta_rank(gold_apn(5, 1))  # bounded by 2^(5+1) = 64
42
```
"""
function delta_rank(F::SBox{N};allow_large=false,max_memory_bytes=256*1024^2,timeout_seconds=Inf) where {N}
    deadline=_design_rank_guard(N;allow_large,max_memory_bytes,timeout_seconds)
    _design_check_time(deadline)
    D = ddt(F)
    _design_check_time(deadline)
    pts = Int[]
    @inbounds for a = 1:((1<<N)-1), b = 0:((1<<N)-1)
        D[a+1, b+1] == 2 && push!(pts, a | (b << N))
    end
    _design_2rank(pts, 2N;deadline)
end
