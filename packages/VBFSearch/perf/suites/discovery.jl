# Application benchmarks: VBF-backed evidence and transactional persistence.
# Mathematical enumeration kernels remain in VBF/perf.
function register!(reg)
    for detailed in (false,true)
        benchmark!(reg; group="evidence", name=detailed ? "candidate_properties_detailed" : "candidate_properties",
            n=8, setup=()->UInt8.(gold_apn(8,1).lut),
            call=lut->candidate_properties(lut;detailed),
            validate=(lut,p)->(@assert p["apn"] && p["algebraic_degree"]==2),
            parameters=(;detailed),note="VBF differential spectrum, degree and signature; optional VBF statistics")
    end
    F=gold_apn(8,1);G=gold_apn(8,3)
    for (name,H) in (("compare_identity",F),("compare_distinct_invariants",G))
        benchmark!(reg; group="evidence",name,n=8,setup=()->(copy(F.lut),copy(H.lut)),
            call=p->compare(p[1],p[2];relation=:ccz,timeout_seconds=1.0,max_nodes=1000),
            validate=(p,v)->(@assert verify_comparison(v)),
            parameters=(;relation="ccz",seconds=1.0,nodes=1000),note="comparison evidence with VBF verification")
    end
    store=VBFSearch.DiscoveryStore
    benchmark!(reg; group="persistence",name="commit_seed",n=8,
        setup=()->begin
            dir=mktempdir();s=store.open_store(dir,Dict("purpose"=>"perf"))
            (;dir,s,lut=copy(F.lut),sigma=sigma_hash(F))
        end,
        call=p->store.seed!(p.s,p.lut,p.sigma,"switching"),
        validate=(p,v)->(@assert length(store.query(p.s,"SELECT * FROM seeds"))==1),
        teardown=p->begin;store.close_store(p.s);rm(p.dir;recursive=true);end,
        note="one seed and work unit, durable SQLite transaction; fresh scratch DB each sample")
end
