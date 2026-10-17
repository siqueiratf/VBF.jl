# Compare the n = 10 candidate (x^3 exchange extension) with the repo's n = 10 proposals.
include(joinpath(@__DIR__, "check_extensions.jl"))     # defines sols, sig, lut_of, known
include(joinpath(@__DIR__, "..", "..", "..", "VBFRepro", "tools", "catalog_proposals.jl"))
cand = setdiff(unique(sig), [sigma_hash(SBox{10}(lut_of(comp_basis(gold_lut(3)))))])
println("candidate sigma classes: ", length(cand))
for r in catalog_proposal_candidates()
    r.F isa SBox{10} || continue
    s = sigma_hash(r.F)
    println(rpad(r.name, 24), " APN=", VBF.differential_uniformity(r.F) == 2, "  matches candidate = ", s in cand)
end
