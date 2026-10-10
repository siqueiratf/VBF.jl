# Shared utilities for Zha, Hu, Sun (2014)
# Paper: Zhengbang Zha, Lei Hu, Siwei Sun (2014),
#        "Constructing new differentially 4-uniform permutations from the inverse function",
#        Finite Fields and Their Applications, 25, 64–71
#
# VBF API used: gf_pow, gf_inv, gf_mul, gf_trace, gf_relative_trace,
#               in_subfield, subfield_elements, primitive_polynomial,
#               SBox, print_banner

using VBF

function print_header(io::IO = stdout)
    print_banner(io,
        "Zha, Hu, Sun (2014): Constructing new differentially 4-uniform",
        "permutations from the inverse function",
        "Finite Fields Appl. 25 (2014), 64–71")
end

# 0^{-1} = 0 convention throughout the paper
const safe_inv = gf_inv_zero_safe

"""
    find_omega(N; modulus) -> Int

Primitive cube root of unity ω in F_{2^N}. Requires 3 | (2^N − 1).
Returns ω = α^{(2^N−1)/3} where α is a verified primitive field element.
"""
function find_omega(N::Int; modulus::Int = primitive_polynomial(N))
    order = (1 << N) - 1
    @assert order % 3 == 0 "3 must divide 2^N - 1 for cube roots to exist"
    gf_pow(gf_primitive_element(N; modulus), order ÷ 3, N; modulus)
end

"""
    find_t_construction1(s, n; modulus) -> Int

Find t ∈ F_q* with t³ = 1 (primitive cube root of unity) for Construction 1.
When s is even, ω ∈ F_q since 3 | (2^s − 1).
"""
function find_t_construction1(s::Int, n::Int; modulus::Int = primitive_polynomial(s * n))
    N = s * n
    ω = find_omega(N; modulus)
    @assert in_subfield(ω, s, N; modulus) "ω must be in F_{2^s}"
    ω
end

"""
    construction1_lut(s, n, t; modulus) -> Vector{Int}

Build LUT for Construction 1 (Eq. 3):
  f(x) = x^{-1} + t  if x ∈ F_q   (x^q = x)
  f(x) = x^{-1}      if x ∉ F_q
where q = 2^s, t ∈ F_q*.
"""
function construction1_lut(s::Int, n::Int, t::Int;
                           modulus::Int = primitive_polynomial(s * n))
    N = s * n
    field_size = 1 << N
    lut = Vector{Int}(undef, field_size)
    for x in 0:(field_size - 1)
        inv_x = safe_inv(x, N; modulus)
        if in_subfield(x, s, N; modulus)
            lut[x + 1] = inv_x ⊻ t
        else
            lut[x + 1] = inv_x
        end
    end
    lut
end

"""
    find_t1_construction2(s, N; modulus) -> Int

Find t₁ ∈ F_q* with Tr(t₁^{-1}) = 1 for Construction 2.
"""
function find_t1_construction2(s::Int, N::Int; modulus::Int = primitive_polynomial(N))
    for x in subfield_elements(N, s; modulus)
        x == 0 && continue
        inv_x = safe_inv(x, N; modulus)
        if gf_trace(inv_x, N; modulus) == 1
            return x
        end
    end
    error("No t₁ ∈ F_q* with Tr(t₁⁻¹) = 1 found")
end

"""
    construction2_lut(s, n, t1, t2; modulus) -> Vector{Int}

Build LUT for Construction 2 (Eq. 8):
  f(x) = t₁·x^{-1} + t₂  if x ∈ F_q   (x^q = x)
  f(x) = x^{-1}           if x ∉ F_q
where q = 2^s, t₁,t₂ ∈ F_q, Tr(t₁^{-1}) = 1.
"""
function construction2_lut(s::Int, n::Int, t1::Int, t2::Int;
                           modulus::Int = primitive_polynomial(s * n))
    N = s * n
    field_size = 1 << N
    lut = Vector{Int}(undef, field_size)
    for x in 0:(field_size - 1)
        if in_subfield(x, s, N; modulus)
            lut[x + 1] = gf_mul(t1, safe_inv(x, N; modulus), N; modulus) ⊻ t2
        else
            lut[x + 1] = safe_inv(x, N; modulus)
        end
    end
    lut
end

"""
    construction3_lut(s, n, t1, t2; modulus) -> Vector{Int}

Build LUT for Construction 3 (Theorem 6):
  f(x) = (x + t₂)^{-1}   if x ∈ S = {x : x^q + x = t₁}
  f(x) = x^{-1}           if x ∉ S
where t₁ ∈ F_{q^n}* with Tr_s^{sn}(t₁) = 0, t₂ ∈ F_q*.
"""
function construction3_lut(s::Int, n::Int, t1::Int, t2::Int;
                           modulus::Int = primitive_polynomial(s * n))
    N = s * n
    field_size = 1 << N
    S = build_affine_subspace(s, n, t1; modulus)
    s_set = Set(S)
    lut = Vector{Int}(undef, field_size)
    for x in 0:(field_size - 1)
        if x ∈ s_set
            lut[x + 1] = safe_inv(x ⊻ t2, N; modulus)
        else
            lut[x + 1] = safe_inv(x, N; modulus)
        end
    end
    lut
end

"""
    build_affine_subspace(s, n, t1; modulus) -> Vector{Int}

S = { x ∈ F_{q^n} : x^q + x = t₁ }.
Non-empty iff Tr_s^{sn}(t₁) = 0.
"""
function build_affine_subspace(s::Int, n::Int, t1::Int;
                               modulus::Int = primitive_polynomial(s * n))
    N = s * n
    q = 1 << s
    field_size = 1 << N
    S = Int[]
    for x in 0:(field_size - 1)
        xq = gf_pow(x, q, N; modulus)
        if (xq ⊻ x) == t1
            push!(S, x)
        end
    end
    S
end

"""
    find_t1_construction3(s, n; modulus) -> Int

Find t₁ ∈ F_{q^n}* with Tr_s^{sn}(t₁) = 0 and S non-empty.
"""
function find_t1_construction3(s::Int, n::Int; modulus::Int = primitive_polynomial(s * n))
    N = s * n
    for t1 in 1:((1 << N) - 1)
        if gf_relative_trace(t1, N, s; modulus) == 0
            S = build_affine_subspace(s, n, t1; modulus)
            if !isempty(S)
                return t1
            end
        end
    end
    error("No valid t₁ found")
end

# Use VBF core nonlinearity
const compute_nonlinearity = nonlinearity

# NL lower bound from Proposition 2/4/6: NL ≥ 2^{sn-1} - 2^{sn/2} - 2^s
function nl_lower_bound(s::Int, n::Int)
    N = s * n
    (1 << (N - 1)) - (1 << (N ÷ 2)) - (1 << s)
end
