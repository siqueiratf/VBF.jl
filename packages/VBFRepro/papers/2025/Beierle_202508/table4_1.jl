# Table 4.1 — independently compute both documented component-profile orders.
# Reuses VBF.QuadraticProfiles; budget failures are inconclusive, never partial profiles.
include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog
using SHA

function table41_member_profiles(F::SBox{8}; depth::Int=5,
        max_nodes::Int=1_000_000, max_subspaces::Int=100_000)
    is_quadratic_apn(F) || throw(ArgumentError("expected a quadratic APN function"))
    ranks = VBF.QuadraticProfiles.component_ranks(
        VBF.QuadraticProfiles.coeff_matrix_from_lut(F.lut))
    alpha = VBF.QuadraticProfiles.component_alphas(ranks)
    results = Dict{Symbol,Any}()
    for order in (:lex, :bminK)
        try
            value = VBF.QuadraticProfiles.profile_pk(alpha, depth; order,
                max_nodes, max_subspaces)
            results[order] = (; status=:complete, profile=value[1], nmax=value[2])
        catch e
            e isa VBF.QuadraticAPNTree.EnumerationLimitError || rethrow()
            results[order] = (; status=:inconclusive, reason=sprint(showerror, e))
        end
    end
    (; ranks, results)
end

"""
    table41_profiles_report(; corpus="beierleleander2022_n8", indices=[9172,9624,10320], ...)

Compute profile-order controls at the three historical outlier indices. Full
Table 4.1 reproduction requires a reconciled 32,892-class input set and an
exhausted depth-six scan; this driver does not imply that such a set is complete.
Member indices and the side-store SHA-256 identify the precise input version.
"""
function table41_profiles_report(; corpus::String="beierleleander2022_n8",
        indices=[9172,9624,10320], limit::Int=3, depth::Int=5,
        max_nodes::Int=1_000_000, max_subspaces::Int=100_000, io::IO=stdout)
    limit >= 0 || throw(ArgumentError("limit must be nonnegative"))
    db = load_catalog()
    try
        info = corpus_info(db, corpus)
        info === nothing && throw(ArgumentError("unknown corpus $corpus"))
        Int(info.n) == 8 || throw(ArgumentError("expected an eight-bit corpus"))
        selected = first(collect(indices), limit)
        all(i -> 1 <= i <= Int(info.member_count), selected) ||
            throw(ArgumentError("member index outside corpus"))
        rows = NamedTuple[]
        for index in selected
            value = table41_member_profiles(corpus_function(db, corpus, index);
                depth, max_nodes, max_subspaces)
            push!(rows, (; index, value.results))
        end
        input_sha256 = bytes2hex(open(SHA.sha256, VBFCatalog.corpus_store_path(corpus)))
        print_section("Table 4.1 — profile-order controls", io)
        print_kv("input", "$corpus SHA256=$input_sha256", io)
        print_kv("depth / indices", "$depth / $selected", io)
        for row in rows
            print_kv("member $(row.index)", row.results, io)
        end
        print_kv("guarantee", "complete entries are exact for their stated order; budget hits are inconclusive", io)
        print_kv("published table", "unresolved: input reconciliation and full depth-six enumeration required", io)
        (; corpus, input_sha256, depth, rows, published_table_reproduced=false)
    finally
        close(db)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    table41_profiles_report()
end
