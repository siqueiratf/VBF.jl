# Validate switch_full.jl against VBF.switching_neighbors (complete system) on the
# APN functions of the catalog with n = 6 and on Gold x^3 with n = 8. For each
# function: the number of APN neighbours per direction and the multiset of CCZ
# fingerprints of all neighbours must agree. Also reports the run times.
#
# Run from the repository root:
#   julia -t 12 --project=. packages/VBFSearch/prototypes/n10/validate_switch_full.jl
include(joinpath(@__DIR__, "switch_full.jl"))
using VBFCatalog

db = load_catalog()
cases = Any[(r.canonical_name, load_sbox(db, r.id)) for r in list_functions(db; n = 6)]
filter!(c -> VBF.differential_uniformity(c[2]) == 2, cases)
push!(cases, ("gold_x3_n8", load_sbox(db, first(r.id for r in list_functions(db; n = 8) if occursin("Gold", r.canonical_name)))))
allok = true
for (name, F) in cases
    N = typeof(F).parameters[1]
    t1 = @elapsed ref = switching_neighbors(F)
    t2 = @elapsed new = switch_full(Int.(F.lut), N)
    cref = Dict(u => length(g) for (u, g) in enumerate(ref) if !isempty(g))
    cnew = Dict{Int,Int}()
    foreach(((u, _),) -> cnew[u] = get(cnew, u, 0) + 1, new.neighbours)
    fref = sort([ccz_fingerprint_hash(G) for g in ref for G in g])
    fnew = sort([ccz_fingerprint_hash(SBox{N}(G)) for (_, G) in new.neighbours])
    ok = cref == cnew && fref == fnew && isempty(new.capped)
    global allok &= ok
    println(rpad(name, 34), " deg ", VBF.algebraic_degree(F), "  neighbours VBF ", sum(values(cref); init = 0),
            " / new ", length(new.neighbours), "  agree = ", ok, "  (VBF ", round(t1, digits = 1), " s, new ",
            round(t2, digits = 2), " s)")
end
println("all agree = ", allok)
