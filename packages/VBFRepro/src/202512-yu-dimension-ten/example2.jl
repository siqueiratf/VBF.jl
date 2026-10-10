# Implements Example 2 — n=5, RC/CR/ID verification
# Paper: Yu, Li, Ichanska, Kaleyski (2025)
# Section: 3.3 Algorithm to determine QAM, Example 2
#
# Pseudocode:
#   n=5: CR=(1,3,5,7,11,15,31), IDlen=7
#   ID = (0 1 1 2 2 4 6)
#        (1 2 3 3 4 4 5)
# VBF API used: (none beyond algorithm1)

include(joinpath(@__DIR__, "algorithm1.jl"))

function example2_report(io::IO = stdout)
    print_section(io, "Example 2: n=5, cyclic representatives and index array")

    n   = 5
    cr  = get_cyclic_reps(n)
    id  = get_indices(n, cr)

    paper_cr = [1, 3, 5, 7, 11, 15, 31]
    print_check(io, "CR matches paper: (1,3,5,7,11,15,31)", cr == paper_cr)
    print_kv(io, "CR", cr)
    print_kv(io, "IDlen (K)", length(cr))
    print_check(io, "IDlen = 7", length(cr) == 7)

    paper_id1 = [0, 1, 1, 2, 2, 4, 6]
    paper_id2 = [1, 2, 3, 3, 4, 4, 5]
    print_check(io, "ID[1,:] matches paper: (0,1,1,2,2,4,6)", id[1,:] == paper_id1)
    print_check(io, "ID[2,:] matches paper: (1,2,3,3,4,4,5)", id[2,:] == paper_id2)
    print_kv(io, "ID[1,:]", id[1,:])
    print_kv(io, "ID[2,:]", id[2,:])

    # Verify reconstruction: CR[t] = CR[ID[1,t]] + 2^{ID[2,t]-1}
    all_ok = true
    for t in 2:length(cr)
        pred = (id[1,t] == 0) ? 0 : cr[id[1,t]]
        reconstructed = pred + (1 << (id[2,t] - 1))
        all_ok &= (reconstructed == cr[t])
    end
    print_check(io, "CR[t] = CR[ID[1,t]] + 2^{ID[2,t]-1} for all t", all_ok)

    print_kv(io, "completeness", "exact (n=5, all 7 representatives checked)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    example2_report()
end
