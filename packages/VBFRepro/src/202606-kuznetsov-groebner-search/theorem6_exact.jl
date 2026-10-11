# Positive equivalence follows from a replayed affine graph map, independently
# checked at all 256 points. No signature equality or negative timeout is used.
using VBF, VBFCatalog, TOML
import VBFCatalog: SQLite
include(joinpath(@__DIR__, "helpers.jl"))
using VBFSearch.DiscoveryEvidence: GraphWitnesses
const DB_EDELPOTT = "edelpott2009_n8"
const EXACT_PAIRS = ((:class_a, 18), (:class_b, 5), (:class_c, 3), (:class_d, 4))
const EXACT_WITNESSES = joinpath(@__DIR__, "test", "fixtures", "edel_pott_ea_witnesses.toml")

"""
Replay saved exact EA witnesses against the current paper representatives and
tracked Edel-Pott corpus. `recover=true` instead runs a bounded native search;
a budget hit returns `equivalent=missing`, never a negative decision. Positive
witnesses are checked with the VBF graph-map replay.
"""
function theorem6_exact_run(; recover::Bool = false, timeout_seconds::Real = 60,
                            max_nodes::Int = 10^6, witness_path = EXACT_WITNESSES)
    reps = representative_sboxes()
    fixtures = recover ? nothing : TOML.parsefile(witness_path)
    db = SQLite.DB(VBFCatalog.catalog_path())
    try
        map(EXACT_PAIRS) do (nm, i)
            F = getfield(reps, nm)
            G = VBFCatalog.corpus_function(db, DB_EDELPOTT, i)
            cols = Int[]; constant = 0; equivalent = missing; status = :inconclusive
            seconds = @elapsed if recover
                result = partition_refinement_equivalence(F, G; relation = :ea,
                    timeout_seconds, max_nodes, algorithm = :optimized)
                if result isa Found
                    A = only(search_solutions(result))
                    cols = Int.(A.linear.cols); constant = Int(A.constant)
                    equivalent = GraphWitnesses.verify_ea_witness(F.lut, G.lut, cols, constant)
                    equivalent || error("invalid recovered EA witness for $nm")
                    status = :verified_witness
                elseif result isa Exhausted
                    equivalent = false; status = :exhausted
                end
            else
                row = fixtures[String(nm)]
                row["member"] == i || error("reference member changed")
                row["candidate_lut"] == Int.(F.lut) || error("paper representative changed")
                row["reference_lut"] == Int.(G.lut) || error("reference corpus changed")
                cols = row["columns"]; constant = row["constant"]
                equivalent = GraphWitnesses.verify_ea_witness(F.lut, G.lut, cols, constant)
                equivalent || error("invalid saved EA witness for $nm")
                status = :verified_witness
            end
            (; nm, member = i, equivalent, status, seconds, columns = cols, constant)
        end |> collect
    finally
        SQLite.close(db)
    end
end

function theorem6_exact_report(io::IO = stdout; kwargs...)
    print_section("Theorem 6 — independently replayed EA witnesses", io)
    rows = theorem6_exact_run(; kwargs...)
    for r in rows
        print_kv(String(r.nm), "$(r.status): Edel-Pott 2009 member $(r.member)", io)
    end
    verified = all(r.equivalent === true for r in rows)
    print_kv("Conclusion", verified ?
        "All four representatives are EA-equivalent, hence CCZ-equivalent, to Edel-Pott 2009 functions; they are not new equivalence classes." :
        "Some comparisons remain unresolved or disagree; do not infer novelty.", io)
    rows
end
if abspath(PROGRAM_FILE) == @__FILE__
    theorem6_exact_report()
end
