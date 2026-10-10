# Audits Section 3.2's saved quadratic seven-bit CCZ-closure census.
# Paper: Baudrin, Galissant and Perrin (2025), Exploring the Set of APN Functions
# Section: 3.2 — Implementation and Results
#
# Pseudocode:
#   1. Bind each checkpoint to its pinned input and shared producer provenance.
#   2. Verify generators, Walsh subspaces, connected orbits and graph witnesses.
#   3. Aggregate complete roots separately from partial results.
# VBF API used: catalog input loading only; the certificate checks use raw bits.
using TOML, SHA
isdefined(@__MODULE__, :section32_seven_inputs) || include("catalog_validation.jl")
isdefined(@__MODULE__, :bgp_test_apn) || include(joinpath("test", "audit_saved_evidence.jl"))

_bgp_seven_require(condition, message) = condition || throw(ArgumentError(message))
_bgp_seven_expired(budget) = (time_ns()-budget.start)*1e-9 >= budget.timeout

function _bgp_seven_span(basis)
    points = UInt32[0]
    for b in basis
        append!(points, UInt32[p ⊻ b for p in points])
    end
    return sort!(points)
end

function _bgp_seven_apply(columns, point)
    image = UInt32(0)
    while point != 0
        image ⊻= columns[trailing_zeros(point)+1]
        point &= point-UInt32(1)
    end
    return image
end

# Independent augmented binary elimination: the rows of L^-1 are the columns
# of L^-T. This does not call VBF's inverse or transpose implementations.
function _bgp_seven_dual_columns(columns)
    width = length(columns)
    rows = UInt64[
        sum(UInt64((columns[c] >> (r-1)) & 1) << (c-1) for c in 1:width) |
        (UInt64(1) << (width+r-1)) for r in 1:width
    ]
    for c in 1:width
        pivot = findfirst(r -> rows[r] & (UInt64(1) << (c-1)) != 0, c:width)
        _bgp_seven_require(pivot !== nothing, "singular generator")
        r = c+pivot-1
        rows[c],rows[r] = rows[r],rows[c]
        for k in 1:width
            k == c && continue
            rows[k] & (UInt64(1) << (c-1)) != 0 && (rows[k] ⊻= rows[c])
        end
    end
    return UInt32[row >> width for row in rows]
end

function _bgp_seven_zeroes(lut, budget)
    size, n = length(lut), trailing_zeros(length(lut))
    zeroes = falses(size^2)
    zeroes[1] = true
    for a in 0:(size-1)
        _bgp_seven_expired(budget) && return nothing
        for b in 0:(size-1)
            value = sum(isodd(count_ones(a & x)+count_ones(b & lut[x+1])) ? -1 : 1
                for x in 0:(size-1))
            value == 0 && (zeroes[(a << n)+b+1] = true)
        end
    end
    return zeroes
end

function _bgp_seven_audit_row(row, input, index, budget)
    _bgp_seven_expired(budget) && return nothing
    lut = Int.(input.function_value.lut)
    n, width = trailing_zeros(length(lut)), 2trailing_zeros(length(lut))
    require(condition, message) = _bgp_seven_require(condition, "root $index: $message")
    require(row["schema"] == "vbf-sevenbit-closure-v1", "unknown checkpoint schema")
    require(row["root_index"] == index, "filename and root index disagree")
    require(row["source_lut"] == lut, "source LUT differs from the pinned dataset")
    require(row["identifier"] == input.identifier && row["label"] == input.label &&
            row["provenance"] == input.provenance, "source identity differs")
    require(row["subspace_algorithm"] == "optimized", "unexpected subspace backend")
    require(row["algorithm_profile"] in ("paper", "optimized"), "unknown group profile")
    require(bgp_test_apn(lut) && bgp_test_degree(lut) == 2, "source is not quadratic APN")
    require(all(hash -> occursin(r"^[0-9a-f]{64}$", hash), values(row["source_hashes"])),
            "malformed producer hashes")
    require(!isempty(row["source_hashes"]), "missing producer hashes")
    if row["complete"]
        require(all(row[k] === true for k in
            ("automorphisms_complete", "subspaces_complete", "actions_complete")),
            "a complete row contains an interrupted stage")
        require(row["stop_reason"] == "none", "complete row has a stop reason")
        order = tryparse(BigInt,row["group_order"])
        require(order !== nothing && order > 0 && order % (1 << n) == 0,
                "complete quadratic group order lacks its translation subgroup")
    end
    zeroes = _bgp_seven_zeroes(lut, budget)
    zeroes === nothing && return nothing
    spans = Vector{UInt32}[]
    for basis in row["bases"]
        _bgp_seven_expired(budget) && return nothing
        require(length(basis) == n && all(x -> x isa Integer && 0 <= x < 1 << width, basis),
                "invalid Walsh basis dimensions or points")
        span = _bgp_seven_span(UInt32.(basis))
        require(length(unique(span)) == 1 << n, "Walsh basis is not full rank")
        require(all(p -> zeroes[Int(p)+1],span), "subspace contains a nonzero Walsh coefficient")
        push!(spans, span)
    end
    require(length(spans) == row["spaces"], "subspace count differs")
    key = Dict(Tuple(span) => i for (i,span) in pairs(spans))
    require(length(key) == length(spans), "duplicate subspaces")
    orbits = row["orbits"]
    require(all(orbit -> !isempty(orbit),orbits), "empty orbit")
    indices = [i for orbit in orbits for i in orbit]
    require(sort(indices) == collect(eachindex(spans)), "orbits do not partition the subspaces")
    labels = zeros(Int,length(spans))
    for (i,orbit) in pairs(orbits), j in orbit
        labels[j] = i
    end
    adjacency = [Int[] for _ in spans]
    for generator in row["generators"]
        _bgp_seven_expired(budget) && return nothing
        certificate = Dict("dimension"=>n, "source_lut"=>lut, "target_lut"=>lut,
            "linear_columns"=>generator["linear_columns"], "constant"=>generator["constant"],
            "relation"=>"ccz")
        require(bgp_test_certificate(certificate), "invalid graph automorphism generator")
        dual = _bgp_seven_dual_columns(UInt32.(generator["linear_columns"]))
        for (i,span) in pairs(spans)
            image = sort!(UInt32[_bgp_seven_apply(dual,p) for p in span])
            j = get(key,Tuple(image),0)
            require(j != 0 || !row["subspaces_complete"], "generator leaves a complete subspace list")
            j == 0 && continue
            if row["actions_complete"]
                require(labels[i] == labels[j], "generator crosses recorded orbits")
            end
            if labels[i] == labels[j]
                push!(adjacency[i],j)
                push!(adjacency[j],i)
            end
        end
    end
    # Undirected generator edges suffice: inverses belong to the generated
    # group. This also validates connected partial orbits when actions stopped.
    for orbit in orbits
        seen, queue = Set([first(orbit)]), [first(orbit)]
        head = 1
        while head <= length(queue)
            for j in adjacency[queue[head]]
                j in seen && continue
                push!(seen,j); push!(queue,j)
            end
            head += 1
        end
        require(seen == Set(orbit), "recorded orbit is not generator-connected")
    end
    witnesses = row["witnesses"]
    require(length(witnesses) == row["classes"] <= length(orbits), "representative count differs")
    row["complete"] && require(length(witnesses) == length(orbits), "complete row omits an orbit")
    degrees = Dict{String,Int}()
    for (i,witness) in pairs(witnesses)
        _bgp_seven_expired(budget) && return nothing
        require(witness["source_lut"] == lut && witness["dimension"] == n &&
                witness["relation"] == "ccz" && witness["target_index"] == i,
                "representative source or orbit index differs")
        require(bgp_test_certificate(witness), "invalid representative graph certificate")
        columns = UInt32.(witness["linear_columns"])
        input_rows = UInt32[sum(((columns[k] >> r) & UInt32(1)) << (k-1)
            for k in 1:width) for r in n:(width-1)]
        require(_bgp_seven_span(input_rows) == spans[first(orbits[i])],
                "representative input rows differ from the selected orbit basis")
        target = Int.(witness["target_lut"])
        require(bgp_test_apn(target), "representative is not APN")
        degree = string(bgp_test_degree(target))
        degrees[degree] = get(degrees,degree,0)+1
    end
    require(degrees == row["degrees"], "degree histogram differs")
    return Dict{String,Any}("root_index"=>index, "label"=>input.label,
        "complete"=>row["complete"], "classes"=>length(witnesses),
        "spaces"=>length(spans), "degrees"=>degrees,
        "algorithm_profile"=>row["algorithm_profile"])
end

function _bgp_seven_audit_paths(paths, inputs, budget; limit, expected_counts)
    rows = Dict{String,Any}[]
    complete_counts, partial_counts = Dict{String,Int}(), Dict{String,Int}()
    provenance = nothing
    visited_indices = Set{Int}()
    stop_reason = "none"
    for path in paths
        length(rows) >= limit && (stop_reason = "limit"; break)
        _bgp_seven_expired(budget) && (stop_reason = "time"; break)
        index = parse(Int,match(r"root_(\d+)\.toml$",basename(path))[1])
        _bgp_seven_require(1 <= index <= length(inputs), "root index outside the input collection")
        _bgp_seven_require(!(index in visited_indices), "duplicate root checkpoint index")
        push!(visited_indices,index)
        data = TOML.parsefile(path)
        current = Dict("source_hashes"=>data["source_hashes"], "schema"=>data["schema"],
            "algorithm_profile"=>data["algorithm_profile"],
            "subspace_algorithm"=>data["subspace_algorithm"], "base_seed"=>data["seed"]-index+1)
        provenance === nothing ? (provenance = current) :
            _bgp_seven_require(provenance == current, "mixed producer provenance")
        row = _bgp_seven_audit_row(data,inputs[index],index,budget)
        row === nothing && (stop_reason = "time"; break)
        push!(rows,row)
        counts = row["complete"] ? complete_counts : partial_counts
        for (degree,count) in row["degrees"]
            counts[degree] = get(counts,degree,0)+count
        end
    end
    covered = sort([row["root_index"] for row in rows]) == collect(eachindex(inputs))
    complete = covered && all(row -> row["complete"],rows)
    complete && _bgp_seven_require(complete_counts == expected_counts, "degree totals differ from the paper")
    summary = Dict{String,Any}("schema"=>"vbf-sevenbit-checkpoint-audit-v1",
        "closures_complete"=>complete, "roots_audited"=>length(rows),
        "roots_completed"=>count(row -> row["complete"],rows),
        "complete_degree_counts"=>complete_counts, "partial_degree_counts"=>partial_counts,
        "paper_totals_match"=>complete && complete_counts == expected_counts,
        "stop_reason"=>stop_reason, "rows"=>rows,
        "completeness_scope"=>"group and subspace exhaustion recorded by producer; not independently replayed",
        "roots_distinctness"=>"inherited from pinned input collection; not independently certified",
        "elapsed_seconds"=>(time_ns()-budget.start)*1e-9,
        "producer_provenance"=>provenance === nothing ? Dict{String,Any}() : provenance)
    return (;complete,rows,complete_counts,partial_counts,summary)
end

"""
    section32_sevenbit_audit(directory; limit=488, timeout_seconds=120,
        save_results=false, result_name="section32_sevenbit_audit")

Fresh structural and certificate audit of atomic seven-bit root checkpoints.
Checks raw graph maps, direct Walsh coefficients, independent inverse-transpose
actions, connected orbit partitions, representative input rows, APN and degrees.
It does not replay group discovery or exhaustive subspace enumeration: those
completeness claims remain attributed to the saved producer run. Partial roots
are counted separately and cannot establish the paper's total. Writing an audit
summary is opt-in and never changes the input checkpoints.
"""
function section32_sevenbit_audit(directory; limit=488, timeout_seconds=120,
    save_results=false, result_name="section32_sevenbit_audit")
    limit >= 0 || throw(ArgumentError("limit must be nonnegative"))
    timeout_seconds >= 0 || throw(ArgumentError("timeout must be nonnegative"))
    occursin(r"^[A-Za-z0-9_-]+$",result_name) || throw(ArgumentError("invalid result name"))
    budget = (;start=time_ns(),timeout=Float64(timeout_seconds))
    inputs = section32_seven_inputs()
    paths = sort!([joinpath(directory,name) for name in readdir(directory)
        if occursin(r"^root_\d+\.toml$",name)])
    result = _bgp_seven_audit_paths(paths,inputs,budget;limit,
        expected_counts=Dict("2"=>488,"3"=>60302,"4"=>21619))
    result.summary["auditor_source_sha256"] = bytes2hex(sha256(read(@__FILE__)))
    if save_results
        path = joinpath(@__DIR__, "results",result_name*".toml")
        _bgp_seven_require(!(abspath(path) in abspath.(paths)), "audit output would overwrite an input checkpoint")
        open(path*".tmp","w") do io
            TOML.print(io,result.summary;sorted=true)
        end
        mv(path*".tmp",path;force=true)
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 1 || error("supply the seven-bit root checkpoint directory")
    result = section32_sevenbit_audit(only(ARGS))
    println("Audited $(length(result.rows)) roots; complete=$(result.complete)")
end
