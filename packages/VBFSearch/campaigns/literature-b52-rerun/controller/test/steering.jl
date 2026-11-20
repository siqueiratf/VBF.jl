# Unit tests of the optional region steering (closure_steering.jl).
#   julia --project=STATE/workspace/docs/inspector controller/test/steering.jl
using Test,SQLite,Random
include(joinpath(@__DIR__,"..","closure_steering.jl"))
using .ClosureSteering: steer_select,fifo_places,steering_options,measure_missing!,steered_rows,lattice_point
const FP=ClosureSteering.FP

"""Synthetic frontier: ids 1..n, points from a fixed list, all unexpanded."""
function synthetic(n;points=[(1,1),(1,1),(1,1),(1,1),(2,5),(3,7)],covered=Dict{Tuple{Int,Int},Int}())
    point=Dict(id=>points[mod1(id,length(points))] for id in 1:n)
    available=Dict{Tuple{Int,Int},Int}();for p in values(point);available[p]=get(available,p,0)+1;end
    admitted=Dict(p=>available[p]+get(covered,p,0) for p in keys(available))
    collect(1:n),point,available,admitted
end

@testset "options" begin
    @test steering_options(Dict()) === nothing
    @test steering_options(Dict("steering"=>"none")) === nothing
    o=steering_options(Dict("steering"=>"region"))
    @test o.fifo_share==0.5 && o.score=="ratio"
    @test_throws ArgumentError steering_options(Dict("steering"=>"region","steering_fifo_share"=>0))
    @test_throws ArgumentError steering_options(Dict("steering"=>"region","steering_fifo_share"=>1.5))
    @test_throws ArgumentError steering_options(Dict("steering"=>"other"))
    @test_throws ArgumentError steering_options(Dict("steering"=>"region","steering_score"=>"x"))
    @test fifo_places(100,0.5)==50 && fifo_places(100,0.3)==30 && fifo_places(8,0.01)==1 && fifo_places(8,1.0)==8
end

@testset "rule" begin
    f,pt,av,ad=synthetic(60)
    a=steer_select(f,pt,av,ad,8;fifo_share=0.5)
    b=steer_select(copy(f),Dict(pt),Dict(av),Dict(ad),8;fifo_share=0.5)
    @test a==b                                   # deterministic
    @test a.fifo==[1,2,3,4]                      # FIFO share: the lowest ids
    @test length(a.ids)==8 && issorted(a.ids) && allunique(a.ids)
    # The FIFO part (ids 1-4) claims (1,1) four times. (2,5) and (3,7) tie at 0/10;
    # the lowest id (5) breaks the tie. The steered places then alternate.
    @test [pt[id] for id in a.steered]==[(2,5),(3,7),(2,5),(3,7)]
    @test length(unique(pt[id] for id in a.steered))>=2
    # Share 1 is exactly FIFO.
    @test steer_select(f,pt,av,ad,8;fifo_share=1.0).ids==collect(1:8)
    # A smaller frontier than the window takes all of it.
    @test steer_select(f[1:5],pt,av,ad,8).ids==collect(1:5)
    # Score "expanded" prefers the point with fewest claims; "ratio" the lowest share.
    f2,pt2,av2,ad2=synthetic(20;points=[(1,1),(2,2)],covered=Dict((1,1)=>2,(2,2)=>30))
    @test pt2[only(steer_select(f2,pt2,av2,ad2,2;fifo_share=0.5).steered)]==(1,1)   # 3/12 < 31/40
    @test pt2[only(steer_select(f2,pt2,av2,ad2,2;fifo_share=0.5,score="expanded").steered)]==(1,1)
    f3,pt3,av3,ad3=synthetic(20;points=[(1,1),(2,2),(2,2),(2,2)],covered=Dict((1,1)=>1,(2,2)=>4))
    @test pt3[only(steer_select(f3,pt3,av3,ad3,2;fifo_share=0.5).steered)]==(2,2)   # 4/19 < 2/6
    @test pt3[only(steer_select(f3,pt3,av3,ad3,2;fifo_share=0.5,score="expanded").steered)]==(1,1)  # 2 < 4
    @test_throws ArgumentError steer_select([2,1],pt,av,ad,2)
end

@testset "progress" begin
    # Simulated closure: each window completes; each expanded parent admits new
    # children, mostly in one heavy region. Every parent must be expanded, and a
    # parent waits at most ceil(#unfinished older parents / FIFO places) + 1 windows.
    rng=Xoshiro(7)
    for share in (0.125,0.5),score in ("ratio","expanded")
        W=8;point=Dict{Int,Tuple{Int,Int}}();done=Set{Int}();next=1
        admit!(p)=(point[next]=p;next+=1)
        for _ in 1:40;admit!((rand(rng,1:4),0));end
        bound=Dict{Int,Int}();windows=0
        while length(done)<length(point) && windows<5000
            frontier=sort!([id for id in keys(point) if !(id in done)])
            for id in frontier
                haskey(bound,id) || (bound[id]=windows+cld(count(<(id),frontier),fifo_places(W,share))+1)
            end
            available=Dict{Tuple{Int,Int},Int}();admitted=Dict{Tuple{Int,Int},Int}()
            for (id,p) in point
                admitted[p]=get(admitted,p,0)+1
                id in done || (available[p]=get(available,p,0)+1)
            end
            for p in keys(admitted);get!(available,p,0);end
            choice=steer_select(frontier,point,available,admitted,W;fifo_share=share,score)
            @test first(choice.ids)==first(frontier)
            windows+=1
            for id in choice.ids
                push!(done,id);@test windows<=bound[id]
                next<=3000 && for _ in 1:rand(rng,0:2);admit!(rand(rng)<0.8 ? (1,0) : (rand(rng,2:9),1));end
            end
        end
        @test length(done)==length(point)
    end
end

@testset "ledger" begin
    roots=joinpath(@__DIR__,"..","..","inputs","seed_count","selected_roots.tsv")
    luts=[String(split(l,'\t')[2]) for l in Iterators.take(Iterators.drop(eachline(roots),1),24)]
    db=SQLite.DB()
    for sql in ("CREATE TABLE candidates(id TEXT PRIMARY KEY,lut_hex TEXT NOT NULL)",
            "CREATE TABLE parents(id INTEGER PRIMARY KEY,candidate_id TEXT NOT NULL UNIQUE REFERENCES candidates(id),origin TEXT NOT NULL,source TEXT NOT NULL)",
            "CREATE TABLE jobs(id INTEGER PRIMARY KEY,parent_id INTEGER,kind TEXT NOT NULL,status TEXT NOT NULL)")
        FP._closure_exec(db,sql)
    end
    for (i,lut) in enumerate(luts)
        FP._closure_exec(db,"INSERT INTO candidates VALUES(?,?)",("c$i",lut))
        FP._closure_exec(db,"INSERT INTO parents VALUES(?,?,?,?)",(i,"c$i",i<=12 ? "root" : "discovered","s$i"))
        FP._closure_exec(db,"INSERT INTO jobs(parent_id,kind,status) VALUES(?,?,?)",(i,"v5",i<=4 ? "done" : "pending"))
    end
    tables()=[String(r["name"]) for r in FP._closure_rows(db,"SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
    before=tables()
    @test measure_missing!(db;batch=5)==24
    @test measure_missing!(db)==0
    @test setdiff(tables(),before)==["steering_regions"]
    stored=FP._closure_rows(db,"SELECT parent_id,two,three FROM steering_regions ORDER BY parent_id")
    @test [(Int(r["two"]),Int(r["three"])) for r in stored]==[lattice_point(hex2bytes(l)) for l in luts]
    o=steering_options(Dict("steering"=>"region","steering_fifo_share"=>0.25))
    a=redirect_stdout(devnull) do;steered_rows(db,4,"root",Set{Int}(),o);end
    b=redirect_stdout(devnull) do;steered_rows(db,4,"root",Set{Int}(),o);end
    @test a==b && length(a)==4 && first(a)["id"]==5 && all(r->r["origin"]=="root",a)
    c=redirect_stdout(devnull) do;steered_rows(db,4,"root",Set([5]),o);end
    @test first(c)["id"]==6 && !(5 in [r["id"] for r in c])
    @test isempty(redirect_stdout(devnull) do;steered_rows(db,4,"none",Set{Int}(),o);end)
    # A newly admitted parent is measured at the next selection.
    FP._closure_exec(db,"INSERT INTO candidates VALUES('c25',?)",(luts[1],))
    FP._closure_exec(db,"INSERT INTO parents VALUES(25,'c25','discovered','s25')")
    @test measure_missing!(db)==1
end
