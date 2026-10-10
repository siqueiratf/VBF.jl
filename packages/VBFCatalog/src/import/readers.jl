module SourceReaders
using VBF
import Downloads
export parse_apn_lut_file, edelpott_luts
"""
    parse_apn_lut_file(path::AbstractString; max_luts = nothing) -> Vector{Vector{Int}}

Extract every inner LUT literal from a Python file of the
`all_funcs = [[..., ...], [..., ...], ...]` shape. Inner lists are
matched via a regex restricted to digits / commas / whitespace, so
the outer enclosing list (whose content contains `[` and `]`
characters) is correctly skipped.

`max_luts` caps the number of LUTs returned (useful for testing or
sampling). `nothing` means "all".

If `zenodo_record` is provided and `path` is missing, download `basename(path)`
from that Zenodo record into a temporary directory before parsing.
"""
function parse_apn_lut_file(path::AbstractString;
                            max_luts::Union{Nothing, Integer} = nothing,
                            zenodo_record::Union{Nothing, AbstractString} = nothing)
    text = _read_apn_lut_file(path; zenodo_record = zenodo_record)
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

function _read_apn_lut_file(path::AbstractString;
                            zenodo_record::Union{Nothing, AbstractString} = nothing)
    isfile(path) && return read(path, String)
    zenodo_record === nothing && return read(path, String)

    filename = basename(path)
    url = _zenodo_file_url(zenodo_record, filename)
    @info "BFA: APN LUT file missing locally; downloading from Zenodo" file=filename url=url
    return mktempdir() do tmpdir
        downloaded = joinpath(tmpdir, filename)
        Downloads.download(url, downloaded)
        read(downloaded, String)
    end
end

function _zenodo_file_url(record::AbstractString, filename::AbstractString)
    base = String(strip(String(record)))
    occursin("/files/", base) && return base
    base = replace(base, r"[?#].*$" => "")
    base = replace(base, r"/+$" => "")
    isempty(base) && error("BFA: empty Zenodo record URL for '$filename'")
    base * "/files/" * _url_path_segment(filename) * "?download=1"
end

function _url_path_segment(s::AbstractString)
    io = IOBuffer()
    for b in codeunits(String(s))
        c = Char(b)
        if ('A' <= c <= 'Z') || ('a' <= c <= 'z') || ('0' <= c <= '9') ||
           c in ('-', '.', '_', '~')
            write(io, b)
        else
            print(io, "%", uppercase(string(b; base = 16, pad = 2)))
        end
    end
    String(take!(io))
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

# --- EP09: SAGE polynomials in eightBitAPN.all_quadratic_polynomials() ---------

# Balanced extraction of every `poly_to_lut(<expr>)` argument in a function body.
function _poly_to_lut_args(body::AbstractString)
    out = String[]; i = firstindex(body)
    while (j = findnext("poly_to_lut(", body, i)) !== nothing
        k = nextind(body, last(j)); depth = 1; start = k
        while depth > 0
            c = body[k]; c == '(' && (depth += 1); c == ')' && (depth -= 1)
            k = nextind(body, k)
        end
        push!(out, strip(body[start:prevind(body, prevind(body, k))]))
        i = k
    end
    out
end

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
    [polynomial_to_lut(_normalise_sage_poly(e, n), n, conway_polynomial(n)) for e in _poly_to_lut_args(body)]
end


end
