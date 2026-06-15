# Implements shared helpers for the Budaghyan–Helleseth–Kaleyski (2020) reproduction.
# Paper: Budaghyan, Helleseth, Kaleyski (2020), "A New Family of APN Quadrinomials",
#        IEEE Trans. Inf. Theory 66(11):7081–7087
# Section: General — field utilities, quadrinomial builder, report formatting
#
# Pseudocode:
#   1. β ← α^((2^n−1)/3) in GF(2^n), the primitive element of GF(2^2)
#   2. C(x) ← x^3 + β·(x^(2^i+1))^(2^k) + β²·x^(3·2^m) + (x^(2^(i+m)+2^m))^(2^k)
#   3. y ∈ β·GF(2^m) iff y^(2^m) = β·y  (for n=2m, m odd, 3∤m)
# VBF API used: gf_pow, gf_mul, primitive_polynomial, SBox

using VBF

# ── Report formatting ────────────────────────────────────────────────────────

function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Budaghyan, Helleseth, Kaleyski (2020): A New Family of APN Quadrinomials")
    println(io, "IEEE Trans. Inf. Theory 66(11):7081–7087, November 2020")
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

# ── GF(2^n) field helpers ────────────────────────────────────────────────────

"""
    beta_in_gfn(n) -> (β, β²)

Returns the primitive element β of GF(2^2) embedded in GF(2^n), together with
β² = β^{-1}. Requires 3 ∣ (2^n−1), i.e., n even. Under the canonical primitive
polynomial, β = α^((2^n−1)/3) where α = 2 is the field generator.

Satisfies: β^3 = 1, β ≠ 1, β ∉ GF(2^m) for n = 2m with m odd.
"""
function beta_in_gfn(n::Int; modulus::Int = primitive_polynomial(n))
    q = (1 << n) - 1
    q % 3 == 0 || error("3 ∤ 2^n−1 for n=$n; n must be even")
    b  = gf_pow(2, q ÷ 3, n; modulus)
    b2 = gf_mul(b, b, n; modulus)
    return b, b2
end

"""
    in_beta_coset(y, β, n, m; modulus) -> Bool

Checks whether y ∈ β·GF(2^m). For n = 2m with m odd and 3 ∤ m, this holds iff
y^(2^m) = β·y (Frobenius criterion via the GF(2^m) minimal polynomial of β).
"""
function in_beta_coset(y::Int, β::Int, n::Int, m::Int; modulus::Int = primitive_polynomial(n))
    gf_pow(y, 1 << m, n; modulus) == gf_mul(β, y, n; modulus)
end

# ── Quadrinomial builder ─────────────────────────────────────────────────────

"""
    build_ci_sbox(n, i, k=0) -> SBox{n}

Builds the S-box for the F13 quadrinomial

    C(x) = x^3 + β·(x^(2^i+1))^(2^k) + β²·x^(3·2^m) + (x^(2^(i+m)+2^m))^(2^k)

with (a, b, c) = (β, β², 1) over GF(2^n), n = 2m. Exponents are reduced mod (2^n−1).
"""
function build_ci_sbox(n::Int, i::Int, k::Int = 0; modulus::Int = primitive_polynomial(n))
    m  = n ÷ 2
    q  = (1 << n) - 1
    b, b2 = beta_in_gfn(n; modulus)
    e2 = (Int64(2^i + 1) * Int64(1 << k)) % q
    e3 = (Int64(3)       * Int64(1 << m)) % q
    e4 = (Int64(2^(i+m) + 2^m) * Int64(1 << k)) % q
    SBox{n}([
        gf_pow(x, 3,  n; modulus) ⊻
        gf_mul(b,  gf_pow(x, e2, n; modulus), n; modulus) ⊻
        gf_mul(b2, gf_pow(x, e3, n; modulus), n; modulus) ⊻
        gf_pow(x, e4, n; modulus)
        for x in 0:(1 << n) - 1
    ])
end

"""
    system_Ei_trivial(n, i) -> Bool

Returns true iff the system E_i (Proposition 1, Eq. 2) has only trivial solutions
x ∈ GF(2), i.e., no (a ≠ 0, x ∉ GF(2)) pair satisfies both conditions:
    a^3·(x^2+x) ∈ β·GF(2^m)  and  a^(2^i+1)·(x^(2^i)+x) ∈ β·GF(2^m).

Exhaustive over all a ∈ GF(2^n)*, x ∈ GF(2^n) \\ GF(2).
"""
function system_Ei_trivial(n::Int, i::Int; modulus::Int = primitive_polynomial(n))
    m  = n ÷ 2
    q  = (1 << n) - 1
    b, _ = beta_in_gfn(n; modulus)
    check(y) = in_beta_coset(y, b, n, m; modulus)
    ei1 = (1 << i) + 1  # exponent 2^i + 1
    for a in 1:q
        a3  = gf_pow(a, 3, n; modulus)
        ai1 = gf_pow(a, ei1, n; modulus)
        for x in 2:q  # skip x ∈ {0, 1} = GF(2)
            A = gf_mul(a3,  gf_pow(x, 2, n; modulus) ⊻ x, n; modulus)
            B = gf_mul(ai1, gf_pow(x, 1 << i, n; modulus) ⊻ x, n; modulus)
            check(A) && check(B) && return false  # non-trivial solution found
        end
    end
    true
end
