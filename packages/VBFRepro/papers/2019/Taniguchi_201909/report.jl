using VBF

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem3.jl"))
include(joinpath(@__DIR__, "theorem4.jl"))
include(joinpath(@__DIR__, "fact_helleseth_kholosha.jl"))
include(joinpath(@__DIR__, "section2_carlet_zhou_pott.jl"))
include(joinpath(@__DIR__, "theorem5_presemifield.jl"))

function paper_report(io::IO = stdout)
    print_header(io)

    section2_carlet_zhou_pott_report(io)
    fact_helleseth_kholosha_report(io)
    theorem3_report(io)
    theorem4_report(io)
    theorem5_presemifield_report(io)

    print_section(io, "Γ-rank table (loaded from paper — computed via Magma)")
    print_kv(io, "Theorem 1 [Carlet]", "13200")
    print_kv(io, "Corollary 1 [Zhou-Pott, i=2]", "13642")
    print_kv(io, "Theorem 3 [a≠0, b⁵=1]", "13700")
    print_kv(io, "Theorem 3 [a≠0, b⁵≠1]", "13798")
    println(io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_report()
end
