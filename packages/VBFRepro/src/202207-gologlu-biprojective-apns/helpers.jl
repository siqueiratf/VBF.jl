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

function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Gologlu (2022): Biprojective Almost Perfect Nonlinear Functions")
    println(io, "IEEE Transactions on Information Theory")
    println(io, "=" ^ 72)
    println(io, "Julia $(VERSION)  |  $(Dates.now())")
    println(io, "=" ^ 72)
end

"""
    drop_trailing_zeros(v) -> Vector

Return v with trailing zeros removed (for compact NF display).
"""
function drop_trailing_zeros(v::AbstractVector{<:Integer})
    i = findlast(!iszero, v)
    i === nothing ? Int[] : collect(v[1:i])
end
