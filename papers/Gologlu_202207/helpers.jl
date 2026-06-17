# Implements shared helpers for the Gologlu (2022) reproduction.
# Paper: Gologlu, F. (2022), "Biprojective Almost Perfect Nonlinear Functions",
#        IEEE Transactions on Information Theory
# Section: General — biprojective SBox constructor + print helpers
#
# Pseudocode (biprojective_sbox):
#   For each (x,y) in GF(2^m)×GF(2^m):
#     1. f(x,y) = a0*x^{q+1} + b0*x^q*y + c0*x*y^q + d0*y^{q+1}  (q=2^qi mod m)
#     2. g(x,y) = a1*x^{r+1} + b1*x^r*y + c1*x*y^r + d1*y^{r+1}  (r=2^rj mod m)
#     3. pack as (x|(y<<m)) → (f|(g<<m))
# VBF API used: gf_pow, gf_mul, primitive_polynomial, SBox

using VBF
using Dates

"""
    biprojective_sbox(m, qi, coeff_f, rj, coeff_g; modulus) -> SBox{2m}

Build a (q,r)-biprojective APN function on GF(2^m)×GF(2^m) as an SBox{2m}.
- `qi`: exponent index so that q = 2^(qi mod m)
- `rj`: exponent index so that r = 2^(rj mod m)
- `coeff_f = (a0,b0,c0,d0)`: coefficients of f(x,y) = a0*x^{q+1} + b0*x^q*y + c0*x*y^q + d0*y^{q+1}
- `coeff_g = (a1,b1,c1,d1)`: coefficients of g(x,y) analogously with r

Input is packed as x|(y<<m), output as f|(g<<m).
"""
function biprojective_sbox(
    m::Int,
    qi::Int,
    coeff_f::NTuple{4,Int},
    rj::Int,
    coeff_g::NTuple{4,Int};
    modulus::Int = primitive_polynomial(m),
)
    q = 1 << mod(qi, m)
    r = 1 << mod(rj, m)
    len = 1 << m
    a0, b0, c0, d0 = coeff_f
    a1, b1, c1, d1 = coeff_g
    mod_ = modulus
    n = m  # half-dimension

    mul(a, b) = gf_mul(a, b, n; modulus = mod_)
    pow(a, e) = gf_pow(a, e, n; modulus = mod_)

    lut = Vector{Int}(undef, 1 << (2n))
    for x = 0:(len-1)
        for y = 0:(len-1)
            xq = pow(x, q)
            yq = pow(y, q)
            fval = mul(a0, mul(x, xq)) ⊻
                   mul(b0, mul(xq, y)) ⊻
                   mul(c0, mul(x, yq)) ⊻
                   mul(d0, mul(y, yq))
            xr = pow(x, r)
            yr = pow(y, r)
            gval = mul(a1, mul(x, xr)) ⊻
                   mul(b1, mul(xr, y)) ⊻
                   mul(c1, mul(x, yr)) ⊻
                   mul(d1, mul(y, yr))
            lut[(x | (y << n)) + 1] = fval | (gval << n)
        end
    end
    SBox{2n}(lut)
end

function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Gologlu (2022): Biprojective Almost Perfect Nonlinear Functions")
    println(io, "IEEE Transactions on Information Theory")
    println(io, "=" ^ 72)
    println(io, "Julia $(VERSION)  |  $(Dates.now())")
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
    drop_trailing_zeros(v) -> Vector

Return v with trailing zeros removed (for compact NF display).
"""
function drop_trailing_zeros(v::AbstractVector{<:Integer})
    i = findlast(!iszero, v)
    i === nothing ? Int[] : collect(v[1:i])
end
