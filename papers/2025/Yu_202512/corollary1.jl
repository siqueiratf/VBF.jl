# Implements Corollary 1 — K cyclic representatives suffice; |CR| ≈ 2^n/n
# Paper: Yu, Li, Ichanska, Kaleyski (2025)
# Section: 3.1 Reducing the data to be tested, Corollary 1
#
# Pseudocode:
#   CR = getCyclicEquivalenceRepresentatives(n)
#   K  = |CR|   # ≈ 2^n / n
# VBF API used: (none beyond helpers)

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "algorithm1.jl"))

function corollary1_report(io::IO = stdout)
    print_section(io, "Corollary 1: |CR| ≈ 2^n/n (n cyclic representatives suffice)")

    for n in [5, 6, 7, 8, 9, 10]
        cr  = get_cyclic_reps(n)
        k   = length(cr)
        approx = (1 << n) / n
        print_kv(io, "n=$n: K=|CR|", k)
        print_kv(io, "  2^n/n", round(approx, digits=2))
        print_check(io, "  K ≈ 2^n/n (within factor 2)", k <= 2 * approx && k >= approx / 2)
    end

    print_kv(io, "completeness", "exact (closed-form orbit enumeration)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    corollary1_report()
end
