# Task 3 — the 553 claimed-new functions (all40_new.tsv).
# Re-decode each (QK.lut as in analyze.jl AND an independent bit-level decoder),
# confirm algebraic degree 2, differential uniformity 2, recompute sigma_hash ==
# stored hash, confirm absence from the index by direct SQL (any n, any source),
# and confirm pairwise-distinct hashes.
# Usage: julia --project=/home/ts/VBF.jl verify_new553.jl
using VBF, VBFCatalog, Printf
include(joinpath(@__DIR__, "..", "qknuth.jl")); using .QK
const DBI = VBFCatalog.DBInterface
lines = collect(eachline(joinpath(@__DIR__, "..", "all40_new.tsv")))
function Cmat(coeffs)
    length(coeffs) == 56 || error("bad coeffs length")
    c = [parse(UInt16, coeffs[2k-1:2k], base = 16) for k in 1:28]
    C = zeros(UInt16, 8, 8); t = 0
    for a in 1:8, b in a+1:8
        t += 1; C[a, b] = c[t]; C[b, a] = c[t]
    end
    C, c
end
# independent decoder straight from the stated definition: F(x) = XOR_{i<j} x_i x_j c_ij, x_1 = LSB
function lut_direct(c)
    out = zeros(UInt8, 256)
    for x in 0:255
        v = 0x00; t = 0
        for i in 1:8, j in i+1:8
            t += 1
            ((x >> (i-1)) & 1 == 1 && (x >> (j-1)) & 1 == 1) && (v ⊻= UInt8(c[t]))
        end
        out[x+1] = v
    end
    out
end
idx = VBFCatalog._open_sigma_index()
nrow = 0; ok_dec = 0; ok_deg = 0; ok_du = 0; ok_hash = 0; absent = 0; absent_n8 = 0
hashes = String[]; coeffset = Set{String}(); bad = String[]
t0 = time()
for l in lines
    global nrow += 1
    h0, co = split(l, '\t'); h0 = String(h0); co = String(co)
    push!(hashes, h0); push!(coeffset, co)
    C, c = Cmat(co)
    L1 = UInt8.(QK.lut(C, 8)); L2 = lut_direct(c)
    L1 == L2 ? (global ok_dec += 1) : push!(bad, "$h0 decode_disagree")
    F = SBox{8}(L1)
    algebraic_degree(F) == 2 ? (global ok_deg += 1) : push!(bad, "$h0 degree=$(algebraic_degree(F))")
    du = differential_uniformity(F)
    du == 2 ? (global ok_du += 1) : push!(bad, "$h0 du=$du")
    h = VBFCatalog.sigma_hash(F)
    h == h0 ? (global ok_hash += 1) : push!(bad, "$h0 recomputed=$h")
    c_all = first(DBI.execute(idx, "SELECT COUNT(*) c FROM ccz_sigma_index WHERE sigma_hash = '$h0'")).c
    c_n8 = first(DBI.execute(idx, "SELECT COUNT(*) c FROM ccz_sigma_index WHERE n = 8 AND sigma_hash = '$h0'")).c
    c_all == 0 ? (global absent += 1) : push!(bad, "$h0 present_in_index rows=$c_all")
    c_n8 == 0 && (global absent_n8 += 1)
end
# sanity: the SQL lookup does find hashes that ARE indexed (positive control of the query itself)
pc = [String(r.sigma_hash) for r in DBI.execute(idx, "SELECT sigma_hash FROM ccz_sigma_index WHERE n = 8 ORDER BY RANDOM() LIMIT 5")]
pc_found = count(h -> first(DBI.execute(idx, "SELECT COUNT(*) c FROM ccz_sigma_index WHERE sigma_hash = '$h'")).c > 0, pc)
@printf("lines=%d decoders_agree=%d degree2=%d du2=%d hash_matches_stored=%d absent_from_index(any n)=%d absent_n8=%d\n",
        nrow, ok_dec, ok_deg, ok_du, ok_hash, absent, absent_n8)
@printf("distinct hashes=%d distinct coeff strings=%d\n", length(unique(hashes)), length(coeffset))
@printf("query positive control: %d/5 random indexed hashes found by the same SQL\n", pc_found)
println("problems: ", isempty(bad) ? "none" : join(bad, "; "))
@printf("wall %.1fs\n", time() - t0)
