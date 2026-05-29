"""
Text rendering helpers: Markdown / LaTeX for S-box lookup tables and for
the integer statistic tables (DDT / LAT / BCT / …). A pure-Julia
presentation layer returning `String`s, so it composes with paper
notebooks and is easy to snapshot-test.

!!! note "Not ported"
    sboxU's `display/output.py` is a Rich-based experiment-logging
    framework (`Experiment` / `Chronograph` / `section` / `pprint` with
    terminal markup) — terminal-UI infrastructure coupled to the `rich`
    library, not algorithmic content — and is intentionally left out.
    The matplotlib "Pollock" plot (`display/pollock.py`) is likewise
    deferred to a future plotting extension.
"""

# --- S-box LUTs ---------------------------------------------------------------

"""
    to_markdown(s::SBox; per_row=16) -> String

The lookup table of `s` as a GitHub-flavoured Markdown table: a header
row of input values `x` and a body row of `F(x)`, wrapped every
`per_row` columns.
"""
function to_markdown(s::SBox{N, T}; per_row::Integer = 16) where {N, T}
    n = 1 << N
    io = IOBuffer()
    for start in 0:per_row:n - 1
        stop = min(start + per_row - 1, n - 1)
        xs = start:stop
        println(io, "| x | ", join(xs, " | "), " |")
        println(io, "|", repeat("---|", length(xs) + 1))
        println(io, "| F(x) | ", join((Int(s.lut[x + 1]) for x in xs), " | "), " |")
        stop < n - 1 && println(io)
    end
    rstrip(String(take!(io)))
end

"""
    to_latex(s::SBox) -> String

The lookup table of `s` as a LaTeX `array` (two rows: `x` and `F(x)`).
"""
function to_latex(s::SBox{N, T}) where {N, T}
    n = 1 << N
    io = IOBuffer()
    println(io, "\\begin{array}{c|", repeat("c", n), "}")
    println(io, "x & ", join(0:n - 1, " & "), " \\\\")
    println(io, "\\hline")
    println(io, "F(x) & ", join((Int(s.lut[x + 1]) for x in 0:n - 1), " & "), " \\\\")
    print(io, "\\end{array}")
    String(take!(io))
end

# --- statistic tables (DDT / LAT / BCT / …) -----------------------------------

"""
    table_to_markdown(M::AbstractMatrix{<:Integer}; corner="·") -> String

A 0-indexed integer table (e.g. the output of [`ddt`](@ref) / [`lat`](@ref))
as a Markdown table, with a leading row and column of indices. `corner`
labels the top-left cell.
"""
function table_to_markdown(M::AbstractMatrix{<:Integer}; corner::AbstractString = "·")
    r, c = size(M)
    io = IOBuffer()
    println(io, "| ", corner, " | ", join(0:c - 1, " | "), " |")
    println(io, "|", repeat("---|", c + 1))
    for i in 1:r
        println(io, "| ", i - 1, " | ", join((Int(M[i, j]) for j in 1:c), " | "), " |")
    end
    rstrip(String(take!(io)))
end

"""
    table_to_latex(M::AbstractMatrix{<:Integer}) -> String

A 0-indexed integer table as a LaTeX `array` with index header row and
column.
"""
function table_to_latex(M::AbstractMatrix{<:Integer})
    r, c = size(M)
    io = IOBuffer()
    println(io, "\\begin{array}{c|", repeat("c", c), "}")
    println(io, " & ", join(0:c - 1, " & "), " \\\\")
    println(io, "\\hline")
    for i in 1:r
        println(io, i - 1, " & ", join((Int(M[i, j]) for j in 1:c), " & "), " \\\\")
    end
    print(io, "\\end{array}")
    String(take!(io))
end
