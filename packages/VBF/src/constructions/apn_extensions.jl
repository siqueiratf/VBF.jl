"""
Rectangular APN extensions by zero-image two-flat constraints.

The one-coordinate method solves the affine parity system of Gillot–Langevin,
*Observation of known APNs* (arXiv:2601.11247v1), Section 6. The optional
normalization removes additions of affine functions and existing coordinates
by fixing their evaluation pivots. A normalized search covers the corresponding
extension classes, rather than every raw truth table.
"""

mutable struct _APNXBudget
    started::UInt64
    nodes::Int
    maximum::Int
    seconds::Float64
end

struct _APNXStopped <: Exception
    point::StopPoint
end

_apnx_elapsed(b::_APNXBudget) = Float64(time_ns() - b.started) / 1e9

function _apnx_check!(b::_APNXBudget, stage; consume=false, frontier=Dict{String,Any}())
    reason = _apnx_elapsed(b) >= b.seconds ? :time :
        consume && b.nodes >= b.maximum ? :nodes : nothing
    reason === nothing || throw(_APNXStopped(StopPoint(reason, string(stage);
        resume_key=merge(Dict{String,Any}("stage"=>string(stage)), frontier))))
    consume && (b.nodes += 1)
    return nothing
end

function _apnx_budget(max_nodes, timeout_seconds)
    0 <= max_nodes <= typemax(Int) || throw(ArgumentError("invalid max_nodes"))
    timeout_seconds >= 0 && !isnan(timeout_seconds) ||
        throw(ArgumentError("invalid timeout_seconds"))
    return _APNXBudget(time_ns(), 0, Int(max_nodes), Float64(timeout_seconds))
end

function _apnx_flats(G::AbstractTruthTable, budget::_APNXBudget)
    q = length(G)
    flats = NTuple{4,Int}[]
    for x in 0:q-4, y in x+1:q-3, z in y+1:q-2
        _apnx_check!(budget, :flat_construction; consume=true,
            frontier=Dict{String,Any}("x"=>x,"y"=>y,"z"=>z))
        t = xor(x,y,z)
        t > z || continue
        xor(G.lut[x+1],G.lut[y+1],G.lut[z+1],G.lut[t+1]) == 0 || continue
        push!(flats,(x,y,z,t))
    end
    return flats
end

function _apnx_normalization_points(G::AbstractTruthTable{N,M}, budget) where {N,M}
    N + M + 1 <= 64 || throw(ArgumentError("normalization supports N+M+1 ≤ 64"))
    basis = UInt64[]
    points = Int[]
    for x in 0:length(G)-1
        _apnx_check!(budget, :normalization)
        row = UInt64(1) | (UInt64(x)<<1) | (UInt64(G.lut[x+1])<<(N+1))
        is_in_span(row,basis;nbits=N+M+1) && continue
        push!(points,x)
        basis = linear_basis([basis;row];nbits=N+M+1)
    end
    return points
end

function _apnx_insert!(rows, columns, row::BitVector, nvars::Int)
    for i in eachindex(rows)
        row[columns[i]] && (row .⊻= rows[i])
    end
    lead = findfirst(@view row[1:nvars])
    lead === nothing && return !row[nvars+1]
    push!(rows,row)
    push!(columns,lead)
    return true
end

function _apnx_affine_solution(rows, columns, nvars, budget)
    work = copy.(rows)
    for i in reverse(eachindex(work)), j in 1:i-1
        _apnx_check!(budget, :elimination)
        work[j][columns[i]] && (work[j] .⊻= work[i])
    end
    particular = falses(nvars)
    for i in eachindex(work)
        particular[columns[i]] = work[i][nvars+1]
    end
    pivots = Set(columns)
    kernel = BitVector[]
    for f in 1:nvars
        _apnx_check!(budget, :kernel)
        f in pivots && continue
        v = falses(nvars)
        v[f] = true
        for i in eachindex(work)
            v[columns[i]] = work[i][f]
        end
        push!(kernel,v)
    end
    return particular,kernel
end

function _apnx_space(G::AbstractTruthTable{N,M}, budget; normalize=true) where {N,M}
    M == N-1 || throw(ArgumentError("one-coordinate space requires M=N−1"))
    flats = _apnx_flats(G,budget)
    q = length(G)
    rows = BitVector[]
    columns = Int[]
    for flat in flats
        _apnx_check!(budget,:parity_system)
        row = falses(q+1)
        row[q+1] = true
        for x in flat
            row[x+1] = true
        end
        if !_apnx_insert!(rows,columns,row,q)
            return (;particular=nothing,kernel=BitVector[],kernel_dimension=q-length(rows),
                normalized_dimension=0,normalization_points=Int[],flats,consistent=false)
        end
    end
    kernel_dimension = q-length(rows)
    points = normalize ? _apnx_normalization_points(G,budget) : Int[]
    for x in points
        row = falses(q+1)
        row[x+1] = true
        _apnx_insert!(rows,columns,row,q) || error("normalization destroyed consistency")
    end
    particular,kernel = _apnx_affine_solution(rows,columns,q,budget)
    return (;particular,kernel,kernel_dimension,normalized_dimension=length(kernel),
        normalization_points=points,flats,consistent=true)
end

"""
    apn_extension_space(G; normalize=true, max_nodes=10^6, timeout_seconds=60)

Solve the complete one-coordinate APN extension parity system of a rectangular
`G : F₂ᴺ → F₂ᴺ⁻¹` (Gillot–Langevin, Section 6, Lemma 2). An `Exhausted` result
contains one record with a particular Boolean table, a homogeneous kernel,
the full kernel dimension before normalization, and the retained dimension.
An inconsistent system has `particular=nothing`. `BudgetHit` has no system
record: a partial matrix must never be interpreted as the complete kernel.
Nodes count candidate triples during flat construction; elimination and
normalization are time bounded. Frontiers are diagnostic, not resumable state.
"""
function apn_extension_space(G::AbstractTruthTable{N,M}; normalize::Bool=true,
    max_nodes::Integer=10^6, timeout_seconds::Real=60) where {N,M}
    budget = _apnx_budget(max_nodes,timeout_seconds)
    region = SearchRegion(:apn_extension_space,"$(N)-to-$(M) parity system";
        params=Dict{String,Any}("normalize"=>normalize,"max_nodes"=>max_nodes,
            "timeout_seconds"=>timeout_seconds))
    result = Any[]
    try
        _apnx_check!(budget,:validation;consume=true)
        push!(result,_apnx_space(G,budget;normalize))
    catch err
        err isa _APNXStopped || rethrow()
        return BudgetHit(err.point,region,result;nodes_visited=budget.nodes,
            elapsed_seconds=_apnx_elapsed(budget))
    end
    return Exhausted(region,result;nodes_visited=budget.nodes,
        elapsed_seconds=_apnx_elapsed(budget))
end

"""
    apn_extensions(G; normalize=true, max_nodes=10^6, max_solutions=1000,
                   timeout_seconds=60)

Enumerate square APN extensions of rectangular `G` by one coordinate using
Gillot–Langevin (2026), Section 6. Output packing is `(G(x) << 1) | g(x)`.
Each table is independently checked for differential uniformity 2. With
normalization, the region contains representatives modulo adding affine and
existing coordinate functions. `Exhausted` certifies that region; caps return
`BudgetHit`, even if they might coincide with its last solution.
"""
function apn_extensions(G::AbstractTruthTable{N,M}; normalize::Bool=true,
    max_nodes::Integer=10^6,max_solutions::Integer=1000,
    timeout_seconds::Real=60) where {N,M}
    M == N-1 || throw(ArgumentError("one-coordinate extensions require M=N−1"))
    max_solutions >= 0 || throw(ArgumentError("max_solutions must be nonnegative"))
    budget = _apnx_budget(max_nodes,timeout_seconds)
    region = SearchRegion(:apn_extensions,"$(N)-to-$(M) one-coordinate extensions";
        params=Dict{String,Any}("normalize"=>normalize,"max_nodes"=>max_nodes,
            "max_solutions"=>max_solutions,"timeout_seconds"=>timeout_seconds))
    found = SBox{N,_storage_for(N)}[]
    try
        _apnx_check!(budget,:validation;consume=true)
        max_solutions == 0 && throw(_APNXStopped(StopPoint(:solutions,"zero solution cap")))
        space = _apnx_space(G,budget;normalize)
        space.consistent || return Exhausted(region,found;nodes_visited=budget.nodes,
            elapsed_seconds=_apnx_elapsed(budget))
        for combo in big(0):(big(1)<<length(space.kernel))-1
            _apnx_check!(budget,:candidate;consume=true,
                frontier=Dict{String,Any}("combination"=>string(combo)))
            g = copy(space.particular)
            for i in eachindex(space.kernel)
                isodd(combo>>(i-1)) && (g .⊻= space.kernel[i])
            end
            F = SBox{N}([(Int(G.lut[x])<<1)|Int(g[x]) for x in eachindex(g)])
            differential_uniformity(F) == 2 || error("invalid parity-system extension")
            push!(found,F)
            length(found) >= max_solutions && throw(_APNXStopped(StopPoint(:solutions,
                "extension solution cap";resume_key=Dict{String,Any}("combination"=>string(combo)))))
        end
    catch err
        err isa _APNXStopped || rethrow()
        return BudgetHit(err.point,region,found;nodes_visited=budget.nodes,
            elapsed_seconds=_apnx_elapsed(budget))
    end
    return Exhausted(region,found;nodes_visited=budget.nodes,
        elapsed_seconds=_apnx_elapsed(budget))
end
