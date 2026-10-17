# Preliminary n = 10 prototype of the exchange move (anchor V_7, U_8 = V_7 + <q>,
# re-extension U_8 -> S_10). Standalone: Base Julia only, so the cost figures
# isolate the arithmetic. Forms on F_2^10 are UInt64 masks over the 45 pairs
# (i < j); flats are the decomposable bivectors x ^ y.
#
# Re-extension replaces the dense 2^37-point transform of the n = 8 code by
# Lee-Brickell information-set decoding: an APN extension S = U + <t, v> exists
# iff the code {(<w, t>)_{w in Z}} + <1> holds the indicator of Z(t) with
# |Z(t)| <= |Z|/3 and the system {<w, v> = 1 : w in Z(t)} is consistent
# (Lemma 2 of the paper draft).
#
# Run: julia --project=@. -t 1 exchange_n10.jl

using Random

const n = 10
const NP = n * (n - 1) ÷ 2                      # 45
const PAIR = let P = zeros(Int, n, n), k = 0
    for i in 1:n, j in i+1:n
        P[i, j] = P[j, i] = k; k += 1
    end
    P
end
const PAIRINV = [(i, j) for i in 1:n for j in i+1:n]
bit(x, i) = (x >> (i - 1)) & 1

# --- GF(2^10) and the Gold seeds ---------------------------------------------------
const POLY = 0x409                                # x^10 + x^3 + 1 (primitive)
function gmul(a::Int, b::Int)
    r = 0
    while b != 0
        (b & 1 == 1) && (r ⊻= a)
        b >>= 1; a <<= 1
        (a >> n) & 1 == 1 && (a ⊻= POLY)
    end
    r
end
gpow(a, e) = (r = 1; for _ in 1:e; r = gmul(r, a); end; r)
gold_lut(e) = [gpow(x, e) for x in 0:(1 << n)-1]

function differential_uniformity(lut)
    N = length(lut); best = 0; cnt = zeros(Int, N)
    for a in 1:N-1
        fill!(cnt, 0)
        @inbounds for x in 0:N-1
            cnt[(lut[x+1] ⊻ lut[(x ⊻ a)+1])+1] += 1
        end
        best = max(best, maximum(cnt))
    end
    best
end

# Quadratic part of component k: a_ij = f(0)+f(e_i)+f(e_j)+f(e_i+e_j).
function comp_basis(lut)
    basis = UInt64[]
    for k in 1:n
        f(x) = (lut[x+1] >> (k - 1)) & 1
        w = UInt64(0)
        for i in 1:n, j in i+1:n
            a = f(0) ⊻ f(1 << (i-1)) ⊻ f(1 << (j-1)) ⊻ f((1 << (i-1)) | (1 << (j-1)))
            a == 1 && (w |= UInt64(1) << PAIR[i, j])
        end
        push!(basis, w)
    end
    basis
end

# --- ranks, flats, spans ------------------------------------------------------------
function form_rank(w::UInt64)
    rows = zeros(UInt16, n)
    @inbounds for i in 1:n, j in i+1:n
        if (w >> PAIR[i, j]) & 1 == 1
            rows[i] |= UInt16(1) << (j - 1); rows[j] |= UInt16(1) << (i - 1)
        end
    end
    r = 0
    @inbounds for c in 0:n-1
        p = 0
        for k in r+1:n
            if (rows[k] >> c) & 1 == 1; p = k; break; end
        end
        p == 0 && continue
        r += 1; rows[r], rows[p] = rows[p], rows[r]
        for k in 1:n
            k != r && (rows[k] >> c) & 1 == 1 && (rows[k] ⊻= rows[r])
        end
    end
    r
end

function all_flats()
    s = Set{UInt64}()
    for x in 1:(1 << n)-1, y in x+1:(1 << n)-1
        w = UInt64(0)
        for i in 1:n, j in i+1:n
            (bit(x, i) & bit(y, j)) ⊻ (bit(x, j) & bit(y, i)) == 1 && (w |= UInt64(1) << PAIR[i, j])
        end
        push!(s, w)
    end
    sort!(collect(s))
end

span(b) = (v = UInt64[0]; for x in b; append!(v, v .⊻ x); end; v)
orth(w, basis) = all(b -> iseven(count_ones(w & b)), basis)
is_apn_space(basis, flats) = !any(w -> orth(w, basis), flats)

function rank_f2(vs)
    rows = copy(vs); r = 0
    for c in 0:63
        p = findfirst(k -> k > r && (rows[k] >> c) & 1 == 1, eachindex(rows))
        p === nothing && continue
        r += 1; rows[r], rows[p] = rows[p], rows[r]
        for k in eachindex(rows)
            k != r && (rows[k] >> c) & 1 == 1 && (rows[k] ⊻= rows[r])
        end
    end
    r
end

# Best 7-dim subspace of the 10-dim component space, via its 3-dim annihilator A:
# b(V) = 2^-3 * sum_{a in A} bhat(a), bhat = Walsh transform of the bent indicator.
function best_anchor(basis)
    m = length(basis); N = 1 << m
    comb(c) = reduce(⊻, (basis[k] for k in 1:m if bit(c, k) == 1); init = UInt64(0))
    bent = [c == 0 ? 0 : (form_rank(comb(c)) == n ? 1 : 0) for c in 0:N-1]
    h = [b == 1 ? -1 : 1 for b in bent]                  # Walsh of (-1)^bent
    len = 1
    while len < N
        for i in 0:2len:N-1, j in i:i+len-1
            a, b = h[j+1], h[j+len+1]; h[j+1] = a + b; h[j+len+1] = a - b
        end
        len <<= 1
    end
    bhat = [(a == 0 ? N : 0) - h[a+1] for a in 0:N-1] .÷ 2 # transform of the indicator
    best = -1; arg = (0, 0, 0)
    for a1 in 1:N-1, a2 in a1+1:N-1, a3 in a2+1:N-1
        (a3 == a1 ⊻ a2) && continue
        sp = (a1, a2, a1 ⊻ a2, a3, a3 ⊻ a1, a3 ⊻ a2, a3 ⊻ a1 ⊻ a2)
        (minimum(sp) == a1 && minimum(x for x in sp if x != a1) == a2 &&
         minimum(sp[4:7]) == a3) || continue
        s = (bhat[1] + sum(bhat[x+1] for x in sp)) ÷ 8
        s > best && (best = s; arg = (a1, a2, a3))
    end
    V = [comb(c) for c in 0:N-1 if c != 0 && all(a -> iseven(count_ones(c & a)), arg)]
    Vb = UInt64[]
    for v in V
        rank_f2([Vb; v]) > length(Vb) && push!(Vb, v)
    end
    best, Vb, sum(bent)
end

# Fast bent test: rows of the alternating matrix from 6 byte tables, then a
# branch-light elimination. Rank n (= 10) means bent.
const ROWTAB = let T = zeros(UInt16, n, 256, 6)
    for byte in 0:5, v in 0:255, b in 0:7
        p = 8byte + b
        (p < NP && (v >> b) & 1 == 1) || continue
        i, j = PAIRINV[p+1]
        T[i, v+1, byte+1] ⊻= UInt16(1) << (j - 1); T[j, v+1, byte+1] ⊻= UInt16(1) << (i - 1)
    end
    T
end
const BUF = [zeros(UInt16, n) for _ in 1:Threads.maxthreadid()]
@inline is_bent(w::UInt64) = is_bent(w, BUF[Threads.threadid()])
@inline function is_bent(w::UInt64, r::Vector{UInt16})
    @inbounds begin
        fill!(r, 0)
        for byte in 0:5
            v = Int((w >> (8byte)) & 0xff) + 1
            for i in 1:n
                r[i] ⊻= ROWTAB[i, v, byte+1]
            end
        end
        for c in 0:n-1
            m = UInt16(1) << c
            p = 0
            for k in c+1:n
                (p == 0 && r[k] & m != 0) && (p = k)
            end
            p == 0 && return false
            piv = r[p]; r[p] = r[c+1]; r[c+1] = piv
            for k in c+2:n
                r[k] ⊻= piv * ((r[k] >> c) & 0x0001)
            end
        end
    end
    true
end
coset_bent(q, Vspan) = count(v -> is_bent(q ⊻ v), Vspan)

# --- Lee-Brickell search for extensions of U --------------------------------------------
# Rows are bit-packed words over Z with a 64-bit tag recording the combination
# (45 form coordinates, bit 63 = the all-ones row).
function extensions_isd(Ub, flats; iters = 20_000, rng = Xoshiro(1))
    Z = [w for w in flats if orth(w, Ub)]
    L = length(Z); W = cld(L, 64)
    pack(f) = (r = zeros(UInt64, W); for (k, w) in enumerate(Z); f(w) && (r[(k-1)>>6+1] |= UInt64(1) << ((k-1)&63)); end; r)
    rows = [pack(w -> (w >> p) & 1 == 1) for p in 0:NP-1]; tags = [UInt64(1) << p for p in 0:NP-1]
    push!(rows, pack(_ -> true)); push!(tags, UInt64(1) << 63)
    wmax = L ÷ 3; found = Dict{UInt64,Int}(); sols = Set{Vector{UInt64}}()
    cols = collect(1:L)
    getb(r, c) = (r[(c-1)>>6+1] >> ((c-1)&63)) & 1
    for _ in 1:iters
        shuffle!(rng, cols)
        R = [copy(r) for r in rows]; T = copy(tags); k = 0
        for c in cols                                        # systematic form on a random information set
            p = findfirst(i -> i > k && getb(R[i], c) == 1, eachindex(R))
            p === nothing && continue
            k += 1; R[k], R[p] = R[p], R[k]; T[k], T[p] = T[p], T[k]
            for i in eachindex(R)
                if i != k && getb(R[i], c) == 1
                    R[i] .⊻= R[k]; T[i] ⊻= T[k]
                end
            end
            k == length(R) && break
        end
        K = k
        for i in 1:K, j in i:K                               # p = 1 (i == j) and p = 2
            wt = 0; @inbounds for x in 1:W; wt += count_ones(i == j ? R[i][x] : R[i][x] ⊻ R[j][x]); end
            tag = i == j ? T[i] : T[i] ⊻ T[j]
            (wt <= wmax && (tag >> 63) == 1) || continue
            haskey(found, tag) && continue
            found[tag] = wt
            t = tag & ((UInt64(1) << NP) - 1)                # <w,t> = 0 exactly on the support
            Zt = [w for w in Z if iseven(count_ones(w & t))]
            for v in solve_ones(Zt)
                S = vcat(Ub, t, v)
                rank_f2(S) == n && is_apn_space(S, flats) && push!(sols, canon(S))
            end
        end
    end
    sols, L, length(found)
end

# All v (modulo the kernel, a few representatives) with <w, v> = 1 for w in Zt.
function solve_ones(Zt)
    rows = [(w, 1) for w in Zt]; piv = Int[]; r = 0
    for c in 0:NP-1
        p = findfirst(k -> k > r && (rows[k][1] >> c) & 1 == 1, eachindex(rows))
        p === nothing && continue
        r += 1; rows[r], rows[p] = rows[p], rows[r]
        for k in eachindex(rows)
            if k != r && (rows[k][1] >> c) & 1 == 1
                rows[k] = (rows[k][1] ⊻ rows[r][1], rows[k][2] ⊻ rows[r][2])
            end
        end
        push!(piv, c)
    end
    any(k -> rows[k][1] == 0 && rows[k][2] == 1, r+1:length(rows)) && return UInt64[]
    v0 = UInt64(0)
    for (k, c) in enumerate(piv); rows[k][2] == 1 && (v0 |= UInt64(1) << c); end
    free = setdiff(0:NP-1, piv)
    kern = UInt64[]
    for f in free                                        # kernel basis vector for free column f
        v = UInt64(1) << f
        for (k, c) in enumerate(piv); (rows[k][1] >> f) & 1 == 1 && (v |= UInt64(1) << c); end
        push!(kern, v)
    end
    length(kern) > 12 && (kern = kern[1:12])             # cap, as max_kernel in the n = 8 code
    [v0 ⊻ x for x in span(kern)]
end

function canon(S)                                        # reduced row echelon basis
    rows = copy(S); r = 0
    for c in 63:-1:0
        p = findfirst(k -> k > r && (rows[k] >> c) & 1 == 1, eachindex(rows))
        p === nothing && continue
        r += 1; rows[r], rows[p] = rows[p], rows[r]
        for k in eachindex(rows)
            k != r && (rows[k] >> c) & 1 == 1 && (rows[k] ⊻= rows[r])
        end
    end
    sort!(rows[1:r])
end

# --- driver -------------------------------------------------------------------------
function main()
    t = @elapsed flats = all_flats()
    println("flats: ", length(flats), " (", round(t, digits = 1), " s)")
    rng = Xoshiro(7)
    ws = rand(rng, UInt64, 10^6) .& ((UInt64(1) << NP) - 1)
    form_rank(ws[1]); t = @elapsed s = sum(form_rank, ws)
    println("form_rank: ", round(t / 1e6 * 1e9, digits = 1), " ns per form")
    @assert all(w -> is_bent(w) == (form_rank(w) == n), ws[1:10^5])
    is_bent(ws[1]); t = @elapsed s = count(is_bent, ws)
    println("is_bent: ", round(t / 1e6 * 1e9, digits = 1), " ns per form; bent fraction ", s / 1e6)
    for e in (3, 9)
        lut = gold_lut(e)
        println("\n== Gold x^$e on GF(2^10) ==")
        println("delta = ", differential_uniformity(lut))
        C = comp_basis(lut)
        println("dim C2 = ", rank_f2(C), ", flat criterion APN = ", is_apn_space(C, flats))
        t = @elapsed (b7, V7, nb) = best_anchor(C)
        println("bent components = $nb; M_7 = $b7 (", round(t, digits = 1), " s, all 3-dim annihilators)")
        Vs = span(V7)
        # target b(U_8): the best 8-dim subspace of C2 that contains V_7
        out = [c for c in C if rank_f2([V7; c]) == 8]
        b8 = maximum(coset_bent(q, Vs) for q in span(C) if rank_f2([V7; q]) == 8) + b7
        println("target b(U_8) = $b8 (best U_8 >= V_7 inside C2)")
        need = b8 - b7
        qs = rand(rng, UInt64, 20_000) .& ((UInt64(1) << NP) - 1)
        t = @elapsed hits = count(q -> coset_bent(q, Vs) == need, qs)
        per = t / length(qs)
        println("coset count: ", round(per * 1e6, digits = 2), " us per coset; hits $hits / $(length(qs)) random cosets")
        println("  projected exhaustive scan of 2^38 cosets: ", round(per * 2.0^38 / 86400, digits = 1), " CPU-thread-days per anchor")
        # positive control: re-extend a U_8 inside C2
        q8 = first(q for q in span(C) if rank_f2([V7; q]) == 8 && coset_bent(q, Vs) == need)
        U8 = vcat(V7, q8)
        rest = [c for c in C if rank_f2([U8; c]) > 8]
        tt, vv = rest[1], first(c for c in rest if rank_f2([U8; rest[1]; c]) == 10)
        Z = [w for w in flats if orth(w, U8)]
        println("partition of Z by C2: ", [count(w -> iseven(count_ones(w & x)), Z) for x in (tt, vv, tt ⊻ vv)], " of ", length(Z))
        t = @elapsed (sols, L, nf) = extensions_isd(U8, flats; iters = 3_000)
        own = canon(C) in sols
        println("ISD re-extension: |Z| = $L, candidate t found = $nf, APN extensions = $(length(sols)), contains C2(F) = $own (",
                round(t, digits = 1), " s for 3000 iterations)")
        # exchange: U_8 = V_7 + <q> with q outside C2
        for (i, q) in enumerate(Iterators.filter(q -> coset_bent(q, Vs) == need && rank_f2([C; q]) == 11, qs))
            i > 3 && break
            t = @elapsed (sols, L, nf) = extensions_isd(vcat(V7, q), flats; iters = 3_000)
            println("exchange q #$i: |Z| = $L, candidates = $nf, APN extensions = $(length(sols)) (", round(t, digits = 1), " s)")
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
