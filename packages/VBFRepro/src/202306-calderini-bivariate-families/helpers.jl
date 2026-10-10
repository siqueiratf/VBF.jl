# Implements shared helpers for Calderini, Li, Villa (2023) reproduction.
# Paper: Calderini, Li, Villa (2023), "Extending two families of bivariate APN functions",
#        Finite Fields and Their Applications.
# Section: General — field helpers, bivariate LUT builders
#
# Pseudocode (family_f1_lut):
#   For each (x,y) in F_{2^m} x F_{2^m}:
#     1. f(x,y) = x^{q+1} + x*y^q + alpha*y^{q+1}
#     2. g(x,y) = x^{q2+1} + alpha*x^{q2}*y + (1+alpha)^q*x*y^{q2} + alpha*y^{q2+1}
#     3. pack as z=x|(y<<m) -> f|(g<<m)
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox, differential_uniformity

using VBF
using Dates

function has_no_root_projective(m::Int, k::Int, alpha::Int;
                                modulus::Int = primitive_polynomial(m))
    q = 1 << k
    for x in 1:(1 << m) - 1
        xq = gf_pow(x, q, m; modulus = modulus)
        val = gf_mul(x, xq, m; modulus = modulus) ⊻ x ⊻ alpha
        val == 0 && return false
    end
    return true
end

function find_alpha(m::Int, k::Int; modulus::Int = primitive_polynomial(m))
    for alpha in 1:(1 << m) - 1
        has_no_root_projective(m, k, alpha; modulus = modulus) && return alpha
    end
    return nothing
end

function family_f1_lut(m::Int, k::Int, alpha::Int;
                       modulus::Int = primitive_polynomial(m))
    q  = 1 << k
    q2 = 1 << (2 * k)
    len = 1 << m
    mul_(a, b) = gf_mul(a, b, m; modulus = modulus)
    pow_(a, e) = gf_pow(a, e, m; modulus = modulus)
    one_plus_alpha_q = pow_(1 ⊻ alpha, q)

    lut = Vector{Int}(undef, 1 << (2 * m))
    for x in 0:len-1
        for y in 0:len-1
            xq   = pow_(x, q);    yq  = pow_(y, q)
            xq1  = mul_(x, xq);   yq1 = mul_(y, yq)

            f = xq1 ⊻ mul_(x, yq) ⊻ mul_(alpha, yq1)

            xq2  = pow_(x, q2);   yq2  = pow_(y, q2)
            xq21 = mul_(x, xq2);  yq21 = mul_(y, yq2)

            g = xq21 ⊻
                mul_(alpha, mul_(xq2, y)) ⊻
                mul_(one_plus_alpha_q, mul_(x, yq2)) ⊻
                mul_(alpha, yq21)

            lut[(x | (y << m)) + 1] = f | (g << m)
        end
    end
    SBox{2 * m}(lut)
end

function family_f2_lut(m::Int, alpha::Int;
                       modulus::Int = primitive_polynomial(m))
    len = 1 << m
    mul_(a, b) = gf_mul(a, b, m; modulus = modulus)
    pow_(a, e) = gf_pow(a, e, m; modulus = modulus)
    one_plus_alpha_sq = pow_(1 ⊻ alpha, 2)

    lut = Vector{Int}(undef, 1 << (2 * m))
    for x in 0:len-1
        for y in 0:len-1
            x2 = mul_(x, x); x3 = mul_(x2, x)
            x4 = mul_(x2, x2); x5 = mul_(x4, x)
            y2 = mul_(y, y); y3 = mul_(y2, y)
            y4 = mul_(y2, y2); y5 = mul_(y4, y)

            f = x3 ⊻ mul_(x, y) ⊻ mul_(x, y2) ⊻ mul_(alpha, y3)

            g = x5 ⊻
                mul_(x, y) ⊻
                mul_(alpha, mul_(x2, y2)) ⊻
                mul_(alpha, mul_(x4, y)) ⊻
                mul_(one_plus_alpha_sq, mul_(x, y4)) ⊻
                mul_(alpha, y5)

            lut[(x | (y << m)) + 1] = f | (g << m)
        end
    end
    SBox{2 * m}(lut)
end

# Strip trailing zero counts from a subspace-count signature so it can be
# compared against the paper's trimmed N_F vectors (e.g. [1365, 100100, 140664]).
function trim_signature(sig::Vector{Int})
    last_nz = findlast(!=(0), sig)
    last_nz === nothing ? Int[] : sig[1:last_nz]
end

function paper_banner(io::IO = stdout)
    print_banner(
        io,
        "Calderini, Li, Villa (2023)",
        "Extending two families of bivariate APN functions",
        "Finite Fields and Their Applications",
        "Julia $(VERSION)  |  $(Dates.today())",
    )
end
