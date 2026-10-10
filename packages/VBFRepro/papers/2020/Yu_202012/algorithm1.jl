# Implements Section 3.2 — Algorithm 1, TranFirRow/GetElemC/GetNoneSquare.
# Paper: Yu, Kaleyski, Budaghyan, Li (2020), classification with F₂ coefficients.
# Pseudocode:
#   1. For odd n, choose H[1,2] modulo squaring (Proposition 1).
#   2. Fill each cyclic orbit; exclude the span of the preceding first-row pairs.
#   3. Reject prefixes whose (j-1)×j submatrix is not proper (Definition 3).
#   4. Test completed matrices with VBF's exact QAM oracle; bucket or confirm EA.
# VBF API used: qam_cyclic_orbits, qam_from_cyclic, rank_f2, is_cyclic_qam,
#   qam_to_sbox, apn_ea_mugshot, partition_refinement_equivalence, SearchOutcome.
# Scope: the printed pseudocode assumes odd n=2m-1. Even n retains the explicitly
# labelled core odometer; it is not presented as the paper's Algorithm 1.

include(joinpath(@__DIR__, "helpers.jl"))
using SHA,TOML

# GetNoneSquare: all nonzero Frobenius orbits, not just normal elements.
function algorithm1_get_none_square(n::Int)
    seen = falses(1 << n)
    reps = Int[]
    for a in 1:(1 << n)-1
        seen[a+1] && continue
        push!(reps, a)
        b = a
        while !seen[b+1]
            seen[b+1] = true
            b = gf_pow(b, 2, n)
        end
    end
    reps
end

# Definition 3, applied to the fully determined upper-left rectangular block.
function algorithm1_is_proper(A::AbstractMatrix{<:Integer}, n::Int)
    m, k = size(A)
    m > 0 && k > 0 || throw(ArgumentError("proper submatrix must be nonempty"))
    values = zeros(UInt, k)
    for mask in 1:(1 << m)-1
        fill!(values, 0)
        for row in 1:m
            iszero(mask & (1 << (row-1))) && continue
            for col in 1:k
                values[col] ⊻= UInt(A[row,col])
            end
        end
        rank_f2(values; nbits=n) >= k-1 || return false
    end
    true
end

"""
    algorithm1_search(n; prune=true, orbit_reduction=true, confirm=false, ...)

Odd-dimensional source Algorithm 1. `prune=false, orbit_reduction=false` is the
same first-row traversal without prefix rejection, for exhaustive controls.
`max_evaluations` counts attempted prefixes, so even a search with no leaves is
bounded. Frobenius reduction exhausts a quotient by a proved output-linear
permutation, not every cyclic matrix. `confirm=false` retains invariant buckets;
only `confirm=true` can count EA classes, and an undecided comparison is BudgetHit.
Even n uses the core odometer, with its different candidate-count budget.
"""
function algorithm1_search(n::Int;
    limit::Int=typemax(Int), max_evaluations::Int=1 << 20,
    confirm::Bool=false, timeout_seconds::Real=Inf,
    equivalence_timeout_seconds::Real=60, max_equivalence_nodes::Int=10^6,
    prune::Bool=true, orbit_reduction::Bool=true, observer=nothing)
    3 <= n <= 16 || throw(ArgumentError("dimension must be between 3 and 16"))
    limit >= 0 && max_evaluations >= 0 && max_equivalence_nodes >= 0 ||
        throw(ArgumentError("budgets must be nonnegative"))
    timeout_seconds >= 0 && equivalence_timeout_seconds >= 0 ||
        throw(ArgumentError("timeouts must be nonnegative"))
    if iseven(n)
        outcome = search_qam(n,1; limit,max_evaluations,confirm,timeout_seconds,
            equivalence_timeout_seconds,max_equivalence_nodes,observer)
        return (;outcome,implementation=:even_dimension_odometer,
            prefixes=nothing,final_tests=nothing,span_pruned=nothing,proper_pruned=nothing)
    end
    k = (n-1) ÷ 2
    orbits = qam_cyclic_orbits(n,1)
    @assert length(orbits) == k && all(length(o)==n for o in orbits)
    leading = orbit_reduction ? algorithm1_get_none_square(n) : collect(1:(1 << n)-1)
    domain = collect(1:(1 << n)-1)
    values = zeros(Int,k)
    found = typeof(qam_to_sbox(zeros(Int,n,n)))[]
    buckets = Dict{Any,typeof(found)}()
    params = Dict{String,Any}("n"=>n,"m"=>1,"confirm"=>confirm,
        "solution_unit"=>confirm ? "ea_class" : "mugshot_bucket",
        "prune"=>prune,"orbit_reduction"=>orbit_reduction,
        "budget_unit"=>"attempted_prefix", "leading_orbits"=>length(leading),
        "equivalence_timeout_seconds"=>Float64(equivalence_timeout_seconds),
        "max_equivalence_nodes"=>max_equivalence_nodes,
        "exhaustion_scope"=>orbit_reduction ? "Frobenius quotient of nonzero cyclic entries" : "all nonzero cyclic entries")
    region = SearchRegion(:yu2020_algorithm1,"Yu2020 odd cyclic QAM n=$n";
        size=BigInt(length(leading))*BigInt(length(domain))^(k-1),params)
    prefixes=0; final_tests=0; span_pruned=0; proper_pruned=0
    stop=:complete; reason=:nodes; start=time()
    function stopped()
        if time()-start >= timeout_seconds
            stop=:budget; reason=:time
        elseif length(found) >= limit
            stop=:limit
        elseif prefixes >= max_evaluations
            stop=:budget; reason=:nodes
        end
        stop != :complete
    end
    function visit(depth)
        stopped() && return
        H = qam_from_cyclic(n,1,values)
        preceding = Int[]
        if depth > 1
            for col in 2:depth
                push!(preceding,H[1,col],H[1,n+2-col])
            end
            if prune && rank_f2(UInt.(preceding);nbits=n) < 2*depth-2
                span_pruned+=1; return
            end
        end
        candidates = depth == 1 ? leading : domain
        for value in candidates
            stopped() && return
            prefixes+=1
            if prune && depth > 1 &&
                rank_f2(UInt.([preceding;value]);nbits=n) == length(preceding)
                span_pruned+=1; continue
            end
            values[depth]=value
            H = qam_from_cyclic(n,1,values)
            if prune && depth > 1 && !algorithm1_is_proper(view(H,1:depth,1:depth+1),n)
                proper_pruned+=1; continue
            end
            if depth < k
                visit(depth+1)
            else
                final_tests+=1
                is_cyclic_qam(H,1) || continue
                observer === nothing || observer(:apn_matrix,copy(H))
                F = qam_to_sbox(H)
                bucket = get!(() -> typeof(found)(),buckets,apn_ea_mugshot(F))
                duplicate = !confirm && !isempty(bucket)
                if confirm
                    for old in bucket
                        if old == F
                            duplicate=true;break
                        end
                        remaining=max(0,timeout_seconds-(time()-start))
                        eq=partition_refinement_equivalence(F,old;relation=:ea,
                            timeout_seconds=min(equivalence_timeout_seconds,remaining),max_nodes=max_equivalence_nodes)
                        if eq isa BudgetHit
                            stop=:budget;reason=:external;return
                        elseif eq isa Found
                            duplicate=true;break
                        end
                    end
                end
                duplicate || (push!(found,F);push!(bucket,F))
            end
        end
        values[depth]=0
    end
    visit(1)
    elapsed=time()-start
    outcome = stop == :complete ? Exhausted(region,found;nodes_visited=prefixes,elapsed_seconds=elapsed) :
        stop == :limit ? Found(found,region;nodes_visited=prefixes,elapsed_seconds=elapsed) :
        BudgetHit(StopPoint(reason,reason==:external ? "EA comparison inconclusive" : "Algorithm1 prefix/time budget reached"),
            region,found;nodes_visited=prefixes,elapsed_seconds=elapsed)
    (;outcome,implementation=:paper_odd_dimension_algorithm1,prefixes,final_tests,span_pruned,proper_pruned)
end

algorithm1_run(n::Int;kwargs...) = algorithm1_search(n;kwargs...).outcome

function algorithm1_report(io::IO=stdout;n_demo::Int=7,max_evaluations::Int=1 << 24,
    timeout_seconds::Real=60,confirm::Bool=false,save_results::Bool=false,
    equivalence_timeout_seconds::Real=60,max_equivalence_nodes::Int=10^6)
    print_section(io,"Algorithm 1 — cyclic-QAM traversal (n=$n_demo)")
    result=algorithm1_search(n_demo;max_evaluations,timeout_seconds,confirm,
        equivalence_timeout_seconds,max_equivalence_nodes)
    functions=search_solutions(result.outcome)
    print_kv(io,"implementation",result.implementation)
    print_kv(io,"attempted prefixes / completed matrix tests","$(result.prefixes) / $(result.final_tests)")
    print_kv(io,"span / proper-submatrix rejects","$(result.span_pruned) / $(result.proper_pruned)")
    print_kv(io,"result unit",confirm ? "EA classes (complete decisions)" : "invariant buckets; lower bound on classes")
    print_kv(io,"solutions",length(functions))
    print_kv(io,"completeness",coverage_note(result.outcome))
    print_kv(io,"scope",result.outcome.region.params)
    isempty(functions) || print_check(io,"all returned functions are APN",all(differential_uniformity(F)==2 for F in functions))
    if save_results
        metadata=Dict{String,Any}("dimension"=>n_demo,"julia_version"=>string(VERSION),
            "implementation"=>string(result.implementation),"outcome"=>string(outcome_tag(result.outcome)),
            "region_size"=>string(result.outcome.region.size),"parameters"=>result.outcome.region.params,
            "max_evaluations"=>max_evaluations,"timeout_seconds"=>Float64(timeout_seconds),
            "source_sha256"=>bytes2hex(sha256(read(@__FILE__))),
            "returned_luts"=>[Int.(F.lut) for F in functions])
        for key in (:prefixes,:final_tests,:span_pruned,:proper_pruned)
            value=getproperty(result,key)
            value===nothing || (metadata[string(key)]=value)
        end
        path=joinpath(@__DIR__,"results","algorithm1_n$(n_demo)_$(confirm ? "ea" : "buckets").toml")
        mkpath(dirname(path))
        open(path*".tmp","w") do file
            TOML.print(file,metadata;sorted=true)
        end
        mv(path*".tmp",path;force=true)
        print_kv(io,"saved evidence",path)
    end
    (;n_demo,n_classes=length(functions),exhaustive=is_exhausted(result.outcome),outcome_tag=outcome_tag(result.outcome),result)
end

if abspath(PROGRAM_FILE) == @__FILE__
    algorithm1_report()
end
