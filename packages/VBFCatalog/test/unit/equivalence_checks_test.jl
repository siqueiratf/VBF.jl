@testitem "equivalence_checks" begin
using Test, VBF, VBFCatalog, SQLite, DBInterface, TOML

mktempdir() do dir
    path=joinpath(dir,"checks.sqlite")
    db=create_catalog(path)
    F=gold_apn(3)
    G=SBox{3}([F(x) ⊻ 1 for x in 0:7])
    H=SBox{3}(zeros(Int,8))
    try
        stopped=check_equivalence!(db,F,G;max_nodes=0)
        @test stopped.status=="inconclusive"
        @test TOML.parse(stopped.evidence)["stop"]=="nodes"
        @test !verify_equivalence_check(stopped,F,G)
        positive=check_equivalence!(db,F,G;timeout_seconds=10)
        @test positive.status=="equivalent"
        @test verify_equivalence_check(positive,F,G)
        @test verify_equivalence_check(positive,G,F)
        @test !verify_equivalence_check(positive,F,H)
        @test check_equivalence!(db,G,F;max_nodes=0).id==positive.id
        @test length(list_equivalence_checks(db,F,G))==2
        @test TOML.parse(positive.parameters)["rng_seed"]==940
        @test positive.solver_sha256==equivalence_solver_fingerprint()
        @test isempty(list_equivalence_checks(db,F,G;relation=:ea))
        ea=check_equivalence!(db,F,G;relation=:ea,timeout_seconds=10)
        @test ea.status=="equivalent"
        @test verify_equivalence_check(ea,F,G)
        @test length(list_equivalence_checks(db,F,G;relation=:ea))==1
        identity=check_equivalence!(db,F,F;max_nodes=0)
        @test verify_equivalence_check(identity,F,F)
        proof=TOML.parse(positive.evidence)
        proof["columns"]=fill(0,6)
        corrupt=merge(positive,(;evidence=sprint(io->TOML.print(io,proof))))
        @test !verify_equivalence_check(corrupt,F,G)
        @test !verify_equivalence_check(merge(positive,(;evidence="invalid = [")),F,G)
        negative=check_equivalence!(db,F,H;timeout_seconds=10)
        @test negative.status=="inequivalent"
        @test !verify_equivalence_check(negative,F,H)
        @test check_equivalence!(db,H,F;max_nodes=0).id==negative.id
        SQLite.execute(db,"UPDATE equivalence_checks SET solver_sha256='stale' WHERE id=?",(negative.id,))
        retry=check_equivalence!(db,F,H;max_nodes=0)
        @test retry.id!=negative.id && retry.status=="inconclusive"
        fresh=check_equivalence!(db,F,G;reuse=false,timeout_seconds=10)
        @test fresh.id!=positive.id && fresh.status=="equivalent"
        @test count_functions(db)==0
        @test_throws ArgumentError check_equivalence!(db,F,G;max_nodes=-1)
        @test_throws ArgumentError check_equivalence!(db,F,G;relation=:linear)
        @test_throws ArgumentError check_equivalence!(db,F,gold_apn(4))
        @test_throws SQLite.SQLiteException SQLite.execute(db,
            "UPDATE equivalence_checks SET status='timeout_means_false' WHERE id=?",(positive.id,))
        close(db)
        db=load_catalog(path)
        @test verify_equivalence_check(only(filter(r->r.id==positive.id,list_equivalence_checks(db,F,G))),F,G)
        @test only(Int(r.c) for r in DBInterface.execute(db,
            "SELECT COUNT(*) c FROM equivalence_checks WHERE relation='ccz' AND status='inconclusive'"))==2

        # Exercise the actual include-safe build entry point's history copy.
        context=Module(gensym(:EquivalenceBuild))
        Core.eval(context,:(include(path)=Base.include($context,path)))
        Base.include(context,joinpath(pkgdir(VBFCatalog),"src","import","build_catalog.jl"))
        target=create_catalog(joinpath(dir,"rebuilt.sqlite"))
        try
            @test Base.invokelatest(getfield(context,:preserve_equivalence_checks!),target,path)==7
            @test list_equivalence_checks(target,F,G)==list_equivalence_checks(db,F,G)
            @test verify_equivalence_check(first(list_equivalence_checks(target,F,G)),F,G)
            @test Base.invokelatest(getfield(context,:preserve_equivalence_checks!),target,joinpath(dir,"missing.sqlite"))==0
        finally
            close(target)
        end
    finally
        close(db)
    end
end
end
