# Implements paper-local helpers for Li & Wang (2014).
# Paper: Li, Wang (2014), "Constructing Differentially 4-Uniform Permutations over
#        GF(2^{2m}) from Quadratic APN Permutations over GF(2^{2m+1})",
#        Designs, Codes and Cryptography 72:249–264
# Section: General — field utilities, subspace restriction, report formatting
#
# Pseudocode:
#   1. gf_trace(x, n)            = x ⊕ x^2 ⊕ … ⊕ x^{2^{n-1}} ∈ {0,1}
#   2. gf_relative_trace(x,m,k)  = Tr_{GF(2^m)/GF(2^k)}(x)
#   3. make_nbit_lut(G, H)       = n-bit LUT of G restricted to sorted subspace H
#   4. build_fu(F, u, N)         = Theorem 2: F_u = L_u∘F^{-1} restricted to H_u
#   5. build_fu_prime(F, u, N)   = Theorem 5: F_u' = F_u + id restricted to H_u
#   6. tr0_subspace(m)           = {x ∈ GF(2^m) | Tr_m(x) = 0}, sorted
#   7. sbox_inverse(s)           = compositional inverse LUT
#   8. rdf_set(F)                = {RD_F(a,4) | a ∈ F*} (EA-invariant)
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox, ddt

using VBF
using Dates

"""
    gf_trace(x, n; modulus) -> Int

Absolute trace Tr_{GF(2^n)/GF(2)}(x) = x ⊕ x^2 ⊕ x^4 ⊕ … ⊕ x^{2^{n-1}} ∈ {0,1}.
"""
function gf_trace(x::Integer, n::Int; modulus::Int = primitive_polynomial(n))
    acc = 0
    xi = Int(x)
    for _ in 1:n
        acc ⊻= xi
        xi = gf_mul(xi, xi, n; modulus = modulus)
    end
    acc
end

"""
    gf_relative_trace(x, m, k; modulus) -> Int

Relative trace Tr_{GF(2^m)/GF(2^k)}(x) = x ⊕ x^{2^k} ⊕ x^{2^{2k}} ⊕ … ⊕ x^{2^{(m/k-1)k}}.
Requires k | m. Result lies in the subfield GF(2^k) ⊆ GF(2^m).
"""
function gf_relative_trace(
    x::Integer,
    m::Int,
    k::Int;
    modulus::Int = primitive_polynomial(m),
)
    m % k == 0 || throw(ArgumentError("gf_relative_trace: k=$k must divide m=$m"))
    steps = m ÷ k
    acc = 0
    xi = Int(x)
    frob_exp = 1 << k
    for _ in 1:steps
        acc ⊻= xi
        xi = gf_pow(xi, frob_exp, m; modulus = modulus)
    end
    acc
end

"""
    make_nbit_lut(G_lut, H_sorted) -> Vector{Int}

Restrict G: GF(2^N) → GF(2^N) to the subspace H_sorted (sorted 2^n elements),
returning the n-bit LUT indexed by position in H_sorted.

Identifies H_sorted with {0,…,2^n-1} via sorted order: φ(i) = H_sorted[i+1].
Asserts G maps H into H.
"""
function make_nbit_lut(G_lut::Vector{Int}, H_sorted::Vector{Int})
    N_big = length(G_lut)
    n_sub = length(H_sorted)
    phi_inv = fill(-1, N_big)
    for (i, h) in enumerate(H_sorted)
        phi_inv[h+1] = i - 1
    end
    lut = Vector{Int}(undef, n_sub)
    for i in 0:n_sub-1
        y = H_sorted[i+1]
        result = G_lut[y+1]
        idx = phi_inv[result+1]
        idx >= 0 || error("make_nbit_lut: G($(y)) = $(result) ∉ H_sorted")
        lut[i+1] = idx
    end
    lut
end

"""
    build_fu(F_lut, u, N; modulus) -> (fu_lut, H_u)

Theorem 2 construction: given F quadratic APN permutation over GF(2^N) (N = n+1,
n even) as a 2^N-entry LUT, and nonzero u ∈ GF(2^N)*, build F_u over F_2^n.

  L_u(x) = F(x) ⊕ F(x⊕u) ⊕ F(u),  H_u = Im(L_u),  F_u = L_u∘F^{-1}|_{H_u}.

Returns (fu_lut::Vector{Int}, H_u::Vector{Int}) where H_u is sorted and fu_lut
indexes into H_u (i → H_u[fu_lut[i]+1]).
"""
function build_fu(F_lut::AbstractVector{<:Integer}, u::Int, N::Int; modulus::Int = primitive_polynomial(N))
    u != 0 || throw(ArgumentError("build_fu: u must be nonzero"))
    q = 1 << N
    length(F_lut) == q || throw(ArgumentError("build_fu: F_lut must have length 2^N = $q"))

    F_inv = zeros(Int, q)
    for x in 0:q-1
        F_inv[Int(F_lut[x+1])+1] = x
    end

    Fu_val = Int(F_lut[u+1])
    L_u_lut = [Int(F_lut[x+1]) ⊻ Int(F_lut[(x ⊻ u)+1]) ⊻ Fu_val for x in 0:q-1]

    H_u = sort(collect(Set(L_u_lut)))
    n = N - 1
    length(H_u) == 1 << n ||
        error("build_fu: |H_u| = $(length(H_u)), expected $(1<<n); check F is quadratic APN perm with F(0)=0")

    G_lut = [L_u_lut[F_inv[y+1]+1] for y in 0:q-1]  # Vector{Int}

    fu_lut = make_nbit_lut(G_lut, H_u)
    return fu_lut, H_u
end

"""
    build_fu_prime(F_lut, u, N; modulus) -> (fu_prime_lut, H_u)

Theorem 5 construction: F_u'(x) = F_u(x) + x (addition in GF(2^N) via H_u).
EA-equivalent to F_u. Returns (fu_prime_lut, H_u).
"""
function build_fu_prime(
    F_lut::AbstractVector{<:Integer},
    u::Int,
    N::Int;
    modulus::Int = primitive_polynomial(N),
)
    fu_lut, H_u = build_fu(F_lut, u, N; modulus = modulus)
    q_big = 1 << N
    phi_inv = fill(-1, q_big)
    for (i, h) in enumerate(H_u)
        phi_inv[h+1] = i - 1
    end
    n = N - 1
    fu_prime_lut = Vector{Int}(undef, 1 << n)
    for i in 0:(1<<n)-1
        y_fu = H_u[fu_lut[i+1]+1]   # φ(F_u(i))
        y_i  = H_u[i+1]              # φ(i)
        result = y_fu ⊻ y_i           # F_u(φ(i)) + φ(i) in GF(2^N)
        idx = phi_inv[result+1]
        idx >= 0 || error("build_fu_prime: result $(result) ∉ H_u at i=$i")
        fu_prime_lut[i+1] = idx
    end
    return fu_prime_lut, H_u
end

"""
    tr0_subspace(m; modulus) -> Vector{Int}

The (m-1)-dimensional subspace Tr^{(0)} = {x ∈ GF(2^m) | Tr_m(x) = 0}, sorted.
Has 2^{m-1} elements.
"""
function tr0_subspace(m::Int; modulus::Int = primitive_polynomial(m))
    sort([x for x in 0:(1<<m)-1 if gf_trace(x, m; modulus = modulus) == 0])
end

"""
    sbox_inverse(s::SBox{N}) -> SBox{N}

Compositional inverse: result.lut[s.lut[x+1]+1] = x for all x.
"""
function sbox_inverse(s::SBox{N}) where {N}
    q = 1 << N
    inv_lut = Vector{Int}(undef, q)
    for x in 0:q-1
        inv_lut[s.lut[x+1]+1] = x
    end
    SBox{N}(inv_lut)
end

"""
    rdf_set(F::SBox{N}) -> Set{Int}

EA-invariant RD_F(4) = { |{b | #{x: F(x)+F(x+a)=b} = 4}| : a ∈ F*_{2^N} }.
Uses the DDT: DDT[a,b] = #{x : F(x⊕a)⊕F(x) = b}.
"""
function rdf_set(F::SBox{N}) where {N}
    q = 1 << N
    d = ddt(F)
    result = Set{Int}()
    for a in 1:q-1
        cnt = count(b -> d[a+1, b+1] == 4, 0:q-1)
        push!(result, cnt)
    end
    result
end

function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Li, Wang (2014): Constructing Differentially 4-Uniform Permutations")
    println(io, "over GF(2^{2m}) from Quadratic APN Permutations over GF(2^{2m+1})")
    println(io, "Designs, Codes and Cryptography 72:249–264")
    println(io, "Reproduced: $(Dates.today())")
    println(io, "=" ^ 72)
end

