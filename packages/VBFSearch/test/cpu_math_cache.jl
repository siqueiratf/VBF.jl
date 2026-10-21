using Test,VBF,VBFSearch,SHA

@testset "Exact-LUT property caches are bounded and cannot be poisoned" begin
    E=VBFSearch.DiscoveryEvidence
    F=gold_apn(8);cache=E.PropertyCache(;max_entries=2)
    expected=E.properties(F.lut)
    first=E.properties(F.lut;cache)
    @test first==expected && cache.misses==1 && cache.hits==0
    first["sigma_hash"]="changed"
    first["ddt_histogram"][1]["count"]=-1
    @test E.properties(copy(F.lut);cache)==expected
    @test cache.hits==1
    for shift in UInt8[1,2]
        lut=F.lut .⊻ shift
        @test E.properties(lut;cache)==E.properties(lut)
        @test length(cache.values)<=2
    end
    @test E.properties(F.lut;cache)==expected
    @test cache.misses==4
    detailed=E.properties(F.lut;cache,detailed=true)
    @test detailed==E.properties(F.lut;detailed=true)
    @test haskey(detailed,"anf") && !haskey(E.properties(F.lut;cache),"anf")
    @test_throws ErrorException E.properties([256;zeros(Int,255)];cache)
    @test_throws ArgumentError E.PropertyCache(;max_entries=-1)
    disabled=E.PropertyCache(;max_entries=0)
    @test E.properties(F.lut;cache=disabled)==expected
    @test isempty(disabled.values)
end

@testset "Each cached parent remains bound to its complete work packet" begin
    E=VBFSearch.DiscoveryEvidence;F=gold_apn(8);p=E.properties(F.lut)
    context=VBFSearch.ClosureWorkContext(;property_cache_entries=2)
    packet=Dict{String,Any}("schema"=>VBFSearch.CLOSURE_WORK_SCHEMA,
        "target_b6"=>52,"max_kernel"=>23,"parent"=>Dict(
            "lut_hex"=>p["lut_hex"],"lut_sha256"=>p["lut_sha256"],"sigma"=>p["sigma_hash"]))
    packet["packet_sha256"]=VBFSearch._closure_packet_digest(packet)
    @test VBFSearch._closure_compute_parent(packet,context)==F
    @test VBFSearch._closure_compute_parent(packet,context)==F
    @test context.property_cache.misses==1 && context.property_cache.hits==1
    for (key,value) in (("sigma","stale"),("lut_sha256","stale"),("lut_hex",bytes2hex(F.lut .⊻ UInt8(1))))
        altered=deepcopy(packet);altered["parent"][key]=value
        altered["packet_sha256"]=VBFSearch._closure_packet_digest(altered)
        @test_throws ErrorException VBFSearch._closure_compute_parent(altered,context)
    end
    malformed=deepcopy(packet);malformed["target_b6"]=54
    @test_throws ErrorException VBFSearch._closure_compute_parent(malformed,context)
end

@testset "Verified execution fingerprints agree with fresh evidence" begin
    E=VBFSearch.DiscoveryEvidence;F=gold_apn(8);p=E.properties(F.lut)
    session=VBFSearch._equivalence_solver_session()
    @test E.solver_fingerprint(session)==E.solver_fingerprint()
    @test session.evidence_sha256==E.filehash(joinpath(pkgdir(VBFSearch),"src","evidence.jl"))
    fresh=E._compare_verified_properties(F.lut,F.lut,p,p;relation=:ea)
    cached=E._compare_verified_properties(F.lut,F.lut,p,p;relation=:ea,solver_session=session)
    @test cached==fresh && E.verify_comparison(cached)
    stale=copy(p);stale["lut_hex"]=bytes2hex(F.lut .⊻ UInt8(1))
    @test_throws ErrorException E._compare_verified_properties(F.lut,F.lut,p,stale;solver_session=session)
end

@testset "Shared property caches preserve independent worker results" begin
    E=VBFSearch.DiscoveryEvidence;F=gold_apn(8)
    cache=E.PropertyCache(;max_entries=2)
    first_context=VBFSearch.ClosureWorkContext(;property_cache=cache)
    second_context=VBFSearch.ClosureWorkContext(;property_cache=cache)
    @test first_context.property_cache===second_context.property_cache===cache
    @test first_context.guard!==second_context.guard
    @test VBFSearch.ClosureWorkContext().property_cache!==VBFSearch.ClosureWorkContext().property_cache
    expected=E.properties(F.lut)
    start=Base.Event()
    tasks=[Threads.@spawn begin
        wait(start)
        E.properties(F.lut;cache)
    end for _ in 1:32]
    notify(start)
    results=fetch.(tasks)
    @test all(==(expected),results)
    @test cache.hits+cache.misses==length(tasks)
    @test length(cache.values)==length(cache.order)==1
    results[1]["sigma_hash"]="changed"
    results[1]["ddt_histogram"][1]["count"]=-1
    @test all(==(expected),results[2:end])
    @test E.properties(F.lut;cache)==expected
    luts=[F.lut .⊻ UInt8(i) for i in 0:7]
    expected_many=E.properties.(luts)
    start_many=Base.Event()
    tasks_many=[Threads.@spawn begin
        wait(start_many)
        E.properties(luts[i];cache)
    end for i in eachindex(luts)]
    notify(start_many)
    @test fetch.(tasks_many)==expected_many
    @test length(cache.values)==length(cache.order)==cache.max_entries
    @test length(unique(cache.order))==length(cache.order)
    @test all(key->haskey(cache.values,key),cache.order)
    @test cache.hits+cache.misses==length(tasks)+1+length(tasks_many)
end
