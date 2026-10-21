module ClosureEquivalenceSnapshotTests
using Test,VBFSearch
const FP=VBFSearch

"""Synthetic persistence identities; no mathematical equivalence is asserted."""
function target_properties(i;sigma=i==3 ? "bucket-b" : "bucket-a")
    lut=UInt8.(0:255) .⊻ UInt8(i)
    Dict{String,Any}("lut_sha256"=>FP.DiscoveryEvidence.lut_id(lut),"lut_hex"=>bytes2hex(lut),
        "sigma_hash"=>sigma,"apn"=>true,"quadratic"=>true,"differential_uniformity"=>2,
        "algebraic_degree"=>2,"ortho_lut_hex"=>"")
end

"""Build real legacy/normalized schemas without a campaign or production input."""
function fixture(f;normalized=false)
    mktempdir() do directory
        db=FP.SQLite.DB();FP._closure_create_schema(db;normalized)
        lease=FP._closure_lease(directory)
        s=FP.ClosureStore(db,directory,lease,Dict{String,Any}(),1,UInt64(0))
        properties=Dict(i=>target_properties(i) for i in 1:8)
        try
            FP._closure_exec(s,"PRAGMA foreign_keys=ON")
            for i in 1:8
                FP._closure_insert_candidate!(s,properties[i])
                i<=3 && FP._closure_add_parent!(s,properties[i]["lut_sha256"],properties[i]["sigma_hash"])
            end
            for i in (4,5)
                id=properties[i]["lut_sha256"]
                FP._closure_add_job!(s,1,"deduplicate","deduplicate:$id",Dict("candidate_id"=>id))
            end
            f(s,properties)
        finally
            FP.DiscoveryStore.close_statements!(s.statements);close(db);close(lease)
        end
    end
end

"""Compare cached and ordinary target identities, including deterministic order."""
function exact_targets(s,sigma,cache)
    plain=FP._closure_parent_targets(s,sigma)
    cached=FP._closure_parent_targets(s,sigma,cache)
    @test [Dict(row) for row in cached]==plain
    @test issorted([row["id"] for row in cached])
    cached
end

"""Resolve one immutable reference row against the exact uncached point query."""
function exact_parent(s,id,cache)
    plain=FP._closure_parent_target(s,id)
    cached=FP._closure_parent_target(s,id,cache)
    @test cached["candidate_id"]==plain["candidate_id"]
    @test cached["lut_hex"]==plain["lut_hex"]
    cached
end

@testset "Target snapshots are immutable, ordered, connection-bound and bounded" begin
    for normalized in (false,true)
        fixture(;normalized) do s,properties
            cache=FP._ClosureParentTargetCache(s;max_targets=3,max_entries=2)
            @test_throws ErrorException FP._ClosureParentTargetCache(s)
            @test_throws ArgumentError FP._ClosureParentTargetCache(s;max_targets=0)
            @test_throws ArgumentError FP._ClosureParentTargetCache(s;max_entries=0)
            rows=exact_targets(s,"bucket-a",cache)
            @test [row["id"] for row in rows]==[1,2]
            @test FP._closure_parent_targets(s,"bucket-a",cache)===rows
            @test FP._closure_parent_target(s,1,cache)===rows[1]
            original=rows[1]["lut_hex"];copied=copy(rows[1]);copied["lut_hex"]="changed"
            @test rows[1]["lut_hex"]==original
            immutable_graph(value)=value isa String || (isimmutable(value) && all(
                immutable_graph(getfield(value,index)) for index in 1:fieldcount(typeof(value))))
            @test immutable_graph(rows)
            @test_throws Exception setindex!(rows,rows[2],1)
            @test_throws MethodError setindex!(rows[1],"changed","lut_hex")
            @test_throws KeyError rows[1]["saved_exhaustive"]
            exact_parent(s,2,cache);exact_targets(s,"bucket-b",cache)
            stats=FP._closure_parent_target_cache_stats(cache)
            @test stats["target_rows"]==3 && stats["entries"]==2
            @test stats["hits"]>=1 && stats["parent_hits"]>=2
            exact_targets(s,"empty-a",cache)
            @test !haskey(cache.parent_rows,1) && !haskey(cache.parent_rows,2)
            exact_parent(s,1,cache)
            for i in 1:10;exact_targets(s,"empty-$i",cache);end
            stats=FP._closure_parent_target_cache_stats(cache)
            @test stats["entries"]<=2 && stats["target_rows"]<=3
            @test stats["evictions"]>0 && stats["parent_misses"]>0
            @test length(cache.order)<=2cache.max_entries
            exact_targets(s,missing,cache);exact_targets(s,123,cache)
            @test FP._closure_parent_target_cache_stats(cache)["bypasses"]>=2
            @test_throws ArgumentError FP._closure_parent_target(s,999,cache)
            @test isempty(FP._closure_rows(s,"SELECT name FROM main.sqlite_master WHERE name LIKE 'closure_parent_targets_%'"))
            @test FP._closure_count(s,"SELECT COUNT(*) n FROM temp.sqlite_master WHERE type='trigger' AND name LIKE 'closure_parent_targets_%'")==6
            fixture(;normalized) do other,_
                @test_throws ArgumentError FP._closure_parent_targets(other,"bucket-a",cache)
                @test_throws ArgumentError FP._closure_parent_target(other,1,cache)
            end
        end
        fixture(;normalized) do s,_
            cache=FP._ClosureParentTargetCache(s;max_targets=1)
            exact_targets(s,"bucket-a",cache);exact_targets(s,"bucket-a",cache)
            stats=FP._closure_parent_target_cache_stats(cache)
            @test stats["target_rows"]==0 && stats["entries"]==0 && stats["oversized"]==2
            @test isempty(cache.parent_rows)
        end
        fixture(;normalized) do s,_
            FP._closure_exec(s,"BEGIN IMMEDIATE")
            @test_throws ErrorException FP._ClosureParentTargetCache(s)
            FP._closure_exec(s,"ROLLBACK")
        end
    end
end

@testset "Identity triggers invalidate snapshots without clearing on admission state" begin
    for normalized in (false,true)
        fixture(;normalized) do s,properties
            ex(sql,args=())=FP._closure_exec(s,sql,args)
            cache=FP._ClosureParentTargetCache(s);exact_targets(s,"bucket-a",cache)
            physical=normalized ? "closure_candidates" : "candidates"
            initial=cache.clears
            for i in (1,4)
                ex("UPDATE $physical SET class_id=1,state='equivalent' WHERE id=?",(properties[i]["lut_sha256"],))
            end
            ex("UPDATE $physical SET sigma='unused-change' WHERE id=?",(properties[8]["lut_sha256"],))
            @test cache.clears==initial
            exact_targets(s,"bucket-a",cache);exact_parent(s,1,cache)
            ex("UPDATE $physical SET sigma='identity-change' WHERE id=?",(properties[1]["lut_sha256"],))
            @test cache.clears>initial && cache.dirty && isempty(cache.entries) && isempty(cache.parent_rows)
            exact_targets(s,"bucket-a",cache)
            changed_lut=repeat("fe",256)
            if normalized
                ex("UPDATE closure_candidates SET lut=? WHERE id=?",(hex2bytes(changed_lut),properties[1]["lut_sha256"]))
            else
                ex("UPDATE candidates SET lut_hex=? WHERE id=?",(changed_lut,properties[1]["lut_sha256"]))
            end
            @test exact_targets(s,"bucket-a",cache)[1]["lut_hex"]==changed_lut
            @test exact_parent(s,1,cache)["lut_hex"]==changed_lut
            ex("UPDATE parents SET candidate_id=? WHERE id=1",(properties[6]["lut_sha256"],))
            @test exact_parent(s,1,cache)["candidate_id"]==properties[6]["lut_sha256"]
            ex("UPDATE parents SET sigma='bucket-b' WHERE id=1")
            @test [row["id"] for row in exact_targets(s,"bucket-a",cache)]==[2]
            @test [row["id"] for row in exact_targets(s,"bucket-b",cache)]==[1,3]
            ex("DELETE FROM jobs WHERE parent_id=3");ex("UPDATE parents SET id=33 WHERE id=3")
            @test [row["id"] for row in exact_targets(s,"bucket-b",cache)]==[1,33]
            ex("DELETE FROM parents WHERE id=33")
            @test [row["id"] for row in exact_targets(s,"bucket-b",cache)]==[1]
            parent=FP._closure_add_parent!(s,properties[7]["lut_sha256"],"bucket-a")
            @test [row["id"] for row in exact_targets(s,"bucket-a",cache)]==[2,parent]
            ex("PRAGMA foreign_keys=OFF")
            ex("DELETE FROM $physical WHERE id=?",(properties[2]["lut_sha256"],))
            @test [row["id"] for row in exact_targets(s,"bucket-a",cache)]==[parent]
            @test_throws ArgumentError FP._closure_parent_target(s,2,cache)
            FP._closure_insert_candidate!(s,properties[2])
            @test [row["id"] for row in exact_targets(s,"bucket-a",cache)]==[2,parent]
            ex("UPDATE $physical SET id='maintenance-id' WHERE id=?",(properties[2]["lut_sha256"],))
            @test [row["id"] for row in exact_targets(s,"bucket-a",cache)]==[parent]
            ex("UPDATE parents SET candidate_id='maintenance-id' WHERE id=2")
            @test exact_parent(s,2,cache)["candidate_id"]=="maintenance-id"
        end
    end
end

@testset "Cache reads after mutations never retain rolled-back identities" begin
    for normalized in (false,true)
        fixture(;normalized) do s,properties
            ex(sql,args=())=FP._closure_exec(s,sql,args)
            cache=FP._ClosureParentTargetCache(s)
            ex("BEGIN IMMEDIATE")
            baseline=exact_targets(s,"bucket-a",cache)
            @test length(cache.entries)==1 && !cache.dirty
            ex("SAVEPOINT mutation")
            parent=FP._closure_add_parent!(s,properties[7]["lut_sha256"],"bucket-a")
            @test length(exact_targets(s,"bucket-a",cache))==3
            exact_parent(s,parent,cache)
            @test cache.dirty && isempty(cache.entries) && isempty(cache.parent_rows)
            ex("ROLLBACK TO mutation");ex("RELEASE mutation")
            @test length(exact_targets(s,"bucket-a",cache))==2
            @test cache.dirty && isempty(cache.entries)
            @test_throws ArgumentError FP._closure_parent_target(s,parent,cache)
            ex("COMMIT");FP._closure_parent_target_cache_boundary!(cache)
            @test !cache.dirty && isempty(cache.entries)
            @test exact_targets(s,"bucket-a",cache)==baseline
            ex("BEGIN IMMEDIATE");ex("SAVEPOINT identity")
            ex("UPDATE parents SET candidate_id=? WHERE id=1",(properties[6]["lut_sha256"],))
            @test exact_parent(s,1,cache)["candidate_id"]==properties[6]["lut_sha256"]
            exact_targets(s,"bucket-a",cache)
            ex("ROLLBACK TO identity");ex("RELEASE identity")
            @test exact_parent(s,1,cache)["candidate_id"]==properties[1]["lut_sha256"]
            @test cache.dirty && isempty(cache.entries)
            ex("ROLLBACK");FP._closure_parent_target_cache_boundary!(cache)
            @test exact_targets(s,"bucket-a",cache)==baseline
            ex("BEGIN IMMEDIATE")
            FP._closure_add_parent!(s,properties[7]["lut_sha256"],"bucket-a")
            @test length(exact_targets(s,"bucket-a",cache))==3
            ex("ROLLBACK")
            @test length(exact_targets(s,"bucket-a",cache))==2
            @test !cache.dirty
            ex("BEGIN IMMEDIATE");inside=exact_targets(s,"bucket-a",cache);ex("ROLLBACK")
            @test FP._closure_parent_targets(s,"bucket-a",cache)===inside
        end
    end
end

@testset "Cached packets retain candidate-specific negatives and stale-pair rejection" begin
    for normalized in (false,true)
        fixture(;normalized) do s,properties
            ex(sql,args=())=FP._closure_exec(s,sql,args)
            cache=FP._ClosureParentTargetCache(s)
            jobs=Dict(i=>only(FP._closure_rows(s,"SELECT * FROM jobs WHERE job_key=?",("deduplicate:"*properties[i]["lut_sha256"],))) for i in (4,5))
            function packet(i;native=false,cached=true)
                FP._closure_equivalence_packet(s,jobs[i];native,target_cache=cached ? cache : nothing)
            end
            for i in (4,5), native in (false,true)
                @test packet(i;native)==packet(i;native,cached=false)
                @test FP._closure_packet_digest(packet(i;native))==FP._closure_packet_digest(packet(i;native,cached=false))
            end
            fingerprint=FP.DiscoveryEvidence.solver_fingerprint(FP._closure_solver_session(s))
            negative=Dict{String,Any}("status"=>"inequivalent_by_exhaustive_solver","solver_implementation_sha256"=>fingerprint)
            FP._closure_insert_comparison!(s,properties[4]["lut_sha256"],1,negative)
            @test packet(4)["targets"][1]["saved_exhaustive"]
            @test !packet(5)["targets"][1]["saved_exhaustive"]
            @test packet(4)==packet(4;cached=false)
            FP._closure_insert_comparison!(s,properties[4]["lut_sha256"],1,Dict("status"=>"inconclusive_budget"))
            @test !packet(4)["targets"][1]["saved_exhaustive"]
            @test packet(4)==packet(4;cached=false)
            old=packet(4;native=true)
            exact_parent(s,1,cache)
            result=Dict{String,Any}("schema"=>old["schema"],"packet_sha256"=>old["packet_sha256"],
                "candidate_id"=>old["candidate_id"],"properties"=>properties[4],"complete"=>true,
                "comparisons"=>[Dict("target_parent"=>1,"proof"=>Dict{String,Any}())])
            ex("UPDATE parents SET candidate_id=? WHERE id=1",(properties[6]["lut_sha256"],))
            for cached in (false,true)
                failure=try FP._closure_equivalence_apply!(s,jobs[4],old,result;target_cache=cached ? cache : nothing);nothing catch error;error end
                @test failure isa ErrorException && occursin("equivalence target changed",sprint(showerror,failure))
            end
            ex("UPDATE parents SET candidate_id=? WHERE id=1",(properties[1]["lut_sha256"],))
            exact_targets(s,"bucket-a",cache)
            changed_lut=repeat("fc",256)
            if normalized
                ex("UPDATE closure_candidates SET lut=? WHERE id=?",(hex2bytes(changed_lut),properties[1]["lut_sha256"]))
            else
                ex("UPDATE candidates SET lut_hex=? WHERE id=?",(changed_lut,properties[1]["lut_sha256"]))
            end
            for cached in (false,true)
                failure=try FP._closure_equivalence_apply!(s,jobs[4],old,result;target_cache=cached ? cache : nothing);nothing catch error;error end
                @test failure isa ErrorException && occursin("equivalence target changed",sprint(showerror,failure))
            end
            @test !FP.SQLite.intransaction(s.db)
            @test FP._closure_parent_target_cache_stats(cache)["hits"]>0
            @test FP._closure_parent_target_cache_stats(cache)["parent_hits"]>0
        end
    end
end
end
