# Component-rank profiles of quadratic (8,8)-functions (Beierle et al. 2025, Def. 3.4 of v2).
#
#   alpha(s) = 2^(8 - rank(s)) for the component s.F (rank of its alternating matrix)
#   BS(V)    = (b(V), K(V)),  b = #bent (rank 8) nonzero elements, K = sum_{s in V\0} alpha(s)
#   P_k(F)   = greatest tuple [BS(V_0),...,BS(V_k)] over flags V_0 < ... < V_k of Comp(F)
#
# Two orders on pairs are implemented:
#   :lex     standard lexicographic order on (b, K)          (maximize b, then maximize K)
#   :bminK   maximize b, then MINIMIZE K                      (order matching Table 3.1)
# The greatest tuple is found level by level, keeping all subspaces V_i that reach the
# best prefix (exact: the continuation of a flag depends only on its last subspace).
module QuadraticProfiles
using ..VBF: QuadraticAPNTree, rank_f2

export coeff_matrix, coeff_matrix_from_lut, component_alphas, rank_counts, profile_pk,
       max_bent_subspace_dim, component_ranks, lut_from_matrix

const N = 8
const Q = 1 << N

"Decode an eight-variable quadratic coefficient string."
coeff_matrix(s::AbstractString) = QuadraticAPNTree.decode_coeffs(s,8)
"Extract degree-two coefficients; affine terms do not affect the profile."
function coeff_matrix_from_lut(lut::AbstractVector)
    length(lut)==256 || throw(ArgumentError("expected 8-bit LUT"))
    QuadraticAPNTree.coeff_matrix_from_lut(lut)
end
"Homogeneous quadratic LUT for byte-valued coefficients."
lut_from_matrix(C) = UInt8.(QuadraticAPNTree.lut(C,8))

"ranks[b+1] = rank of component b.F (b = 0..255; ranks[1] = 0)."
function component_ranks(C)
    QuadraticAPNTree.check_matrix(C,8,8)
    ranks = zeros(Int, Q)
    rows = zeros(UInt16, N)
    for b in 1:Q-1
        for i in 1:N
            r = UInt16(0)
            for j in 1:N
                isodd(count_ones(UInt16(b) & C[i, j])) && (r |= UInt16(1) << (j - 1))
            end
            rows[i] = r
        end
        ranks[b+1] = rank_f2(rows;nbits=8)
    end
    ranks
end

"alpha[b+1] = 2^(8-rank) for b != 0, alpha[1] = 0 (zero excluded from K)."
component_alphas(ranks) = [b == 0 ? 0 : 1 << (N - ranks[b+1]) for b in 0:Q-1]

"Counts of nonzero components of rank (8,6,4,2) (rank 0 counted separately)."
rank_counts(ranks) = (count(==(8), ranks[2:end]), count(==(6), ranks[2:end]),
                      count(==(4), ranks[2:end]), count(==(2), ranks[2:end]), count(==(0), ranks[2:end]))

# --- subspaces as 256-bit membership masks -------------------------------------------
const Mask = NTuple{4,UInt64}
@inline hasel(m::Mask, x::Int) = (m[(x >> 6) + 1] >> (x & 63)) & 1 == 1
@inline function addel(m::Mask, x::Int)
    k = (x >> 6) + 1
    ntuple(i -> i == k ? m[i] | (UInt64(1) << (x & 63)) : m[i], 4)
end
function elements(m::Mask)
    out = Int[]
    for w in 1:4
        v = m[w]
        while v != 0
            t = trailing_zeros(v); push!(out, 64(w - 1) + t); v &= v - 1
        end
    end
    out
end

"""
    profile_pk(alpha, k; order=:lex) -> (profile::Vector{Tuple{Int,Int}}, nmax::Vector{Int})

Greatest tuple [BS(V_0),...,BS(V_k)]; nmax[i+1] = number of distinct subspaces V_i that
attain the optimal prefix at level i.
"""
function profile_pk(alpha::Vector{Int}, k::Int; order::Symbol = :lex, max_subspaces::Int = 1_000_000, max_nodes::Int=10_000_000)
    length(alpha)==256 && alpha[1]==0 || throw(ArgumentError("expected 256 component weights, zero excluded"))
    0 <= k <= 8 && max_subspaces>0 || throw(ArgumentError("invalid profile depth/budget"))
    sgn = order === :lex ? 1 : order === :bminK ? -1 : error("order")
    budget=QuadraticAPNTree.Budget(max_nodes)
    zero = (UInt64(1), UInt64(0), UInt64(0), UInt64(0))   # {0}
    cur = Dict{Mask,Tuple{Int,Int}}(zero => (0, 0))
    prof = [(0, 0)]; nmax = [1]
    seen = falses(Q)
    for lev in 1:k
        best = (typemin(Int), typemin(Int)); nxt = Dict{Mask,Tuple{Int,Int}}()
        for (V, (b0, K0)) in cur
            QuadraticAPNTree.tick!(budget)
            els = elements(V)
            fill!(seen, false)
            for x in els; seen[x+1] = true; end
            for v in 1:Q-1
                seen[v+1] && continue
                bc = 0; Kc = 0; W = V
                for u in els
                    y = u ⊻ v; seen[y+1] = true
                    a = alpha[y+1]; Kc += a; a == 1 && (bc += 1)
                    W = addel(W, y)
                end
                key = (b0 + bc, sgn * (K0 + Kc))
                if key > best
                    best = key; empty!(nxt); nxt[W] = (b0 + bc, K0 + Kc)
                elseif key == best
                    nxt[W] = (b0 + bc, K0 + Kc)
                end
                length(nxt) <= max_subspaces || throw(QuadraticAPNTree.EnumerationLimitError(max_subspaces))
            end
        end
        length(nxt) <= max_subspaces || throw(QuadraticAPNTree.EnumerationLimitError(max_subspaces))
        push!(prof, (best[1], sgn * best[2])); push!(nmax, length(nxt))
        cur = nxt
    end
    prof, nmax
end

"""
Maximum dimension d of a subspace of Comp(F) all of whose nonzero elements are bent
(capped at 4 = n/2, the vectorial-bent bound), and the number of such d-dim subspaces
(counted only when d <= 4 is reached; exact count via canonical increasing bases).
"""
function max_bent_subspace_dim(alpha::Vector{Int}; count_top::Bool = true, max_nodes::Int=10_000_000)
    length(alpha)==256 && alpha[1]==0 || throw(ArgumentError("expected 256 component weights, zero excluded"))
    bent = [alpha[b+1] == 1 for b in 0:Q-1]
    bentlist = [b for b in 1:Q-1 if bent[b+1]]
    budget=QuadraticAPNTree.Budget(max_nodes)
    best = Ref(0)
    tops = Set{Mask}()
    function dfs(V::Mask, els::Vector{Int}, d::Int, last::Int)
        QuadraticAPNTree.tick!(budget)
        if d > best[]
            best[] = d; empty!(tops)
        end
        d == best[] && count_top && push!(tops, V)
        d >= 4 && return
        for v in bentlist
            v <= last && continue
            hasel(V, v) && continue
            ok = true
            for u in els
                bent[(u ⊻ v)+1] || (ok = false; break)
            end
            ok || continue
            W = V; nels = copy(els)
            for u in els
                W = addel(W, u ⊻ v); push!(nels, u ⊻ v)
            end
            dfs(W, nels, d + 1, v)
            (!count_top && best[] >= 4) && return
        end
    end
    dfs((UInt64(1), UInt64(0), UInt64(0), UInt64(0)), [0], 0, 0)
    best[], count_top ? length(tops) : -1
end


end
