# Implements paper-local helpers for the Beierle–Leander (2022) reproduction.
# Paper: Beierle, Leander (2022), "New Instances of Quadratic APN Functions",
#        IEEE Trans. Inf. Theory 68(1):670–678 / arXiv:2009.07204
# Section: General — shared helpers, I/O, formatting
#
# VBF API used: SBox

using VBF

# ── Report formatting ────────────────────────────────────────────────────────

"""Print paper title, authors, and venue."""
function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Beierle, Leander (2022): New Instances of Quadratic APN Functions")
    println(io, "IEEE Trans. Inf. Theory 68(1):670–678 / arXiv:2009.07204")
    println(io, "=" ^ 72)
end

# ── Dataset I/O ──────────────────────────────────────────────────────────────

"""
    parse_lut_line(line) -> Vector{Int}

Parse one brace-wrapped dataset line (format: `{v0, v1, ...}`) into a
0-based LUT vector. Beierle–Leander (2022), dataset format.
"""
function parse_lut_line(line::AbstractString)::Vector{Int}
    s = strip(line)
    # Strip leading '{' and trailing '},?' (format: `{v0, v1, ...}` or `{...},`).
    s = lstrip(s, '{')
    # Strip optional trailing comma then closing brace (order matters: ",}" or "}," or "}").
    s = rstrip(s, ' ')
    s = rstrip(s, ',')
    s = rstrip(s, '}')
    s = rstrip(s, ',')
    parts = split(s, ',')
    return [parse(Int, strip(p)) for p in parts if !isempty(strip(p))]
end

"""
    stream_dataset(path; limit = typemax(Int)) -> Channel{SBox}

Line-streamed reader for the large dataset files. Never reads the whole
file into memory. Beierle–Leander (2022), dataset format.
"""
function stream_dataset(path::AbstractString; limit::Int = typemax(Int))
    return Channel{SBox}(function (ch)
        for (i, line) in enumerate(eachline(path))
            i > limit && break
            stripped = strip(line)
            isempty(stripped) && continue
            lut = parse_lut_line(stripped)
            put!(ch, SBox(lut))
        end
    end)
end
