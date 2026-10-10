"""
    biprojective_sbox(m, qi, coeff_f, rj, coeff_g; modulus) -> SBox{2m}

Evaluate a (q,r)-biprojective function on GF(2^m)×GF(2^m) as an SBox{2m}.
- `qi`: exponent index so that q = 2^(qi mod m)
- `rj`: exponent index so that r = 2^(rj mod m)
- `coeff_f = (a0,b0,c0,d0)`: coefficients of f(x,y) = a0*x^{q+1} + b0*x^q*y + c0*x*y^q + d0*y^{q+1}
- `coeff_g = (a1,b1,c1,d1)`: coefficients of g(x,y) analogously with r

This evaluator does not assert APN; that property depends on the coefficients.
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
    2<=m<=8 || throw(ArgumentError("half-dimension must be 2:8"))
    all(c->0<=c<(1<<m),(coeff_f...,coeff_g...)) || throw(ArgumentError("coefficients outside the field"))
    gf_primitive_element(m;modulus)
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
