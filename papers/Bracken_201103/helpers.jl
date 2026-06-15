# Implements paper-local helpers for the Bracken–Byrne–Markin–McGuire (2011) reproduction.
# Paper: Bracken, Byrne, Markin, McGuire (2011), "A Few More Quadratic APN Functions",
#        Cryptography and Communications 3:43–53
# Section: General — field utilities, quadrinomial builder, report formatting
#
# Pseudocode:
#   1. n = 3k; u primitive in GF(2^n); v,w ∈ GF(2^k) with vw ≠ 1
#   2. 2^{-k} ≡ 2^{2k} (mod 2^n−1) since n=3k
#   3. F(x) = u^{2^k} x^{2^{2k}+2^{k+s}}
#           + u x^{2^s+1}
#           + v x^{2^{2k}+1}
#           + w u^{2^k+1} x^{2^{k+s}+2^s}
# VBF API used: gf_mul, gf_pow, primitive_polynomial, SBox

using VBF


function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Bracken, Byrne, Markin, McGuire (2011): A Few More Quadratic APN Functions")
    println(io, "Cryptography and Communications 3:43–53, 2011")
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
    bracken_lut(k, s, u, v, w; modulus) -> Vector{Int}

LUT for the Bracken–Byrne–Markin–McGuire quadrinomial family over GF(2^(3k)):

    F(x) = u^{2^k} x^{2^{2k}+2^{k+s}}
          + u x^{2^s+1}
          + v x^{2^{2k}+1}
          + w u^{2^k+1} x^{2^{k+s}+2^s}

Conditions for APN (Theorem 1): (s,3k)=1, (3,k)=1, 3∣(k+s), u primitive
in GF(2^n), v,w ∈ GF(2^k) with vw≠1.

Subfamilies: v=w=0 → Family 1; v=0,w≠0 → Family 7; v≠0,w=0 → Family 8W;
             v≠0,w≠0,vw≠1 → Family 8 (new).

The exponent 2^{-k} mod (2^n−1) equals 2^{2k} when n=3k.
"""
function bracken_lut(k::Int, s::Int, u::Int, v::Int, w::Int;
                     modulus::Int = primitive_polynomial(3k))::Vector{Int}
    n  = 3k
    e1 = (1 << (2k)) + (1 << (k + s))    # 2^{2k}+2^{k+s}
    e2 = (1 << s) + 1                      # 2^s+1
    e3 = (1 << (2k)) + 1                   # 2^{2k}+1
    e4 = (1 << (k + s)) + (1 << s)        # 2^{k+s}+2^s
    c1 = gf_pow(u, 1 << k, n; modulus)           # u^{2^k}
    c2 = u                                         # u
    c3 = v                                         # v
    c4 = gf_mul(w, gf_pow(u, (1 << k) + 1, n; modulus), n; modulus)  # w·u^{2^k+1}
    [gf_mul(c1, gf_pow(x, e1, n; modulus), n; modulus) ⊻
     gf_mul(c2, gf_pow(x, e2, n; modulus), n; modulus) ⊻
     gf_mul(c3, gf_pow(x, e3, n; modulus), n; modulus) ⊻
     gf_mul(c4, gf_pow(x, e4, n; modulus), n; modulus)
     for x in 0:(1<<n)-1]
end


"""
    gf_subfield_elem(n, k, i; modulus) -> Int

The i-th nonzero element of GF(2^k) embedded in GF(2^n) (requires k ∣ n), i.e.
u^(i·(2^n−1)/(2^k−1)) where u = 2 is the primitive element. Index i ∈ 0..2^k−2.
"""
function gf_subfield_elem(n::Int, k::Int, i::Int;
                           modulus::Int = primitive_polynomial(n))::Int
    norm = ((1 << n) - 1) ÷ ((1 << k) - 1)
    gf_pow(2, (i * norm) % ((1 << n) - 1), n; modulus)
end
