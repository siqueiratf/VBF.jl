# Implements Section 3.1 — Algorithm 1 (FINDLINEAR: orbit partition of F₂ⁿ under L)
# Paper: Ichanska, Berg, Kaleyski, Yu (2024/2025), "Pushing the QAM method for finding APN functions further"
# Section: 3.1 — Orbit restrictions, Algorithm 1
#
# Pseudocode (Algorithm 1 FINDLINEAR):
#   1. linClasses ← {}; fieldF ← {x : x ∈ F₂ⁿ, x ≠ 0}
#   2. While fieldF ≠ ∅:
#      a. el ← RANDOM(fieldF)
#      b. orb ← {l(el) : l ∈ L}
#      c. linClasses ← linClasses ∪ {orb}; fieldF ← fieldF \ orb
#   3. return linClasses
# Algorithm 2 EQUIVSET: from each orbit, pick element with smallest exponent (discrete log)
# VBF API used: gf_pow, conway_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

"""
    findlinear(group) -> Vector{Set{Int}}

Algorithm 1 (FINDLINEAR): partition a set of elements under the action of a group.
The group is given as a vector of LUT representations of permutations.
"""
function findlinear(elements::Vector{Int}, group::Vector{Vector{Int}})
    remaining = Set(elements)
    classes = Vector{Set{Int}}()
    while !isempty(remaining)
        el = first(remaining)
        orb = Set{Int}(lut[el+1] for lut in group)
        push!(classes, orb)
        setdiff!(remaining, orb)
    end
    classes
end

"""
    equivset(classes, n, m; modulus) -> Vector{Int}

Algorithm 2 (EQUIVSET): for each orbit class, pick the representative with the
smallest discrete logarithm (smallest exponent of the primitive element).
"""
function equivset(classes::Vector{Set{Int}}, n::Int;
                  modulus::Int = conway_polynomial(n))
    dlog = Dict{Int,Int}()
    a = 2
    cur = 1
    for k in 0:(1<<n)-2
        dlog[cur] = k
        cur = gf_mul(cur, a, n; modulus = modulus)
    end
    reps = Int[]
    for cls in classes
        best = argmin(x -> dlog[x], collect(cls))
        push!(reps, best)
    end
    sort!(reps; by = x -> dlog[x])
end

"""
    demo_algorithm1_n4_m2() -> (orbits, reps)

Demo of Algorithm 1 for (n=4, m=2): partition F₂⁴ ∖ {0} under linear perms
with F₂₂ coefficients. Returns orbit classes and their representatives.
"""
function demo_algorithm1_n4_m2()
    n = 4; m = 2; mod = conway_polynomial(n)
    perms = linear_perms_subfield(n, m; modulus = mod)
    elems = collect(1:(1<<n)-1)
    classes = findlinear(elems, perms)
    reps = equivset(classes, n; modulus = mod)
    (classes, reps, perms)
end

"""
    verify_n8_m2_first_level() -> Bool

Verify paper Section 4.1: F₂⁸ = Orb(1,L) ∪ Orb(a,L) ∪ Orb(a^7,L) ∪ Orb(a^17,L)
for (n=8, m=2). Confirmed by computing all 65536 linear maps with F₂₂ coefficients
and finding 4 orbits under their action. Representative elements: {1, a, a^7, a^17}.
"""
function verify_n8_m2_first_level()
    n = 8; m = 2; mod = conway_polynomial(n)
    perms = linear_perms_subfield(n, m; modulus = mod)
    elems = collect(1:(1<<n)-1)
    classes = findlinear(elems, perms)
    reps = equivset(classes, n; modulus = mod)
    a = 2
    a7  = gf_pow(2, 7,  n; modulus = mod)
    a17 = gf_pow(2, 17, n; modulus = mod)
    (length(classes) == 4, reps, Set(reps) == Set([1, a, a7, a17]), length(perms))
end

function algorithm1_report(io::IO = stdout)
    print_section(io, "Algorithm 1: FINDLINEAR orbit partition (Section 3.1)")

    # Demo for n=4, m=2
    println(io, "\n### Demo: (n=4, m=2)")
    n = 4; m = 2; mod = conway_polynomial(n)
    classes4, reps4, perms4 = demo_algorithm1_n4_m2()
    print_kv(io, "n", n)
    print_kv(io, "m", m)
    print_kv(io, "|L| (linear perms with F₂² coefficients)", length(perms4))
    print_kv(io, "number of orbits", length(classes4))
    dlog4 = Dict{Int,Int}(); cur = 1
    for k in 0:(1<<n)-2; dlog4[cur] = k; cur = gf_mul(cur, 2, n; modulus=mod); end
    rep_strs = ["a^$(dlog4[r])" for r in reps4]
    print_kv(io, "orbit representatives", join(rep_strs, ", "))
    print_check(io, "orbits partition all $(length(1:(1<<n)-1)) non-zero elements",
                sum(length(c) for c in classes4) == (1<<n)-1)

    # Main result: n=8, m=2
    println(io, "\n### Main case: (n,m) = (8,2), Section 4.1")
    print_kv(io, "note", "Computing all linear perms with F₄ coefficients over F₂⁸ (4^8=65536 maps)...")
    n8 = 8; m2 = 2; mod8 = conway_polynomial(n8)
    ok, reps8, reps_match, nperms = verify_n8_m2_first_level()
    a   = 2
    a7  = gf_pow(2, 7,  n8; modulus = mod8)
    a17 = gf_pow(2, 17, n8; modulus = mod8)
    print_kv(io, "|L| (perms with F₂² coefficients over F₂⁸)", nperms)
    print_check(io, "First level partition = 4 orbits", ok)
    print_check(io, "Representatives = {1, a, a^7, a^17} (paper Section 4.1)", reps_match)
    print_kv(io, "completeness", "exact (exhaustive enumeration of all 65536 F₂²-coefficient linear maps)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    algorithm1_report()
end
