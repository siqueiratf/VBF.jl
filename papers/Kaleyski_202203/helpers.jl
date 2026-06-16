# Implements shared helpers for the Kaleyski (2022) reproduction.
# Paper: Kaleyski, N. (2022), "Deciding EA-equivalence via invariants",
#        Cryptography and Communications (2021), arXiv:2203.XXXXX
# Section: General — shared helpers, Walsh-vector sigma computation
#
# Pseudocode:
#   sigma_multiplicities_vec: elementwise M_k^F(0,s) via Walsh formula
#     1. Precompute rowsum[b] = sum_a W_F(a,b)^k
#     2. For each s: sigma[s] = (1/2^{2n}) * sum_b (-1)^{b·s} * rowsum[b]
# VBF API used: SBox, lat, gf_monomial_lut

using VBF

function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Kaleyski (2022): Deciding EA-equivalence via invariants")
    println(io, "Cryptography and Communications, 2021")
    println(io, "=" ^ 72)
end

function print_section(title::AbstractString, io::IO = stdout)
    println(io, "\n── ", title, " ", "─" ^ max(0, 70 - length(title) - 4))
end

function print_check(label::AbstractString, ok::Bool, io::IO = stdout)
    println(io, "  ", ok ? "[ OK ]" : "[FAIL]", " ", label)
end

function print_kv(label::AbstractString, value, io::IO = stdout)
    println(io, "  ", label, ": ", value)
end

"""
    sigma_multiplicities_vec(F::SBox{N,T}; k::Int = 4) -> Vector{Int}

Elementwise Walsh-formula computation of Proposition 4 (Eq. 2):
    M_k^F(0, s) = 2^{-2n} · Σ_{a,b ∈ F₂ⁿ} (-1)^{b·s} · W_F(a,b)^k

Returns `Vector{Int}` of length 2ⁿ; `result[s+1] = M_k^F(0, s)`.
Unlike `sigma_multiplicities`, preserves the per-element index (not a multiset).
"""
function sigma_multiplicities_vec(F::SBox{N,T}; k::Int = 4) where {N,T}
    k ≥ 2 || throw(ArgumentError("k must be ≥ 2, got k = $k"))
    n_size = 1 << N
    L = lat(F)
    rowsum = zeros(Int128, n_size)
    @inbounds for b = 0:(n_size - 1)
        s = Int128(0)
        for a = 0:(n_size - 1)
            w = Int128(L[a + 1, b + 1])
            pw = w
            for _ = 1:(k - 1)
                pw *= w
            end
            s += pw
        end
        rowsum[b + 1] = s
    end
    result = zeros(Int, n_size)
    @inbounds for s = 0:(n_size - 1)
        σ = Int128(0)
        for b = 0:(n_size - 1)
            sign =
                ((count_ones(UInt(b) & UInt(s)) & 1) == 0) ? Int128(1) :
                Int128(-1)
            σ += sign * rowsum[b + 1]
        end
        result[s + 1] = Int(σ >> (2 * N))
    end
    return result
end

"""
    gold_x3(N::Int) -> SBox

Gold function x^3 as SBox over F₂ᴺ, using the primitive polynomial from VBF.
"""
function gold_x3(N::Int)
    lut = gf_monomial_lut(N, 3)
    return SBox{N,UInt8}(UInt8.(lut))
end

"""
    apply_linear(lut::AbstractVector{T}, x::AbstractVector{T}) -> T

Apply a linear map (given as its 2ⁿ-length LUT) to element x (as integer).
"""
apply_linear(lut::AbstractVector{T}, x::Integer) where {T} = lut[Int(x) + 1]
