# Implements Table 2 — APN function counts for n=6..10 via Algorithm 3 (partial search)
# Paper: Yu, Li, Ichanska, Kaleyski (2025)
# Section: 4.2 Further observation, Table 2
#
# Table 2 is produced by Algorithm 3 (Section 4.2), NOT Algorithm 2 (Section 4.1).
# Algorithm 3 restricts non-self-paired free variables d≥2 to Fₙ (instead of GF(2^n)*),
# giving ≈ nᵈ speedup where d = floor(n/2)-1 (number of restricted variables).
# The self-paired diagonal (d=n/2 for even n) stays in GF(2^{n/2})*.
#
# Paper counts: n=6→4, n=7→78, n=8→142, n=9→26, n=10→45
# This script verifies n=6 (fast, <0.1s) and n=7 (seconds).
# n=8,9,10 require hours to 45h on modern hardware; out of scope for default run.
# VBF API used: conway_polynomial

include(joinpath(@__DIR__, "algorithm3.jl"))

const TABLE2_EXPECTED = Dict(6 => 4, 7 => 78, 8 => 142, 9 => 26, 10 => 45)

function table2_report(io::IO = stdout;
                       max_n::Int = 7,
                       max_evaluations::Int = 1 << 24)
    print_section(io, "Table 2: APN function counts (Algorithm 2)")

    print_kv(io, "paper counts", TABLE2_EXPECTED)

    for n in 6:max_n
        mod = conway_polynomial(n)
        t0  = time()
        cnt = partial_search_apn_f2(n; limit = 1000, max_evaluations = max_evaluations,
                                    modulus = mod)
        elapsed = time() - t0
        expected = get(TABLE2_EXPECTED, n, nothing)
        exhaustive = (max_evaluations >= 1 << 24) && n <= 7
        match = expected !== nothing && cnt == expected
        print_kv(io, "n=$n: count", cnt)
        print_kv(io, "n=$n: time (s)", round(elapsed, digits=3))
        exhaustive && print_check(io, "n=$n: count == $(expected) (paper)", match)
        !exhaustive && print_kv(io, "n=$n: completeness", "budget-limited")
    end

    max_n < 8 && print_kv(io, "n=8,9,10", "out of scope (hours to days)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    table2_report()
end
