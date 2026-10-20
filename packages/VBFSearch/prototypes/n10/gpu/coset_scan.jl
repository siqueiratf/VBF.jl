# Portable GPU scan of the exchange step at n = 10: for an anchor V_7 < Q_10
# (128 forms) and every coset q + V_7 of the 2^38 cosets, count the bent forms
# (rank 10) and keep the cosets whose count equals `need`.
#
# One KernelAbstractions kernel runs on CUDA (GTX 1060, CUDA 12.x runtime),
# AMDGPU (RX 6700 / gfx1031) and the CPU. Choose with N10_BACKEND=cuda|amdgpu|cpu.
# A form is stored as the 10 rows of its alternating matrix (UInt16 each), so
# rows(q + v) = rows(q) xor rows(v), and consecutive cosets differ by one basis
# vector of the complement (Gray code).
#
# Run: julia --project=. coset_scan.jl [log2_cosets]

using KernelAbstractions, Atomix, Random
const BACKEND = get(ENV, "N10_BACKEND", "cuda")
if BACKEND == "cuda"
    using CUDA
    const DEV = CUDABackend()
    devarray(x) = CuArray(x)
elseif BACKEND == "amdgpu"
    using AMDGPU
    const DEV = ROCBackend()
    devarray(x) = ROCArray(x)
else
    const DEV = CPU()
    devarray(x) = copy(x)
end

include(joinpath(@__DIR__, "..", "exchange_n10.jl"))   # PAIRINV, comp_basis, gold_lut, best_anchor, rank_f2, span, coset_bent

const NR = 10                                           # rows of a 10 x 10 alternating matrix

function form_rows(w::UInt64)
    r = zeros(UInt16, NR)
    for p in 0:NP-1
        (w >> p) & 1 == 1 || continue
        i, j = PAIRINV[p+1]
        r[i] ⊻= UInt16(1) << (j - 1); r[j] ⊻= UInt16(1) << (i - 1)
    end
    r
end

# Extend the anchor basis to F_2^45 with unit vectors: the added vectors are
# the complement basis that indexes the 2^38 cosets.
function complement_basis(V)
    C = UInt64[]; B = copy(V)
    for p in 0:NP-1
        e = UInt64(1) << p
        if rank_f2([B; e]) > length(B)
            push!(B, e); push!(C, e)
        end
    end
    C
end
coset_rep(idx::UInt64, C) = reduce(⊻, (C[k] for k in eachindex(C) if (idx >> (k - 1)) & 1 == 1); init = UInt64(0))

# Bent test on 10 rows held in registers. For each column c, the first row
# with bit c is the pivot; every row with bit c (the pivot too) is reduced by
# it, so no swap and no dynamic index is necessary. A column without a pivot
# means rank < 10.
using Base.Cartesian: @nexprs
@inline function bent_tuple(r::NTuple{10,UInt16})
    @nexprs 10 k -> r_k = r[k]
    @nexprs 10 c -> begin
        m = UInt16(1) << (c - 1)
        piv = 0x0000; found = false
        @nexprs 10 k -> begin
            h = (r_k & m) != 0x0000
            piv = ifelse(h & !found, r_k, piv)
            found |= h
        end
        found || return false
        @nexprs 10 k -> (r_k = ifelse((r_k & m) != 0x0000, r_k ⊻ piv, r_k))
    end
    true
end
@inline xorrow(q::NTuple{10,UInt16}, a, off) = ntuple(i -> @inbounds(q[i] ⊻ a[off+i]), Val(10))

# Thread t scans the aligned block [base + t*K, base + (t+1)*K) in Gray-code order.
# exact = true fills the full histogram; exact = false stops a coset as soon as
# it can no longer reach `need` (the production mode).
@kernel function scan_kernel!(hist, hits, nhits, @Const(vrows), @Const(crows), base::UInt64,
                              logK::Int, need::Int, exact::Bool)
    t = @index(Global, Linear)
    s = base + (UInt64(t - 1) << logK)
    q = ntuple(_ -> 0x0000, Val(10))
    for b in 0:37                                       # rows of the first coset of the block
        if (s >> b) & 1 == 1
            q = xorrow(q, crows, b * NR)
        end
    end
    K = 1 << logK
    for j in 0:K-1
        if j > 0                                        # Gray code step: flip bit tz(j)
            q = xorrow(q, crows, trailing_zeros(j) * NR)
        end
        cnt = 0
        for v in 0:127
            cnt += bent_tuple(xorrow(q, vrows, v * NR)) ? 1 : 0
            (!exact && (cnt > need || cnt + 127 - v < need)) && break
        end
        if exact
            Atomix.@atomic hist[cnt+1] += UInt32(1)
        end
        if cnt == need
            g = UInt64(j ⊻ (j >> 1))
            h = Atomix.@atomic nhits[1] += UInt32(1)
            @inbounds h <= length(hits) && (hits[h] = s + g)
        end
    end
end

# Scan cosets [base, base + nthreads*K); returns (histogram, hit indices).
function scan(vrows_d, crows_d, base, nthreads, logK, need; exact = false, maxhits = 1 << 16)
    hist = devarray(zeros(UInt32, 129)); hits = devarray(zeros(UInt64, maxhits)); nh = devarray(zeros(UInt32, 1))
    scan_kernel!(DEV, 256)(hist, hits, nh, vrows_d, crows_d, UInt64(base), logK, need, exact; ndrange = nthreads)
    KernelAbstractions.synchronize(DEV)
    n = Int(Array(nh)[1])
    Array(hist), sort(Array(hits)[1:min(n, maxhits)]), n
end

function run_scan()
    flats = all_flats()
    C = comp_basis(gold_lut(3))
    b7, V7, _ = best_anchor(C)
    need = 178 - b7
    Vs = span(V7)                                       # 128 forms, index = combination of V7
    Cb = complement_basis(V7)
    @assert length(Cb) == 38
    vrows_d = devarray(reduce(vcat, form_rows.(Vs)))
    crows_d = devarray(reduce(vcat, form_rows.(Cb)))
    println("backend = $BACKEND, anchor b(V7) = $b7, need = $need")

    # 1. correctness: exact histogram of a small range against the CPU reference.
    logK = 6; nth = 1 << 12                             # 2^18 cosets
    hist, _, _ = scan(vrows_d, crows_d, 0, nth, logK, need; exact = true)
    ref = zeros(UInt32, 129)
    for idx in UInt64(0):UInt64(nth << logK - 1)
        ref[coset_bent(coset_rep(idx, Cb), Vs)+1] += 1
    end
    println("histogram matches the CPU reference: ", hist == ref, "  (", sum(hist), " cosets, max count ",
            findlast(!iszero, hist) - 1, ")")

    # 2. throughput in production mode (early exit).
    lg = length(ARGS) > 0 ? parse(Int, ARGS[1]) : 28
    logK = 8; nth = 1 << (lg - logK)
    scan(vrows_d, crows_d, 0, 1 << 8, logK, need)       # compile
    t = @elapsed (_, hits, n) = scan(vrows_d, crows_d, 0, nth, logK, need)
    rate = 2.0^lg / t
    println("scanned 2^$lg cosets in ", round(t, digits = 2), " s: ", round(rate / 1e6, digits = 1),
            " M cosets/s; hits = $n")
    println("projected full scan of 2^38 cosets: ", round(2.0^38 / rate / 3600, digits = 2), " h per anchor")
    for idx in hits[1:min(end, 3)]
        println("  hit $idx: CPU count = ", coset_bent(coset_rep(idx, Cb), Vs))
    end
end

run_scan()
