# Implements Section 6.2 — construction of new APN permutations on F_{2^9}
# Paper: Chase, Lisoněk (2021), "Construction of APN permutations via Walsh
#        zero spaces"
# Section: 6.2 — Construction of new APN permutations
#
# Pseudocode:
#   n = 9, f = x^3 (degree 2), g = x^{1/3} (degree 5):
#     1. Draw trivially intersecting WZ pairs from Props 5.1 / 5.2 / 5.3
#        (fixed seed).
#     2. Apply Proposition 2.2 to each pair (and record the compositional
#        inverse too — swapping the roles of S and T).
#     3. Every result is an APN permutation CCZ-equivalent to f (by
#        construction); collect algebraic degrees → expect {2, 4, 5}.
#     4. Degree-4 permutations are EA-inequivalent to f and g because the
#        algebraic degree is an EA invariant (2 resp. 5 ≠ 4).
# VBF API used: gold_apn, compositional_inverse, is_permutation,
#   differential_uniformity, algebraic_degree, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "proposition5_1.jl"))
include(joinpath(@__DIR__, "proposition5_2.jl"))
include(joinpath(@__DIR__, "proposition5_3.jl"))

"""
    section6_2_build(; n, i, modulus, samples, seed) -> NamedTuple

Sample WZ pairs from the Section 5 constructions, build the CCZ-equivalent
permutations of Proposition 2.2 and collect their algebraic degrees.
`samples` bounds the number of parameter draws per construction.
"""
function section6_2_build(;
    n::Int = 9,
    i::Int = 1,
    modulus::Int = primitive_polynomial(n),
    samples::Int = 12,
    seed::Int = 42,
)
    F = gold_apn(n, i; modulus)
    Finv = compositional_inverse(F)
    deg_f = algebraic_degree(F)
    deg_g = algebraic_degree(Finv)
    tm = trace_mask_table(n; modulus)
    xis = filter(x -> x != 0 && x != 1, subfield_elements(n, 3; modulus))
    rng = MersenneTwister(seed)
    pairs = Tuple{String,Vector{UInt32},Vector{UInt32}}[]
    push!(pairs, ("trivial {Z_a0, Z_0b}", z_a0_span(n), z_0b_span(n)))
    for _ = 1:samples
        xi = rand(rng, xis)
        mu = rand(rng, 1:(1<<n)-1)
        Y, Z = proposition5_1_pair(xi, mu, n, i; modulus)
        push!(pairs, ("Prop 5.1 (ξ=$xi, μ=$mu)", Y, Z))
    end
    tries = 0
    drawn = 0
    while drawn < samples && tries < 50 * samples
        tries += 1
        xi = rand(rng, xis)
        mu = rand(rng, 1:(1<<n)-1)
        nu = rand(rng, 1:(1<<n)-1)
        proposition5_2_condition(xi, mu, nu, n, i; modulus) || continue
        Y, Z = proposition5_2_pair(xi, mu, nu, n, i; modulus)
        push!(pairs, ("Prop 5.2 (ξ=$xi, μ=$mu, ν=$nu)", Y, Z))
        drawn += 1
    end
    tries = 0
    drawn = 0
    while drawn < samples && tries < 50 * samples
        tries += 1
        xi = rand(rng, xis)
        mu = rand(rng, 1:(1<<n)-1)
        nu = rand(rng, 1:(1<<n)-1)
        proposition5_3_condition(xi, mu, nu, n, i; modulus) || continue
        Y, Z = proposition5_3_pair(xi, mu, nu, n, i; modulus)
        push!(pairs, ("Prop 5.3 (ξ=$xi, μ=$mu, ν=$nu)", Y, Z))
        drawn += 1
    end
    results = NamedTuple[]
    all_apn_perm = true
    for (label, S, T) in pairs
        g = wz_pair_to_permutation(F, S, T; tm)
        ginv = compositional_inverse(g)
        perm = is_permutation(g)
        apn = differential_uniformity(g) == 2
        all_apn_perm &= perm && apn
        push!(
            results,
            (; label, perm, apn, degree = algebraic_degree(g),
               degree_inv = algebraic_degree(ginv)),
        )
    end
    degrees = sort(unique(vcat([r.degree for r in results], [r.degree_inv for r in results])))
    (; n, i, seed, samples, deg_f, deg_g, results, all_apn_perm, degrees,
       n_pairs = length(pairs))
end

function section6_2_report(io::IO = stdout; samples::Int = 12, seed::Int = 42)
    r = section6_2_build(; samples, seed)
    print_section("Section 6.2 — APN permutations on F_{2^9} CCZ-equivalent to x^3", io)
    print_check(io, "deg f = 2 and deg g = x^{1/3} = 5", r.deg_f == 2 && r.deg_g == 5)
    print_check(io, "all $(r.n_pairs) constructed functions are APN permutations", r.all_apn_perm)
    print_check(io, "algebraic degrees found = {2, 4, 5}", r.degrees == [2, 4, 5])
    print_check(
        io,
        "degree-4 permutations exist ⟹ EA-inequivalent to f (2) and g (5)",
        4 in r.degrees,
    )
    for res in r.results
        print_kv(io, res.label, "degree $(res.degree), inverse degree $(res.degree_inv)")
    end
    print_kv(io, "seed", r.seed)
    print_kv(io, "CCZ equivalence to f", "exact by construction (Prop 2.2)")
    print_kv(io, "completeness", "budget-limited ($(r.samples) draws per construction)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    section6_2_report()
end
