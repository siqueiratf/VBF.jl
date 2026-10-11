# Example 4.2 is separated from Gold but belongs to a class published in 2009.
# Replay an explicit EA graph map with a VBF graph-map replay.
using VBF, VBFCatalog, TOML
include(joinpath(@__DIR__, "helpers.jl"))
using VBFSearch.DiscoveryEvidence: GraphWitnesses

function prior_art_witness(; recover::Bool = false, timeout_seconds::Real = 60, max_nodes::Int = 10^6)
    n = 8; m = PAPER_MODULUS_8; alpha = 2
    beta = gf_pow(alpha, 85, n; modulus = m)
    candidate = [gf_pow(x, 3, n; modulus = m) ⊻
        gf_mul(gf_mul(beta, gf_trace(x, n; modulus = m), n; modulus = m),
               gf_relative_trace(x, n, 2; modulus = m), n; modulus = m) for x in 0:255]
    # Budaghyan--Carlet--Leander 2009 eq. (6), a=alpha:
    # x^3 + a^(-1) Tr(a^3 x^9), the same field modulus as Example 4.2.
    a_inv = gf_inv(alpha, n; modulus = m)
    a3 = gf_pow(alpha, 3, n; modulus = m)
    reference = [gf_pow(x, 3, n; modulus = m) ⊻ gf_mul(a_inv,
        gf_trace(gf_mul(a3, gf_pow(x, 9, n; modulus = m), n; modulus = m), n; modulus = m),
        n; modulus = m) for x in 0:255]
    if recover
        outcome = partition_refinement_equivalence(SBox(candidate), SBox(reference);
            relation = :ea, timeout_seconds, max_nodes, algorithm = :optimized)
        outcome isa Found || return (; verified = missing, outcome, candidate, reference)
        A = only(search_solutions(outcome))
        columns, constant = Int.(A.linear.cols), Int(A.constant)
        verified = GraphWitnesses.verify_ea_witness(candidate, reference, columns, constant)
        verified || error("invalid recovered prior-art EA witness")
        return (; verified, candidate, reference, columns, constant)
    end
    row = TOML.parsefile(joinpath(@__DIR__, "test", "fixtures", "bcl2009_ea_witness.toml"))
    row["candidate_lut"] == candidate || error("Example 4.2 changed")
    row["reference_lut"] == reference || error("2009 equation changed")
    verified = GraphWitnesses.verify_ea_witness(candidate, reference, row["columns"], row["constant"])
    verified || error("invalid prior-art EA witness")
    (; verified, candidate, reference, columns = row["columns"], constant = row["constant"])
end

"""
Verify Example 4.2 against the **primary-source** Edel--Pott 2009 Table 9
entry 1.3, then bind that row to its alternate polynomial and corpus member.
The member index is not inferred from Table 9 numbering: the alternate LUT
matches corpus member 5 pointwise, and a second EA witness relates the primary
formula to that alternate representative.
"""
function edel_pott_prior_art_witness(; recover::Bool = false,
        timeout_seconds::Real = 10, max_nodes::Int = 10^6)
    n = 8; m = 285; u = 2 # Edel--Pott Table 2 field and primitive element.
    candidate = prior_art_witness().candidate
    primary = [gf_pow(x, 3, n; modulus = m) ⊻ gf_mul(u,
        gf_trace(gf_mul(gf_pow(u, 63, n; modulus = m), gf_pow(x, 3, n; modulus = m), n; modulus = m) ⊻
                 gf_mul(gf_pow(u, 252, n; modulus = m), gf_pow(x, 9, n; modulus = m), n; modulus = m),
                 n; modulus = m), n; modulus = m) for x in 0:255]
    alternate = terms_to_lut([(1,3), (gf_pow(u,245,n; modulus=m),33),
        (gf_pow(u,183,n; modulus=m),66), (gf_pow(u,21,n; modulus=m),144)], n, m)
    row = TOML.parsefile(joinpath(@__DIR__, "test", "fixtures", "bcl2009_ea_witness.toml"))["edel_pott_1_3"]
    row["candidate_lut"] == candidate || error("Example 4.2 changed")
    row["reference_lut"] == primary || error("Edel--Pott primary formula changed")
    corpus_row = row["corpus_witness"]
    member = Int(corpus_row["member"])
    db = VBFCatalog.load_catalog()
    corpus = try
        Int.(VBFCatalog.corpus_function(db, "edelpott2009_n8", member).lut)
    finally
        VBFCatalog.SQLite.close(db)
    end
    corpus == alternate == corpus_row["reference_lut"] || error("Edel--Pott alternate polynomial/corpus binding changed")
    function verify_map(f, g, saved)
        cols, constant = saved["columns"], Int(saved["constant"])
        if recover
            result = partition_refinement_equivalence(SBox(f), SBox(g);
                relation = :ea, timeout_seconds, max_nodes, algorithm = :optimized)
            result isa Found || return (; verified = missing, outcome = result, columns = Int[], constant = 0)
            A = only(search_solutions(result))
            cols, constant = Int.(A.linear.cols), Int(A.constant)
        end
        verified = GraphWitnesses.verify_ea_witness(f, g, cols, constant)
        verified || error("invalid Edel--Pott EA witness")
        (; verified, columns = cols, constant)
    end
    to_primary = verify_map(candidate, primary, row)
    to_corpus = verify_map(primary, corpus, corpus_row)
    verified = to_primary.verified === true && to_corpus.verified === true ? true : missing
    (; verified, candidate, primary, alternate, corpus, member,
       source = "Edel--Pott 2009 Table 9 entry 1.3", to_primary, to_corpus)
end

function prior_art_report(io::IO = stdout)
    r = prior_art_witness()
    print_section("Example 4.2 — prior art", io)
    print_check(io, "explicit EA graph map to Budaghyan--Carlet--Leander (2009), eq. (6), a=alpha, modulus=285", r.verified)
    ep = edel_pott_prior_art_witness()
    print_check(io, "explicit EA graph map to Edel--Pott (2009), Table 9 entry 1.3; alternate polynomial equals corpus member $(ep.member)", ep.verified)
    print_kv(io, "guarantee", "EA-equivalent, hence CCZ-equivalent, to a 2009 function; separation from Gold does not imply novelty")
    merge(r, (; edel_pott = ep))
end
if abspath(PROGRAM_FILE) == @__FILE__
    prior_art_report()
end
