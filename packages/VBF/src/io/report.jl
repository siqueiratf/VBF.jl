"""
Console report helpers for paper-reproduction scripts.

Every `packages/VBFRepro/src/<slug>/` reproduction prints the same shape of structured
progress — a banner, titled sections, pass/fail checks, key/value lines — so
that surface lives here once instead of being re-defined in every paper's
`helpers.jl`. The format is the one documented in the `reproduce-paper` skill:

    ## <section title>          ← print_section
      [PASS] <check>            ← print_check
      key: value               ← print_kv

All emitters take the `IO` either first or last (with `stdout` as the default
when omitted), so paper scripts may call them in whichever order reads best at
the call site without re-implementing the function.
"""

"""
    status_str(ok::Bool) -> String

`"PASS"` when `ok`, otherwise `"FAIL"`. The textual tag used by
[`print_check`](@ref).
"""
status_str(ok::Bool) = ok ? "PASS" : "FAIL"

"""
    print_banner(lines...; io=stdout, width=72)

Print `lines` framed by full-width `=` rules. Use for a paper's top-of-report
header (title, venue, field parameters). The `IO` may be passed positionally as
the first argument instead of by keyword.
"""
function print_banner(io::IO, lines::AbstractString...; width::Integer = 72)
    rule = "="^width
    println(io, rule)
    for line in lines
        println(io, line)
    end
    println(io, rule)
end
print_banner(lines::AbstractString...; io::IO = stdout, width::Integer = 72) =
    print_banner(io, lines...; width = width)

"""
    print_section(title, io=stdout)
    print_section(io, title)

Print a titled section header: a blank line followed by `## <title>`.
"""
print_section(title::AbstractString, io::IO = stdout) = println(io, "\n## ", title)
print_section(io::IO, title::AbstractString) = print_section(title, io)

"""
    print_check(label, ok, io=stdout)
    print_check(io, label, ok=true)

Print an indented `[PASS]`/`[FAIL]` line for the check `label`.
"""
print_check(label::AbstractString, ok::Bool, io::IO = stdout) =
    println(io, "  [", status_str(ok), "] ", label)
print_check(io::IO, label::AbstractString, ok::Bool = true) = print_check(label, ok, io)

"""
    print_kv(label, value, io=stdout)
    print_kv(io, label, value)

Print an indented `label: value` line.
"""
print_kv(label::AbstractString, value, io::IO = stdout) =
    println(io, "  ", label, ": ", value)
print_kv(io::IO, label::AbstractString, value) = print_kv(label, value, io)
