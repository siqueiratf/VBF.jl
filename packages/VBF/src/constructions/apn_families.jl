"""
The known infinite families of APN **power** functions `F(x) = x^d` over
`GF(2ⁿ)` — the classical list (see Budaghyan, *Construction and Analysis of
Cryptographic Functions*, 2014, and the original sources):

| family   | exponent `d`                                  | condition          |
|----------|-----------------------------------------------|--------------------|
| Gold     | `2ᵏ + 1`                                       | `gcd(k, n) = 1`    |
| Kasami   | `2^{2k} − 2ᵏ + 1`                              | `gcd(k, n) = 1`    |
| Welch    | `2ᵗ + 3`                                       | `n = 2t+1` (odd)   |
| Niho     | `2ᵗ + 2^{t/2} − 1` (t even) /                  | `n = 2t+1` (odd)   |
|          | `2ᵗ + 2^{(3t+1)/2} − 1` (t odd)               |                    |
| inverse  | `2ⁿ − 2`                                       | `n` odd            |
| Dobbertin| `2^{4k} + 2^{3k} + 2^{2k} + 2ᵏ − 1`            | `n = 5k`           |

Each constructor returns the monomial `SBox{n}` (an APN function under its stated
condition; only Gold is quadratic — the others have higher algebraic degree).
The field representation is a basis choice (`modulus`); APN-ness is independent of
it.
"""

function gold_apn(n::Integer, k::Integer = 1; modulus::Integer = primitive_polynomial(n))
    gcd(Int(k), Int(n)) == 1 || throw(ArgumentError("gold_apn: need gcd(k, n) = 1, got k=$k, n=$n"))
    SBox{Int(n)}(gf_monomial_lut(Int(n), (1 << Int(k)) + 1; modulus = Int(modulus)))
end

function kasami_apn(n::Integer, k::Integer = 2; modulus::Integer = primitive_polynomial(n))
    gcd(Int(k), Int(n)) == 1 || throw(ArgumentError("kasami_apn: need gcd(k, n) = 1, got k=$k, n=$n"))
    d = (1 << (2 * Int(k))) - (1 << Int(k)) + 1
    SBox{Int(n)}(gf_monomial_lut(Int(n), d; modulus = Int(modulus)))
end

function welch_apn(n::Integer; modulus::Integer = primitive_polynomial(n))
    isodd(Int(n)) || throw(ArgumentError("welch_apn: n must be odd, got $n"))
    t = Int(n) ÷ 2
    SBox{Int(n)}(gf_monomial_lut(Int(n), (1 << t) + 3; modulus = Int(modulus)))
end

function niho_apn(n::Integer; modulus::Integer = primitive_polynomial(n))
    isodd(Int(n)) || throw(ArgumentError("niho_apn: n must be odd, got $n"))
    t = Int(n) ÷ 2
    d = iseven(t) ? (1 << t) + (1 << (t ÷ 2)) - 1 :
                    (1 << t) + (1 << ((3t + 1) ÷ 2)) - 1
    SBox{Int(n)}(gf_monomial_lut(Int(n), d; modulus = Int(modulus)))
end

function inverse_apn(n::Integer; modulus::Integer = primitive_polynomial(n))
    isodd(Int(n)) || throw(ArgumentError("inverse_apn: APN only for odd n, got $n"))
    SBox{Int(n)}(gf_monomial_lut(Int(n), (1 << Int(n)) - 2; modulus = Int(modulus)))
end

function dobbertin_apn(n::Integer; modulus::Integer = primitive_polynomial(n))
    Int(n) % 5 == 0 || throw(ArgumentError("dobbertin_apn: n must be divisible by 5, got $n"))
    k = Int(n) ÷ 5
    d = (1 << (4k)) + (1 << (3k)) + (1 << (2k)) + (1 << k) - 1
    SBox{Int(n)}(gf_monomial_lut(Int(n), d; modulus = Int(modulus)))
end

"""
    known_apn_monomials(n; modulus=primitive_polynomial(n))
        -> Vector{Tuple{Symbol, SBox{n}}}

The APN power functions on `GF(2ⁿ)` from the classical families that apply at
dimension `n` (Gold `x³`, Kasami at the smallest valid `k`, and — for odd `n` —
Welch / Niho / inverse, plus Dobbertin when `5 ∣ n`), tagged by family name.
"""
function known_apn_monomials(n::Integer; modulus::Integer = primitive_polynomial(n))
    nn = Int(n)
    out = Tuple{Symbol, SBox{nn}}[]
    push!(out, (:gold, gold_apn(nn, 1; modulus = modulus)))
    k = 2
    while k < nn && gcd(k, nn) != 1
        k += 1
    end
    k < nn && push!(out, (:kasami, kasami_apn(nn, k; modulus = modulus)))
    if isodd(nn)
        push!(out, (:welch, welch_apn(nn; modulus = modulus)))
        push!(out, (:niho, niho_apn(nn; modulus = modulus)))
        push!(out, (:inverse, inverse_apn(nn; modulus = modulus)))
    end
    nn % 5 == 0 && push!(out, (:dobbertin, dobbertin_apn(nn; modulus = modulus)))
    out
end
