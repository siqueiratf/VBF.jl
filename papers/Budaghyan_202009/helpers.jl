# Implements shared helpers for the Budaghyan et al. (2020) reproduction.
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: General — shared utilities
#
# Pseudocode:
#   compute_m_F: iterate β over F₂ⁿ, compute min pi_multiset key
#   lower_bound_distance: ceil(m_F/3) + 1
#   is_cube_gf: check c^((2^N-1)/gcd(3,2^N-1)) == 1
# VBF API used: SBox, pi_multiset, sorted_pairs, gf_monomial_lut, gf_pow

using VBF

function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Budaghyan, Carlet, Helleseth, Kaleyski (2020)")
    println(io, "On the Distance Between APN Functions")
    println(io, "IEEE Transactions on Information Theory")
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
    gold_x3(N::Int) -> SBox

Gold function x^3 over GF(2^N) using the default primitive polynomial.
"""
function gold_x3(N::Int)
    SBox{N}(gf_monomial_lut(N, 3))
end

"""
    apply_modifications(F, U, V) -> SBox

Build G from F by XOR-shifting: G(U[i]) = F(U[i]) ⊕ V[i], G(x) = F(x) otherwise.
U and V are 0-based field elements stored in Julia 1-based arrays.
"""
function apply_modifications(F::SBox{N,T}, U::AbstractVector{<:Integer}, V::AbstractVector{<:Integer}) where {N,T}
    lut = copy(F.lut)
    for (u, v) in zip(U, V)
        lut[Int(u)+1] = lut[Int(u)+1] ⊻ T(v)
    end
    SBox{N,T}(lut)
end

"""
    compute_m_F(F) -> Int

m_F = min_{β,b ∈ F₂ⁿ} |Π_F^β(b)|: the minimum count over all shifts β and all
output values b. Iterates all β and uses the smallest key from pi_multiset.
"""
function compute_m_F(F::SBox{N,T}) where {N,T}
    n = 1 << N
    m = typemax(Int)
    for β = 0:(n-1)
        sp = pi_multiset(F, β)
        pairs = sorted_pairs(sp)
        isempty(pairs) && continue
        k = pairs[1].first
        k < m && (m = k)
    end
    m
end

"""
    lower_bound_distance(m_F) -> Int

Lower bound d(F, G) ≥ ⌈m_F/3⌉ + 1 from Corollary 2.
"""
lower_bound_distance(m_F::Int) = (m_F + 2) ÷ 3 + 1

"""
    is_cube_gf(N, c) -> Bool

True iff c is a perfect cube in GF(2^N). 0 is always a cube.
For N odd: every element is a cube (gcd(3, 2^N-1) = 1).
For N even: check c^((2^N-1)/3) == 1.
"""
function is_cube_gf(N::Int, c::Integer; modulus::Integer = primitive_polynomial(N))
    Int(c) == 0 && return true
    ord = (1 << N) - 1  # |GF(2^N)*|
    g = gcd(3, ord)
    g == 1 && return true  # N odd: all elements are cubes
    gf_pow(Int(c), ord ÷ g, N; modulus = Int(modulus)) == 1
end
