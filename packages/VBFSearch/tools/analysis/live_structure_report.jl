"""Incremental VBF structure measurements of a running campaign.

Campaign/catalog inputs are read-only. The separate derived cache stores exact
LUT-keyed VBF measurements. Every report states how many admitted classes have
been measured; it never presents an unfinished census as complete.
"""
module LiveClosureStructure
using VBF,SQLite,JSON3,TOML,SHA,Dates
const SQL=SQLite.DBInterface

"""Compute the rank profile and ortho/nonbent invariants using VBF APIs."""
function measurements(lut,sha)
    bytes2hex(SHA.sha256(lut))==sha || error("candidate LUT binding differs")
    F=SBox{8}(lut);ranks=VBF.QuadraticProfiles.component_ranks(VBF.QuadraticProfiles.coeff_matrix_from_lut(lut))
    counts=[count(==(rank),ranks[2:end]) for rank in (8,6,4,2)]
    bent,c6,c4,c2=counts
    bent==170+4c4+20c2 && c6+5c4+21c2==85 || error("quadratic APN rank identity failed")
    ortho=ortho_derivative(F);signature=nonbent_signature(F)
    item(i)=length(signature)>=i ? Int(signature[i]) : 0
    (sha,bent,c6,c4,c2,algebraic_degree(ortho),differential_uniformity(ortho),item(2),item(3),item(4),1)
end

"""Aggregate one read snapshot of the derived caches; no live-ledger scans."""
function publish(db,run,out,template)
    totals=Dict("seeds"=>0,"known"=>0,"new"=>0,"earlier"=>0)
    tallies=Dict(name=>Dict{Tuple,Int}() for name in ("bent","du","degree","signature","four"))
    total=cutoff=analyzed=0;holds=true
    SQL.execute(db,"BEGIN")
    try
        metadata=only([(n=Int(r.n),cutoff=Int(r.cutoff)) for r in SQL.execute(db,"SELECT COUNT(*) n,MAX(id) cutoff FROM current.classes")])
        total,cutoff=metadata.n,metadata.cutoff
        for r in SQL.execute(db,"SELECT c.origin,c.absent,f.bent,f.c6,f.c4,f.c2,f.degree,f.du,f.two,f.three,f.four,f.identity_ok FROM current.classes c JOIN features f ON f.sha=c.sha")
            group=String(r.origin)=="root" ? "seeds" : r.absent==1 ? "new" : "known"
            totals[group]+=1;analyzed+=1;holds&=r.identity_ok==1
            for (name,key) in (("bent",(group,Int(r.bent),Int(r.c6),Int(r.c4),Int(r.c2))),
                    ("du",(group,Int(r.du))),("degree",(group,Int(r.degree))),
                    ("signature",(group,Int(r.two),Int(r.three))),("four",(group,r.four>0)))
                tally=tallies[name];tally[key]=get(tally,key,0)+1
            end
        end
        SQL.execute(db,"COMMIT")
    catch
        SQL.execute(db,"ROLLBACK");rethrow()
    end
    report=Dict{String,Any}("schema"=>"vbf-closure-structure-v1","generated_utc"=>string(now(UTC))*"Z",
        "run"=>basename(run),"current_run"=>abspath(run),"freeze"=>"live derived cache",
        "reference"=>template["reference"],"live"=>true,"refresh_seconds"=>60,
        "groups"=>[Dict("key"=>key,"name"=>name,"classes"=>totals[key]) for (key,name) in
            (("seeds","Published seeds"),("known","Catalog signature matches"),("new","Outside published catalog"),("earlier","Earlier dataset (not classified here)"))],
        "coverage"=>Dict("classes_analyzed"=>analyzed,"total_classes"=>total,"parent_cutoff"=>cutoff,
            "remaining"=>total-analyzed,"complete"=>analyzed==total),
        "identity_holds"=>holds,"references"=>template["references"],"family_equivalence"=>Any[],"automorphisms"=>nothing,
        "children"=>Dict("seeds"=>24294,"new_total"=>totals["new"],"mean_children"=>0),
        "yield"=>Any[],"corpora"=>Any[],"producers"=>Any[],"methods"=>Any[],"literature"=>Any[])
    fields=Dict("bent"=>("group","bent","c6","c4","c2"),"du"=>("group","du"),
        "degree"=>("group","degree"),"signature"=>("group","two","three"),"four"=>("group","has_four"))
    for (name,tally) in tallies
        report[name]=[merge(Dict(zip(fields[name],key)),Dict("classes"=>value)) for (key,value) in sort!(collect(tally);by=first)]
    end
    catalog=joinpath(out,"catalog.json")
    isfile(catalog) && (report["catalog_comparison"]=JSON3.read(read(catalog,String),Dict{String,Any}))
    tmp=joinpath(out,"structure.json.tmp");write(tmp,JSON3.write(report));mv(tmp,joinpath(out,"structure.json");force=true)
    println(JSON3.write(Dict("event"=>"structure_published","utc"=>report["generated_utc"],"coverage"=>report["coverage"])));flush(stdout)
end

"""Consume new class IDs in bounded batches, preferring both recent and older gaps."""
function watch(run,template_path;batch_size=2048,refresh_seconds=60)
    run=abspath(run);out=joinpath(run,"reports");template=JSON3.read(read(template_path,String),Dict{String,Any})
    db=SQLite.DB(joinpath(out,"features.sqlite"))
    SQL.execute(db,"PRAGMA journal_mode=WAL");SQL.execute(db,"PRAGMA synchronous=NORMAL");SQL.execute(db,"PRAGMA busy_timeout=10000")
    SQL.execute(db,"PRAGMA cache_size=-131072")
    SQL.execute(db,"ATTACH DATABASE ? AS current",("file:"*joinpath(out,"classes.sqlite")*"?mode=ro",))
    last_publish=0.0
    try
        publish(db,run,out,template);last_publish=time()
        while true
            work=Tuple{Int,String}[]
            for order in ("DESC","ASC")
                for r in SQL.execute(db,"SELECT c.id,c.sha FROM current.classes c LEFT JOIN features f ON f.sha=c.sha WHERE f.sha IS NULL ORDER BY c.id $order LIMIT ?",(batch_size÷2,))
                    push!(work,(Int(r.id),String(r.sha)))
                end
            end
            unique!(work)
            if !isempty(work)
                source=SQLite.DB("file:"*joinpath(run,"closure.sqlite")*"?mode=ro")
                luts=Vector{Vector{UInt8}}()
                try
                    SQL.execute(source,"PRAGMA query_only=ON");SQL.execute(source,"PRAGMA busy_timeout=10000")
                    statement=SQLite.Stmt(source,"SELECT c.lut_hex FROM parents p JOIN candidates c ON c.id=p.candidate_id WHERE p.id=? AND p.candidate_id=?")
                    for (id,sha) in work
                        push!(luts,only([hex2bytes(String(r.lut_hex)) for r in SQL.execute(statement,(id,sha))]))
                    end
                finally
                    close(source)
                end
                results=Vector{Any}(undef,length(work))
                Threads.@threads for i in eachindex(work)
                    results[i]=measurements(luts[i],work[i][2])
                end
                SQL.execute(db,"BEGIN IMMEDIATE")
                try
                    statement=SQLite.Stmt(db,"INSERT OR IGNORE INTO features VALUES(?,?,?,?,?,?,?,?,?,?,?)")
                    for result in results;SQL.execute(statement,result);end
                    SQL.execute(db,"COMMIT")
                catch
                    SQL.execute(db,"ROLLBACK");rethrow()
                end
                println(JSON3.write(Dict("event"=>"features_measured","classes"=>length(work),"maximum_parent"=>maximum(first,work))));flush(stdout)
            end
            if time()-last_publish>=refresh_seconds
                publish(db,run,out,template);last_publish=time()
            end
            isempty(work) && sleep(10)
        end
    finally
        close(db)
    end
end
end
if abspath(PROGRAM_FILE)==(@__FILE__)
    LiveClosureStructure.watch(ARGS[1],ARGS[2])
end
