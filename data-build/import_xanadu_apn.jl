# Imports the Xanadu `apn-ccz-graph-framework/list_of_APN_functions_for_different_n`
# into the BFA catalog by:
#
#   1. parsing each polynomial expression in the file (X, ksi, +, *, **);
#   2. evaluating it as a length-2ⁿ LUT over GF(2ⁿ) using the Conway
#      polynomial for n (which is what Sage uses for `GF(2^n)` and so
#      is what Xanadu's `ksi` refers to);
#   3. hashing the LUT and either merging "xanadu@<sha>" into an existing
#      BFA function row, merging it into an existing
#      reconciliation_disagreements row, or recording a fresh
#      reconciliation row with `kind="only_in_some"`.
#
# Idempotent on re-run (no duplicate sources, no duplicate rows).
#
# Usage:
#     # uses BFA_XANADU_PATH env var or default ~/sboxU/apn-ccz-graph-framework
#     julia --project=. data-build/import_xanadu_apn.jl
#     julia --project=. data-build/import_xanadu_apn.jl --max 50

using BFA
import SQLite
import DBInterface

include(joinpath(@__DIR__, "_polynomial_parser.jl"))

const _DEFAULT_XANADU_PATHS = (
    get(ENV, "BFA_XANADU_PATH", ""),
    "/home/zambonin/APN.jl/Xanadu-ins@apn-ccz-graph-framework",   # current layout (2026-05-28)
    joinpath(homedir(), "APN.jl", "Xanadu-ins@apn-ccz-graph-framework"),
    joinpath(homedir(), "sboxU", "apn-ccz-graph-framework"),       # legacy fallbacks
    "/home/zambonin/sboxU/apn-ccz-graph-framework",
)

function xanadu_path()
    for p in _DEFAULT_XANADU_PATHS
        isempty(p) && continue
        isfile(joinpath(p, "list_of_APN_functions_for_different_n")) && return p
    end
    error("BFA: cannot find apn-ccz-graph-framework; set BFA_XANADU_PATH")
end

function xanadu_short_sha(path::AbstractString)
    try
        return readchomp(`git -C $path rev-parse --short HEAD`)
    catch
        return "unknown"
    end
end

# Parsed entry: (n, label, raw_expression_string)
const XanaduEntry = NamedTuple{(:n, :label, :expr), Tuple{Int, String, String}}

"""
    parse_xanadu_file(path) -> Vector{XanaduEntry}

Read the polynomial-list file at `path` and return every `(n, label,
expression)` triple it contains. Robust to:

- `#n = K` block headers
- entries written either as `("3", X**3+ksi**11*X**6)` (n ≥ 6) or
  `("1", "X^3")` (n = 5)
- inconsistent indentation / trailing whitespace
- `=====` separator lines between blocks
"""
function parse_xanadu_file(path::AbstractString)
    out = XanaduEntry[]
    current_n = 0
    text = read(path, String)
    for raw in split(text, '\n')
        line = strip(raw)
        m = match(r"^#\s*n\s*=\s*(\d+)", line)
        if m !== nothing
            current_n = parse(Int, m.captures[1])
            continue
        end
        current_n == 0 && continue

        # quoted-polynomial style:  ("1", "X^3"),
        m = match(r"^\(\s*\"(\d+)\"\s*,\s*\"([^\"]+)\"\s*\),?\s*$", line)
        if m !== nothing
            push!(out, (n = current_n,
                        label = String(m.captures[1]),
                        expr = String(strip(m.captures[2]))))
            continue
        end

        # bare-polynomial style:    ("2", X**3+ksi**11*X**6),
        m = match(r"^\(\s*\"(\d+)\"\s*,\s*(.+?)\s*\),?\s*$", line)
        if m !== nothing
            push!(out, (n = current_n,
                        label = String(m.captures[1]),
                        expr = String(strip(m.captures[2]))))
            continue
        end
    end
    out
end

function _fid_by_sha(db::SQLite.DB, sha::AbstractString)
    sql = "SELECT id FROM functions WHERE lut_sha256 = " *
          BFA._sql_quote(String(sha)) * " LIMIT 1"
    for r in DBInterface.execute(db, sql)
        return Int(r.id)
    end
    nothing
end

function _merge_recon_source!(db::SQLite.DB, sha::AbstractString, source_tag::AbstractString)
    cur = ""
    rid = 0
    sql = "SELECT id, present_in FROM reconciliation_disagreements WHERE lut_sha256 = " *
          BFA._sql_quote(String(sha)) * " LIMIT 1"
    for r in DBInterface.execute(db, sql)
        rid = Int(r.id)
        cur = String(r.present_in)
    end
    rid == 0 && return false
    parts = split(cur, '|')
    String(source_tag) in parts && return true
    new_val = cur * "|" * String(source_tag)
    SQLite.execute(db, "UPDATE reconciliation_disagreements SET present_in = " *
                       BFA._sql_quote(new_val) *
                       " WHERE id = $rid")
    true
end

struct XanaduStats
    parsed::Int
    evaluated::Int
    merged_function::Int        # matched an existing BFA functions row
    merged_recon::Int           # matched an existing reconciliation row (e.g. from sboxu import)
    recorded::Int               # new reconciliation row created
    parse_errors::Int           # polynomial parser failed on the expression
end

function import_xanadu_entries!(db::SQLite.DB, entries::Vector{XanaduEntry},
                                 source_tag::AbstractString;
                                 bfa_sha::AbstractString,
                                 max_entries::Union{Nothing, Integer} = nothing)
    parsed = evaluated = merged_function = merged_recon = recorded = parse_errors = 0
    bfa_repo = "bfa@" * bfa_sha
    seen = 0
    for entry in entries
        parsed += 1
        max_entries !== nothing && seen ≥ Int(max_entries) && break
        seen += 1
        modulus = try
            conway_polynomial(entry.n)
        catch
            parse_errors += 1
            @warn "no Conway polynomial for n; skipping" n = entry.n label = entry.label
            continue
        end
        lut = try
            polynomial_to_lut(entry.expr, entry.n, modulus)
        catch err
            parse_errors += 1
            @warn "polynomial parse error" expr = entry.expr exception = err
            continue
        end
        evaluated += 1
        s = SBox{entry.n}(lut)
        sha = lut_sha256_hex(s)
        fid = _fid_by_sha(db, sha)
        if fid !== nothing
            merge_source_repo!(db, fid, source_tag)
            merged_function += 1
        elseif _merge_recon_source!(db, sha, source_tag)
            merged_recon += 1
        else
            record_disagreement!(db;
                n = entry.n,
                lut_sha256 = sha,
                present_in = source_tag,
                absent_from = bfa_repo,
                kind = "only_in_some")
            recorded += 1
        end
    end
    XanaduStats(parsed, evaluated, merged_function, merged_recon, recorded, parse_errors)
end

function _human(io::IO, st::XanaduStats)
    println(io, "[xanadu] parsed=$(st.parsed) evaluated=$(st.evaluated) ",
                "merged_function=$(st.merged_function) ",
                "merged_recon=$(st.merged_recon) ",
                "recorded=$(st.recorded) parse_errors=$(st.parse_errors)")
end

function main(; max_entries::Union{Nothing, Integer} = nothing)
    xanadu_dir = xanadu_path()
    sha = xanadu_short_sha(xanadu_dir)
    tag = "xanadu@" * sha
    bfa_sha = try
        readchomp(`git -C $(pkgdir(BFA)) rev-parse --short HEAD`)
    catch
        "unknown"
    end
    @info "Xanadu APN import" xanadu_dir sha bfa_sha
    listing = joinpath(xanadu_dir, "list_of_APN_functions_for_different_n")
    isfile(listing) || error("BFA: $listing missing")
    entries = parse_xanadu_file(listing)
    db = load_catalog()
    try
        st = import_xanadu_entries!(db, entries, tag;
                                     bfa_sha = bfa_sha,
                                     max_entries = max_entries)
        _human(stdout, st)
    finally
        close(db)
    end
    return nothing
end

function _cli_args()
    args = copy(ARGS)
    max = nothing
    i = 1
    while i ≤ length(args)
        if args[i] == "--max" && i < length(args)
            max = parse(Int, args[i + 1])
            i += 2
        else
            i += 1
        end
    end
    (max,)
end

if !isinteractive()
    max, = _cli_args()
    main(; max_entries = max)
end
