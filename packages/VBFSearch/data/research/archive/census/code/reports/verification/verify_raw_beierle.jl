# Extra check (beyond Task 1): the beierle2025_n8 side store was imported with
# encode_quadratic(...; verify = false), so nothing verified decode(encode(F)) == F.
# Stream the raw published file (Zenodo 16752428, new_apns.txt; one LUT per line)
# and require decode_quadratic_lut(member i) == LUT on line i, for EVERY line.
# (The importer drops malformed / non-QAPN / duplicate lines; if none were
# dropped, member i corresponds to line i.)
# Usage: julia -t 6 --project=/home/ts/VBF.jl verify_raw_beierle.jl [/path/to/new_apns.txt]
using VBF, VBFCatalog, Printf, SHA
const SQLite = VBFCatalog.SQLite; const DBI = VBFCatalog.DBInterface
raw = isempty(ARGS) ? expanduser("~/.cache/bfa-data/beierle2025/new_apns.txt") : ARGS[1]
function parse_lut!(lut::Vector{Int}, line::AbstractString)   # same grammar as the importer's parse_lut_line!
    k = 0
    for tok in eachsplit(strip(line, ['[', ']', ' ', '\r']), ',')
        k += 1; k > 256 && return false
        lut[k] = parse(Int, strip(tok))
    end
    k == 256
end
store = SQLite.DB(VBFCatalog.corpus_store_path("beierle2025_n8"))
powtab = monomial_power_table(8, 285)
t0 = time(); lines = 0; ok = 0; bad = 0; badparse = 0; firstbad = String[]
bufL = String[]; bufI = Int[]; bufC = Vector{UInt8}[]
st = DBI.execute(store, "SELECT idx, coeffs FROM members ORDER BY idx")
it = iterate(st)
function flushb()
    res = fill(0, length(bufL))     # 1 ok, -1 mismatch, -2 parse failure
    Threads.@threads for j in eachindex(bufL)
        lut = Vector{Int}(undef, 256)
        if !parse_lut!(lut, bufL[j]); res[j] = -2; continue; end
        res[j] = decode_quadratic_lut(bufC[j], 8, 285; powtab = powtab) == lut ? 1 : -1
    end
    for j in eachindex(res)
        res[j] == 1 && (global ok += 1)
        res[j] == -1 && (global bad += 1; length(firstbad) < 10 && push!(firstbad, "member $(bufI[j]) != line $(bufI[j])"))
        res[j] == -2 && (global badparse += 1)
    end
    empty!(bufL); empty!(bufI); empty!(bufC)
end
open(raw) do io
    for line in eachline(io)
        isempty(strip(line)) && continue
        global lines += 1
        if it === nothing
            push!(firstbad, "raw line $lines has no store member"); global bad += 1; continue
        end
        r, s = it
        push!(bufL, line); push!(bufI, Int(r.idx)); push!(bufC, Vector{UInt8}(r.coeffs))
        Int(r.idx) == lines || push!(firstbad, "idx $(r.idx) at line $lines")
        global it = iterate(st, s)
        length(bufL) >= 50_000 && (flushb(); lines % 500_000 == 0 && (println("  $lines lines, $(round(time()-t0))s"); flush(stdout)))
    end
end
flushb()
extra = 0
while it !== nothing; global extra += 1; global it = iterate(st, it[2]); end
@printf("raw file: %s (%d bytes)\nnon-empty lines=%d  LUT-identical=%d  mismatched=%d  unparseable=%d  store members beyond file=%d\n",
        raw, filesize(raw), lines, ok, bad, badparse, extra)
println("first problems: ", isempty(firstbad) ? "none" : join(firstbad, "; "))
@printf("wall %.1fs\n", time() - t0)
