# Audit F061: the former 61-row gamma/delta CSV was not Table 1 of this
# publication. The actual Table 1 has nine LE-automorphism rows and six
# extended-Walsh columns W0..W5, with old/new counts in parentheses.
include(joinpath(@__DIR__, "helpers.jl"))

function table1_status(io::IO = stdout; kwargs...)
    print_section("Table 1 — reconstruction status", io)
    print_kv("status", "UNSUPPORTED: LE-automorphism/Walsh cross-tabulation and old/new membership not reconstructed", io)
    print_kv("required", "original dataset, per-instance LE class assignments, and the historical 8192-instance comparison set", io)
    (; status = :unsupported, all_ok = false)
end
# Historical make targets remain explicit unsupported reports; no foreign table
# or loaded publication value is treated as independently computed evidence.
check_ranks(io::IO = stdout; kwargs...) = table1_status(io; kwargs...)
check_walsh(io::IO = stdout; kwargs...) = table1_status(io; kwargs...)
multiplier_group_order(io::IO = stdout; kwargs...) = table1_status(io; kwargs...)
if abspath(PROGRAM_FILE) == @__FILE__
    table1_status()
end
