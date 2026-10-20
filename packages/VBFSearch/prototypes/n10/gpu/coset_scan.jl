# Portable GPU scan of the exchange step at n = 10: for an anchor V_7 < Q_10
# (128 forms) and every coset q + V_7 of the 2^38 cosets, count the bent forms
# (rank 10) and keep the cosets whose count lies in the window `need` (an
# integer or a range lo:hi).
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
# it can no longer reach the window [nlo, nhi] (the production mode).
@kernel function scan_kernel!(hist, hits, nhits, @Const(vrows), @Const(crows), base::UInt64,
                              logK::Int, nlo::Int, nhi::Int, exact::Bool)
    t = @index(Global, Linear)
    s = base + (((t - 1) % UInt64) << logK)
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
            (!exact && (cnt > nhi || cnt + 127 - v < nlo)) && break
        end
        if exact
            Atomix.@atomic hist[cnt+1] += UInt32(1)
        end
        if nlo <= cnt <= nhi
            g = (j ⊻ (j >> 1)) % UInt64
            h = Atomix.@atomic nhits[1] += UInt32(1)
            @inbounds h <= length(hits) && (hits[h] = s + g)
        end
    end
end

# --- Bit-sliced variant: one UInt32 word holds entry (i, j) of 32 forms q + v ----
# For column c, the first row with bit c is the pivot in each lane; every row
# with bit c is reduced by it. Columns below c are already zero, so only j >= c
# is updated. A lane stays alive while each column has a pivot (rank 10).
function _bent_sliced_expr()
    r(i, j) = Symbol("r_", i, "_", j); p(j) = Symbol("p_", j)
    body = Expr[]
    for i in 1:NR, j in 1:NR
        push!(body, :($(r(i, j)) = @inbounds(vs[off+$((i - 1) * NR + j)]) ⊻ (UInt32(0) - UInt32((q[$i] >> $(j - 1)) & 0x0001))))
    end
    push!(body, :(alive = 0xffffffff))
    for c in 1:NR
        push!(body, :(found = 0x00000000))
        for j in c:NR
            push!(body, :($(p(j)) = 0x00000000))
        end
        for k in 1:NR
            push!(body, :(sel = $(r(k, c)) & ~found))
            push!(body, :(found |= $(r(k, c))))
            for j in c:NR
                push!(body, :($(p(j)) |= sel & $(r(k, j))))
            end
        end
        push!(body, :(alive &= found))
        push!(body, :(alive == 0x00000000 && return alive))
        c == NR && continue
        for k in 1:NR
            push!(body, :(h = $(r(k, c))))
            for j in c:NR
                push!(body, :($(r(k, j)) ⊻= h & $(p(j))))
            end
        end
    end
    push!(body, :(return alive))
    Expr(:block, body...)
end
@eval @inline function bent_sliced(q::NTuple{10,UInt16}, vs, off::Int)
    $(_bent_sliced_expr())
end

# vs[b*100 + (i-1)*10 + j], bit l = bit j-1 of row i of form 32b + l.
function slice_forms(Vs)
    vs = zeros(UInt32, 4 * NR * NR)
    for b in 0:3, l in 0:31
        rows = form_rows(Vs[32b+l+1])
        for i in 1:NR, j in 1:NR
            (rows[i] >> (j - 1)) & 1 == 1 && (vs[b*NR*NR+(i-1)*NR+j] |= UInt32(1) << l)
        end
    end
    vs
end

@kernel function scan_sliced!(hist, hits, nhits, @Const(vslice), @Const(crows), base::UInt64,
                              logK::Int, nlo::Int, nhi::Int, exact::Bool)
    t = @index(Global, Linear)
    s = base + (((t - 1) % UInt64) << logK)
    q = ntuple(_ -> 0x0000, Val(10))
    for b in 0:37
        if (s >> b) & 1 == 1
            q = xorrow(q, crows, b * NR)
        end
    end
    K = 1 << logK
    for j in 0:K-1
        if j > 0
            q = xorrow(q, crows, trailing_zeros(j) * NR)
        end
        cnt = 0
        for b in 0:3
            cnt += count_ones(bent_sliced(q, vslice, b * NR * NR))
            (!exact && (cnt > nhi || cnt + 96 - 32b < nlo)) && break
        end
        if exact
            Atomix.@atomic hist[cnt+1] += UInt32(1)
        end
        if nlo <= cnt <= nhi
            g = (j ⊻ (j >> 1)) % UInt64
            h = Atomix.@atomic nhits[1] += UInt32(1)
            @inbounds h <= length(hits) && (hits[h] = s + g)
        end
    end
end

# Scan cosets [base, base + nthreads*K); returns (histogram, hit indices).
# kernel = :regs takes the row table of the 128 forms, :sliced the slice table.
function scan(vtab_d, crows_d, base, nthreads, logK, need; exact = false, maxhits = 1 << 16, kernel = :sliced)
    hist = devarray(zeros(UInt32, 129)); hits = devarray(zeros(UInt64, maxhits)); nh = devarray(zeros(UInt32, 1))
    k! = kernel == :sliced ? scan_sliced!(DEV, 256) : scan_kernel!(DEV, 256)
    k!(hist, hits, nh, vtab_d, crows_d, UInt64(base), logK, first(need), last(need), exact; ndrange = nthreads)
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
    tables = Dict(:regs => devarray(reduce(vcat, form_rows.(Vs))), :sliced => devarray(slice_forms(Vs)))
    crows_d = devarray(reduce(vcat, form_rows.(Cb)))
    println("backend = $BACKEND, anchor b(V7) = $b7, need = $need")

    # 1. correctness: exact histogram of a small range against the CPU reference.
    logK = 6; nth = 1 << 12                             # 2^18 cosets
    ref = zeros(UInt32, 129)
    for idx in UInt64(0):UInt64(nth << logK - 1)
        ref[coset_bent(coset_rep(idx, Cb), Vs)+1] += 1
    end
    lg = length(ARGS) > 0 ? parse(Int, ARGS[1]) : 28
    kernels = Symbol.(split(get(ENV, "N10_KERNEL", "regs,sliced"), ","))
    for kern in kernels
        hist, _, _ = scan(tables[kern], crows_d, 0, nth, logK, need; exact = true, kernel = kern)
        println("[$kern] histogram matches the CPU reference: ", hist == ref, "  (", sum(hist), " cosets)")

        # 2. throughput in production mode (early exit).
        lK = 8; nt = 1 << (lg - lK)
        scan(tables[kern], crows_d, 0, 1 << 8, lK, need; kernel = kern)    # compile
        t = @elapsed (_, hits, nh) = scan(tables[kern], crows_d, 0, nt, lK, need; kernel = kern)
        rate = 2.0^lg / t
        println("[$kern] scanned 2^$lg cosets in ", round(t, digits = 2), " s: ", round(rate / 1e6, digits = 1),
                " M cosets/s; hits = $nh; projected 2^38 scan: ", round(2.0^38 / rate / 3600, digits = 2), " h per anchor")
        for idx in hits[1:min(end, 2)]
            println("  hit $idx: CPU count = ", coset_bent(coset_rep(idx, Cb), Vs))
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_scan()
end
