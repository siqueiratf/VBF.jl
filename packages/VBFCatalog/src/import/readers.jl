module SourceReaders
using VBF
export parse_apn_lut_file, parse_apn_lut_text, parse_decimal_lut!, edelpott_luts
"""
    parse_apn_lut_file(path::AbstractString; max_luts = nothing) -> Vector{Vector{Int}}

Extract every inner LUT literal from a Python file of the
`all_funcs = [[..., ...], [..., ...], ...]` shape. Inner lists are
matched via a regex restricted to digits / commas / whitespace, so
the outer enclosing list (whose content contains `[` and `]`
characters) is correctly skipped.

`max_luts` caps the number of LUTs returned (useful for testing or
sampling). `nothing` means "all".
"""
function parse_apn_lut_file(path::AbstractString;
                            max_luts::Union{Nothing, Integer} = nothing)
    text = read(path,String)
    parse_apn_lut_text(text;max_luts)
end

function parse_apn_lut_text(text::AbstractString;max_luts=nothing)
    luts = Vector{Int}[]
    pattern = r"\[((?:\s*-?(?:0[xX][0-9a-fA-F]+|\d+)\s*,?\s*)+)\]"
    for m in eachmatch(pattern, text)
        body = strip(m.captures[1])
        nums = [_parse_integer_literal(s)
                for s in split(body, r"\s*,\s*"; keepempty = false)]
        push!(luts, nums)
        max_luts !== nothing && length(luts) ≥ Int(max_luts) && break
    end
    luts
end

function _parse_integer_literal(s::AbstractString)
    s2 = strip(s)
    sign=startswith(s2,"-") ? -1 : 1
    sign<0 && (s2=s2[2:end])
    if startswith(s2, "0x") || startswith(s2, "0X")
        return sign*parse(Int, s2[3:end]; base = 16)
    else
        return sign*parse(Int, s2)
    end
end

function _balanced_paren_arg(text::AbstractString, open::Int)
    depth = 0
    i = open
    n = lastindex(text)
    start = 0
    while i ≤ n
        c = text[i]
        if c == '('
            depth += 1
            depth == 1 && (start = nextind(text, i))
        elseif c == ')'
            depth -= 1
            depth == 0 && return text[start:prevind(text, i)]
        end
        i = nextind(text, i)
    end
    error("unbalanced parenthesis starting at $open")
end

# Every argument of `wrapper(...)` in `text`, as raw strings.
function _wrapper_args(text::AbstractString, wrapper::AbstractString)
    args = String[]
    pat = wrapper * "("
    idx = firstindex(text)
    while true
        r = findnext(pat, text, idx)
        r === nothing && break
        open = last(r)                       # index of '('
        arg = _balanced_paren_arg(text, open)
        push!(args, String(strip(arg)))
        idx = nextind(text, open)
    end
    args
end


# --- EP09: SAGE polynomials in eightBitAPN.all_quadratic_polynomials() ---------

# Expand `sum(X**(K*2**i) for i in range(0, N))` to `(X**K + X**2K + … + X**128K)`, normalise the `**` powers + a stray `+  +` typo to VBF polynomial syntax.
function _normalise_sage_poly(e::AbstractString, n)
    while (m = match(r"sum\(X\*\*\((\d+)\*2\*\*i\) for i in range\(0, ?N\)\)", e)) !== nothing
        K = parse(Int, m.captures[1])
        e = replace(e, m.match => "(" * join(["X**$(K * (1 << i))" for i in 0:n - 1], " + ") * ")")
    end
    replace(replace(e, r"\+\s*\+" => "+"), r"\s+" => " ")
end

function edelpott_luts(path::AbstractString; n=8)
    src = read(path, String)
    i0 = findfirst("def all_quadratic_polynomials", src)
    i1 = findnext("\ndef ", src, last(i0) + 1)
    body = src[last(i0):(i1 === nothing ? lastindex(src) : first(i1))]
    [polynomial_to_lut(_normalise_sage_poly(e, n), n, conway_polynomial(n)) for e in _wrapper_args(body,"poly_to_lut")]
end


function parse_decimal_lut!(lut::Vector{UInt8}, s::AbstractString)
    occursin(r"-\s*\d",s) && return -1
    n = 0; cur = 0; indig = false; bad = false
    @inbounds for c in codeunits(s)
        if 0x30 <= c <= 0x39
            cur = 10cur + (c - 0x30); indig = true
            cur > 255 && (bad = true; cur = 0)
        elseif indig
            n += 1; n <= 256 && (lut[n] = UInt8(cur)); cur = 0; indig = false
        end
    end
    if indig
        n += 1; n <= 256 && (lut[n] = UInt8(cur))
    end
    bad ? -1 : n
end


end
