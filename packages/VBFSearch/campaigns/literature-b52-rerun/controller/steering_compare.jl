# Compare closure runs by (two, three) lattice-point coverage (see STEERING.md).
#
#   julia --project=STATE/workspace/docs/inspector controller/steering_compare.jl STATE1 [STATE2 ...]
#
# Read-only for each STATE: the ledger is copied with VACUUM INTO to a
# temporary file, the copy gets the lattice points, and the session logs give
# the completion order of the parents. Output: one JSON object per STATE.
using VBFSearch,SQLite,Dates
include(joinpath(@__DIR__,"closure_steering.jl"))
const CS=ClosureSteering
const FP=VBFSearch
utc(s)=DateTime(chopsuffix(String(s),"Z"))

function summary(state;step=1000)
    copy=tempname()*".sqlite"
    source=SQLite.DB("file:"*joinpath(state,"run","closure.sqlite")*"?mode=ro")
    try
        FP._closure_exec(source,"VACUUM INTO ?",(copy,))
    finally
        close(source)
    end
    db=SQLite.DB(copy)
    CS.measure_missing!(db)
    point=Dict{Int,Tuple{Int,Int}}();origin=Dict{Int,String}();admitted=Dict{Int,DateTime}()
    for r in FP._closure_rows(db,"SELECT p.id,p.origin,p.admitted_utc,r.two,r.three FROM parents p JOIN steering_regions r ON r.parent_id=p.id")
        id=Int(r["id"]);point[id]=(Int(r["two"]),Int(r["three"]));origin[id]=String(r["origin"]);admitted[id]=utc(r["admitted_utc"])
    end
    close(db);rm(copy;force=true)
    done=Tuple{DateTime,Int}[];first_dispatch=nothing
    for log in sort(filter(f->startswith(f,"session-"),readdir(joinpath(state,"logs"))))
        for line in eachline(joinpath(state,"logs",log))
            occursin("\"seed_completed\"",line) || continue
            t=get(FP.JSON3.read(line),:timing,nothing);t===nothing && continue
            push!(done,(utc(t[:completed_utc]),Int(t[:parent_id])))
            d=utc(t[:first_dispatch_utc]);first_dispatch=first_dispatch===nothing ? d : min(first_dispatch,d)
        end
    end
    sort!(done);unique!(last,done)
    hours=isempty(done) ? 0.0 : Dates.value(done[end][1]-first_dispatch)/3.6e6
    reached=Set{Tuple{Int,Int}}();curve=Int[]
    for (i,(_,id)) in enumerate(done)
        push!(reached,point[id]);i%step==0 && push!(curve,length(reached))
    end
    count_by(ids)=(c=Dict{Tuple{Int,Int},Int}();for id in ids;c[point[id]]=get(c,point[id],0)+1;end;c)
    A=count_by(keys(point));E=count_by(last.(done))
    ratios=sort!([get(E,p,0)/a for (p,a) in A])
    q(x)=isempty(ratios) ? 0.0 : ratios[clamp(ceil(Int,x*length(ratios)),1,length(ratios))]
    discovered=count(==("discovered"),values(origin))
    new_in_window=isempty(done) ? 0 : count(id->origin[id]=="discovered" && first_dispatch<=admitted[id]<=done[end][1],keys(origin))
    Dict("state"=>state,"parents"=>length(point),"discovered"=>discovered,"expanded"=>length(done),
        "hours"=>round(hours;digits=3),"new_classes_per_hour"=>hours>0 ? round(new_in_window/hours;digits=1) : 0.0,
        "lattice_points"=>length(A),"points_expanded"=>length(E),"points_not_expanded"=>length(A)-length(E),
        "points_reached_per_$(step)_expanded"=>curve,
        "coverage_E_over_A_quantiles"=>Dict("p10"=>q(.1),"p50"=>q(.5),"p90"=>q(.9)))
end

for state in ARGS
    println(FP.JSON3.write(summary(abspath(state))))
end
