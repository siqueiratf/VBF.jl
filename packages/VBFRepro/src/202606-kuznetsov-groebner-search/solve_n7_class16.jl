using TOML
using Random
using VBF
import AlgebraicSolving as AS


include("helpers.jl")

function pair_index_n(p::Int, q::Int, n::Int)
    p * (2*n - 1 - p) ÷ 2 + q - p - 1
end
function row_idx_n(j::Int, r::Int, s::Int, n::Int)
    j * (n * (n - 1) ÷ 2) + pair_index_n(r, s, n)
end
function col_idx_n(p::Int, q::Int, k::Int, n::Int)
    pair_index_n(p, q, n) * n + k
end
function build_M_A_n(A::AbstractMatrix{Bool}, n::Int)
    n_pairs = n * (n - 1) ÷ 2
    M = falses(n * n_pairs, n_pairs * n)
    for j in 0:(n-1), r in 0:(n-2), s in (r+1):(n-1)
        row = row_idx_n(j, r, s, n) + 1
        for p in 0:(n-2), q in (p+1):(n-1)
            val = (A[p+1, r+1] & A[q+1, s+1]) ⊻ (A[p+1, s+1] & A[q+1, r+1])
            val && (M[row, col_idx_n(p, q, j, n) + 1] ⊻= true)
        end
        for k in 0:(n-1)
            A[j+1, k+1] && (M[row, col_idx_n(r, s, k, n) + 1] ⊻= true)
        end
    end
    M
end

function _toml_to_int_matrix(rows)::Matrix{Int}
    isempty(rows) && return zeros(Int, 0, 0)
    nr = length(rows)
    nc = length(rows[1])
    M = zeros(Int, nr, nc)
    for r in 1:nr
        M[r, :] = Int.(rows[r])
    end
    M
end

n = 7
class_idx = 22

# 1. Load A
filename = "../Beierle_202107/tuples/AllTuplesMatrices7.toml"
data = TOML.parsefile(filename)
raw = sort(get(data, "blocks", Any[]), by = b -> Int(b["index"]))
b = raw[class_idx]
A_int = _toml_to_int_matrix(b["A"])
A = falses(n, n)
for i in 1:n, j in 1:n
    A[i, j] = (A_int[i, j] % 2 != 0)
end

# 2. Build M_A and parameterize V_A
M = build_M_A_n(A, n)
pivot_cols, free_cols = VBF.rref_f2!(M)
n_pivots = length(pivot_cols)
n_free = length(free_cols)
S = [Int[] for _ in 1:n_pivots]
for i in 1:n_pivots
    for (j, fc) in enumerate(free_cols)
        M[i, fc] && push!(S[i], j)
    end
end
println("Class $class_idx: dim(V_A) = $n_free")

function apply_fc22_sol22_n(b::AbstractVector{Bool}, n::Int)
    n_pairs = n * (n - 1) ÷ 2
    c = falses(n_pairs * n)
    for (k, fc) in enumerate(free_cols)
        c[fc] = b[k]
    end
    for (i, pc) in enumerate(pivot_cols)
        val = false
        for j in S[i]
            val ⊻= b[j]
        end
        c[pc] = val
    end
    c
end

function quadratic_lut_n(c::AbstractVector{Bool}, n::Int)
    lut = zeros(UInt8, 1 << n)
    pidx = 0
    for p in 0:(n-2), q in (p+1):(n-1)
        contrib = UInt8(0)
        for k in 0:(n-1)
            c[pidx * n + k + 1] && (contrib |= UInt8(1 << k))
        end
        if contrib != 0
            for x in 0:((1<<n)-1)
                ((x >> p) & 1 == 1) && ((x >> q) & 1 == 1) && (lut[x+1] ⊻= contrib)
            end
        end
        pidx += 1
    end
    lut
end

# 3. Find a center (Phase 1)
rng = Random.MersenneTwister(42)
println("Running Phase 1 (Random Sampling) for APN center...")
center_lut = nothing
for i in 1:50000
    b = rand(rng, Bool, n_free)
    c = apply_fc22_sol22_n(b, n)
    lut = quadratic_lut_n(c, n)
    F = SBox{7}(lut)
    du = differential_uniformity(F)
    if du == 2
        println("Found APN center at iteration $i!")
        global center_lut = lut
        break
    end
end

if center_lut === nothing
    println("Could not find an APN center. Picking a random center.")
    global b = rand(rng, Bool, n_free)
    c = apply_fc22_sol22_n(b, n)
    global center_lut = quadratic_lut_n(c, n)
end

# 4. Phase 2 (Gröbner Basis)
const PH2_N = 7
const PH2_PAIRS = [(p, q) for p in 0:(PH2_N-1) for q in (p+1):(PH2_N-1)]
const PH2_K = length(PH2_PAIRS)
const PH2_PIDX = Dict(PH2_PAIRS[i] => i - 1 for i in eachindex(PH2_PAIRS))
const PH2_FREE_PAIRS = [(4, 5), (4, 6), (5, 6)] # 3 pairs * 7 bits = 21 free vars

ph2_vi(j::Int, p::Int, q::Int) = j * PH2_K + PH2_PIDX[(min(p, q), max(p, q))]

function ph2_free_indices()
    v = Int[]
    for (p, q) in PH2_FREE_PAIRS, j in 0:(PH2_N-1)
        push!(v, ph2_vi(j, p, q))
    end
    sort!(v)
end

function quad_anf_coeffs(lut::AbstractVector{<:Integer})
    c = falses(PH2_N * PH2_K)
    for (p, q) in PH2_PAIRS
        xp = 1 << p; xq = 1 << q
        v = lut[1] ⊻ lut[xp + 1] ⊻ lut[xq + 1] ⊻ lut[(xp | xq) + 1]
        for j in 0:(PH2_N-1)
            ((v >> j) & 1 == 1) && (c[ph2_vi(j, p, q) + 1] = true)
        end
    end
    c
end

function coeffs_to_lut(c::AbstractVector{Bool})
    lut = zeros(UInt8, 1 << PH2_N)
    for x in 0:((1<<PH2_N)-1)
        val = UInt8(0)
        for j in 0:(PH2_N-1)
            fj = false
            for (p, q) in PH2_PAIRS
                (((x >> p) & 1) == 1 && ((x >> q) & 1) == 1 && c[ph2_vi(j, p, q) + 1]) && (fj = !fj)
            end
            fj && (val |= UInt8(1) << j)
        end
        lut[x + 1] = val
    end
    lut
end

const PH2_BP = Set{UInt32}
ph2_bxor!(a::PH2_BP, p::PH2_BP) = (for m in p; (m in a) ? delete!(a, m) : push!(a, m); end; a)
function ph2_bmul(p::PH2_BP, q::PH2_BP)
    r = PH2_BP()
    for x in p, y in q
        m = x | y
        (m in r) ? delete!(r, m) : push!(r, m)
    end
    r
end

function ph2_det(M::Matrix{PH2_BP}, rows::Vector{Int}, cols::Vector{Int})
    m = length(rows); full = (1 << m) - 1
    dp = Vector{PH2_BP}(undef, full + 1); dp[1] = PH2_BP([UInt32(0)])
    for mask in 1:full
        ri = count_ones(UInt32(mask)); acc = PH2_BP()
        for ci in 1:m
            b = 1 << (ci - 1); (mask & b) == 0 && continue
            e = M[rows[ri], cols[ci]]; isempty(e) && continue
            sub = dp[(mask ⊻ b) + 1]; isempty(sub) && continue
            ph2_bxor!(acc, ph2_bmul(e, sub))
        end
        dp[mask + 1] = acc
    end
    dp[full + 1]
end

function ph2_build(center_coeffs::AbstractVector{Bool})
    free = ph2_free_indices()
    bitof = Dict(free[i] => UInt32(1) << (i - 1) for i in eachindex(free))
    csym = [PH2_BP() for _ in 1:(PH2_N * PH2_K)]
    for v in 0:(PH2_N * PH2_K - 1)
        if haskey(bitof, v)
            push!(csym[v + 1], bitof[v])
        elseif center_coeffs[v + 1]
            push!(csym[v + 1], UInt32(0))
        end
    end
    cc(j, p, q) = csym[ph2_vi(j, p, q) + 1]
    function M_a(a)
        M = Matrix{PH2_BP}(undef, PH2_N, PH2_N)
        for j in 0:(PH2_N-1), l in 0:(PH2_N-1)
            e = PH2_BP()
            for pp in 0:(l - 1); ((a >> pp) & 1 == 1) && ph2_bxor!(e, cc(j, pp, l)); end
            for qq in (l + 1):(PH2_N-1); ((a >> qq) & 1 == 1) && ph2_bxor!(e, cc(j, l, qq)); end
            M[j + 1, l + 1] = e
        end
        M
    end
    subs = [[r for r in 1:PH2_N if r != d] for d in 1:PH2_N]
    gens = PH2_BP[]
    for a in 1:((1<<PH2_N)-1)
        M = M_a(a); prod = PH2_BP([UInt32(0)])
        for rs in subs, cs in subs
            minor = ph2_det(M, rs, cs); q = copy(minor); ph2_bxor!(q, PH2_BP([UInt32(0)]))
            prod = ph2_bmul(prod, q)
            isempty(prod) && break
        end
        if isempty(prod)
        elseif length(prod) == 1 && (UInt32(0) in prod)
            return (:infeasible, PH2_BP[], free)
        else
            push!(gens, prod)
        end
    end
    (:ok, gens, free)
end

function ph2_variety(gbBP::Vector{PH2_BP}, n_free_vars::Int)
    vmask = [reduce(|, g; init = UInt32(0)) for g in gbBP]
    sols = UInt32[]
    function dfs(idx::Int, asg::UInt32, fixed::UInt32)
        if idx < 0
            push!(sols, asg); return
        end
        bit = UInt32(1) << idx
        for val in (UInt32(0), bit)
            a2 = asg | val; f2 = fixed | bit; ok = true
            for gi in eachindex(gbBP)
                if (vmask[gi] & f2) == vmask[gi]
                    cnt = 0
                    for m in gbBP[gi]; ((a2 & m) == m) && (cnt ⊻= 1); end
                    cnt != 0 && (ok = false; break)
                end
            end
            ok && dfs(idx - 1, a2, f2)
        end
    end
    dfs(n_free_vars - 1, UInt32(0), UInt32(0))
    sols
end

function ph2_to_bp(g, n_free_vars::Int)
    p = PH2_BP()
    for ev in AS.exponent_vectors(g)
        mask = UInt32(0)
        for i in 1:n_free_vars; ev[i] != 0 && (mask |= UInt32(1) << (i - 1)); end
        (mask in p) ? delete!(p, mask) : push!(p, mask)
    end
    p
end

function phase2_slice(center; verify::Bool = true)
    lut = center isa SBox ? center.lut : center
    coeffs = quad_anf_coeffs(lut)
    println("Building Phase 2 system...")
    status, gensBP, free = ph2_build(coeffs)
    n_free_vars = length(free)
    status === :infeasible && return SBox{7}[]

    println("Computing Grobner Basis over GF(2) in $n_free_vars variables...")
    R, cv = AS.polynomial_ring(AS.GF(2), ["c$i" for i in 1:n_free_vars])
    to_as(p::PH2_BP) = isempty(p) ? R(0) : sum(begin
        mon = R(1)
        for i in 0:(n_free_vars-1); (m >> i) & 1 == 1 && (mon *= cv[i + 1]); end
        mon
    end for m in p)
    gens = AS.elem_type(R)[to_as(p) for p in gensBP]
    for i in 1:n_free_vars; push!(gens, cv[i]^2 + cv[i]); end

    gb = AS.groebner_basis(AS.Ideal(gens))
    (length(gb) == 1 && AS.is_constant(gb[1]) && !iszero(gb[1])) && return SBox{7}[]
    gbBP = PH2_BP[ph2_to_bp(g, n_free_vars) for g in gb]; filter!(g -> !isempty(g), gbBP)

    println("Enumerating variety...")
    seen = Set{Vector{UInt8}}(); out = SBox{7}[]
    for sol in ph2_variety(gbBP, n_free_vars)
        c = copy(coeffs)
        for (i, v) in enumerate(free); c[v + 1] = ((sol >> (i - 1)) & 1) == 1; end
        l = coeffs_to_lut(c)
        F = SBox{7}(l)
        verify && differential_uniformity(F) != 2 && continue
        l in seen && continue
        push!(seen, l); push!(out, F)
    end
    out
end

apns = phase2_slice(center_lut)
println("Found $(length(apns)) APNs in this slice!")
for (i, apn) in enumerate(apns)
    println("APN $i: differential_uniformity = $(differential_uniformity(apn))")
end
