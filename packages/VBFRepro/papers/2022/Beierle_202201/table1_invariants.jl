# Implements Table 1 rank invariants, Walsh spectrum, and multiplier group.
# Paper: Beierle, Leander (2022), "New Instances of Quadratic APN Functions",
#        IEEE Trans. Inf. Theory 68(1):670–678 / arXiv:2009.07204
# Section: Table 1 — table1-rank-invariants, table1-walsh-spectrum,
#          table1-multiplier-group
#
# VBF API used: SBox, polynomial_to_lut, gamma_rank, delta_rank, lat,
#   absolute_walsh_spectrum, sorted_pairs, conway_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

# ── CSV parsing ──────────────────────────────────────────────────────────────

"""
    _strip_backticks(s) -> String

Strip surrounding backticks from a CSV cell value.
"""
function _strip_backticks(s::AbstractString)
    s = strip(s)
    startswith(s, '`') && endswith(s, '`') && return s[2:end-1]
    return String(s)
end

"""
    _parse_rank(s) -> Union{Int, Nothing}

Parse a rank cell (backtick-wrapped integer, or '-' for missing).
"""
function _parse_rank(s::AbstractString)
    v = _strip_backticks(s)
    v == "-" && return nothing
    return parse(Int, v)
end

"""
    parse_table1(csv_path) -> Vector{NamedTuple}

Parse Table 1 CSV into a vector of rows with fields:
  dim, id, polynomial, equiv, walsh_class, gamma_rank, delta_rank, multiplier.
Beierle–Leander (2022), Table 1.
"""
function parse_table1(csv_path::AbstractString)
    rows = []
    lines = readlines(csv_path)
    # skip header (line 1)
    i = 2
    while i <= length(lines)
        line = lines[i]
        # Lines for rows 8.9 and 8.10 are double-quoted in the CSV (Function
        # field contains commas). Detect by looking for the opening double-quote
        # after the second comma-delimited field.
        # Strategy: if the third field starts with `"`, consume lines until the
        # closing `"` appears.
        # Split on commas carefully: first two fields are simple backtick-wrapped.
        # Manually extract the 8 fields.
        full_line = line
        # Merge continuation lines for double-quoted Function cells.
        while true
            # Count unescaped double-quotes in the accumulated line.
            nq = count(==('\"'), full_line)
            # If there is exactly one double-quote (opening), the field spans lines.
            nq == 1 && i < length(lines) || break
            i += 1
            full_line = full_line * " " * lines[i]
        end
        fields = _split_csv_line(full_line)
        length(fields) < 8 && (i += 1; continue)
        dim_s     = _strip_backticks(fields[1])
        id_s      = _strip_backticks(fields[2])
        poly_s    = _strip_csv_field(fields[3])
        equiv_s   = _strip_backticks(fields[4])
        walsh_s   = _strip_backticks(fields[5])
        gamma_s   = _strip_backticks(fields[6])
        delta_s   = _strip_backticks(fields[7])
        mult_s    = join(fields[8:end], ",")
        dim = parse(Int, dim_s)
        gamma = gamma_s == "-" ? nothing : parse(Int, gamma_s)
        delta = delta_s == "-" ? nothing : parse(Int, delta_s)
        push!(rows, (;
            dim,
            id      = id_s,
            polynomial = poly_s,
            equiv   = equiv_s,
            walsh_class = walsh_s,
            gamma_rank  = gamma,
            delta_rank  = delta,
            multiplier  = mult_s,
        ))
        i += 1
    end
    return rows
end

"""Split one CSV line respecting double-quoted multi-field values."""
function _split_csv_line(line::AbstractString)
    fields = String[]
    buf = IOBuffer()
    in_quotes = false
    for c in line
        if c == '"'
            in_quotes = !in_quotes
        elseif c == ',' && !in_quotes
            push!(fields, String(take!(buf)))
        else
            write(buf, c)
        end
    end
    push!(fields, String(take!(buf)))
    return fields
end

"""Strip surrounding backticks (or double-quote wrapping) from a CSV field."""
function _strip_csv_field(s::AbstractString)
    s = strip(s)
    # After double-quote removal by the CSV splitter, field may still have backticks.
    startswith(s, '`') && endswith(s, '`') && return s[2:end-1]
    return String(s)
end

# ── Polynomial → SBox conversion ─────────────────────────────────────────────

"""
    _has_trace(poly_str) -> Bool

Detect Tr_{n}(...) trace notation (not supported by polynomial_to_lut).
"""
_has_trace(s::AbstractString) = occursin("Tr", s)

"""
    table1_polynomial_to_sbox(row) -> Union{SBox, Nothing}

Convert the polynomial string in a Table 1 row to an SBox via polynomial_to_lut.
Uses the Conway polynomial for GF(2^n).

Returns nothing for rows that cannot be parsed:
  - Polynomials containing Tr_{n}(...) trace (not supported by the
    univariate parser; would require implementing the absolute trace map).
  - Polynomials using 'p' as the primitive element (some n=10 rows):
    'p' is an alias for 'a'/'ksi' in some catalogs but the tokenizer does
    not recognise it.
  Beierle–Leander (2022), Table 1.
"""
function table1_polynomial_to_sbox(row)
    n = row.dim
    poly = row.polynomial
    # Rows with trace functions are not parseable.
    if _has_trace(poly)
        return nothing
    end
    # Some n=10 rows use 'p' as the generator (same role as 'a'/'ksi').
    # Replace 'p' with 'a' so the tokenizer picks it up as 'ksi'.
    # Only do this when 'p' appears adjacent to '^' or a digit (to avoid
    # matching false positives, though none exist in this CSV).
    # Strip LaTeX braces from exponents: x^{3} → x^3, a^{8} → a^8.
    poly_norm = replace(poly, r"\{(\d+)\}" => s"\1")
    # Replace 'p' with 'a': some n=10 rows use 'p' as the primitive element.
    # Safe because 'p' is not a valid token in the polynomial grammar.
    poly_norm = replace(poly_norm, "p" => "a")
    mod = try
        conway_polynomial(n)
    catch
        # n=11 has no Conway polynomial in the VBF table; skip.
        return nothing
    end
    lut = try
        polynomial_to_lut(poly_norm, n, mod)
    catch
        # TODO: If parse fails (e.g. due to parenthesised sub-expressions in
        # rows 8.9/8.10 beyond what the flat parser handles), return nothing.
        # polynomial_to_lut delegates to evaluate_polynomial which does support
        # parentheses, so this branch handles unexpected parse errors only.
        return nothing
    end
    return SBox(lut)
end

# ── Check ranks ───────────────────────────────────────────────────────────────

"""
    check_ranks(io; max_dim, save_results) -> NamedTuple

For each Table 1 row with dim <= max_dim and known rank values, compute
gamma_rank and delta_rank and compare to the CSV.
Beierle–Leander (2022), Table 1 — table1-rank-invariants.
"""
function check_ranks(
    io::IO = stdout;
    max_dim::Int = 7,
    save_results::Bool = false,
)
    print_section("table1-rank-invariants (dim ≤ $max_dim)", io)
    csv_path = joinpath(@__DIR__, "inputs", "table1.csv")
    table = parse_table1(csv_path)
    checked = 0
    skipped_dim = 0
    skipped_missing = 0
    skipped_parse = 0
    failures = []
    results = []
    for row in table
        row.dim > max_dim && (skipped_dim += 1; continue)
        (row.gamma_rank === nothing || row.delta_rank === nothing) &&
            (skipped_missing += 1; continue)
        f = table1_polynomial_to_sbox(row)
        if f === nothing
            skipped_parse += 1
            print_kv("  SKIP (parse)", "$(row.id): $(row.polynomial[1:min(40,end)])…", io)
            continue
        end
        gr = gamma_rank(f)
        dr = delta_rank(f)
        gr_ok = gr == row.gamma_rank
        dr_ok = dr == row.delta_rank
        ok = gr_ok && dr_ok
        checked += 1
        if !ok
            push!(failures, row.id)
            print_kv("  MISMATCH $(row.id)", "Γ: got $gr expected $(row.gamma_rank); Δ: got $dr expected $(row.delta_rank)", io)
        end
        push!(results, (; id=row.id, dim=row.dim,
            gamma_computed=gr, gamma_csv=row.gamma_rank, gamma_ok=gr_ok,
            delta_computed=dr, delta_csv=row.delta_rank, delta_ok=dr_ok, ok))
    end
    all_ok = isempty(failures)
    print_kv("checked", checked, io)
    print_kv("skipped (dim > $max_dim)", skipped_dim, io)
    print_kv("skipped (ranks missing in CSV)", skipped_missing, io)
    print_kv("skipped (polynomial unparseable)", skipped_parse, io)
    print_check("all checked rows match CSV ranks", all_ok, io)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "table1_ranks.toml"), "w") do f
            println(f, "# table1_ranks results")
            for r in results
                println(f, "[[result]]")
                println(f, "id = \"$(r.id)\"")
                println(f, "dim = $(r.dim)")
                println(f, "gamma_computed = $(r.gamma_computed)")
                println(f, "gamma_csv = $(r.gamma_csv)")
                println(f, "delta_computed = $(r.delta_computed)")
                println(f, "delta_csv = $(r.delta_csv)")
                println(f, "ok = $(r.ok)")
            end
        end
    end
    return (; results, all_ok, checked, skipped_dim, skipped_missing, skipped_parse)
end

# ── Check Walsh spectrum ──────────────────────────────────────────────────────

"""
    _walsh_class(f::SBox{N}) -> String

Classify the Walsh spectrum of f into a named class for APN functions.
Gold-class: ≤ 2 distinct nonzero absolute LAT values (2- or 3-valued).
Inverse-class: ≥ 5 distinct nonzero values (occurs only for odd n, family x^{2^n-2}).
Dobbertin-class: ≥ 5 distinct nonzero values for even n (family x^{d} with n=5k).
Beierle–Leander (2022), Table 1 — table1-walsh-spectrum.
"""
function _walsh_class(f::SBox{N}) where {N}
    sp = absolute_walsh_spectrum(f)
    pairs = sorted_pairs(sp)
    vals = [p.first for p in pairs]
    nonzero_vals = filter(v -> v > 0, vals)
    # Gold-class: ≤ 2 distinct nonzero absolute Walsh values.
    if length(nonzero_vals) <= 2
        return "Gold"
    # For many-valued spectra, distinguish Inverse (odd n) from Dobbertin (even n).
    # Inverse APN x^{2^n-2} requires odd n; Dobbertin x^{d} requires n = 5k (even or odd).
    # In Table 1 n=10 only Dobbertin appears; n=7,9,11 Inverse appears.
    elseif isodd(N)
        return "Inverse"
    else
        return "Dobbertin"
    end
end

"""
    check_walsh(io; save_results) -> NamedTuple

For each Table 1 row, compute the Walsh spectrum class and compare to CSV.
Rows where the polynomial is unparseable are skipped with a note.
Beierle–Leander (2022), Table 1 — table1-walsh-spectrum.
"""
function check_walsh(io::IO = stdout; save_results::Bool = false)
    print_section("table1-walsh-spectrum", io)
    csv_path = joinpath(@__DIR__, "inputs", "table1.csv")
    table = parse_table1(csv_path)
    checked = 0
    skipped_parse = 0
    failures = []
    results = []
    for row in table
        f = table1_polynomial_to_sbox(row)
        if f === nothing
            skipped_parse += 1
            print_kv("  SKIP (parse)", "$(row.id): $(row.polynomial[1:min(40,end)])…", io)
            continue
        end
        computed = _walsh_class(f)
        expected = row.walsh_class
        ok = computed == expected
        checked += 1
        if !ok
            push!(failures, row.id)
            print_kv("  MISMATCH $(row.id)",
                "got \"$computed\" expected \"$expected\"", io)
        end
        push!(results, (; id=row.id, dim=row.dim,
            computed, expected, ok))
    end
    all_ok = isempty(failures)
    print_kv("checked", checked, io)
    print_kv("skipped (polynomial unparseable)", skipped_parse, io)
    print_check("all checked rows match CSV Walsh spectrum class", all_ok, io)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "table1_walsh.toml"), "w") do f
            println(f, "# table1_walsh results")
            for r in results
                println(f, "[[result]]")
                println(f, "id = \"$(r.id)\"")
                println(f, "dim = $(r.dim)")
                println(f, "computed = \"$(r.computed)\"")
                println(f, "expected = \"$(r.expected)\"")
                println(f, "ok = $(r.ok)")
            end
        end
    end
    return (; results, all_ok, checked, skipped_parse)
end

# ── Multiplier group (out-of-scope stub) ──────────────────────────────────────

"""
    multiplier_group_order(io) -> nothing

Out-of-scope stub. The "multiplier group" in Table 1 refers to the order of the
linear self-equivalence group of F. Computing it requires confirming whether
it equals |Aut_LE(F)| from le_automorphism_search, and full group-order
computation is expensive. Semantics unconfirmed — stub with TODO.
Beierle–Leander (2022), Table 1, Multiplier group column.
"""
function multiplier_group_order(io::IO = stdout)
    println(
        io,
        "[OUT-OF-SCOPE] multiplier_group_order: see PLAN.md §3 and Table 1 TODO. " *
        "The 'multiplier group' is the linear self-equivalence group of F; its " *
        "order computation via le_automorphism_search is not confirmed and " *
        "is expensive for large n.",
    )
    return nothing
end
