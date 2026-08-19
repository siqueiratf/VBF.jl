# Implements Algorithm 1 (the stateful APN filter φ_APN) and Note 9's explicit
# stabiliser generators.
# Paper: Brinkmann, Leander (2008), "On the Classification of APN Functions up to
#        Dimension Five", Designs, Codes and Cryptography 49(1-3):273-288.
# Section: 3 (Algorithm 1) and 6 (Note 9)
#
# Pseudocode:
#   1. APNFilter(n)              — the (c,a) table state f̃ of Algorithm 1
#   2. filter_push!/filter_pop!  — one φ_APN step and its undo (backtracking)
#   3. count_apn_backtrack(n)    — enumerate F(F₂ⁿ,F₂ⁿ) with the filter; the leaf
#                                  count is #APN(n) of Table 4
#   4. note9_generators()        — h₁, h₂, h₃ of Note 9, de-mangled from the OCR
#   5. is_ea_self_equivalence    — is α ∈ H, i.e. ∃ linear bijection β, affine γ
#                                  with β∘s∘α ⊕ γ = s?
# VBF API used: SBox, algebraic_degree, is_permutation, mobius, rank_f2,
#               complete_basis
#
# Algorithm 1, verbatim from the paper (with the OCR noise removed):
#
#   function φ_APN(b, (f̃, s̃))
#       var t ← deg s̃                      ▷ depth of recursion − 1
#       s̃ ← ∇ˡ_{deg s̃ ↦ b} s̃
#       for all x ∈ [0; t−1] do
#           var c ← t ⊕ x
#           var a ← s̃(x) ⊕ s̃(t)            ▷ t = x ⊕ c
#           if f̃(c, a) = TRUE then return FALSE     ▷ table conflict
#           f̃ ← ϖ_{(c,a) ↦ TRUE} f̃                 ▷ table update
#       return (f̃, s̃)
#
# The table f̃ records the solved equations s(t) + s(t+c) = a. A second attempt to
# set the same (c, a) means two distinct pairs {t, t⊕c} and {t′, t′⊕c} share a
# derivative value, i.e. the APN condition fails on the 2-dimensional affine
# subspace {t, t⊕c, t′, t′⊕c} (Lemma 1). This is linear rather than quadratic in
# deg s̃ — one read/store per already-determined position rather than one per
# 2-dimensional affine subspace — which is the paper's point.

isdefined(@__MODULE__, :table3_luts) || include(joinpath(@__DIR__, "table3.jl"))

"""
    APNFilter(n)

The state `f̃` of Algorithm 1: a `(c, a) ∈ F₂ⁿ × F₂ⁿ` table of solved derivative
equations, plus the scratch needed to undo a step on backtracking.
"""
struct APNFilter
    n::Int
    table::Matrix{Bool}
    touched::Vector{Vector{Tuple{Int,Int}}}
end

function APNFilter(n::Int)
    N = 1 << n
    APNFilter(n, falses(N, N), [Vector{Tuple{Int,Int}}(undef, N) for _ = 1:N])
end

"""
    filter_push!(f, s, t, b) -> Int

One φ_APN step: refine the template `s` at position `t` with value `b` and fold
the `t`-th row of derivative equations into the table. Returns the number of
table entries written, or `-1` on a table conflict (⇒ backtrack). The caller must
pass that return value to [`filter_pop!`](@ref) — including on conflict, where
the partially written entries still have to be rolled back.
"""
function filter_push!(f::APNFilter, s::Vector{Int}, t::Int, b::Int)
    s[t+1] = b
    buf = f.touched[t+1]
    k = 0
    @inbounds for x = 0:(t-1)
        c = t ⊻ x
        a = s[x+1] ⊻ b
        f.table[c+1, a+1] && return -(k + 1)   # conflict; k entries were written
        f.table[c+1, a+1] = true
        k += 1
        buf[k] = (c, a)
    end
    k
end

"""
    filter_pop!(f, t, k)

Undo the table writes of a [`filter_push!`](@ref) at position `t`. `k` is that
call's return value (negative encodes a conflict).
"""
function filter_pop!(f::APNFilter, t::Int, k::Int)
    n_written = k < 0 ? -k - 1 : k
    buf = f.touched[t+1]
    @inbounds for j = 1:n_written
        (c, a) = buf[j]
        f.table[c+1, a+1] = false
    end
    nothing
end

"""
    count_apn_backtrack(n) -> Int

Count `#APN(n) = #{s ∈ F(F₂ⁿ,F₂ⁿ) : s is APN}` (Table 4) by the paper's own
method: a left-refining backtrack over the lookup table, pruned at every position
by Algorithm 1's stateful filter.

This is the paper's algorithmic contribution, not a re-derivation of the DDT: no
`differential_uniformity` call is made. It replaces the `O((2ⁿ)^{2ⁿ})` brute force
of `count_apn_n3` — n=3 drops from ~2 minutes to well under a second.
"""
function count_apn_backtrack(n::Int)
    N = 1 << n
    f = APNFilter(n)
    s = zeros(Int, N)
    total = Ref(0)
    function rec(t::Int)
        if t == N
            total[] += 1
            return
        end
        for b = 0:(N-1)
            k = filter_push!(f, s, t, b)
            k ≥ 0 && rec(t + 1)
            filter_pop!(f, t, k)
        end
    end
    rec(0)
    total[]
end

# ---------------------------------------------------------------------------
# Note 9 — the explicit generators of the stabiliser H of Table 3 no. 1.
#
# Paper Issue 5: the cycle notation in (13)–(15) is OCR-mangled, e.g.
# `(217252228)` for the 5-cycle (2 17 25 22 28) and `(3031)` for (30 31). The
# de-mangling below is self-checking: each reconstruction must be a permutation
# of 0..31 covering every point exactly once, must be *affine*, and must satisfy
# the defining condition of H.

"""
    perm_from_cycles(cycles, n) -> Vector{Int}

Build the LUT of a permutation of `F₂ⁿ` from disjoint cycles (points not listed
are fixed). Throws if the result is not a permutation.
"""
function perm_from_cycles(cycles, n::Int)
    N = 1 << n
    p = collect(0:(N-1))
    for cyc in cycles, i in eachindex(cyc)
        p[cyc[i]+1] = cyc[mod1(i + 1, length(cyc))]
    end
    sort(p) == collect(0:(N-1)) ||
        throw(ArgumentError("perm_from_cycles: cycles do not form a permutation"))
    p
end

"""
    note9_generators() -> Vector{Vector{Int}}

`h₁, h₂, h₃` of Note 9, eqs (13)–(15), as LUTs on `F₂⁵`. `h₃` is `x ↦ x ⊕ 1`.
"""
function note9_generators()
    h1 = perm_from_cycles(
        [[2, 17, 25, 22, 28], [3, 16, 24, 23, 29], [4, 21, 12, 26, 6],
         [5, 20, 13, 27, 7], [8, 15, 10, 30, 19], [9, 14, 11, 31, 18]], 5)
    h2 = perm_from_cycles(
        [[1, 2, 10, 13, 4], [3, 8, 7, 9, 5], [6, 11, 15, 14, 12],
         [16, 27, 20, 26, 22], [17, 25, 30, 23, 18], [21, 24, 28, 29, 31]], 5)
    h3 = perm_from_cycles([[2i, 2i + 1] for i = 0:15], 5)
    [h1, h2, h3]
end

"""
    is_affine_perm(p, n) -> Bool

Is the permutation LUT `p` an affine bijection `x ↦ Lx ⊕ c` of `F₂ⁿ`?
"""
function is_affine_perm(p::Vector{Int}, n::Int)
    c = p[1]
    cols = [p[(1<<i)+1] ⊻ c for i = 0:(n-1)]
    for x = 0:((1<<n)-1)
        y = c
        for i = 0:(n-1)
            (x >> i) & 1 == 1 && (y ⊻= cols[i+1])
        end
        y == p[x+1] || return false
    end
    true
end

"""
    outer_linear_for(u, s, n) -> Union{Vector{Int},Nothing}

The LUT of an invertible linear `β` with `β ∘ u ⊕ γ = s` for some affine `γ`, or
`nothing` if none exists.

`β` acts on packed output coordinates, so on ANF coefficients it acts
monomial-wise: every monomial `m` of degree ≥ 2 imposes `β(anf_u[m]) = anf_s[m]`
(the affine drift `γ` can only touch the degree-≤1 part, so those monomials are
unconstrained). Fold the constraints into a reduced partial linear map; they are
realised by an *invertible* `β` iff they are consistent and injective on their
span, which then extends to a bijection by completing both bases.
"""
function outer_linear_for(u::Vector{Int}, s::Vector{Int}, n::Int)
    anfU = mobius(UInt8.(u))
    anfS = mobius(UInt8.(s))
    piv = Dict{Int,Tuple{Int,Int}}()          # leading bit ↦ (input, image)
    for m = 0:((1<<n)-1)
        count_ones(m) ≥ 2 || continue
        x = Int(anfU[m+1])
        y = Int(anfS[m+1])
        placed = false
        while x != 0
            b = 8 * sizeof(Int) - 1 - leading_zeros(x)
            if haskey(piv, b)
                (pi_, po_) = piv[b]
                x ⊻= pi_
                y ⊻= po_
            else
                piv[b] = (x, y)
                placed = true
                break
            end
        end
        placed && continue
        y == 0 || return nothing              # inconsistent constraint
    end
    ins = UInt8[UInt8(v[1]) for v in values(piv)]
    outs = UInt8[UInt8(v[2]) for v in values(piv)]
    rank_f2(UInt32.(outs); nbits = n) == length(outs) || return nothing
    fin = complete_basis(ins, n)
    fout = complete_basis(outs, n)
    lut = zeros(Int, 1 << n)
    for mask = 0:((1<<n)-1)
        v = 0
        w = 0
        for j = 0:(n-1)
            if (mask >> j) & 1 == 1
                v ⊻= Int(fin[j+1])
                w ⊻= Int(fout[j+1])
            end
        end
        lut[v+1] = w
    end
    lut
end

"""
    is_ea_self_equivalence(s, α, n) -> Bool

Is `α ∈ H`, i.e. does the affine bijection `α` extend to an element `(α, β, γ)`
of the stabiliser `G_s` — a linear bijection `β` and an affine `γ` with
`β ∘ s ∘ α ⊕ γ = s`? By Corollary 8, `β` and `γ` are then unique.

The witness is constructed and re-checked, so a `true` here is not an oracle
verdict but an explicit `(β, γ)`.
"""
function is_ea_self_equivalence(s::Vector{Int}, α::Vector{Int}, n::Int)
    is_affine_perm(α, n) || return false
    u = [s[α[x+1]+1] for x = 0:((1<<n)-1)]
    β = outer_linear_for(u, s, n)
    β === nothing && return false
    B = SBox{n}(β)
    (is_permutation(B) && algebraic_degree(B) ≤ 1 && β[1] == 0) || return false
    γ = [s[x+1] ⊻ β[u[x+1]+1] for x = 0:((1<<n)-1)]
    algebraic_degree(SBox{n}(γ)) ≤ 1
end

"""
    permutation_group_order(gens, n) -> Int

Order of the permutation group generated by `gens` (LUTs on `F₂ⁿ`), by breadth
first closure. Only used on Note 9's small group.
"""
function permutation_group_order(gens::Vector{Vector{Int}}, n::Int)
    N = 1 << n
    id = collect(0:(N-1))
    seen = Set{Vector{Int}}([id])
    frontier = [id]
    while !isempty(frontier)
        nxt = Vector{Vector{Int}}()
        for p in frontier, g in gens
            q = [g[p[i+1]+1] for i = 0:(N-1)]
            if !(q in seen)
                push!(seen, q)
                push!(nxt, q)
            end
        end
        frontier = nxt
    end
    length(seen)
end

"""
    algorithm1_report(io)

Algorithm 1 (the stateful filter) and Note 9 (the explicit stabiliser
generators).
"""
function algorithm1_report(io::IO = stdout)
    print_section(io, "Algorithm 1 — the stateful APN filter φ_APN")
    println(io, "  Backtrack over the lookup table, pruned by the (c,a) table of solved")
    println(io, "  derivative equations. No DDT is ever built.")
    for (n, expected) in [(1, 4), (2, 192), (3, 688128)]
        got = count_apn_backtrack(n)
        print_check(io, "n=$n: backtrack #APN = $got (Table 4: $expected)", got == expected)
    end
    println(io, "  n=4 (#APN ≈ 1.9·10¹³) is out of reach for leaf enumeration; Section 6")
    println(io, "  derives it from the orbit-stabiliser formula instead.")

    print_section(io, "Note 9 — explicit generators of the stabiliser H of Table 3 no. 1")
    s = table3_luts()[1].lut
    s = Int.(s)
    gens = note9_generators()
    labels = ["h₁", "h₂", "h₃"]
    all_ok = true
    for (lbl, h) in zip(labels, gens)
        aff = is_affine_perm(h, 5)
        self = is_ea_self_equivalence(s, h, 5)
        all_ok &= aff && self
        print_check(io, "$lbl is an affine bijection of F₂⁵ and lies in H (β, γ constructed)",
                    aff && self)
    end
    ord = permutation_group_order(gens, 5)
    print_check(io, "|⟨h₁,h₂,h₃⟩| = $ord — the paper's first n=5 stabiliser order (4960)",
                ord == 4960)
    print_check(io, "all three Note 9 generators verified", all_ok)
    println(io, "  4960 feeds the Table 4 n=5 orbit sum in section6.jl.")
end

if abspath(PROGRAM_FILE) == @__FILE__
    algorithm1_report()
end
