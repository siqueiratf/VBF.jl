# Exact Edel-Pott switching for any APN function F on F_2^N (also non-quadratic),
# parallel over the output directions u.
#
# G = F + u*s is APN iff s sums to 0 on every affine 2-flat on which F sums to u
# (F is APN, so F never sums to 0 on a flat). These conditions are linear in the
# 2^N values of s. The trivial solutions
#     T_u = constants + linear functions + { b.F : b.u = 0 }
# always solve the system and have dimension 2N. Random flats with sum u are
# added one by one; if the kernel dimension drops to 2N, the kernel equals T_u
# and u has no neighbour (exact). Otherwise every flat with sum u is added (also
# exact). Every nonzero class s in K_u / T_u is then tested with an explicit APN
# check. A quotient larger than `maxq` is reported and not enumerated.
#
# switch_full(F) -> (; neighbours = [(u, G)], qdims = Dict(u => dim K_u/T_u), capped)

using VBF, Random

struct BitFun
    w::Vector{UInt64}
end
BitFun(N::Int) = BitFun(zeros(UInt64, max(1, (1 << N) >> 6)))
@inline getb(f::BitFun, x) = (f.w[(x >> 6) + 1] >> (x & 63)) & 1
@inline flip!(f::BitFun, x) = (f.w[(x >> 6) + 1] ⊻= UInt64(1) << (x & 63); f)
function lowbit(f::BitFun)
    for (i, x) in enumerate(f.w)
        x != 0 && return (i - 1) * 64 + trailing_zeros(x)
    end
    -1
end
xor!(a::BitFun, b::BitFun) = (a.w .⊻= b.w; a)

# Incremental elimination: pivots[p+1] holds a row whose lowest set bit is p.
mutable struct System
    pivots::Vector{Union{Nothing,BitFun}}
    rank::Int
end
System(N) = System(Vector{Union{Nothing,BitFun}}(nothing, 1 << N), 0)
function insert!(S::System, row::BitFun)
    while true
        p = lowbit(row)
        p < 0 && return false
        if S.pivots[p+1] === nothing
            S.pivots[p+1] = row; S.rank += 1
            return true
        end
        xor!(row, S.pivots[p+1])
    end
end
function equation(N, pts)
    r = BitFun(N)
    for x in pts
        flip!(r, x)
    end
    r
end

# Kernel basis of the system (all s with <row, s> = 0 for every row).
function kernel(S::System, N)
    M = 1 << N
    piv = [p for p in 0:M-1 if S.pivots[p+1] !== nothing]
    rows = Dict(p => BitFun(copy(S.pivots[p+1].w)) for p in piv)
    for p in reverse(piv)                               # full reduction (RREF)
        for q in piv
            q < p || continue
            getb(rows[q], p) == 1 && xor!(rows[q], rows[p])
        end
    end
    isp = falses(M); foreach(p -> isp[p+1] = true, piv)
    basis = BitFun[]
    for f in 0:M-1
        isp[f+1] && continue
        v = BitFun(N); flip!(v, f)
        for p in piv
            getb(rows[p], f) == 1 && flip!(v, p)
        end
        push!(basis, v)
    end
    basis
end

function trivial_basis(F, N, u)
    M = 1 << N
    T = BitFun[]
    c = BitFun(N); foreach(x -> flip!(c, x), 0:M-1); push!(T, c)
    for i in 0:N-1
        l = BitFun(N); foreach(x -> (x >> i) & 1 == 1 && flip!(l, x), 0:M-1); push!(T, l)
    end
    # basis of u-perp, then the components b.F
    for b in 1:M-1
        iseven(count_ones(b & u)) || continue
        f = BitFun(N); foreach(x -> isodd(count_ones(b & F[x+1])) && flip!(f, x), 0:M-1)
        push!(T, f)
    end
    T
end

# Independent subset of `vs` modulo the span of `base` (both BitFun lists).
function reduce_mod(base, vs, N)
    S = System(N)
    foreach(b -> insert!(S, BitFun(copy(b.w))), base)
    [v for v in vs if insert!(S, BitFun(copy(v.w)))]
end

function apn(G, N)
    M = 1 << N; cnt = zeros(Int, M)
    for a in 1:M-1
        fill!(cnt, 0)
        @inbounds for x in 0:M-1
            d = G[x+1] ⊻ G[(x ⊻ a)+1]
            (cnt[d+1] += 1) > 2 && return false
        end
    end
    true
end

function switch_direction(F, N, u; rng = Xoshiro(u), random_eqs = 4 << N, maxq = 16)
    M = 1 << N; S = System(N); triv = 2N
    added = 0; draws = 0
    while added < random_eqs && draws < 2000 * random_eqs   # random phase
        draws += 1
        x = rand(rng, 0:M-1); a = rand(rng, 1:M-1); b = rand(rng, 1:M-1)
        (b == a) && continue
        F[x+1] ⊻ F[(x ⊻ a)+1] ⊻ F[(x ⊻ b)+1] ⊻ F[(x ⊻ a ⊻ b)+1] == u || continue
        added += 1
        insert!(S, equation(N, (x, x ⊻ a, x ⊻ b, x ⊻ a ⊻ b)))
        M - S.rank == triv && return (Tuple{Int,Vector{Int}}[], 0, false, :random)
    end
    for a in 1:M-1, b in a+1:M-1                         # exact phase: every flat with sum u
        ab = a ⊻ b
        (a < ab) || continue                            # each 2-dim subspace once
        for x in 0:M-1
            (x < x ⊻ a && x < x ⊻ b && x < x ⊻ ab) || continue
            F[x+1] ⊻ F[(x ⊻ a)+1] ⊻ F[(x ⊻ b)+1] ⊻ F[(x ⊻ ab)+1] == u || continue
            insert!(S, equation(N, (x, x ⊻ a, x ⊻ b, x ⊻ ab)))
        end
    end
    M - S.rank == triv && return (Tuple{Int,Vector{Int}}[], 0, false, :exact)
    K = kernel(S, N)
    Q = reduce_mod(trivial_basis(F, N, u), K, N)
    length(Q) > maxq && return (Tuple{Int,Vector{Int}}[], length(Q), true, :exact)
    out = Tuple{Int,Vector{Int}}[]
    for c in 1:(1 << length(Q))-1
        s = BitFun(N)
        for (k, q) in enumerate(Q)
            (c >> (k - 1)) & 1 == 1 && xor!(s, q)
        end
        G = [F[x+1] ⊻ (getb(s, x) == 1 ? u : 0) for x in 0:M-1]
        apn(G, N) && push!(out, (u, G))
    end
    (out, length(Q), false, :exact)
end

function switch_full(F::Vector{Int}, N::Int; maxq = 16)
    M = 1 << N
    res = Vector{Any}(undef, M - 1)
    Threads.@threads :dynamic for u in 1:M-1
        res[u] = switch_direction(F, N, u; maxq)
    end
    neighbours = reduce(vcat, (r[1] for r in res); init = Tuple{Int,Vector{Int}}[])
    qdims = Dict(u => res[u][2] for u in 1:M-1 if res[u][2] > 0)
    capped = [u for u in 1:M-1 if res[u][3]]
    (; neighbours, qdims, capped)
end
