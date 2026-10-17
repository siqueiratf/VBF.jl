"""Finite affine switching families in a frozen VBFSearch closure export.

Run from the root environment with the analysis directory as the first argument.
The export is read-only evidence from Edel–Pott switching; all new mathematical
checks below use VBF. Recorded edges do not constitute a complete class graph.
"""
module ClosureStructureStudy

using VBF, JSON3, TOML, SHA, Dates, Printf

const QP = VBF.QuadraticProfiles

"""Load exact switching records, retaining each kernel and parent only once."""
function switching_fibers(directory)
    fibers = Dict{Tuple{Int,Int},Dict{String,Any}}()
    for line in eachline(joinpath(directory, "switching-records.jsonl"))
        row = JSON3.read(line)
        direction, combination = parse.(Int, split(String(row.cursor), ':'))
        key = (Int(row.parent_id), direction)
        fiber = get!(fibers, key) do
            kernel = TOML.parse(String(row.kernel_evidence))
            Dict{String,Any}("parent_id"=>key[1], "direction"=>direction,
                "dimension"=>Int(row.dimension), "job_id"=>Int(row.job_id),
                "parent_lut"=>hex2bytes(String(row.parent_lut_hex)),
                "parent_sigma"=>String(row.parent_sigma),
                "parent_origin"=>String(row.parent_origin),
                "parent_source"=>String(row.parent_source),
                "basis"=>[hex2bytes(String(b)) for b in kernel["basis_hex"]],
                "members"=>Dict{Int,Any}())
        end
        fiber["members"][combination] = (
            lut=hex2bytes(String(row.child_lut_hex)),
            sigma=String(row.child_sigma),
            class_id=row.child_class === nothing ? 0 : Int(row.child_class),
            path_id=Int(row.path_id))
    end
    fibers
end

"""Give the Boolean quadratic part as a packed 28-monomial vector."""
function boolean_quadratic_mask(lut)
    C = QP.coeff_matrix_from_lut(lut)
    pairs = [(i,j) for i in 1:8 for j in i+1:8]
    foldl(|, (UInt32(C[i,j] & 1) << (k-1) for (k,(i,j)) in enumerate(pairs)); init=UInt32(0))
end

"""Find the common radical of the polar forms of a Boolean switching space."""
function switching_radical(basis)
    rows = UInt8[]
    for b in basis
        C = QP.coeff_matrix_from_lut(b)
        for i in 1:8
            row = foldl(|, (UInt8(C[min(i,j),max(i,j)] & 1) << (j-1)
                for j in 1:8 if j != i); init=UInt8(0))
            push!(rows, row)
        end
    end
    radical = kernel_f2(rows; nbits=8)
    quotient_coordinates = kernel_f2(radical; nbits=8)
    Dict{String,Any}("radical_dimension"=>length(radical),
        "radical_basis"=>Int.(radical), "quotient_dimension"=>length(quotient_coordinates),
        "quotient_linear_form_masks"=>Int.(quotient_coordinates))
end

"""Enumerate bounded affine parameter symmetries preserving every recorded class."""
function parameter_symmetries(members,d; max_nodes=1000000, timeout_seconds=10)
    labels = [m["sigma_hash"] for m in members]
    groups = Dict(label=>UInt8[i-1 for i in eachindex(labels) if labels[i]==label] for label in unique(labels))
    maps = Vector{Vector{Int}}()
    nodes = Ref(0); stopped = Ref(false); started=time()
    function extend!(columns,images,constant)
        nodes[] += 1
        if nodes[]>max_nodes || time()-started>timeout_seconds
            stopped[]=true; return
        end
        k=length(columns)
        if k==d
            push!(maps,Int.(images)); return
        end
        for target in groups[labels[(1<<k)+1]]
            column=target ⊻ constant
            is_in_span(column,columns;nbits=d) && continue
            next=images .⊻ column
            all(labels[Int(next[i])+1]==labels[(1<<k)+i] for i in eachindex(next)) || continue
            extend!(vcat(columns,column),vcat(images,next),constant)
            stopped[] && return
        end
    end
    for constant in groups[first(labels)]
        extend!(UInt8[],UInt8[constant],constant)
        stopped[] && break
    end
    orders=Int[]
    for map in maps
        iterate=collect(0:(1<<d)-1)
        order=0
        while true
            iterate=map[iterate .+ 1]; order+=1
            iterate==collect(0:(1<<d)-1) && break
            order<=4096 || error("unexpected parameter permutation order")
        end
        push!(orders,order)
    end
    Dict{String,Any}("complete"=>!stopped[], "search_nodes"=>nodes[], "order"=>length(maps),
        "element_order_histogram"=>Dict(string(o)=>count(==(o),orders) for o in sort!(unique(orders))),
        "maps"=>maps,"element_orders"=>orders,
        "scope"=>"Affine symmetries of the finite parameter-to-class partition; not yet a uniform action on input/output coordinates.")
end

"""Recognize an exact finite-field norm description of the class partition."""
function norm_model(members,symmetries,d)
    labels=[m["sigma_hash"] for m in members]
    multiplicities=Dict(label=>count(==(label),labels) for label in unique(labels))
    singleton=findfirst(i->multiplicities[labels[i]]==1,eachindex(labels))
    singleton===nothing && return Dict("found"=>false)
    anchor=singleton-1
    for (map,order) in zip(symmetries["maps"],symmetries["element_orders"])
        order in (3,5) || continue
        centered_columns=UInt8[map[((1<<i)⊻anchor)+1]⊻anchor for i in 0:d-1]
        T=F2LinearMap{d,UInt8}(centered_columns)
        diff=UInt8[centered_columns[i+1]⊻UInt8(1<<i) for i in 0:d-1]
        moving=linear_basis(diff;nbits=d)
        m=length(moving)
        m==(order==3 ? 2 : 4) || continue
        equations=UInt8[foldl(|,(UInt8((diff[j]>>(i-1))&1)<<(j-1) for j in 1:d);init=UInt8(0)) for i in 1:d]
        fixed=kernel_f2(equations;nbits=d)
        orbit=UInt8[first(moving)]
        for _ in 2:m; push!(orbit,T(last(orbit))); end
        rank_f2(vcat(fixed,orbit);nbits=d)==d || continue
        E=F2LinearMap{d,UInt8}(vcat(orbit,zeros(UInt8,d-m)))
        modulus=m==2 ? 7 : 31
        exponent=((1<<m)-1)÷((1<<(m÷2))-1)
        all(E(gf_mul(2,z,m;modulus))==T(E(z)) for z in 0:(1<<m)-1) || error("field embedding differs")
        classes=Dict{Tuple{Int,Int},String}()
        valid=true
        for (u,value) in enumerate(VBF.span_from_basis(fixed)),z in 0:(1<<m)-1
            parameter=anchor ⊻ Int(value) ⊻ Int(E(z))
            key=(u-1,gf_pow(z,exponent,m;modulus))
            label=labels[parameter+1]
            haskey(classes,key) && classes[key]!=label && (valid=false;break)
            classes[key]=label
        end
        valid && length(Set(values(classes)))==length(classes)==length(unique(labels)) || continue
        return Dict{String,Any}("found"=>true,"parameter_anchor"=>anchor,
            "fixed_dimension"=>length(fixed),"fixed_basis"=>Int.(fixed),
            "field_degree"=>m,"field_modulus"=>modulus,"field_basis_in_parameters"=>Int.(orbit),
            "norm_exponent"=>exponent,"norm_target_degree"=>m÷2,
            "all_parameter_pairs_classified"=>true,"parameter_symmetry_order"=>order,
            "parameter_symmetry_map"=>map,
            "description"=>"After the recorded affine parameter change, two members are EA-equivalent iff their fixed coordinates and finite-field norms agree.")
    end
    Dict("found"=>false)
end

"""Check a product of two F4-to-F2 norms in the four-dimensional example."""
function product_norm_model(members,symmetries,d)
    d==4 || return Dict("found"=>false)
    labels=[m["sigma_hash"] for m in members]
    singleton=findfirst(i->count(==(labels[i]),labels)==1,eachindex(labels))
    singleton===nothing && return Dict("found"=>false)
    anchor=singleton-1
    actions=[]
    for (map,order) in zip(symmetries["maps"],symmetries["element_orders"])
        order==3 || continue
        columns=UInt8[map[((1<<i)⊻anchor)+1]⊻anchor for i in 0:d-1]
        T=F2LinearMap{d,UInt8}(columns)
        moving=linear_basis(UInt8[columns[i+1]⊻UInt8(1<<i) for i in 0:d-1];nbits=d)
        length(moving)==2 || continue
        w=first(moving); basis=UInt8[w,T(w)]
        push!(actions,(T=T,basis=basis))
    end
    for a in actions,b in actions
        columns=vcat(a.basis,b.basis)
        rank_f2(columns;nbits=d)==4 || continue
        all(a.T(w)==w for w in b.basis) && all(b.T(w)==w for w in a.basis) || continue
        E=F2LinearMap{d,UInt8}(columns)
        classes=Dict{Tuple{Int,Int},String}(); valid=true
        for z in 0:3,w in 0:3
            parameter=anchor ⊻ Int(E(z|(w<<2)))
            key=(gf_pow(z,3,2;modulus=7),gf_pow(w,3,2;modulus=7))
            label=labels[parameter+1]
            haskey(classes,key) && classes[key]!=label && (valid=false;break)
            classes[key]=label
        end
        valid && length(classes)==length(Set(values(classes)))==4 || continue
        return Dict{String,Any}("found"=>true,"parameter_anchor"=>anchor,"field_modulus"=>7,
            "first_field_basis"=>Int.(a.basis),"second_field_basis"=>Int.(b.basis),
            "all_parameter_pairs_classified"=>true,
            "description"=>"Two members are EA-equivalent iff both F4-to-F2 norms agree; class sizes 1,3,3,9.")
    end
    Dict("found"=>false)
end

"""Replay exported positive EA witnesses using VBF's graph transformation API."""
function replay_class_witnesses(directory)
    path=joinpath(directory,"ea-witnesses.jsonl")
    isfile(path) || return Dict("available"=>false)
    verified=0;identical=0;targets=Set{String}()
    for line in eachline(path)
        proof=JSON3.read(line)
        f,g=hex2bytes(String(proof.candidate_lut_hex)),hex2bytes(String(proof.target_lut_hex))
        bytes2hex(SHA.sha256(f))==proof.candidate_sha256 || error("witness source digest differs")
        bytes2hex(SHA.sha256(g))==proof.target_sha256 || error("witness target digest differs")
        F,G=SBox{8}(f),SBox{8}(g)
        if proof.status=="identical_lut"
            F==G || error("identity witness differs"); identical+=1
        else
            A=F2AffineMap(F2LinearMap(Int.(proof.columns)),Int(proof.constant))
            is_invertible(A.linear) && all(iszero(c>>8) for c in A.linear.cols[1:8]) || error("graph map is not EA")
            ccz_equivalent_function(F,A)==G || error("positive EA witness failed graph replay")
            verified+=1
        end
        push!(targets,String(proof.target_sha256))
    end
    Dict{String,Any}("available"=>true,"positive_EA_witnesses_replayed"=>verified,
        "identical_representatives"=>identical,"distinct_class_targets"=>length(targets),
        "sha256"=>bytes2hex(open(SHA.sha256,path)))
end

"""Try to lift a parameter symmetry to uniform EA input and output linear parts."""
function lift_parameter_symmetry(family; timeout_seconds=5)
    model=family["finite_field_norm_model"]
    get(model,"found",false) || return Dict("attempted"=>false)
    map=model["parameter_symmetry_map"]
    first_moved=findfirst(i->map[i]!=i-1,eachindex(map))
    first_moved===nothing && return Dict("attempted"=>false)
    members=family["members"]
    functions=[SBox{8}(hex2bytes(m["lut_hex"])) for m in members]
    a=first_moved;b=map[a]+1
    certificate=ea_equivalence_certificate(functions[a],functions[b];
        on_inconclusive=:missing,timeout_seconds,max_nodes=100000,max_memory_bytes=128*1024^2)
    certificate===nothing || ismissing(certificate) && return Dict("attempted"=>true,"found"=>false,"outcome"=>"inconclusive")
    certificate===nothing && return Dict("attempted"=>true,"found"=>false,"outcome"=>"no_certificate")
    is_invertible(certificate.L1) && is_invertible(certificate.A2) || error("singular EA lift")
    transform=Int[];drifts=Vector{Vector{UInt8}}()
    for (i,F) in enumerate(functions)
        candidates=findall(m->m["sigma_hash"]==members[i]["sigma_hash"],members)
        transformed=UInt8[certificate.L1(F(certificate.A2(x))) for x in 0:255]
        fits=Int[];matching_drifts=Vector{Vector{UInt8}}()
        for j in candidates
            drift=functions[j].lut .⊻ transformed
            algebraic_degree(SBox{8}(drift))<=1 || continue
            push!(fits,j-1);push!(matching_drifts,drift)
        end
        length(fits)==1 || return Dict("attempted"=>true,"found"=>false,"outcome"=>"certificate_does_not_act_uniformly_on_family")
        push!(transform,only(fits));push!(drifts,only(matching_drifts))
    end
    inner=certificate.A2 isa F2AffineMap ? certificate.A2.linear : certificate.A2
    constant=certificate.A2 isa F2AffineMap ? Int(certificate.A2.constant) : 0
    Dict{String,Any}("attempted"=>true,"found"=>true,"all_family_members_checked"=>true,
        "first_mask"=>a-1,"second_mask"=>b-1,"induced_parameter_map"=>transform,
        "outer_columns_hex"=>bytes2hex(certificate.L1.cols),"inner_columns_hex"=>bytes2hex(inner.cols),
        "inner_constant"=>constant,"affine_drift_luts_hex"=>bytes2hex.(drifts),
        "one_common_affine_drift"=>all(==(first(drifts)),drifts))
end

"""Reconstruct every vertex, verify APN and degree, and identify class collapses."""
function verify_family(fiber)
    parent, basis, direction = fiber["parent_lut"], fiber["basis"], UInt8(fiber["direction"])
    d = fiber["dimension"]
    length(basis) == d || error("incomplete kernel basis")
    all(length(b)==256 && all(v->v in (0,1),b) for b in basis) || error("invalid Boolean basis")
    masks = boolean_quadratic_mask.(basis)
    quadratic_rank = rank_f2(masks; nbits=28)
    members = Dict{String,Any}[]
    for combination in 0:(1<<d)-1
        lut = copy(parent)
        for j in 1:d
            ((combination >> (j-1)) & 1) == 0 && continue
            for x in eachindex(lut)
                basis[j][x] != 0 && (lut[x] ⊻= direction)
            end
        end
        F = SBox{8}(lut)
        differential_uniformity(F) == 2 && algebraic_degree(F) == 2 ||
            error("switching family contains a nonquadratic or non-APN function")
        p = Dict("sigma_hash"=>sigma_hash(F), "lut_sha256"=>bytes2hex(SHA.sha256(lut)), "lut_hex"=>bytes2hex(lut))
        saved = get(fiber["members"], combination, nothing)
        if saved !== nothing
            lut == saved.lut && p["sigma_hash"] == saved.sigma || error("recorded switching vertex differs")
        elseif combination == 0
            p["sigma_hash"] == fiber["parent_sigma"] || error("parent signature differs")
        end
        C = QP.coeff_matrix_from_lut(lut)
        profile = QP.rank_counts(QP.component_ranks(C))
        push!(members, Dict{String,Any}("mask"=>combination, "lut_hex"=>p["lut_hex"],
            "lut_sha256"=>p["lut_sha256"], "sigma_hash"=>p["sigma_hash"],
            "recorded"=>combination == 0 || saved !== nothing,
            "class_id"=>combination == 0 ? fiber["parent_id"] : saved === nothing ? 0 : saved.class_id,
            "component_rank_counts_8_6_4_2_0"=>collect(profile)))
    end
    distinct = length(Set(m["sigma_hash"] for m in members))
    known_ids = Set(m["class_id"] for m in members if m["class_id"] != 0)
    fully_classified = all(m["class_id"] != 0 for m in members)
    fully_classified && length(known_ids) != distinct && error("class identifiers and signature counts differ")
    for sigma in unique(m["sigma_hash"] for m in members)
        ids=Set(m["class_id"] for m in members if m["sigma_hash"]==sigma)
        fully_classified && length(ids)!=1 && error("equal-signature members have different class identifiers")
    end
    orbit_hist=Dict(string(n)=>count(s->count(m->m["sigma_hash"]==s,members)==n,unique(m["sigma_hash"] for m in members))
        for n in sort!(unique(count(m->m["sigma_hash"]==s,members) for s in unique(m["sigma_hash"] for m in members))))
    parameter=parameter_symmetries(members,d)
    model=norm_model(members,parameter,d)
    product=product_norm_model(members,parameter,d)
    parameter_lut=UInt8[foldl(|,(UInt8(basis[j][x]!=0)<<(j-1) for j in 1:d);init=UInt8(0)) for x in 1:256]
    parameter_ranks=QP.component_ranks(QP.coeff_matrix_from_lut(parameter_lut))[2:(1<<d)]
    form_rank_hist=Dict(string(r)=>count(==(r),parameter_ranks) for r in sort!(unique(parameter_ranks)))
    geometry = switching_radical(basis)
    factorization = Dict{String,Any}("checked"=>false)
    if geometry["quotient_dimension"] == 4 && d == 6 && quadratic_rank == 6
        forms = UInt8.(geometry["quotient_linear_form_masks"])
        products = [UInt8[isodd(count_ones(forms[i] & UInt8(x))) && isodd(count_ones(forms[j] & UInt8(x)))
            for x in 0:255] for i in 1:4 for j in i+1:4]
        product_masks = boolean_quadratic_mask.(products)
        spans_equal = rank_f2(vcat(masks, product_masks); nbits=28) == 6
        spans_equal || error("four-variable factorization differs")
        factorization = Dict{String,Any}("checked"=>true, "equal_modulo_affine_terms"=>true,
            "description"=>"All six quadratic products of four quotient linear forms; affine terms may be removed separately for each member.")
    end
    Dict{String,Any}("parent_id"=>fiber["parent_id"], "parent_origin"=>fiber["parent_origin"],
        "parent_source"=>fiber["parent_source"], "direction"=>Int(direction),
        "parameter_dimension"=>d, "vertices"=>length(members),
        "all_vertices_quadratic_APN_recomputed"=>true,
        "all_vertices_recorded"=>all(m["recorded"] for m in members),
        "distinct_signatures"=>distinct, "distinct_assigned_classes"=>length(known_ids),
        "fully_classified"=>fully_classified, "quadratic_parameter_rank"=>quadratic_rank,
        "class_multiplicity_histogram"=>orbit_hist,"parameter_symmetries"=>parameter,
        "finite_field_norm_model"=>model,"switching_form_rank_histogram"=>form_rank_hist,
        "product_norm_model"=>product,
        "geometry"=>geometry, "four_variable_factorization"=>factorization,
        "basis_hex"=>bytes2hex.(basis), "boolean_quadratic_masks"=>Int.(masks), "members"=>members)
end

"""Summarize observed class edges without asserting that absent edges do not exist."""
function observed_switching_graph(fibers)
    adjacent = Dict{Int,Set{Int}}()
    edges = Set{Tuple{Int,Int}}()
    loops, unresolved = 0, 0
    for fiber in values(fibers), member in values(fiber["members"])
        a, b = fiber["parent_id"], member.class_id
        b == 0 && (unresolved += 1; continue)
        a == b && (loops += 1; continue)
        push!(edges, minmax(a,b))
        push!(get!(adjacent,a,Set{Int}()),b)
        push!(get!(adjacent,b,Set{Int}()),a)
    end
    remaining = Set(keys(adjacent))
    components = Vector{Vector{Int}}()
    while !isempty(remaining)
        start = first(remaining); delete!(remaining,start)
        component, queue = Int[], [start]
        while !isempty(queue)
            a = pop!(queue); push!(component,a)
            for b in adjacent[a]
                b in remaining || continue
                delete!(remaining,b); push!(queue,b)
            end
        end
        push!(components,sort!(component))
    end
    sort!(components; by=c->(-length(c),first(c)))
    Dict{String,Any}("nonloop_class_edges"=>length(edges), "recorded_self_class_edges"=>loops,
        "unresolved_recorded_edges"=>unresolved, "vertices_with_edges"=>length(adjacent),
        "observed_components"=>length(components),
        "component_size_histogram"=>Dict(string(n)=>count(c->length(c)==n,components) for n in sort!(unique(length.(components)))),
        "largest_component_vertices"=>isempty(components) ? Int[] : first(components),
        "scope"=>"Only observed provenance edges; missing edges and component separation are not certified.")
end

"""Write a two-layer view of a cube and its additional parameter dimensions."""
function write_cube(directory, family)
    d = family["parameter_dimension"]
    n = min(d,3)
    open(joinpath(directory,"switching-cube.dot"),"w") do io
        println(io,"graph Cube { graph [layout=neato, overlap=false, bgcolor=white]; node [shape=circle,fontname=\"DejaVu Sans\"]; ")
        for t in 0:(1<<n)-1
            x = 2*((t>>0)&1) + 0.7*((t>>2)&1)
            y = 2*((t>>1)&1) + 0.7*((t>>2)&1)
            label = string(t; base=2,pad=n)
            println(io,"v$t [label=\"$label\",pos=\"$x,$(y)!\"];")
            for j in 0:n-1
                s = t ⊻ (1<<j)
                t < s && println(io,"v$t -- v$s [label=\"s$(j+1)\",fontsize=10];")
            end
        end
        println(io,"label=\"Verified 3-face of an affine $d-cube: $(1<<d) APN functions, $(family["distinct_signatures"]) separated classes.\"; labelloc=b; }")
    end
end

"""Study every recorded nontrivial switching fiber and verify selected large examples."""
function main(directory; limit=12)
    started = time()
    fibers = switching_fibers(directory)
    rows = collect(values(fibers))
    d_hist = Dict(string(d)=>count(f->f["dimension"]==d,rows) for d in sort!(unique(f["dimension"] for f in rows)))
    profile_hist = Dict{String,Int}()
    class_sets=Dict{String,Set{String}}()
    for f in rows
        sigmas = Set([f["parent_sigma"]; [m.sigma for m in values(f["members"])]] )
        f["distinct_recorded_signatures"] = length(sigmas)
        f["complete_recorded_cube"] = length(f["members"]) == (1<<f["dimension"])-1
        key = "d$(f["dimension"]):$(length(sigmas))_classes"
        profile_hist[key] = get(profile_hist,key,0)+1
        identifier=bytes2hex(SHA.sha256(join(sort!(collect(sigmas)),',')))
        push!(get!(class_sets,key,Set{String}()),identifier)
    end
    sort!(rows; by=f->(-f["distinct_recorded_signatures"],-f["dimension"],f["parent_id"],f["direction"]))
    graph = observed_switching_graph(fibers)
    println("Loaded $(length(rows)) fibers; quotient dimensions: $d_hist"); flush(stdout)
    examples = Dict{String,Any}[]
    cells=Set{Tuple{Int,Int}}()
    selected=Dict{String,Any}[]
    for f in rows
        cell=(f["dimension"],f["distinct_recorded_signatures"])
        cell in cells && continue
        push!(cells,cell);push!(selected,f)
    end
    for f in Iterators.take(selected,limit)
        verified = verify_family(f)
        push!(examples,verified)
        @printf("Verified parent %d, direction %d: 2^%d = %d vertices, %d signatures, radical dimension %d\n",
            f["parent_id"],f["direction"],f["dimension"],verified["vertices"],verified["distinct_signatures"],verified["geometry"]["radical_dimension"])
        flush(stdout)
        println("  multiplicities $(verified["class_multiplicity_histogram"]); parameter symmetry group $(verified["parameter_symmetries"]["order"]); norm model $(verified["finite_field_norm_model"])")
        flush(stdout)
    end
    for family in examples
        family["parameter_dimension"]==6 || continue
        family["uniform_EA_lift"]=lift_parameter_symmetry(family)
        println("EA lift for parent $(family["parent_id"]): $(get(family["uniform_EA_lift"],"outcome",get(family["uniform_EA_lift"],"found",false)))")
        flush(stdout)
    end
    replay=replay_class_witnesses(directory)
    snapshot = JSON3.read(read(joinpath(directory,"snapshot.json"),String),Dict{String,Any})
    report = Dict{String,Any}("generated_utc"=>string(Dates.now(Dates.UTC))*"Z", "snapshot"=>snapshot,
        "fibers_with_evaluated_candidates"=>length(rows), "dimension_histogram"=>d_hist,
        "dimension_and_distinct_signature_histogram"=>profile_hist,
        "distinct_class_sets_by_dimension_and_class_count"=>Dict(k=>length(v) for (k,v) in class_sets),
        "fully_recorded_fibers"=>count(f->f["complete_recorded_cube"],rows),
        "graph"=>graph, "verified_families"=>examples, "class_witness_replay"=>replay,"elapsed_seconds"=>time()-started,
        "study_sha256"=>bytes2hex(open(SHA.sha256,@__FILE__)),
        "scope"=>"Finite verified structures in this snapshot. No infinite-family claim or claim of literature novelty.")
    open(joinpath(directory,"structure.json"),"w") do io
        JSON3.pretty(io,report)
    end
    write_cube(directory,first(examples))
    println("Results: ",joinpath(directory,"structure.json"))
end

if abspath(PROGRAM_FILE) == @__FILE__
    isempty(ARGS) && error("usage: julia --project=. closure_structure.jl ANALYSIS_DIRECTORY [EXAMPLES]")
    main(abspath(ARGS[1]); limit=length(ARGS)>1 ? parse(Int,ARGS[2]) : 12)
end

end
