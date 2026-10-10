# Audits saved one-coordinate switching coverage and certificates.
# Paper: Baudrin, Galissant and Perrin (2025), Exploring the Set of APN Functions;
# Gillot and Langevin (2026), Observation of known APNs, Section 6, Fact 3.
# Pseudocode:
#   1. Bind every checkpoint to its actual census parent.
#   2. Independently compute flat-constraint and trivial-space dimensions.
#   3. Check direction coverage, candidate counts and positive graph witnesses.
#   4. Reconstruct the connection graph and compare the saved summary.
# VBF API used: rank_f2, differential_uniformity, F2LinearMap, F2AffineMap
using VBF
using TOML
using SHA
isdefined(@__MODULE__, :bgp_verify_graph_map) || include(joinpath(@__DIR__, "helpers.jl"))

_bgp_switch_require(condition,message) = condition ||
    throw(ArgumentError("switching checkpoint audit: $(message)"))

# Deadline interruption is distinct from a malformed/corrupt checkpoint. A
# caller may retry a stopped audit; it must never use its unverified prefix.
struct BGPSwitchingAuditDeadline <: Exception end
_bgp_switch_audit_check(::Nothing) = nothing
function _bgp_switch_audit_check(check_deadline)
    check_deadline() || throw(BGPSwitchingAuditDeadline())
    return nothing
end

function _bgp_switch_field(record,key)
    _bgp_switch_require(haskey(record,key),"missing $(key)")
    return record[key]
end

function _bgp_switch_count(record,key)
    value = _bgp_switch_field(record,key)
    _bgp_switch_require(value isa Integer && !(value isa Bool) && value >= 0,
        "invalid nonnegative count $(key)")
    return value
end

function _bgp_switch_mask(predicate,size)
    mask = zero(UInt64)
    for x in 0:(size-1)
        predicate(x) && (mask |= UInt64(1) << x)
    end
    return mask
end

# Use the library's reduced basis/membership arithmetic for the trivial
# switching quotient; the affine-flat oracle below supplies its kernel rank.
function _bgp_switch_trivial_basis(F,direction,check_deadline=nothing)
    size = length(F)
    rows = UInt64[typemax(UInt64) >> (64-size)]
    for bit in 0:(inputbits(F)-1)
        _bgp_switch_audit_check(check_deadline)
        push!(rows,_bgp_switch_mask(x -> !iszero(x & (1 << bit)),size))
    end
    for component in 1:(size-1)
        _bgp_switch_audit_check(check_deadline)
        isodd(count_ones(component & direction)) && continue
        push!(rows,_bgp_switch_mask(
            x -> isodd(count_ones(component & Int(F.lut[x+1]))),size))
    end
    return linear_basis(rows;nbits=size)
end

"""
Independently compute one-coordinate switching dimensions from affine two-flats.

Each flat is visited once in increasing point order. Its nonzero image sum
assigns its equation to the corresponding output direction. This differs from
the constructor's ordered derivative-pair traversal. The trivial quotient is
computed as the actual rank of affine input functions and output components
orthogonal to that direction. Truth tables of at most 64 points are supported.
"""
function bgp_switching_flat_dimensions(F::SBox;check_deadline=nothing)
    _bgp_switch_audit_check(check_deadline)
    size = length(F)
    _bgp_switch_require(size <= 64,"flat dimension oracle supports at most six bits")
    equations = [UInt64[] for _ in 1:(size-1)]
    for x in 0:(size-4), y in (x+1):(size-3), z in (y+1):(size-2)
        _bgp_switch_audit_check(check_deadline)
        t = x ⊻ y ⊻ z
        t > z || continue
        direction = Int(F.lut[x+1] ⊻ F.lut[y+1] ⊻ F.lut[z+1] ⊻ F.lut[t+1])
        _bgp_switch_require(direction != 0,"parent has a zero-image flat and is not APN")
        mask = (UInt64(1) << x) | (UInt64(1) << y) |
            (UInt64(1) << z) | (UInt64(1) << t)
        push!(equations[direction],mask)
    end
    dimensions = NamedTuple[]
    for direction in 1:(size-1)
        _bgp_switch_audit_check(check_deadline)
        trivial = _bgp_switch_trivial_basis(F,direction,check_deadline)
        raw_dimension = size-rank_f2(equations[direction];nbits=size)
        _bgp_switch_audit_check(check_deadline)
        trivial_dimension = length(trivial)
        _bgp_switch_require(trivial_dimension <= raw_dimension,"invalid trivial subspace rank")
        push!(dimensions,(;direction,raw_dimension,trivial_dimension,
            quotient_dimension=raw_dimension-trivial_dimension))
    end
    return dimensions
end

"""
    bgp_audit_switching_parent(row, parent, census; parent_index,
        identity=nothing, verify_dimensions=true)

Validate a full or partial saved parent checkpoint and return its checked edges
and counts. A complete checkpoint must cover every output direction and every
nonzero quotient combination, with a valid positive certificate for each APN
neighbour. An incomplete checkpoint retains checked prefixes and undecided
records; it is never promoted to complete. Optional `identity` binds producer
provenance without requiring historical checkpoints to match today's source.
`check_deadline`, when supplied, is a Boolean callback checked between flat,
rank, quotient and certificate steps. Interruption throws
`BGPSwitchingAuditDeadline` and returns no checked row. Individual APN tests,
small GF(2) rank operations and graph-certificate checks finish cooperatively.
"""
function bgp_audit_switching_parent(row,parent,census;
    parent_index,identity=nothing,verify_dimensions=true,check_deadline=nothing)
    _bgp_switch_audit_check(check_deadline)
    F = parent.function_value
    n = inputbits(F)
    size = length(F)
    _bgp_switch_require(size <= 64,"checkpoint audit supports at most six bits")
    _bgp_switch_require(_bgp_switch_field(row,"parent_index") == parent_index,
        "parent index differs from checkpoint filename")
    _bgp_switch_require(_bgp_switch_field(row,"parent_lut") == Int.(F.lut),
        "parent LUT differs from census")
    _bgp_switch_require(_bgp_switch_field(row,"source_root_index") == parent.root_index,
        "source root index differs from census")
    _bgp_switch_require(1 <= parent.root_index <= length(census.roots),"invalid source root index")
    if identity !== nothing
        for (key,value) in identity
            _bgp_switch_require(_bgp_switch_field(row,key) == value,"provenance differs: $(key)")
        end
    end
    complete = _bgp_switch_field(row,"complete")
    constructor_complete = _bgp_switch_field(row,"constructor_complete")
    _bgp_switch_require(complete isa Bool && constructor_complete isa Bool,
        "completeness flags must be Boolean")
    evaluations = _bgp_switch_count(row,"evaluations")
    neighbors = _bgp_switch_count(row,"neighbors")
    _bgp_switch_count(row,"comparisons")
    _bgp_switch_count(row,"nodes")
    records = _bgp_switch_field(row,"records")
    _bgp_switch_require(length(records) == neighbors,"neighbor count differs from records")
    _bgp_switch_require(neighbors == evaluations,"candidate/APN counts differ for complete APN constraints")
    _bgp_switch_require(differential_uniformity(F) == 2,"parent is not APN")
    _bgp_switch_audit_check(check_deadline)
    dimensions = verify_dimensions ? bgp_switching_flat_dimensions(F;check_deadline) : nothing
    directions = _bgp_switch_field(row,"directions")
    _bgp_switch_require(length(directions) <= size-1,"too many output directions")
    done_counts = zeros(BigInt,size-1)
    for (index,direction) in enumerate(directions)
        _bgp_switch_audit_check(check_deadline)
        _bgp_switch_require(_bgp_switch_field(direction,"direction") == index,
            "completed directions are not the ordered prefix")
        raw = _bgp_switch_count(direction,"raw_dimension")
        trivial = _bgp_switch_count(direction,"trivial_dimension")
        quotient = _bgp_switch_count(direction,"quotient_dimension")
        _bgp_switch_require(quotient <= raw <= size && trivial+quotient == raw,
            "inconsistent kernel dimensions")
        if verify_dimensions
            expected = dimensions[index]
            _bgp_switch_require(raw == expected.raw_dimension &&
                trivial == expected.trivial_dimension && quotient == expected.quotient_dimension,
                "flat-kernel dimension proof differs for direction $(index)")
        end
        expected_count = (big(1) << quotient)-1
        _bgp_switch_require(_bgp_switch_count(direction,"evaluations") == expected_count &&
            _bgp_switch_count(direction,"neighbors") == expected_count,
            "direction $(index) did not enumerate all quotient combinations")
        done_counts[index] = expected_count
    end
    constructor_complete && _bgp_switch_require(length(directions) == size-1,
        "complete constructor omitted output directions")
    done_evaluations = sum(done_counts)
    _bgp_switch_require(evaluations >= done_evaluations,"evaluations omit completed directions")
    constructor_complete && _bgp_switch_require(evaluations == done_evaluations,
        "complete evaluations differ from direction totals")
    if !constructor_complete && verify_dimensions
        active = length(directions)+1
        active_count = active <= size-1 ? (big(1) << dimensions[active].quotient_dimension)-1 : 0
        _bgp_switch_require(evaluations <= done_evaluations+active_count,
            "partial evaluations exceed the active direction")
    end
    by_direction = zeros(Int,size-1)
    trivial_bases = [_bgp_switch_trivial_basis(F,direction,check_deadline) for direction in 1:(size-1)]
    quotient_supports = [UInt64[] for _ in 1:(size-1)]
    seen = Set{Tuple}()
    edges = Tuple{Int,Int}[]
    all_matched = true
    previous_direction = 0
    for record in records
        _bgp_switch_audit_check(check_deadline)
        lut = _bgp_switch_field(record,"candidate_lut")
        _bgp_switch_require(length(lut) == size &&
            all(value -> value isa Integer && 0 <= value < size,lut),"invalid candidate LUT")
        key = Tuple(lut)
        _bgp_switch_require(!(key in seen),"duplicate candidate within one parent")
        push!(seen,key)
        difference = Int.(F.lut) .⊻ lut
        nonzero = unique(filter(!iszero,difference))
        _bgp_switch_require(length(nonzero) == 1,"candidate is not a nontrivial one-direction switch")
        direction = only(nonzero)
        support = _bgp_switch_mask(x -> !iszero(difference[x+1]),size)
        _bgp_switch_require(!is_in_span(support,trivial_bases[direction];nbits=size),
            "candidate is trivial in the switching quotient")
        _bgp_switch_require(all(previous ->
            !is_in_span(support ⊻ previous,trivial_bases[direction];nbits=size),
            quotient_supports[direction]),"duplicate switching quotient coset")
        push!(quotient_supports[direction],support)
        _bgp_switch_require(direction >= previous_direction,"candidate directions are out of order")
        _bgp_switch_require(constructor_complete || direction <= length(directions)+1,
            "candidate belongs to an unvisited direction")
        previous_direction = direction
        by_direction[direction] += 1
        _bgp_switch_require(_bgp_switch_field(record,"candidate_sha256") ==
            bytes2hex(sha256(UInt8.(lut))),"candidate hash differs from LUT")
        G = SBox{n,UInt8}(UInt8.(lut))
        _bgp_switch_require(differential_uniformity(G) == 2,"candidate is not APN")
        _bgp_switch_audit_check(check_deadline)
        status = _bgp_switch_field(record,"status")
        _bgp_switch_require(status in ("matched","undecided","outside_known_roots"),"unknown record status")
        if status == "matched"
            target = _bgp_switch_field(record,"root_index")
            _bgp_switch_require(target isa Integer && 1 <= target <= length(census.roots),
                "invalid target root index")
            witness = _bgp_switch_field(record,"witness")
            _bgp_switch_require(_bgp_switch_field(witness,"dimension") == n &&
                _bgp_switch_field(witness,"relation") == "ccz" &&
                _bgp_switch_field(witness,"source_lut") == lut &&
                _bgp_switch_field(witness,"target_lut") == Int.(census.roots[target].lut),
                "positive witness is not bound to candidate and root")
            columns = _bgp_switch_field(witness,"linear_columns")
            constant = _bgp_switch_field(witness,"constant")
            _bgp_switch_require(length(columns) == 2n &&
                all(value -> value isa Integer && 0 <= value < 1 << (2n),columns) &&
                constant isa Integer && 0 <= constant < 1 << (2n),"invalid affine map data")
            A = F2AffineMap(F2LinearMap{2n,UInt32}(UInt32.(columns)),UInt32(constant))
            _bgp_switch_require(bgp_verify_graph_map(G,census.roots[target],A),
                "positive graph certificate is invalid")
            _bgp_switch_audit_check(check_deadline)
            push!(edges,(parent.root_index,Int(target)))
        else
            all_matched = false
        end
    end
    for index in eachindex(directions)
        _bgp_switch_audit_check(check_deadline)
        _bgp_switch_require(by_direction[index] == done_counts[index],
            "direction $(index) has missing candidate records")
    end
    _bgp_switch_require(complete == (constructor_complete && all_matched),
        "complete flag disagrees with constructor and membership results")
    _bgp_switch_audit_check(check_deadline)
    return (;complete,constructor_complete,evaluations,neighbors,edges,
        directions_checked=length(directions),dimensions_verified=verify_dimensions)
end

function _bgp_audit_components(count,edges)
    remaining = Set(1:count)
    components = Vector{Int}[]
    while !isempty(remaining)
        queue = [minimum(remaining)]
        delete!(remaining,only(queue))
        for source in queue, target in collect(remaining)
            if (source,target) in edges || (target,source) in edges
                delete!(remaining,target)
                push!(queue,target)
            end
        end
        push!(components,sort(queue))
    end
    return components
end

"""Validate a saved switching directory and reconstruct its summary connection graph."""
function bgp_audit_switching_results(summary_path,census;
    verify_dimensions=true,check_deadline=nothing)
    _bgp_switch_audit_check(check_deadline)
    summary = TOML.parsefile(summary_path)
    _bgp_switch_audit_check(check_deadline)
    identity = Dict("census_sha256"=>census.sha256,"schema"=>"vbf-switching-closure-v1",
        "source_hashes"=>_bgp_switch_field(summary,"source_hashes"),
        "seed"=>_bgp_switch_field(summary,"seed"))
    _bgp_switch_require(_bgp_switch_field(summary,"census_sha256") == census.sha256,
        "summary belongs to another census")
    name = _bgp_switch_field(summary,"checkpoint_directory")
    _bgp_switch_require(name isa AbstractString && occursin(r"^[A-Za-z0-9_-]+$",name),
        "invalid checkpoint directory")
    directory = joinpath(dirname(summary_path),name)
    count = _bgp_switch_count(summary,"parents_processed")
    _bgp_switch_require(count <= length(census.parents),"too many processed parents")
    edges = Set{Tuple{Int,Int}}()
    complete_parents = 0
    evaluations = 0
    comparisons = 0
    nodes = 0
    matched = Set{Tuple}()
    for index in 1:count
        _bgp_switch_audit_check(check_deadline)
        path = joinpath(directory,"parent_$(lpad(index,3,'0')).toml")
        row = TOML.parsefile(path)
        audit = bgp_audit_switching_parent(row,census.parents[index],census;
            parent_index=index,identity,verify_dimensions,check_deadline)
        complete_parents += audit.complete
        evaluations += audit.evaluations
        comparisons += row["comparisons"]
        nodes += row["nodes"]
        union!(edges,audit.edges)
        for record in row["records"]
            record["status"] == "matched" && push!(matched,Tuple(record["candidate_lut"]))
        end
        index < count && _bgp_switch_require(audit.complete,"incomplete parent followed by later checkpoints")
    end
    complete = count == length(census.parents) && complete_parents == count
    _bgp_switch_require(_bgp_switch_field(summary,"complete") === complete,"summary complete flag differs")
    _bgp_switch_require(_bgp_switch_count(summary,"parents_completed") == complete_parents,
        "summary completed-parent count differs")
    _bgp_switch_require(_bgp_switch_count(summary,"evaluations") == evaluations &&
        _bgp_switch_count(summary,"comparisons") == comparisons &&
        _bgp_switch_count(summary,"nodes") == nodes,"summary search counters differ")
    _bgp_switch_require(_bgp_switch_count(summary,"unique_matched_luts") == length(matched),
        "summary unique candidate count differs")
    recorded_edges = Set(Tuple(edge) for edge in _bgp_switch_field(summary,"edges"))
    _bgp_switch_require(recorded_edges == edges,"summary connection edges differ from certificates")
    components = _bgp_audit_components(length(census.roots),edges)
    _bgp_switch_require(_bgp_switch_field(summary,"components") == components,
        "summary connected components differ")
    _bgp_switch_require(_bgp_switch_field(summary,"conjecture_proved") === false,
        "switching closure does not prove all APN functions are known")
    _bgp_switch_audit_check(check_deadline)
    return (;complete,parents_checked=count,complete_parents,evaluations,
        comparisons,nodes,edges,components,unique_matched_luts=length(matched))
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 2 || error("usage: section32_switching_audit.jl SUMMARY.toml CENSUS.toml")
    isdefined(@__MODULE__,:bgp_saved_census) || include(joinpath(@__DIR__, "section32_switching.jl"))
    census = bgp_saved_census(ARGS[2])
    println(bgp_audit_switching_results(ARGS[1],census))
end
