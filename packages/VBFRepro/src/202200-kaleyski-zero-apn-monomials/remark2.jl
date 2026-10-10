# Implements Remark 2: computational experiments for (k=1,l=7) and (k=1,l=5)
# Paper: Kaleyski, Nesheim, Stănică (2022), "A doubly-infinite family of 0-APN monomials"
# Section: 2 — Remark 2
#
# Pseudocode:
#   1. For each (k,l) pair, enumerate n in [1, max_n]
#   2. Check Theorem 1 conditions → theorem_dims
#   3. Check actual 0-APN via polynomial root counting → actual_dims
#   4. Report counts and uncovered dimensions
# VBF API used: print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

function remark2_experiment(io::IO, l::Int, k::Int; max_n::Int = 100)
    e = e_exponent(l, k)
    print_kv(io, "(l,k)", "($l,$k), e(l,k) = $e")

    theorem_dims = Int[]
    actual_dims = Int[]
    for n in 1:max_n
        if theorem1_holds(l, k, n)
            push!(theorem_dims, n)
        end
        if is_zero_apn_poly(e, n)
            push!(actual_dims, n)
        end
    end

    uncovered = setdiff(actual_dims, theorem_dims)

    print_kv(io, "  theorem dimensions", "$(length(theorem_dims))")
    print_kv(io, "  actual 0-APN dimensions", "$(length(actual_dims))")
    print_kv(io, "  uncovered by theorem", "$(length(uncovered)): $uncovered")

    return (; l, k, e, theorem_dims, actual_dims, uncovered, max_n)
end

function remark2_report(io::IO = stdout; max_n::Int = 100)
    print_section(io, "Remark 2 — Computational experiments")

    r7 = remark2_experiment(io, 7, 1; max_n)
    print_check(io, "(l=7,k=1): 28 theorem dims",
        length(r7.theorem_dims) == 28)
    print_check(io, "(l=7,k=1): 33 actual 0-APN dims",
        length(r7.actual_dims) == 33)
    print_check(io, "(l=7,k=1): uncovered = {7,35,49,77,91}",
        r7.uncovered == [7, 35, 49, 77, 91])

    println(io)
    r5 = remark2_experiment(io, 5, 1; max_n)
    print_check(io, "(l=5,k=1): 40 theorem dims",
        length(r5.theorem_dims) == 40)
    print_check(io, "(l=5,k=1): 50 actual 0-APN dims",
        length(r5.actual_dims) == 50)
    expected_uncovered_5 = [5 + 10i for i in 0:9]
    print_check(io, "(l=5,k=1): uncovered = 5+10k, k=0..9",
        r5.uncovered == expected_uncovered_5)

    return (; r7, r5)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    remark2_report()
end
