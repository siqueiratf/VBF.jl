# Section 3 — conclusive pairwise distinction of the exact Table 2 representatives.
# Distinct ortho-derivative signatures imply CCZ-inequivalence for quadratic APNs.
# Equal signatures remain unresolved; no comparison to all known constructions follows.
include(joinpath(@__DIR__, "section3.jl"))

function family_separation_report(; io::IO=stdout)
    rows = NamedTuple[]
    for row in table2_n12_instances()
        verified = is_quadratic_apn(row.sbox)
        verified || error("Table 2 representative $(row.family) is not quadratic APN")
        push!(rows, (; family=row.family, signature=sigma_key(row.sbox)))
    end
    pairs = [(; first=rows[i].family, second=rows[j].family,
        status=rows[i].signature != rows[j].signature ? :proven_ccz_inequivalent : :unresolved)
        for i in eachindex(rows) for j in (i+1):length(rows)]
    print_section("Exact n=12 Table 2 representative comparisons", io)
    for pair in pairs
        print_kv("$(pair.first) / $(pair.second)", pair.status, io)
    end
    print_kv("guarantee", "distinct full invariant tuples certify these pairs only; no global novelty claim", io)
    (; rows, pairs, all_distinguished=all(p.status == :proven_ccz_inequivalent for p in pairs))
end

if abspath(PROGRAM_FILE) == @__FILE__
    family_separation_report()
end
