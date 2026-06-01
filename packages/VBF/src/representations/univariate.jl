"""
Univariate-polynomial representation of a vectorial Boolean function.

A function `F: GF(2ⁿ) → GF(2ⁿ)` has a unique univariate polynomial form
`F(X) = Σ cₑ Xᵉ` with `cₑ ∈ GF(2ⁿ)`. This module parses such polynomials from
the string syntax used by the upstream catalogs (SageMath / Magma:
`X` / `x` the variable, `ksi` / `g` / `a` the field generator, `**` or `^` for
powers, `+`/`*`, parentheses) and evaluates them to a lookup table over
`GF(2ⁿ)` modulo a given irreducible.

Grammar (recursive descent, no explicit AST):

    polynomial = sum  ('+' sum)*
    sum        = product  ('+' product)*
    product    = factor  ('*' factor)*
    factor     = X | ksi | INTEGER | ksi POW INTEGER | X POW INTEGER
    POW        = '**' | '^'

There is no subtraction (over F₂ it equals addition). Integer literals are
interpreted in F₂ (even ⇒ 0, odd ⇒ 1). For the common *flat* case (a sum of
monomials with no parentheses), [`polynomial_terms`] + [`terms_to_lut`] parse
once and evaluate at all 2ⁿ points sharing a [`monomial_power_table`], which is
far faster than re-parsing per point.
"""

# ----- tokenizer ------------------------------------------------------------

function _tokenize_polynomial(s::AbstractString)
    out = String[]
    i = 1
    n = lastindex(s)
    while i ≤ n
        c = s[i]
        if isspace(c)
            i = nextind(s, i)
        elseif c == '+'
            push!(out, "+")
            i = nextind(s, i)
        elseif c == '*' && i + 1 ≤ n && s[i+1] == '*'
            push!(out, "**")
            i += 2
        elseif c == '*'
            push!(out, "*")
            i = nextind(s, i)
        elseif c == '^'
            push!(out, "**")
            i = nextind(s, i)            # normalise ^ to **
        elseif c == '('
            push!(out, "(")
            i = nextind(s, i)
        elseif c == ')'
            push!(out, ")")
            i = nextind(s, i)
        elseif c == 'X' || c == 'x'
            push!(out, "X")
            i = nextind(s, i)
        elseif (c == 'k' || c == 'K') &&
               i + 2 ≤ n &&
               lowercase(s[i:(i+2)]) == "ksi"
            push!(out, "ksi")
            i += 3
        elseif c == 'g'
            # SageMath's `field.gen()` is the same primitive element as `ksi`.
            push!(out, "ksi")
            i = nextind(s, i)
        elseif c == 'a'
            # Magma / Simon-Berg: `a` is the generator, the same primitive
            # element as `ksi`.
            push!(out, "ksi")
            i = nextind(s, i)
        elseif isdigit(c)
            j = i
            while j ≤ n && isdigit(s[j])
                
                j = nextind(s, j)
            end
            push!(out, s[i:prevind(s, j)])
            i = j
        else
            error(
                "unexpected character $(repr(c)) at position $i in $(repr(s))",
            )
        end
    end
    out
end

# ----- evaluator ------------------------------------------------------------

"""
    evaluate_polynomial(expr_str, x, n, modulus; ksi=2) -> Int

Value of `expr_str` (a polynomial in `X` and `ksi`) at the given `x` in
`GF(2ⁿ)` modulo `modulus`. `ksi` defaults to the field generator (the
integer `2`, i.e., the residue class of `x` under the modulus) — that is
SageMath's convention when the field is constructed from a primitive
polynomial.

Constants in the expression are interpreted in F₂: `0` drops the term,
`1` is the multiplicative identity. Any other integer literal that
appears as a standalone constant is reduced mod 2.
"""
function evaluate_polynomial(
    expr_str::AbstractString,
    x::Integer,
    n::Integer,
    modulus::Integer;
    ksi::Integer = 2,
)
    toks = _tokenize_polynomial(expr_str)
    pos = Ref(1)
    val = _parse_polynomial!(toks, pos, Int(x), Int(n), Int(modulus), Int(ksi))
    pos[] ≤ length(toks) && error(
        "polynomial parser: trailing tokens after expression at position $(pos[])",
    )
    val
end

# Sum of terms; stops at end-of-tokens or at a closing ')'.
function _parse_polynomial!(
    toks::Vector{String},
    pos::Ref{Int},
    x::Int,
    n::Int,
    modulus::Int,
    ksi::Int,
)
    result = 0
    while pos[] ≤ length(toks)
        tok = toks[pos[]]
        tok == ")" && break
        result ⊻= _parse_term!(toks, pos, x, n, modulus, ksi)
        if pos[] ≤ length(toks) && toks[pos[]] == "+"
            pos[] += 1
        else
            break
        end
    end
    result
end

# Product of factors; stops at '+' or ')' or end-of-tokens.
function _parse_term!(
    toks::Vector{String},
    pos::Ref{Int},
    x::Int,
    n::Int,
    modulus::Int,
    ksi::Int,
)
    coef = 1               # accumulated coefficient ∈ GF(2ⁿ)
    var_exp = 0            # accumulated exponent of X in this term
    saw_factor = false
    while pos[] ≤ length(toks)
        tok = toks[pos[]]
        if tok == "+" || tok == ")"
            break
        elseif tok == "*"
            pos[] += 1
        elseif tok == "("
            saw_factor = true
            pos[] += 1
            sub = _parse_polynomial!(toks, pos, x, n, modulus, ksi)
            pos[] ≤ length(toks) && toks[pos[]] == ")" ||
                error("polynomial parser: missing ')'")
            pos[] += 1
            coef = gf_mul(coef, sub, n; modulus = modulus)
        elseif tok == "X"
            saw_factor = true
            pos[] += 1
            var_exp += _maybe_read_pow!(toks, pos)
        elseif tok == "ksi"
            saw_factor = true
            pos[] += 1
            e = _maybe_read_pow!(toks, pos)
            coef = gf_mul(
                coef,
                gf_pow(ksi, e, n; modulus = modulus),
                n;
                modulus = modulus,
            )
        elseif occursin(r"^\d+$", tok)
            saw_factor = true
            pos[] += 1
            iseven(parse(Int, tok)) && (coef = 0)
        else
            error("unexpected token $(repr(tok)) at position $(pos[])")
        end
    end
    saw_factor || return 0
    coef == 0 && return 0
    gf_mul(coef, gf_pow(x, var_exp, n; modulus = modulus), n; modulus = modulus)
end

function _maybe_read_pow!(toks::Vector{String}, pos::Ref{Int})
    pos[] ≤ length(toks) || return 1
    toks[pos[]] == "**" || return 1
    pos[] += 1
    pos[] ≤ length(toks) ||
        error("polynomial parser: expected exponent after `**`")
    occursin(r"^\d+$", toks[pos[]]) || error(
        "polynomial parser: expected integer after `**`, got $(repr(toks[pos[]]))",
    )
    e = parse(Int, toks[pos[]])
    pos[] += 1
    e
end

"""
    polynomial_to_lut(expr_str, n, modulus; ksi=2) -> Vector{Int}

`length-2ⁿ` lookup table of `x ↦ p(x)` for the polynomial expression
`p` parsed from `expr_str`.
"""
function polynomial_to_lut(
    expr_str::AbstractString,
    n::Integer,
    modulus::Integer;
    ksi::Integer = 2,
)
    len = 1 << Int(n)
    out = Vector{Int}(undef, len)
    for x = 0:(len-1)
        out[x+1] = evaluate_polynomial(expr_str, x, n, modulus; ksi = ksi)
    end
    out
end

"""
    polynomial_terms(expr_str, n, modulus; ksi=2) -> Vector{Tuple{Int,Int}}

Parse a *flat* polynomial (sum of monomials `c · Xᵉ`; no parentheses) into
`(coefficient, exponent)` pairs — the coefficient an element of `GF(2ⁿ)`, the
exponent the power of `X`. Terms with a zero coefficient (an even integer
literal in F₂) are dropped. Throws on parenthesised sub-expressions; use
[`evaluate_polynomial`](@ref) for those.
"""
function polynomial_terms(
    expr_str::AbstractString,
    n::Integer,
    modulus::Integer;
    ksi::Integer = 2,
)
    toks = _tokenize_polynomial(expr_str)
    ("(" in toks || ")" in toks) && error(
        "polynomial_terms: parenthesised sub-expressions unsupported in $(repr(expr_str))",
    )
    terms = Tuple{Int,Int}[]
    nn = Int(n)
    mod = Int(modulus)
    k = Int(ksi)
    i = 1
    L = length(toks)
    while i ≤ L
        coef = 1
        vexp = 0
        saw = false
        while i ≤ L && toks[i] != "+"
            t = toks[i]
            if t == "*"
                i += 1
            elseif t == "X"
                saw = true
                i += 1
                if i ≤ L && toks[i] == "**"
                    vexp += parse(Int, toks[i+1])
                    i += 2
                else
                    vexp += 1
                end
            elseif t == "ksi"
                saw = true
                i += 1
                e = 1
                if i ≤ L && toks[i] == "**"
                    e = parse(Int, toks[i+1])
                    i += 2
                end
                coef = gf_mul(
                    coef,
                    gf_pow(k, e, nn; modulus = mod),
                    nn;
                    modulus = mod,
                )
            elseif occursin(r"^\d+$", t)
                saw = true
                i += 1
                iseven(parse(Int, t)) && (coef = 0)
            else
                error(
                    "polynomial_terms: unexpected token $(repr(t)) in $(repr(expr_str))",
                )
            end
        end
        i ≤ L && toks[i] == "+" && (i += 1)
        (saw && coef != 0) && push!(terms, (coef, vexp))
    end
    terms
end

"""
    monomial_power_table(n, modulus) -> Vector{Vector{Int}}

`tab[x+1][e+1] = xᵉ` in `GF(2ⁿ)` for `x, e ∈ 0:2ⁿ-1` (with `0⁰ = 1`).
Built once and shared across all polynomials so that [`terms_to_lut`](@ref)
is a table lookup plus one `gf_mul` per term.
"""
function monomial_power_table(n::Integer, modulus::Integer)
    len = 1 << Int(n)
    nn = Int(n)
    mod = Int(modulus)
    tab = Vector{Vector{Int}}(undef, len)
    for x = 0:(len-1)
        row = Vector{Int}(undef, len)
        row[1] = 1
        for e = 1:(len-1)
            row[e+1] = gf_mul(row[e], x, nn; modulus = mod)
        end
        tab[x+1] = row
    end
    tab
end

"""
    terms_to_lut(terms, n, modulus; powtab=nothing) -> Vector{Int}

Length-`2ⁿ` LUT of `x ↦ Σ cᵢ·x^eᵢ` from `(coef, exp)` `terms`. Pass a shared
[`monomial_power_table`](@ref) as `powtab` to amortise the power computation
across many polynomials; without it, falls back to `gf_pow` per term.
"""
function terms_to_lut(
    terms::Vector{Tuple{Int,Int}},
    n::Integer,
    modulus::Integer;
    powtab::Union{Nothing,Vector{Vector{Int}}} = nothing,
)
    len = 1 << Int(n)
    nn = Int(n)
    mod = Int(modulus)
    out = zeros(Int, len)
    for x = 0:(len-1)
        acc = 0
        if powtab === nothing
            for (c, e) in terms
                acc ⊻= gf_mul(
                    c,
                    gf_pow(x, e, nn; modulus = mod),
                    nn;
                    modulus = mod,
                )
            end
        else
            row = powtab[x+1]
            for (c, e) in terms
                acc ⊻= gf_mul(c, row[e+1], nn; modulus = mod)
            end
        end
        out[x+1] = acc
    end
    out
end

"""
    quadratic_exponents(n) -> Vector{Int}

The univariate exponents of Hamming (2-adic) weight ≤ 2 in `0:2ⁿ-1`, ascending:
the constant (weight 0), the `n` linearised terms `X^(2ⁱ)` (weight 1), and the
`C(n,2)` quadratic terms `X^(2ⁱ+2ʲ)` (weight 2). For `n=8`: `1+8+28 = 37`.
"""
quadratic_exponents(n::Integer) =
    [e for e = 0:((1<<Int(n))-1) if count_ones(e) ≤ 2]

"""
    encode_quadratic(terms, n) -> Vector{UInt8}

Pack the coefficients of a degree-≤2 univariate polynomial (as `(coef, exp)`
`terms`, e.g. from [`polynomial_terms`](@ref)) into a compact byte vector
aligned to [`quadratic_exponents`](@ref): `cld(n,8)` little-endian bytes per
`GF(2ⁿ)` coefficient (37 bytes at `n=8`). Lossless; [`decode_quadratic_lut`](@ref)
rebuilds the exact LUT. Throws if any term's exponent has weight > 2.
"""
function encode_quadratic(terms::Vector{Tuple{Int,Int}}, n::Integer)
    nn = Int(n)
    exps = quadratic_exponents(nn)
    slot = Dict(e => i for (i, e) in enumerate(exps))
    coeffs = zeros(Int, length(exps))
    for (c, e) in terms
        haskey(slot, e) || error(
            "encode_quadratic: exponent $e has weight > 2 (not a quadratic term)",
        )
        coeffs[slot[e]] ⊻= c               # field addition of like terms
    end
    nb = cld(nn, 8)
    out = Vector{UInt8}(undef, length(coeffs) * nb)
    for (i, c) in enumerate(coeffs), b = 0:(nb-1)
        out[(i-1)*nb+b+1] = UInt8((c >> (8b)) & 0xff)
    end
    out
end

"""
    decode_quadratic_lut(bytes, n, modulus; powtab=nothing) -> Vector{Int}

Inverse of [`encode_quadratic`](@ref): rebuild the length-`2ⁿ` LUT from a packed
quadratic-coefficient byte vector over `GF(2ⁿ)` modulo `modulus`.
"""
function decode_quadratic_lut(
    bytes::AbstractVector{UInt8},
    n::Integer,
    modulus::Integer;
    powtab::Union{Nothing,Vector{Vector{Int}}} = nothing,
)
    nn = Int(n)
    exps = quadratic_exponents(nn)
    nb = cld(nn, 8)
    length(bytes) == length(exps) * nb || error(
        "decode_quadratic_lut: expected $(length(exps) * nb) bytes, got $(length(bytes))",
    )
    terms = Tuple{Int,Int}[]
    for (i, e) in enumerate(exps)
        c = 0
        for b = 0:(nb-1)
            c |= Int(bytes[(i-1)*nb+b+1]) << (8b)
        end
        c != 0 && push!(terms, (c, e))
    end
    terms_to_lut(terms, nn, Int(modulus); powtab = powtab)
end

"""
    encode_quadratic(F::SBox{N,T}; modulus=conway_polynomial(N),
                     verify=true, powtab=nothing) -> Vector{UInt8}

Pack a degree-≤2 vectorial function given by its **LUT** into the compact
`quadratic-coeffs-v1` byte vector (the substrate for VBFCatalog's bulk-corpus
description store) by recovering the weight-≤2 univariate coefficients of `F`
over `GF(2ᴺ)` modulo `modulus`.

The interpolation is the Mattson–Solomon identity: writing `F(X) = Σₑ cₑ Xᵉ`
over `GF(q)`, `q = 2ᴺ`, one has `c₀ = F(0)` and `cₑ = Σ_{a≠0} F(a)·a^{q-1-e}`
for `1 ≤ e ≤ q-2`. Only the `1 + N + C(N,2)` exponents of 2-adic weight ≤ 2 are
retained; for a genuinely quadratic `F` every higher-weight coefficient is zero
(the univariate 2-adic-weight degree equals the Boolean algebraic degree, a
field-independent invariant). With `verify=true` the packed bytes are decoded
back and required to reproduce `F` exactly — so a function of degree > 2 is
rejected rather than silently truncated. Pass a shared
[`monomial_power_table`](@ref) as `powtab` to amortise the interpolation across
many functions (e.g. a whole bulk corpus).
"""
function encode_quadratic(
    F::SBox{N,T};
    modulus::Integer = conway_polynomial(N),
    verify::Bool = true,
    powtab::Union{Nothing,Vector{Vector{Int}}} = nothing,
) where {N,T}
    nn = Int(N)
    q = 1 << nn
    mod = Int(modulus)
    tab = powtab === nothing ? monomial_power_table(nn, mod) : powtab
    exps = quadratic_exponents(nn)
    nb = cld(nn, 8)
    lut = F.lut
    out = zeros(UInt8, length(exps) * nb)
    for (i, e) in enumerate(exps)
        c = 0
        if e == 0
            c = Int(lut[1])                        # c₀ = F(0)
        else
            j = q - 1 - e                          # paired exponent, in 1:q-2
            for a = 1:(q-1)
                fa = Int(lut[a+1])
                fa == 0 && continue
                c ⊻= gf_mul(fa, tab[a+1][j+1], nn; modulus = mod)
            end
        end
        for b = 0:(nb-1)
            out[(i-1)*nb+b+1] = UInt8((c >> (8b)) & 0xff)
        end
    end
    if verify
        decode_quadratic_lut(out, nn, mod; powtab = tab) == Int.(lut) || error(
            "encode_quadratic(::SBox): F is not degree ≤ 2 over GF(2^$nn) " *
            "(round-trip mismatch); algebraic_degree = $(algebraic_degree(F))",
        )
    end
    out
end
