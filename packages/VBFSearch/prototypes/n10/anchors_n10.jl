# Anchors of the n = 10 seeds: for every quadratic APN class of the catalog,
# the maximum bent count M_7 over 7-dim subspaces of C2(F), the number of
# subspaces that reach it, and the best target b(U_8) over U_8 = V_7 + <q> inside
# C2(F). This number of anchors multiplies the cost of the 2^38 coset scan.
#
# Run from the repository root: julia --project=. packages/VBFSearch/prototypes/n10/anchors_n10.jl
include(joinpath(@__DIR__, "exchange_n10.jl"))
using VBF, VBFCatalog

# All 7-dim V < C2 with b(V) = M_7, via their 3-dim annihilators A in the
# 10-dim coefficient space: b(V) = 2^-3 * sum_{a in A} bhat(a).
function all_best_anchors(basis)
    m = length(basis); N = 1 << m
    comb(c) = reduce(⊻, (basis[k] for k in 1:m if bit(c, k) == 1); init = UInt64(0))
    bent = [c == 0 ? 0 : (is_bent(comb(c)) ? 1 : 0) for c in 0:N-1]
    h = [b == 1 ? -1 : 1 for b in bent]
    len = 1
    while len < N
        for i in 0:2len:N-1, j in i:i+len-1
            a, b = h[j+1], h[j+len+1]; h[j+1] = a + b; h[j+len+1] = a - b
        end
        len <<= 1
    end
    bhat = [(a == 0 ? N : 0) - h[a+1] for a in 0:N-1] .÷ 2
    # Canonical basis of a 3-dim annihilator A: a1 < a2 < a1+a2, a2 < a3, and a3 is
    # the smallest element of the coset a3 + span(a1, a2). Threads split a1.
    nt = Threads.nthreads()
    bests = fill(-1, nt); counts = zeros(Int, nt); keeps = [NTuple{3,Int}[] for _ in 1:nt]
    Threads.@threads :static for a1 in 1:N-1
        id = Threads.threadid()
        @inbounds for a2 in a1+1:N-1
            a12 = a1 ⊻ a2
            a12 > a2 || continue
            s12 = bhat[1] + bhat[a1+1] + bhat[a2+1] + bhat[a12+1]
            for a3 in a2+1:N-1
                (a3 < a3 ⊻ a1 && a3 < a3 ⊻ a2 && a3 < a3 ⊻ a12) || continue
                s = (s12 + bhat[a3+1] + bhat[(a3⊻a1)+1] + bhat[(a3⊻a2)+1] + bhat[(a3⊻a12)+1]) ÷ 8
                if s > bests[id]
                    bests[id] = s; counts[id] = 0; empty!(keeps[id])
                end
                if s == bests[id]
                    counts[id] += 1
                    length(keeps[id]) < 8 && push!(keeps[id], (a1, a2, a3))
                end
            end
        end
    end
    best = maximum(bests)
    nanchors = sum(counts[i] for i in 1:nt if bests[i] == best)
    args = reduce(vcat, (keeps[i] for i in 1:nt if bests[i] == best))
    anchors = map(args[1:min(end, 8)]) do arg
        V = [comb(c) for c in 0:N-1 if c != 0 && all(a -> iseven(count_ones(c & a)), arg)]
        Vb = UInt64[]
        for v in V
            rank_f2([Vb; v]) > length(Vb) && push!(Vb, v)
        end
        Vb
    end
    best, nanchors, anchors, sum(bent)
end

function target_b8(C, V7)
    Vs = span(V7)
    maximum(coset_bent(q, Vs) for q in span(C) if rank_f2([V7; q]) == 8) + count(is_bent, Vs)
end

db = VBFCatalog.load_catalog()
rows = list_functions(db; n = 10)
seen = Set{String}()
println(rpad("class", 40), lpad("bent", 6), lpad("M_7", 6), lpad("anchors", 9), lpad("b8 targets", 14))
total = 0
for r in rows
    F = load_sbox(db, r.id)
    VBF.differential_uniformity(F) == 2 || continue
    VBF.algebraic_degree(F) == 2 || continue
    s = sigma_hash(F)
    s in seen && continue
    push!(seen, s)
    C = comp_basis(Int.(F.lut))
    M7, na, anchors, nb = all_best_anchors(C)
    b8 = sort(unique(target_b8(C, V) for V in anchors))
    global total += na
    println(rpad(r.canonical_name, 40), lpad(nb, 6), lpad(M7, 6), lpad(na, 9), lpad(join(b8, ","), 14)); flush(stdout)
end
println("classes = ", length(seen), ", anchors in total = ", total)
