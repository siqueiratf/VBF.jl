# Imports sboxU's APN function database into the BFA catalog.
#
# Reads the Python LUT literals in
# `sboxU/sboxU/scripts/apnDB/{BeierleLeander, firstQAM, secondQAM, apn_8bit_BLP22}.py`,
# extracts each LUT, computes its SHA-256, and:
#
#   - if the SHA already exists in the BFA `functions` table:
#       merge "sboxu@<sha>" into the row's `source_repo` pipe-list;
#   - else:
#       insert a row into `reconciliation_disagreements` with
#       `present_in = "sboxu@<sha>"`, `absent_from = "bfa@<sha>"`,
#       `kind = "only_in_some"`, and the LUT's SHA-256 in `lut_sha256`.
#
# This is a *one-off* developer-time step. The BFA package never depends
# on sboxU at runtime; only this script reads from sboxU's checkout.
#
# Usage:
#     # uses BFA_SBOXU_PATH env var or default ~/sboxU
#     julia --project=. data-build/import_sboxu_apn.jl
#     julia --project=. data-build/import_sboxu_apn.jl --max 200

using VBF
using VBFCatalog
import SQLite
import DBInterface

const _DEFAULT_SBOXU_PATHS = (
    get(ENV, "BFA_SBOXU_PATH", ""),
    "/home/zambonin/APN.jl/lpp-crypto@sboxU",   # current layout (2026-05-28)
    joinpath(homedir(), "APN.jl", "lpp-crypto@sboxU"),
    joinpath(homedir(), "sboxU"),               # legacy fallbacks
    "/home/zambonin/sboxU",
)

"""
    sboxu_path() -> String

Resolve the on-disk location of the sboxU checkout. Honoured in order:
`BFA_SBOXU_PATH`, `~/sboxU`, `/home/zambonin/sboxU`. Throws if none
exist.
"""
function sboxu_path()
    for p in _DEFAULT_SBOXU_PATHS
        isempty(p) && continue
        isdir(p) && return p
    end
    error("BFA: cannot find sboxU; set BFA_SBOXU_PATH or pass --sboxu-path")
end

"""
    sboxu_short_sha(path) -> String

`git -C path rev-parse --short HEAD`; returns "unknown" if git fails.
"""
function sboxu_short_sha(path::AbstractString)
    try
        return readchomp(`git -C $path rev-parse --short HEAD`)
    catch
        return "unknown"
    end
end

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
function parse_apn_lut_file(path::AbstractString; max_luts::Union{Nothing, Integer} = nothing)
    text = read(path, String)
    luts = Vector{Int}[]
    # Match `[ … ]` where the body contains only integer literals
    # (decimal or hex) separated by commas / whitespace. The outer
    # `all_funcs = [` list does not match because its body contains
    # the `[` and `]` characters of the inner lists.
    pattern = r"\[((?:\s*(?:0[xX][0-9a-fA-F]+|\d+)\s*,?\s*)+)\]"
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
    if startswith(s2, "0x") || startswith(s2, "0X")
        return parse(Int, s2[3:end]; base = 16)
    else
        return parse(Int, s2)
    end
end

"""
    bfa_function_id_by_sha(db::SQLite.DB, sha::AbstractString) -> Union{Int, Nothing}
"""
function bfa_function_id_by_sha(db::SQLite.DB, sha::AbstractString)
    sql = "SELECT id FROM functions WHERE lut_sha256 = " *
          VBFCatalog._sql_quote(String(sha)) * " LIMIT 1"
    for r in DBInterface.execute(db, sql)
        return Int(r.id)
    end
    nothing
end

"""
    seen_recon_sha(db::SQLite.DB, sha::AbstractString) -> Bool

`true` iff `reconciliation_disagreements` already has a row for `sha`
(so reruns of the importer don't duplicate rows).
"""
function seen_recon_sha(db::SQLite.DB, sha::AbstractString)
    sql = "SELECT 1 FROM reconciliation_disagreements WHERE lut_sha256 = " *
          VBFCatalog._sql_quote(String(sha)) * " LIMIT 1"
    for _ in DBInterface.execute(db, sql); return true; end
    false
end

struct ImportStats
    parsed::Int                # total LUTs parsed
    merged::Int                # LUTs that matched an existing BFA function (source_repo updated)
    recorded::Int              # LUTs added as new reconciliation rows
    already_recorded::Int      # LUTs whose SHA was already in reconciliation_disagreements
    parse_skipped::Int         # LUTs whose length wasn't a power of 2
end

function _human(io, st::ImportStats, label)
    println(io, "[$label] parsed=$(st.parsed) merged=$(st.merged) recorded=$(st.recorded) ",
                "already_recorded=$(st.already_recorded) parse_skipped=$(st.parse_skipped)")
end

"""
    import_sboxu_file!(db, path, source_tag; bfa_sha, max_luts = nothing) -> ImportStats

Run one source file through the merge/record pipeline.
"""
function import_sboxu_file!(db::SQLite.DB, path::AbstractString, source_tag::AbstractString;
                             bfa_sha::AbstractString,
                             max_luts::Union{Nothing, Integer} = nothing)
    parsed = merged = recorded = already_recorded = parse_skipped = 0
    bfa_repo = "bfa@" * bfa_sha
    for lut in parse_apn_lut_file(path; max_luts = max_luts)
        parsed += 1
        len = length(lut)
        n = trailing_zeros(len)
        if 1 << n != len || n < 1 || n > 16
            parse_skipped += 1
            continue
        end
        # construct an SBox; bail out cleanly if the LUT has out-of-range entries
        s = try
            SBox{n}(lut)
        catch
            parse_skipped += 1
            continue
        end
        sha = lut_sha256_hex(s)
        fid = bfa_function_id_by_sha(db, sha)
        if fid !== nothing
            merge_source_repo!(db, fid, source_tag)
            merged += 1
        elseif seen_recon_sha(db, sha)
            already_recorded += 1
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
    ImportStats(parsed, merged, recorded, already_recorded, parse_skipped)
end

"""
    main(; max_luts_per_file = nothing) -> Nothing

Run the full sboxU import against the committed catalog. Idempotent:
re-running merges no duplicate sources and adds no duplicate
reconciliation rows.
"""
function main(; max_luts_per_file::Union{Nothing, Integer} = nothing)
    sboxu_dir = sboxu_path()
    sha = sboxu_short_sha(sboxu_dir)
    tag = "sboxu@" * sha
    bfa_sha = try readchomp(`git -C $(pkgdir(VBF)) rev-parse --short HEAD`) catch; "unknown" end
    @info "sboxU import" sboxu_dir sha bfa_sha
    db = load_catalog()
    try
        for fname in ("BeierleLeander.py", "firstQAM.py", "secondQAM.py", "apn_8bit_BLP22.py")
            full = joinpath(sboxu_dir, "sboxU", "scripts", "apnDB", fname)
            if !isfile(full)
                @warn "skipping (file missing)" path=full
                continue
            end
            st = import_sboxu_file!(db, full, tag;
                                     bfa_sha = bfa_sha,
                                     max_luts = max_luts_per_file)
            _human(stdout, st, fname)
        end
    finally
        close(db)
    end
    return nothing
end

# --- CLI entry point --------------------------------------------------------

function _cli_args()
    args = copy(ARGS)
    max = nothing
    i = 1
    while i <= length(args)
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
    main(; max_luts_per_file = max)
end
