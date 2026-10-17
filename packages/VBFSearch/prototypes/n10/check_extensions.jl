# Are the extra ISD extensions of U_8 <= C2(x^3) new classes? Compare sigma_hash.
include(joinpath(@__DIR__, "exchange_n10.jl"))
using VBF, VBFCatalog

lut_of(S) = [reduce(|, (UInt16(isodd(count_ones(s & qx))) << (k-1) for (k, s) in enumerate(S)); init = UInt16(0))
             for qx in (begin w = UInt64(0)
                 for i in 1:n, j in i+1:n
                     bit(x, i) & bit(x, j) == 1 && (w |= UInt64(1) << PAIR[i, j])
                 end; w end for x in 0:(1 << n)-1)]

flats = all_flats()
for e in (3, 9)
    C = comp_basis(gold_lut(e)); b7, V7, _ = best_anchor(C); Vs = span(V7)
    need = 178 - b7
    q8 = first(q for q in span(C) if rank_f2([V7; q]) == 8 && coset_bent(q, Vs) == need)
    sols, L, nf = extensions_isd(vcat(V7, q8), flats; iters = 30_000)
    ref = sigma_hash(SBox{10}(lut_of(C)))
    println("x^$e: ", length(sols), " extensions")
    for S in sols
        G = SBox{10}(lut_of(S))
        println("  delta = ", VBF.differential_uniformity(G), ", same sigma as parent = ", sigma_hash(G) == ref,
                ", bent comps = ", count(is_bent, span(S)) )
    end
end

# Compare the x^3 extensions with the quadratic n = 10 catalog entries.
db = joinpath(VBFCatalog.catalog_data_dir(), "catalog.sqlite")      # BFA_DATA_DIR or <repo>/.cache/vbfcatalog
known = Dict{String,String}()
for line in eachline(`sqlite3 $db "select canonical_name, hex(lut_blob) from functions where n=10 and is_quadratic=1"`)
    name, hx = split(line, '|')
    lut = reinterpret(UInt16, hex2bytes(hx)) |> collect
    known[sigma_hash(SBox{10}(lut))] = name
end
C = comp_basis(gold_lut(3)); b7, V7, _ = best_anchor(C); Vs = span(V7)
q8 = first(q for q in span(C) if rank_f2([V7; q]) == 8 && coset_bent(q, Vs) == 178 - b7)
sols, _, _ = extensions_isd(vcat(V7, q8), flats; iters = 30_000)
sig = [sigma_hash(SBox{10}(lut_of(S))) for S in sols]
println("distinct sigma among x^3 extensions: ", length(unique(sig)), " of ", length(sig))
for s in sig
    println("  catalog match: ", get(known, s, "none"))
end
