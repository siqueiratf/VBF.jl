# va_generic.jl — n/class-generic self-equivalence subspace V_A machinery.
#
# Extension layer for the GPGPU APN census across Beierle–Brinkmann–Leander 2021
# classes. `helpers.jl` stays the paper-exact n=8/class-22 reference; this module is
# the generic counterpart used by the basis-bin writers and the survey/extension code.
#
# Convention (matches the validated launch_search.jl encoding):
#   pairs (p,q), 0≤p<q<n, indexed by pair_index; output bit k, 0≤k<n.
#   coefficient vector c[col_idx(p,q,k,n)+1] = coeff of x_p·x_q in output bit k
#     (pair-major: pair_index(p,q)*n + k).
#   M_A is the n·npairs × npairs·n self-equivalence constraint matrix (Eq. 2);
#     RREF over F₂ gives the free/pivot split, dim(V_A) = #free columns.
module VAGeneric

using TOML

export load_A, va_parameterize, va_dim, va_basis_lut, write_lut_bin, write_rows_bin,
       pair_index, col_idx, quadratic_lut_n, apply_b

const TUPLES_DIR = joinpath(@__DIR__, "..", "..", "..", "VBFRepro", "src", "202107-beierle-self-equivalence", "tuples")

# ── index helpers ────────────────────────────────────────────────────────────
pair_index(p::Int, q::Int, n::Int) = p * (2n - 1 - p) ÷ 2 + q - p - 1
row_idx(j::Int, r::Int, s::Int, n::Int) = j * (n * (n - 1) ÷ 2) + pair_index(r, s, n)
col_idx(p::Int, q::Int, k::Int, n::Int) = pair_index(p, q, n) * n + k

# ── load BBL2021 automorphism A for (n, class_idx) from the Beierle TOML ───────
function load_A(n::Int, class_idx::Int)::BitMatrix
    f = joinpath(TUPLES_DIR, "AllTuplesMatrices$n.toml")
    isfile(f) || error("missing tuples file: $f")
    raw = sort(get(TOML.parsefile(f), "blocks", Any[]), by = b -> Int(b["index"]))
    (1 <= class_idx <= length(raw)) || error("class $class_idx out of 1:$(length(raw)) for n=$n")
    rows = raw[class_idx]["A"]
    A = falses(n, n)
    for i in 1:n, j in 1:n
        A[i, j] = (Int(rows[i][j]) % 2 != 0)
    end
    A
end

# ── constraint matrix M_A (self-equivalence linear system) ─────────────────────
function build_M_A(A::AbstractMatrix{Bool}, n::Int)::BitMatrix
    np = n * (n - 1) ÷ 2
    M = falses(n * np, np * n)
    for j in 0:(n-1), r in 0:(n-2), s in (r+1):(n-1)
        row = row_idx(j, r, s, n) + 1
        for p in 0:(n-2), q in (p+1):(n-1)
            ((A[p+1, r+1] & A[q+1, s+1]) ⊻ (A[p+1, s+1] & A[q+1, r+1])) &&
                (M[row, col_idx(p, q, j, n) + 1] ⊻= true)
        end
        for k in 0:(n-1)
            A[j+1, k+1] && (M[row, col_idx(r, s, k, n) + 1] ⊻= true)
        end
    end
    M
end

# ── RREF over F₂ (in place); returns (pivot_cols, free_cols) ───────────────────
function rref_f2!(M::BitMatrix)
    nrows, ncols = size(M)
    prow = 1; pivot_cols = Int[]
    for c in 1:ncols
        found = 0
        for r in prow:nrows
            M[r, c] && (found = r; break)
        end
        found == 0 && continue
        push!(pivot_cols, c)
        if found != prow
            tmp = copy(M[found, :]); M[found, :] = M[prow, :]; M[prow, :] = tmp
        end
        for r in 1:nrows
            (r != prow && M[r, c]) && (M[r, :] .⊻= M[prow, :])
        end
        prow += 1
    end
    pivot_cols, setdiff(1:ncols, pivot_cols)
end

# ── parameterization: dim, pivot/free split, and pivot dependency sets S ───────
struct VAParam
    n::Int
    class_idx::Int
    n_free::Int
    pivot_cols::Vector{Int}
    free_cols::Vector{Int}
    S::Vector{Vector{Int}}   # S[i] = free-var indices j feeding pivot i
end

function va_parameterize(n::Int, class_idx::Int)::VAParam
    A = load_A(n, class_idx)
    M = build_M_A(A, n)
    pivot_cols, free_cols = rref_f2!(M)
    S = [Int[] for _ in 1:length(pivot_cols)]
    for i in 1:length(pivot_cols), (j, fc) in enumerate(free_cols)
        M[i, fc] && push!(S[i], j)
    end
    VAParam(n, class_idx, length(free_cols), pivot_cols, free_cols, S)
end

va_dim(n::Int, class_idx::Int) = va_parameterize(n, class_idx).n_free

# ── map a free-coordinate vector b ∈ F₂^{n_free} to the full coeff vector c ────
function apply_b(b_vec::AbstractVector{Bool}, p::VAParam)::BitVector
    c = falses((p.n * (p.n - 1) ÷ 2) * p.n)
    for (k, fc) in enumerate(p.free_cols)
        c[fc] = b_vec[k]
    end
    for (i, pc) in enumerate(p.pivot_cols)
        v = false
        for j in p.S[i]
            v ⊻= b_vec[j]
        end
        c[pc] = v
    end
    c
end

# ── coeff vector c → byte LUT of the quadratic function over F₂ⁿ ───────────────
function quadratic_lut_n(c::AbstractVector{Bool}, n::Int)::Vector{UInt8}
    lut = zeros(UInt8, 1 << n)
    pidx = 0
    for p in 0:(n-2), q in (p+1):(n-1)
        contrib = UInt8(0)
        for k in 0:(n-1)
            c[pidx * n + k + 1] && (contrib |= UInt8(1 << k))
        end
        if contrib != 0
            for x in 0:((1 << n) - 1)
                ((x >> p) & 1 == 1) && ((x >> q) & 1 == 1) && (lut[x+1] ⊻= contrib)
            end
        end
        pidx += 1
    end
    lut
end

# i-th basis function's LUT (b = e_i)
function va_basis_lut(i::Int, p::VAParam)::Vector{UInt8}
    b = falses(p.n_free); b[i] = true
    quadratic_lut_n(apply_b(b, p), p.n)
end

# ── basis-bin writers ──────────────────────────────────────────────────────────
# LUT form: n_free × (2ⁿ/8) UInt64, each function's byte-LUT packed 8 bytes/word.
# Consumed by the legacy LUT/DDT searchers.
function write_lut_bin(path::AbstractString, n::Int, class_idx::Int)
    p = va_parameterize(n, class_idx)
    wpl = (1 << n) ÷ 8
    open(path, "w") do io
        for i in 1:p.n_free
            lut = va_basis_lut(i, p)
            for x in 1:wpl
                w = UInt64(0)
                for b in 0:7
                    w |= UInt64(lut[(x-1)*8 + b + 1]) << (b * 8)
                end
                write(io, w)
            end
        end
    end
    p.n_free
end

# Bilinear-row form: n_free × n UInt64; row i, byte j = coeff vector of pair
# (min(i,j),max(i,j)) = F(e_i⊕e_j). Consumed by apn_search_ultra/n7 + fast_checker.
function write_rows_bin(path::AbstractString, n::Int, class_idx::Int)
    p = va_parameterize(n, class_idx)
    open(path, "w") do io
        for b in 1:p.n_free
            bv = falses(p.n_free); bv[b] = true
            c = apply_b(bv, p)
            for i in 0:(n-1)
                row = UInt64(0)
                for j in 0:(n-1)
                    i == j && continue
                    lo, hi = min(i, j), max(i, j)
                    val = UInt64(0)
                    for k in 0:(n-1)
                        c[col_idx(lo, hi, k, n) + 1] && (val |= UInt64(1) << k)
                    end
                    row |= val << (j * 8)
                end
                write(io, row)
            end
        end
    end
    p.n_free
end

end # module
