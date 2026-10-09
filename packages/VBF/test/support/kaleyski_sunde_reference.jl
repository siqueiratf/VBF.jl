"""Independent, deliberately direct transcription of Algorithms 1–3 (2026/940)."""
module KSPaperReference
using Random

incidence(p, h) = Int(isodd(count_ones(p & h[1])) == h[2])

"""Algorithm 1: weighted incidence counts, retaining signed cell order."""
function point_signature(points, planes, partition, keys)
    [sum(keys[c] * sum(incidence(p,planes[i]) for i in cell)
         for (c,cell) in enumerate(partition)) for p in points]
end

"""Algorithm 2: weighted intersections with the point cells."""
function plane_signature(points, planes, partition, keys)
    [sum(keys[c] * sum(incidence(points[i],h) for i in cell)
         for (c,cell) in enumerate(partition)) for h in planes]
end

"""Split each cell into blocks of increasing signature; no VBF helpers used."""
function split(partition, scores)
    result = Vector{Int}[]
    shape = Vector{Pair{Int,Int}}[]
    for cell in partition
        values = sort(unique(scores[cell]))
        blocks = [[i for i in cell if scores[i] == value] for value in values]
        append!(result,blocks)
        push!(shape,[v => length(b) for (v,b) in zip(values,blocks)])
    end
    return result,shape
end

"""Algorithm 3: fresh shared keys, alternating splits, size-ordered truncation."""
function refine(left,right,planes_left,planes_right,pl,pr,hl,hr,rng,floor;trace=nothing)
    refining = true
    while refining
        before = length(pl) + length(hl)
        keys = rand(rng,1:8191,length(hl))
        pl,sl = split(pl,point_signature(left,planes_left,hl,keys))
        pr,sr = split(pr,point_signature(right,planes_right,hr,keys))
        sl == sr || return false,pl,pr,hl,hr
        trace === nothing || trace(:points,pl,pr,hl,hr)
        keys = rand(rng,1:8191,length(pl))
        hl,sl = split(hl,plane_signature(left,planes_left,pl,keys))
        hr,sr = split(hr,plane_signature(right,planes_right,pr,keys))
        sl == sr || return false,pl,pr,hl,hr
        trace === nothing || trace(:hyperplanes,pl,pr,hl,hr)
        refining = before != length(pl) + length(hl)
    end
    cells = sortperm(length.(hl);alg=MergeSort)
    kept,total = Int[],0
    for c in cells
        total >= floor && break
        push!(kept,c); total += length(hl[c])
    end
    hl,hr = hl[kept],hr[kept]
    trace === nothing || trace(:trim,pl,pr,hl,hr)
    return true,pl,pr,hl,hr
end

"""Algorithms 5/7 initialization, counted without Walsh transforms."""
function initialize(points,d,floor)
    planes = [(UInt32(a),Bool(c)) for a in 1:((1<<d)-1) for c in 0:1]
    counts = [sum(incidence(p,h) for p in points) for h in planes]
    classes = sort(unique(counts);by=t -> (-abs(2t-length(points)),count(==(t),counts),t))
    partition,total = Vector{Int}[],0
    for t in classes
        total >= floor && break
        cell = findall(==(t),counts)
        push!(partition,cell); total += length(cell)
    end
    return planes,partition
end

"""Section 6 Update: explicitly enumerate the small partial affine domain."""
function update!(A,p,q)
    haskey(A,p) && return A[p] == q
    q in values(A) && return false
    if isempty(A)
        A[p] = q
    else
        anchor = minimum(keys(A))
        for (x,y) in collect(A)
            A[p ⊻ x ⊻ anchor] = q ⊻ y ⊻ A[anchor]
        end
    end
    return true
end

"""Explicit closure is independent of the production Schreier–Sims machinery."""
function closure(generators,n)
    queue = [collect(1:n)]
    seen = Set([Tuple(first(queue))])
    for p in queue
        for g in generators
            q = [g[i] for i in p]
            if !(Tuple(q) in seen)
                push!(seen,Tuple(q)); push!(queue,q)
            end
        end
    end
    return queue
end

stabilize(H,fixed) = [g for g in H if all(i -> g[i]==i,fixed)]

function individualize!(partition,c,p)
    cell = partition[c]
    j = findfirst(==(p),cell)
    cell[1],cell[j] = cell[j],cell[1]
    partition[c] = [p]
    length(cell)>1 && insert!(partition,c+1,cell[2:end])
end

"""ValidCCZ / ValidEA on the affine span, independently of map completion."""
function valid_action(A,left,right,m,ea)
    all(p -> haskey(A,p) && A[p] in right,left) || return nothing
    if ea
        quotient = Dict{UInt32,UInt32}()
        for (p,q) in A
            x,y = p >> m,q >> m
            haskey(quotient,x) && quotient[x]!=y && return nothing
            quotient[x] = y
        end
        length(unique(values(quotient))) == length(quotient) || return nothing
    end
    return [Int(A[p] >> m)+1 for p in left]
end

"""Algorithms 4/6: direct ordered partitions and explicit stabilizer elements."""
function dfs(left,right,hleft,hright,pl,pr,hl,hr,A,fixed,H,state,rng,floor,m,ea,nodes,automatic,printed_condition=false)
    nodes[] += 1
    nodes[] <= 10000 || error("reference DFS budget exceeded")
    ok,pl,pr,hl,hr = refine(left,right,hleft,hright,pl,pr,hl,hr,rng,floor)
    ok || return nothing
    for c in eachindex(pl)
        if length(pl[c])==1
            x,y = only(pl[c]),only(pr[c])
            update!(A,left[x],right[y]) || return nothing
            push!(fixed,y)
        end
    end
    H = stabilize(H,fixed)
    if all(p -> haskey(A,p),left)
        action = valid_action(A,left,right,m,ea)
        action === nothing && return nothing
        if automatic && !(action in state[])
            state[] = closure(vcat(state[],[action]),length(left))
        end
        return action
    end
    cells = [c for c in eachindex(pl) if count(i -> !haskey(A,left[i]),pl[c]) > (printed_condition ? 1 : 0)]
    isempty(cells) && return nothing
    c = first(sort(cells;by=i -> length(pl[i]),alg=MergeSort))
    x = first(i for i in pl[c] if !haskey(A,left[i]))
    touched = Int[]
    for y in pr[c]
        automatic && (H = stabilize(state[],fixed))
        orbit = [g[y] for g in H]
        any(i -> i in orbit,touched) && continue
        push!(touched,y)
        B = copy(A)
        update!(B,left[x],right[y]) || continue
        ql,qr = deepcopy(pl),deepcopy(pr)
        individualize!(ql,c,x); individualize!(qr,c,y)
        result = dfs(left,right,hleft,hright,ql,qr,deepcopy(hl),deepcopy(hr),B,
            vcat(fixed,y),stabilize(H,[y]),state,rng,floor,m,ea,nodes,automatic,printed_condition)
        !automatic && result !== nothing && return result
    end
    return nothing
end

"""Algorithm 7; this tiny reference accepts at most four graph points."""
function equivalence(left,right,d,m;floor=16length(left),seed=940,ea=false,H=[collect(1:length(left))])
    length(left)<=4 || error("reference is intentionally limited to four graph points")
    hleft,hl = initialize(left,d,floor)
    hright,hr = initialize(right,d,floor)
    allcounts(points) = sort([sum(incidence(p,h) for p in points) for h in hleft])
    allcounts(left)==allcounts(right) || return nothing,0
    nodes = Ref(0)
    action = dfs(left,right,hleft,hright,[collect(eachindex(left))],[collect(eachindex(right))],
        hl,hr,Dict{UInt32,UInt32}(),Int[],H,Ref(H),Xoshiro(seed),floor,m,ea,nodes,false)
    return action,nodes[]
end

"""Algorithm 5 graph action, including post-DFS quadratic translations."""
function automorphisms(points,d,m;quadratic=false,floor=16length(points),seed=940,ea=false,printed_condition=false)
    length(points)<=4 || error("reference is intentionally limited to four graph points")
    planes,hp = initialize(points,d,floor)
    H = Ref([collect(eachindex(points))])
    A,fixed = Dict{UInt32,UInt32}(),Int[]
    if quadratic
        update!(A,first(points),first(points)); push!(fixed,1)
    end
    nodes = Ref(0)
    dfs(points,points,planes,planes,[collect(eachindex(points))],[collect(eachindex(points))],
        hp,deepcopy(hp),A,fixed,H[],H,Xoshiro(seed),floor,m,ea,nodes,true,printed_condition)
    if quadratic
        translations = [[(x ⊻ a)+1 for x in 0:(length(points)-1)] for a in 0:(length(points)-1)]
        H[] = closure(vcat(H[],translations),length(points))
    end
    return H[],nodes[]
end
end
