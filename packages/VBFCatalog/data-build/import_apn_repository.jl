# Imports the `APN-Repository` n=6..9 APN catalog into the BFA catalog.
#
# APN-Repository stores each entry in Parquet with three relevant
# columns:
#
#   field_n   int      — n
#   irr_poly  string   — irreducible polynomial as a sum-of-monomials
#                        string, e.g. "x^6 + x^4 + x^3 + x + 1"
#   poly      string   — JSON list of [ksi_power, X_power] monomials,
#                        e.g. "[[0, 3]]" for x^3 with coefficient ksi^0 = 1
#
# We materialise each entry to a length-2^n LUT using the per-row
# irreducible polynomial (this is the *one source that records its own
# field convention* — sboxU and Xanadu force us to guess), so the LUT
# we compute matches what APN-Repository would compute. SHA the LUT,
# then merge into the catalog under the same rules as the other importers.
#
# Usage:
#     # uses BFA_APN_REPO_PATH env var or default ~/sboxU/APN-Repository
#     julia --project=. data-build/import_apn_repository.jl
#     julia --project=. data-build/import_apn_repository.jl --max 5

using VBF
using VBFCatalog
import SQLite
import DBInterface
import JSON3
import Parquet2
import Tables

include(joinpath(@__DIR__, "_polynomial_parser.jl"))

const _DEFAULT_APN_REPO_PATHS = (
    get(ENV, "BFA_APN_REPO_PATH", ""),
    "/home/zambonin/APN.jl/cma029@APN-Repository",   # current layout (2026-05-28)
    joinpath(homedir(), "APN.jl", "cma029@APN-Repository"),
    joinpath(homedir(), "sboxU", "APN-Repository"),   # legacy fallbacks
    "/home/zambonin/sboxU/APN-Repository",
)

function apn_repo_path()
    for p in _DEFAULT_APN_REPO_PATHS
        isempty(p) && continue
        isdir(joinpath(p, "database", "apn")) && return p
    end
    error("BFA: cannot find APN-Repository; set BFA_APN_REPO_PATH")
end

function apn_repo_short_sha(path::AbstractString)
    try
        return readchomp(`git -C $path rev-parse --short HEAD`)
    catch
        return "unknown"
    end
end

# ---------------------------------------------------------------------------

"""
    parse_irr_poly_string(s) -> Int

Convert a sum-of-monomials string like `"x^6 + x^4 + x^3 + x + 1"` to
its bit-pattern integer representation (here, `0b1011011 = 91`). The
returned value is the polynomial *including* its leading `x^n` term,
suitable for `gf_mul(...; modulus = …)`.
"""
function parse_irr_poly_string(s::AbstractString)
    bits = 0
    for term in split(strip(s), r"\s*\+\s*")
        t = strip(term)
        if t == "1"
            bits |= 1
        elseif t == "x" || t == "X"
            bits |= 2
        else
            m = match(r"^[xX]\^(\d+)$", t)
            m === nothing &&
                throw(ArgumentError("parse_irr_poly_string: unexpected term $(repr(t)) in $(repr(s))"))
            bits |= 1 << parse(Int, m.captures[1])
        end
    end
    bits
end

"""
    poly_json_to_lut(json_str, n, modulus; ksi=2) -> Vector{Int}

Evaluate a polynomial described by APN-Repository's `poly` JSON.

The JSON shape is a list of `[ksi_power, X_power]` pairs:
`"[[0, 3], [11, 6], [1, 9]]"` ≡ `1·X^3 + ksi^11·X^6 + ksi^1·X^9`.
"""
function poly_json_to_lut(json_str::AbstractString, n::Integer, modulus::Integer;
                           ksi::Integer = 2)
    pairs = JSON3.read(String(json_str))
    # Each pair: [ksi_power, X_power]
    len = 1 << Int(n)
    out = zeros(Int, len)
    n_int   = Int(n)
    mod_int = Int(modulus)
    ksi_int = Int(ksi)
    for x in 0:len - 1
        acc = 0
        for pair in pairs
            ksi_pow = Int(pair[1])
            x_pow   = Int(pair[2])
            coef = gf_pow(ksi_int, ksi_pow, n_int; modulus = mod_int)
            acc ⊻= gf_mul(coef, gf_pow(x, x_pow, n_int; modulus = mod_int),
                          n_int; modulus = mod_int)
        end
        out[x + 1] = acc
    end
    out
end

# ---------------------------------------------------------------------------

function _fid_by_sha(db::SQLite.DB, sha::AbstractString)
    sql = "SELECT id FROM functions WHERE lut_sha256 = " *
          VBFCatalog._sql_quote(String(sha)) * " LIMIT 1"
    for r in DBInterface.execute(db, sql)
        return Int(r.id)
    end
    nothing
end

function _merge_recon_source!(db::SQLite.DB, sha::AbstractString, source_tag::AbstractString)
    cur = ""
    rid = 0
    sql = "SELECT id, present_in FROM reconciliation_disagreements WHERE lut_sha256 = " *
          VBFCatalog._sql_quote(String(sha)) * " LIMIT 1"
    for r in DBInterface.execute(db, sql)
        rid = Int(r.id)
        cur = String(r.present_in)
    end
    rid == 0 && return false
    parts = split(cur, '|')
    String(source_tag) in parts && return true
    new_val = cur * "|" * String(source_tag)
    SQLite.execute(db, "UPDATE reconciliation_disagreements SET present_in = " *
                       VBFCatalog._sql_quote(new_val) *
                       " WHERE id = $rid")
    true
end

struct APNRepoStats
    parsed::Int
    evaluated::Int
    merged_function::Int
    merged_recon::Int
    recorded::Int
    parse_errors::Int
end

function import_apn_repo_file!(db::SQLite.DB, parquet_path::AbstractString,
                                source_tag::AbstractString;
                                bfa_sha::AbstractString,
                                max_rows::Union{Nothing, Integer} = nothing)
    parsed = evaluated = merged_function = merged_recon = recorded = parse_errors = 0
    bfa_repo = "bfa@" * bfa_sha
    ds = Parquet2.Dataset(parquet_path)
    rows = Tables.rows(ds)
    seen = 0
    for row in rows
        parsed += 1
        max_rows !== nothing && seen ≥ Int(max_rows) && break
        seen += 1
        n = Int(row.field_n)
        modulus = try
            parse_irr_poly_string(String(row.irr_poly))
        catch err
            parse_errors += 1
            @warn "irr_poly parse error" n parquet_path exception = err
            continue
        end
        lut = try
            poly_json_to_lut(String(row.poly), n, modulus)
        catch err
            parse_errors += 1
            @warn "poly JSON parse error" n poly = row.poly exception = err
            continue
        end
        evaluated += 1
        s = SBox{n}(lut)
        sha = lut_sha256_hex(s)
        fid = _fid_by_sha(db, sha)
        if fid !== nothing
            merge_source_repo!(db, fid, source_tag)
            merged_function += 1
        elseif _merge_recon_source!(db, sha, source_tag)
            merged_recon += 1
        else
            record_disagreement!(db;
                n = n,
                lut_sha256 = sha,
                present_in = source_tag,
                absent_from = bfa_repo,
                kind = "only_in_some")
            recorded += 1
        end
    end
    APNRepoStats(parsed, evaluated, merged_function, merged_recon, recorded, parse_errors)
end

function _human(io::IO, st::APNRepoStats, label::AbstractString)
    println(io, "[$label] parsed=$(st.parsed) evaluated=$(st.evaluated) ",
                "merged_function=$(st.merged_function) ",
                "merged_recon=$(st.merged_recon) ",
                "recorded=$(st.recorded) parse_errors=$(st.parse_errors)")
end

function main(; max_rows::Union{Nothing, Integer} = nothing)
    repo_dir = apn_repo_path()
    sha = apn_repo_short_sha(repo_dir)
    tag = "apnrepo@" * sha
    bfa_sha = try
        readchomp(`git -C $(pkgdir(VBF)) rev-parse --short HEAD`)
    catch
        "unknown"
    end
    @info "APN-Repository import" repo_dir sha bfa_sha
    db = load_catalog()
    try
        apn_dir = joinpath(repo_dir, "database", "apn")
        for fname in sort(readdir(apn_dir))
            endswith(fname, ".parquet") || continue
            st = import_apn_repo_file!(db, joinpath(apn_dir, fname), tag;
                                        bfa_sha = bfa_sha, max_rows = max_rows)
            _human(stdout, st, fname)
        end
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
    main(; max_rows = max)
end
