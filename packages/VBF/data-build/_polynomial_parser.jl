# Developer-only helper: a tiny parser for the polynomial expressions
# used by upstream APN catalogs (Xanadu's `apn-ccz-graph-framework`,
# `APN-Repository`'s `poly` column, …). Included by the data-build
# importers; NOT part of the runtime BFA package.
#
# Grammar (small enough to recurse-and-descend without an explicit AST):
#
#     polynomial = sum  ('+' sum)*
#     sum        = product  ('+' product)*
#     product    = factor  ('*' factor)*
#     factor     = X | x        (the variable; one occurrence)
#                | ksi          (the primitive root)
#                | INTEGER      (constant in F₂: 0 or 1, used to drop terms)
#                | ksi POW INTEGER
#                | X   POW INTEGER
#                | x   POW INTEGER
#     POW        = '**'  |  '^'
#
# Whitespace between tokens is ignored. There is no subtraction (F₂ ⇒ same
# as addition); the parser doesn't try to be clever about it.
#
# `evaluate_polynomial(expr, x, n, modulus; ksi)` returns the value of the
# polynomial expression at the given x ∈ GF(2ⁿ).

using VBF

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
            push!(out, "+"); i = nextind(s, i)
        elseif c == '*' && i + 1 ≤ n && s[i + 1] == '*'
            push!(out, "**"); i += 2
        elseif c == '*'
            push!(out, "*"); i = nextind(s, i)
        elseif c == '^'
            push!(out, "**"); i = nextind(s, i)            # normalise ^ to **
        elseif c == '('
            push!(out, "("); i = nextind(s, i)
        elseif c == ')'
            push!(out, ")"); i = nextind(s, i)
        elseif c == 'X' || c == 'x'
            push!(out, "X"); i = nextind(s, i)
        elseif (c == 'k' || c == 'K') && i + 2 ≤ n && lowercase(s[i:i + 2]) == "ksi"
            push!(out, "ksi"); i += 3
        elseif c == 'g'
            # SageMath's `g = field.gen()` is the same primitive element as `ksi`
            push!(out, "ksi"); i = nextind(s, i)
        elseif c == 'a'
            # Magma / Simon-Berg convention: `a = field.gen()`, same primitive
            # element as `ksi`. (No identifier in these grammars contains 'a'.)
            push!(out, "ksi"); i = nextind(s, i)
        elseif isdigit(c)
            j = i
            while j ≤ n && isdigit(s[j]); j = nextind(s, j); end
            push!(out, s[i:prevind(s, j)])
            i = j
        else
            error("unexpected character $(repr(c)) at position $i in $(repr(s))")
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
function evaluate_polynomial(expr_str::AbstractString, x::Integer, n::Integer,
                              modulus::Integer; ksi::Integer = 2)
    toks = _tokenize_polynomial(expr_str)
    pos  = Ref(1)
    val  = _parse_polynomial!(toks, pos, Int(x), Int(n), Int(modulus), Int(ksi))
    pos[] ≤ length(toks) &&
        error("polynomial parser: trailing tokens after expression at position $(pos[])")
    val
end

# Sum of terms; stops at end-of-tokens or at a closing ')'.
function _parse_polynomial!(toks::Vector{String}, pos::Ref{Int},
                             x::Int, n::Int, modulus::Int, ksi::Int)
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
function _parse_term!(toks::Vector{String}, pos::Ref{Int},
                     x::Int, n::Int, modulus::Int, ksi::Int)
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
            pos[] ≤ length(toks) && toks[pos[]] == ")" || error("polynomial parser: missing ')'")
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
            coef = gf_mul(coef, gf_pow(ksi, e, n; modulus = modulus),
                          n; modulus = modulus)
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
    occursin(r"^\d+$", toks[pos[]]) ||
        error("polynomial parser: expected integer after `**`, got $(repr(toks[pos[]]))")
    e = parse(Int, toks[pos[]])
    pos[] += 1
    e
end

"""
    polynomial_to_lut(expr_str, n, modulus; ksi=2) -> Vector{Int}

`length-2ⁿ` lookup table of `x ↦ p(x)` for the polynomial expression
`p` parsed from `expr_str`.
"""
function polynomial_to_lut(expr_str::AbstractString, n::Integer, modulus::Integer;
                            ksi::Integer = 2)
    len = 1 << Int(n)
    out = Vector{Int}(undef, len)
    for x in 0:len - 1
        out[x + 1] = evaluate_polynomial(expr_str, x, n, modulus; ksi = ksi)
    end
    out
end

# ----- bulk evaluation (parse-once, then evaluate at all 2ⁿ points) ---------
#
# The recursive-descent `polynomial_to_lut` re-tokenizes and re-parses the
# expression at every `x`, which is fine for a few hundred polynomials but
# far too slow for the ~205k Simon-Berg members. For *flat* polynomials (a
# sum of monomials `c · Xᵉ`, no parenthesised sub-expressions — which is the
# Simon-Berg / monomial-list shape) we parse once into `(coef, exp)` terms
# and share a per-`x` table of powers across every polynomial.

"""
    polynomial_terms(expr_str, n, modulus; ksi=2) -> Vector{Tuple{Int,Int}}

Parse a *flat* polynomial (sum of monomials `c · Xᵉ`; no parentheses) into
`(coefficient, exponent)` pairs — the coefficient an element of `GF(2ⁿ)`, the
exponent the power of `X`. Terms with a zero coefficient (an even integer
literal in F₂) are dropped. Throws on parenthesised sub-expressions; use
[`evaluate_polynomial`](@ref) for those.
"""
function polynomial_terms(expr_str::AbstractString, n::Integer, modulus::Integer;
                           ksi::Integer = 2)
    toks = _tokenize_polynomial(expr_str)
    ("(" in toks || ")" in toks) &&
        error("polynomial_terms: parenthesised sub-expressions unsupported in $(repr(expr_str))")
    terms = Tuple{Int, Int}[]
    nn = Int(n); mod = Int(modulus); k = Int(ksi)
    i = 1; L = length(toks)
    while i ≤ L
        coef = 1; vexp = 0; saw = false
        while i ≤ L && toks[i] != "+"
            t = toks[i]
            if t == "*"
                i += 1
            elseif t == "X"
                saw = true; i += 1
                if i ≤ L && toks[i] == "**"
                    vexp += parse(Int, toks[i + 1]); i += 2
                else
                    vexp += 1
                end
            elseif t == "ksi"
                saw = true; i += 1
                e = 1
                if i ≤ L && toks[i] == "**"
                    e = parse(Int, toks[i + 1]); i += 2
                end
                coef = gf_mul(coef, gf_pow(k, e, nn; modulus = mod), nn; modulus = mod)
            elseif occursin(r"^\d+$", t)
                saw = true; i += 1
                iseven(parse(Int, t)) && (coef = 0)
            else
                error("polynomial_terms: unexpected token $(repr(t)) in $(repr(expr_str))")
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
    len = 1 << Int(n); nn = Int(n); mod = Int(modulus)
    tab = Vector{Vector{Int}}(undef, len)
    for x in 0:len - 1
        row = Vector{Int}(undef, len)
        row[1] = 1
        for e in 1:len - 1
            row[e + 1] = gf_mul(row[e], x, nn; modulus = mod)
        end
        tab[x + 1] = row
    end
    tab
end

"""
    terms_to_lut(terms, n, modulus; powtab=nothing) -> Vector{Int}

Length-`2ⁿ` LUT of `x ↦ Σ cᵢ·x^eᵢ` from `(coef, exp)` `terms`. Pass a shared
[`monomial_power_table`](@ref) as `powtab` to amortise the power computation
across many polynomials; without it, falls back to `gf_pow` per term.
"""
function terms_to_lut(terms::Vector{Tuple{Int, Int}}, n::Integer, modulus::Integer;
                       powtab::Union{Nothing, Vector{Vector{Int}}} = nothing)
    len = 1 << Int(n); nn = Int(n); mod = Int(modulus)
    out = zeros(Int, len)
    for x in 0:len - 1
        acc = 0
        if powtab === nothing
            for (c, e) in terms
                acc ⊻= gf_mul(c, gf_pow(x, e, nn; modulus = mod), nn; modulus = mod)
            end
        else
            row = powtab[x + 1]
            for (c, e) in terms
                acc ⊻= gf_mul(c, row[e + 1], nn; modulus = mod)
            end
        end
        out[x + 1] = acc
    end
    out
end
