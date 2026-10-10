# Theorem 1.1: exact certification of a finite instance by coefficient orbits.
# All field and F₂ linear algebra operations reuse VBF; the reduction is specific
# to the two quadratic monomials in this paper. See README for its proof.
include(joinpath(@__DIR__, "helpers.jl"))
using SHA
using TOML
using Dates
using UUIDs

"""
    binomial_orbit_plan(F::BrackenBinomial)

Validate the field, coefficients and monomial exponents, then compute the exact
derivative/component coefficient cosets. Component normalization needs e₁
coprime to 2ⁿ−1. This is a finite-instance reduction, not an infinite-family proof.
"""
function binomial_orbit_plan(F::BrackenBinomial)
    1 <= F.n <= 30 && F.n == 3F.k && 1 <= F.s < F.n ||
        throw(ArgumentError("requires n=3k<=30 and 1<=s<n"))
    F.t == gcd(F.n, F.s) && F.k % 3 != 0 && (F.k + F.s) % 3 == 0 &&
        F.k % F.t == 0 || throw(ArgumentError("inadmissible theorem parameters"))
    F.e1 == (1 << F.s) + 1 && F.e2 == (1 << 2F.k) + (1 << (F.k + F.s)) ||
        throw(ArgumentError("exponents do not match the stated binomial"))
    N = (1 << F.n) - 1
    alpha = F.c1
    # This public API checks irreducibility and the modulus degree, as well as order.
    alpha_order = gf_multiplicative_order(alpha, F.n; modulus=F.modulus)
    alpha_order == N || throw(ArgumentError("alpha must generate the validated field"))
    F.c2 == gf_pow(alpha, 1 << F.k, F.n; modulus=F.modulus) ||
        throw(ArgumentError("second coefficient must be alpha^(2^k)"))
    gcd(F.e1, N) == 1 || throw(ArgumentError("component normalization requires gcd(e1,2^n-1)=1"))
    e1_inverse = invmod(F.e1, N)
    derivative_exponent = mod(F.e2 - F.e1, N)
    component_exponent = mod(1 - F.e2 * e1_inverse, N)
    derivative_gcd = gcd(derivative_exponent, N)
    component_gcd = gcd(component_exponent, N)
    derivative_gcd == component_gcd || error("power-image orders disagree")
    derivative_base_exponent = mod((1 << F.k) - 1, N)
    component_base_exponent = mod((1 << F.k) - F.e2 * e1_inverse, N)
    derivative_base_exponent % derivative_gcd == component_base_exponent % derivative_gcd ||
        error("normalized coefficient cosets disagree")
    count = N ÷ derivative_gcd
    base = gf_pow(alpha, derivative_base_exponent, F.n; modulus=F.modulus)
    generator = gf_pow(alpha, derivative_gcd, F.n; modulus=F.modulus)
    generator_order = gf_multiplicative_order(generator, F.n; modulus=F.modulus)
    generator_order == count || error("subgroup order verification failed")
    (; n=F.n, k=F.k, s=F.s, t=F.t, modulus=F.modulus, alpha, c1=F.c1, c2=F.c2,
        alpha_order, e1=F.e1, e2=F.e2, group_order=N, e1_inverse,
        derivative_exponent, component_exponent, derivative_gcd, component_gcd,
        derivative_base_exponent, component_base_exponent, base, generator,
        generator_order, coefficient_count=count, original_difference_count=N,
        original_nonzero_component_count=N,
        multiplicity_per_coefficient=derivative_gcd,
        field_irreducibility_verified=true, coefficient_cosets_agree=true)
end

function orbit_linear_data(F::BrackenBinomial)
    n, modulus = F.n, F.modulus
    basis = [1 << j for j in 0:n-1]
    # Reduced Frobenius indices still evaluate the original exponents exactly.
    p1 = [gf_pow(x, 1 << F.s, n; modulus) for x in basis]
    p2 = [gf_pow(x, 1 << (2F.k), n; modulus) for x in basis]
    p3 = [gf_pow(x, 1 << ((F.k + F.s) % n), n; modulus) for x in basis]
    d1 = [p1[j] ⊻ basis[j] for j in 1:n]
    d2 = [p2[j] ⊻ p3[j] for j in 1:n]
    # Polar forms are symmetric, alternating. Populate both halves explicitly.
    polar1 = zeros(Int, n, n)
    polar2 = zeros(Int, n, n)
    for i in 1:n, j in i+1:n
        a = gf_mul(basis[i], p1[j], n; modulus) ⊻ gf_mul(p1[i], basis[j], n; modulus)
        b = gf_mul(p2[i], p3[j], n; modulus) ⊻ gf_mul(p3[i], p2[j], n; modulus)
        polar1[i,j] = polar1[j,i] = a
        polar2[i,j] = polar2[j,i] = b
    end
    trace_mask = sum(gf_trace(x, n; modulus) << (j-1) for (j,x) in enumerate(basis))
    (; d1, d2, polar1, polar2, trace_mask)
end

"Return exact derivative columns and component polar rows at normalized coefficient c."
function orbit_case_matrices(F::BrackenBinomial, data, c::Int)
    0 < c < (1 << F.n) || throw(ArgumentError("coefficient outside nonzero field"))
    n, modulus = F.n, F.modulus
    columns = UInt64[data.d1[j] ⊻ gf_mul(c, data.d2[j], n; modulus) for j in 1:n]
    polar = zeros(UInt64, n)
    for i in 1:n, j in i+1:n
        x = data.polar1[i,j] ⊻ gf_mul(c, data.polar2[i,j], n; modulus)
        if isodd(count_ones(x & data.trace_mask))
            polar[i] |= UInt64(1) << (j-1)
            polar[j] |= UInt64(1) << (i-1)
        end
    end
    (; columns, polar)
end

function orbit_source_hashes()
    root = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
    sources = String[]
    for base in (@__DIR__, dirname(pathof(VBF)))
        for (dir, dirs, files) in walkdir(base)
            filter!(x -> x != "results", dirs)
            for file in files
                (endswith(file, ".jl") || endswith(file, ".tex") || file == "Makefile") &&
                    push!(sources, joinpath(dir, file))
            end
        end
    end
    for file in ("Project.toml", "Manifest.toml")
        isfile(joinpath(root, file)) && push!(sources, joinpath(root, file))
    end
    Dict(relpath(path,root) => bytes2hex(open(SHA.sha256,path)) for path in sort!(unique(sources)))
end

"""
    binomial_orbit_certificate(F; max_coefficients=256, timeout_seconds=30,
                               output_directory=nothing)

Walk the verified coefficient coset once. Full coverage requires the exact
subgroup order, distinct visited coefficients, and return to the initial value.
For each c, record rank(L_c), rank([L_c|1+c]) and the component polar rank.
An incomplete walk certifies no global property. Optional CSV and TOML evidence
bind every row to the plan, source hashes and computation metadata.
"""
function binomial_orbit_certificate(F::BrackenBinomial; max_coefficients::Int=256,
        timeout_seconds::Real=30, output_directory::Union{Nothing,String}=nothing)
    max_coefficients >= 0 && isfinite(timeout_seconds) && timeout_seconds >= 0 ||
        throw(ArgumentError("require nonnegative finite budgets"))
    started = time_ns()
    elapsed() = (time_ns()-started)/1e9
    plan = binomial_orbit_plan(F)
    data = orbit_linear_data(F)
    path = output_directory === nothing ? nothing : abspath(output_directory)
    if path !== nothing
        ispath(path) && throw(ArgumentError("evidence directory already exists"))
        mkpath(path)
    end
    csv = path === nothing ? nothing : open(joinpath(path,"coefficients.csv"),"w")
    csv === nothing || println(csv,"index,coefficient,derivative_rank,augmented_rank,polar_rank")
    rows = NamedTuple[]
    visited = Set{Int}()
    c = plan.base
    stop_reason = "coefficient_limit"
    try
        for index in 1:min(max_coefficients,plan.coefficient_count)
            if elapsed() >= timeout_seconds
                stop_reason = "timeout"
                break
            end
            c in visited && error("coefficient repeated before declared subgroup order")
            push!(visited,c)
            matrices = orbit_case_matrices(F,data,c)
            derivative_rank = rank_f2(matrices.columns; nbits=F.n)
            augmented_rank = rank_f2(vcat(matrices.columns,UInt64(1 ⊻ c)); nbits=F.n)
            polar_rank = rank_f2(matrices.polar; nbits=F.n)
            iseven(polar_rank) || error("alternating polar form has odd rank")
            row = (; index, coefficient=c, derivative_rank, augmented_rank, polar_rank)
            push!(rows,row)
            csv === nothing || println(csv,"$index,$c,$derivative_rank,$augmented_rank,$polar_rank")
            c = gf_mul(c,plan.generator,F.n; modulus=F.modulus)
        end
    finally
        csv === nothing || close(csv)
    end
    checked = length(rows)
    complete = checked == plan.coefficient_count && length(visited) == checked && c == plan.base
    complete && (stop_reason="exhausted")
    ranks = sort!(unique([r.derivative_rank for r in rows]))
    polar_ranks = sort!(unique([r.polar_rank for r in rows]))
    collision_rhs_outside_image = count(r -> r.augmented_rank > r.derivative_rank,rows)
    uniformity_verified = complete && ranks == [F.n-F.t]
    permutation_verified = complete && collision_rhs_outside_image == checked
    # Character orthogonality gives W_q(a)^2 either 0 or 2^(2n-rank(polar)).
    magnitudes = sort!(unique([1 << (F.n-r÷2) for r in polar_ranks]))
    walsh_bound_verified = complete && all(r >= F.n-F.t for r in polar_ranks)
    status = complete ? (uniformity_verified && permutation_verified && walsh_bound_verified ?
        "certified" : "property_check_failed") : "inconclusive"
    summary = Dict{String,Any}(
        "schema_version"=>1, "status"=>status, "scope"=>"specified finite binomial instance",
        "basis"=>"binary polynomial basis; bit j denotes x^j",
        "plan"=>Dict(string(k)=>v for (k,v) in pairs(plan)),
        "max_coefficients"=>max_coefficients, "timeout_seconds"=>Float64(timeout_seconds),
        "coefficients_checked"=>checked, "coverage_complete"=>complete,
        "distinct_coefficients"=>length(visited), "next_coefficient"=>c,
        "stop_reason"=>stop_reason, "elapsed_seconds"=>elapsed(),
        "budget_clock"=>"monotonic time_ns",
        "derivative_ranks"=>ranks, "polar_ranks"=>polar_ranks,
        "collision_rhs_outside_image"=>collision_rhs_outside_image,
        "differential_uniformity_verified"=>uniformity_verified,
        "permutation_verified"=>permutation_verified, "walsh_bound_verified"=>walsh_bound_verified,
        "observed_normalized_walsh_magnitudes"=>magnitudes,
        "walsh_claim"=>"support inclusion for nonzero output masks; no signed-frequency histogram",
        "julia_version"=>string(VERSION), "julia_threads"=>Threads.nthreads(),
        "machine"=>Sys.MACHINE, "cpu"=>Sys.CPU_NAME, "created_at_utc"=>string(now(UTC)))
    if path !== nothing
        summary["source_sha256"] = orbit_source_hashes()
        summary["coefficients_csv_sha256"] = bytes2hex(open(SHA.sha256,joinpath(path,"coefficients.csv")))
        open(joinpath(path,"certificate.toml"),"w") do io
            TOML.print(io,summary; sorted=true)
        end
    end
    (; plan, rows, summary, output_directory=path)
end

function orbit_certificate_report(io::IO=stdout; full_search::Bool=false,
        max_coefficients::Int=256, timeout_seconds::Real=30, save_results::Bool=false)
    F = bracken_binomial(10,2; allow_nonpermutation=false)
    output = save_results ? joinpath(@__DIR__, "results", "orbit-"*
        Dates.format(now(UTC),"yyyymmddTHHMMSS") * "-" * string(uuid4())) : nothing
    evidence = binomial_orbit_certificate(F;
        max_coefficients=full_search ? binomial_orbit_plan(F).coefficient_count : max_coefficients,
        timeout_seconds,output_directory=output)
    print_section("Theorem 1.1 — exact finite coefficient-orbit certificate at n=30",io)
    print_kv("field / alpha", "modulus $(F.modulus), alpha $(F.c1); irreducibility and order verified",io)
    print_kv("coverage", "$(length(evidence.rows))/$(evidence.plan.coefficient_count) normalized coefficients",io)
    print_kv("status", evidence.summary["status"],io)
    print_kv("derivative / polar ranks", "$(evidence.summary["derivative_ranks"]) / $(evidence.summary["polar_ranks"])",io)
    print_kv("collision RHS outside image",evidence.summary["collision_rhs_outside_image"],io)
    print_kv("guarantee", evidence.summary["coverage_complete"] ?
        "covers every nonzero input difference and output mask of this instance through verified cosets" :
        "partial normalized cases only; global DU, permutation and Walsh conclusions inconclusive",io)
    print_kv("Walsh claim", "support inclusion {0, ±2^15, ±2^16}; full signed frequencies not computed",io)
    print_kv("evidence directory",something(output,"not requested"),io)
    evidence
end

if abspath(PROGRAM_FILE)==@__FILE__
    orbit_certificate_report()
end
