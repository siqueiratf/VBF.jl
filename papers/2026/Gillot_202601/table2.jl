# Implements 5.1 — CCZ equivalence; Table 2.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 5.1 — CCZ equivalence; Table 2
#
# Pseudocode:
#   1. Decode the fourteen printed Code64 roots and verify APN.
#   2. Match roots to a certified 716-class closure and compare degree/Γ columns.
# VBF API used: differential_uniformity, partition_refinement_equivalence, gamma_rank

if !isdefined(@__MODULE__,:gl_kappa)
    include("helpers.jl")
end
const GL_CODE64 = [
    "AAA0AEK2AUIoMcOmASMvUCS5FDB2dfTsAYqG7zfvWa0Mh9NpEOncu0DkXJ8Tx/Un",
    "AAAkA4YEAgw0WO+CAICuE0eK9VPDv/FxASQmrBjtYq4ulvdzUOG47Zx3xLTNIKyU",
    "AAAEAYIUAQg0We+yA4yOU0uKtF/Tvf1BACQWbBDdIa4uFP9zE+mYLphHhLjN4KyE",
    "AAABAoQJAhI82PuyAXDzMDv3z3sb5VGpZVhspNBU1YF9zGTDLQwM30s4UczIuOpK",
    "AAAkAw8oAow8qymaAQSmU06+1NXLLDV5ACQ2zBfJEukqdHB/cOeo7ZFDtXfBgquA",
    "AAAkAYwMA4o0iC6+AwaOEsuiVdnLzjxFAK4WTBbtcuMatHNDQqysHlVTZbT1s2Wo",
    "AAAEAIw8Ao4U2W+aAYOSo4WC1FD3rTtRASg2bBLVUuMy5LRncWy8vtx39frN4Sew",
    "AAAkAQsYAYQsSauCAgim0E6uldXLDrdRACgGzh/JUOka1/pHc+eYbp1jtX/h4SGI",
    "AAAkAosgA4g8CSO6AYK28MaOtNHDTbV5AKwejB/5UmES1vJ3EW+IbhNT9XnpgiWw",
    "AAAkAw8oAIoEC6WKAgaeEUiWlNXbj7tRA64mLBPh0Gky9/R3UO2IbxFLFXP5Iq+4",
    "AAAEAwgUAoQ8OW+iAICO0MWq9dvLHX1hAqoGbBTNgiYe1HtbU2+Y7pxnJDz9oSyM",
    "AAAkAYQsA4o0SyquAIyes8O6td3jT7ZVACY+bBTtUuk6d/97Qa6Un1drpbr9MmeQ",
    "AAAgAIQ4AEY8COKmAwaKM0GelRnzrX5lAyUG7B/lI+ESxPtzgiuMXdJjNLb942+Q",
    "AAAgAoYQAEQ0qGiuAwaKEcG+lRv7LXZlA6cGTBXlgesyZPN7ICOkf9BDNDb1wW+4",
]
const GL_TABLE2_DEGREES = [[1, 66, 18], [1, 66, 18], [1, 66, 24], [1, 9, 3], [1, 69, 16], [0, 10, 15], [1, 15, 3], [1, 63, 27], [1, 15, 3], [1, 1, 1], [1, 5, 7], [1, 66, 24], [1, 1, 1], [1, 69, 22]]
const GL_TABLE2_GAMMA = [1170, 1174, 1170, 1166, 1172, 1300, 1158, 1170, 1170, 1146, 1166, 1168, 1102, 1172]

"""Decode the six-bit-per-character Code64 of GL Table 2, then verify APN."""
function gl_paper_roots()
    alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    roots=[SBox{6}([findfirst(==(c),alphabet)-1 for c in code]) for code in GL_CODE64]
    all(differential_uniformity(F)==2 for F in roots) || error("Code64 convention failed APN validation")
    return roots
end

"""Cross-check the Table 2 root degree distributions against saved certified EA closures."""
function gl_table2(;known=nothing,limit=14,max_nodes=10^6,timeout_seconds=60,
    compute_gamma=false,save_results=false)
    started=time_ns()
    rows=NamedTuple[]
    roots=gl_paper_roots()
    for i in 1:min(limit,14)
        remaining=timeout_seconds-(time_ns()-started)*1e-9
        remaining<=0 && break
        F=roots[i]
        degree_counts=nothing
        label="unresolved"
        certificate=nothing
        if known!==nothing
            for (name,G) in sort!(collect(known.roots);by=first)
                remaining=timeout_seconds-(time_ns()-started)*1e-9
                remaining<=0 && break
                outcome=partition_refinement_equivalence(F,G;relation=:ccz,max_nodes,
                    timeout_seconds=remaining)
                if !isempty(search_solutions(outcome))
                    A=first(search_solutions(outcome))
                    gl_verify_graph_map(F,G,A;relation=:ccz) || error("invalid root match")
                    label=name
                    selected=[R for (R,l) in zip(known.representatives,known.root_labels) if l==name]
                    degree_counts=[count(R->algebraic_degree(R)==d,selected) for d in 2:4]
                    certificate=(;linear_columns=Int.(A.linear.cols),constant=Int(A.constant),
                        source_lut=Int.(F.lut),target_lut=Int.(G.lut))
                    break
                end
            end
        end
        rank=compute_gamma ? gamma_rank(F) : nothing
        push!(rows,(;label=i,matched_source=label,degree_counts,
            degree_agrees=degree_counts==GL_TABLE2_DEGREES[i],gamma_rank=rank,
            gamma_agrees=rank===nothing ? nothing : rank==GL_TABLE2_GAMMA[i],certificate))
    end
    degrees_complete=length(rows)==14 && known!==nothing && known.complete &&
        all(r.degree_counts!==nothing for r in rows)
    complete=degrees_complete && compute_gamma
    r=(;parameters=(;limit,max_nodes,timeout_seconds,compute_gamma),complete,degrees_complete,processed=length(rows),rows,gamma_executed=compute_gamma,
        matches_printed=complete && all(r.degree_agrees && r.gamma_agrees for r in rows),
        source_sha256=known===nothing ? "unavailable" : known.sha256,
        elapsed_seconds=(time_ns()-started)*1e-9,stop_reason=complete ? :none : :partial)
    gl_save("table2",r;save_results)
    return r
end

function gl_table2_report(io::IO=stdout;kwargs...)
    return gl_report("Table 2 — Code64 roots",gl_table2(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_table2_report(limit=1)
end
