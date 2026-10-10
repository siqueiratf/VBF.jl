@testitem "catalog_import" begin
using Test
include("reference/runtests.jl")
end

@testitem "catalog_storage" begin
using Test, VBF, VBFCatalog, SHA, TOML, SQLite, DBInterface
include("../../src/import/check.jl")
include("../../src/import/cache.jl")
include("../../src/import/load_sources.jl")
include("../../src/import/bibliography.jl")

@testset "bundled corpus checksums" begin
    db=load_catalog()
    try
        for name in list_corpora(db)
            info=corpus_info(db,name)
            info.store_file=="catalog" || continue
            @test corpus_store_path(db,name)==catalog_path()
            @test corpus_digest(db,name)==info.store_sha256
        end
    finally
        close(db)
    end
    readonly=SQLite.DB("file:"*catalog_path()*"?mode=ro")
    try
        @test corpus_store_path(readonly,"edelpott2009_n8")==catalog_path()
        @test differential_uniformity(corpus_function(readonly,"edelpott2009_n8",1))==2
    finally
        close(readonly)
    end
end

@testset "corpus isolation, rollback, cache and source agreement" begin
    mktempdir() do dir
        old_catalog=get(ENV,"BFA_CATALOG_PATH",nothing)
        old_data=get(ENV,"BFA_DATA_DIR",nothing)
        ENV["BFA_CATALOG_PATH"]=joinpath(dir,"catalog.sqlite")
        ENV["BFA_DATA_DIR"]=dir
        try
            close(create_catalog(catalog_path()))
            F=gold_apn(8); enc=encode_quadratic(F)
            write(joinpath(dir,"rep1.txt"),"fixture")
            withenv("BFA_THESIS_PATH"=>dir) do
                @test with_source(identity,"simonberg")==dir
            end
            bibliography_db=load_catalog()
            insert_bibliography!(bibliography_db)
            ensure_bib!(bibliography_db,"Gold_196801")
            @test_throws ErrorException ensure_bib!(bibliography_db,"missing-fixture")
            @test only(Int(r.c) for r in DBInterface.execute(bibliography_db,"SELECT COUNT(*) c FROM bibliography WHERE bib_key='Gold_196801'"))==1
            close(bibliography_db)
            for (name,external,count) in (("one",false,2),("two",false,1),("large",true,3))
                store=build_corpus_store!(name,fill(enc,count);external)
                db=load_catalog()
                register_corpus!(db;name,n=8,m=8,degree=2,modulus=conway_polynomial(8),
                    encoding="quadratic-coeffs-v1",member_count=count,bytes_per_member=length(enc),
                    store_file=store.store_file,store_sha256=store.sha256,family="fixture",
                    bib_key=nothing,source_repo="fixture",contributor="fixture",added_date="fixture",notes="fixture")
                @test corpus_digest(db,name)==bytes2hex(SHA.sha256(repeat(enc,count)))
                @test corpus_function(db,name,count)==F
                @test_throws BoundsError corpus_coefficients(db,name,count+1)
                @test_throws ArgumentError corpus_coefficients(db,name,0)
                close(db)
            end
            @test_throws ErrorException build_corpus_store!("one",[enc,UInt8[1]])
            @test_throws ErrorException build_corpus_store!("one",Vector{UInt8}[])
            db=load_catalog()
            @test corpus_length(db,"one")==2
            @test corpus_coefficients(db,"one",2)==enc
            @test corpus_store_path(db,"one")==catalog_path()
            @test corpus_store_path(db,"large")==joinpath(dir,"members.sqlite")
            @test_throws ArgumentError materialize_corpus_luts(db,"one";path=catalog_path())
            output=materialize_corpus_luts(db,"one";path=joinpath(dir,"luts.sqlite"))
            luts=SQLite.DB(output)
            @test only(Int(r.c) for r in DBInterface.execute(luts,"SELECT COUNT(*) c FROM members"))==2
            @test all(Vector{UInt8}(r.lut)==canonical_lut_bytes(F) for r in DBInterface.execute(luts,"SELECT lut FROM members"))
            close(luts)
            source=joinpath(dir,"original.txt"); write(source,"fixture\n")
            record_import!(db,"large",source)
            close(db)
            target=create_catalog(joinpath(dir,"target.sqlite"))
            try
                @test cached_corpus!(target,catalog_path(),"large",source)
                @test corpus_length(target,"large")==3
                write(source,"changed\n")
                @test_throws ErrorException cached_corpus!(target,catalog_path(),"large",source)
                write(source,"fixture\n")
                previous=load_catalog()
                DBInterface.execute(previous,"UPDATE bulk_corpora SET modulus=? WHERE name='large'",(0x11b,))
                close(previous)
                @test_throws ErrorException cached_corpus!(target,catalog_path(),"large",source)
                previous=load_catalog()
                DBInterface.execute(previous,"UPDATE bulk_corpora SET modulus=? WHERE name='large'",(0x11d,))
                close(previous)
                bulk=SQLite.DB(joinpath(dir,"members.sqlite"))
                DBInterface.execute(bulk,"UPDATE corpus_members SET coeffs=? WHERE corpus='large' AND idx=1",(zeros(UInt8,length(enc)),))
                close(bulk)
                @test_throws ErrorException cached_corpus!(target,catalog_path(),"large",source)
            finally
                close(target)
            end
        finally
            old_catalog===nothing ? delete!(ENV,"BFA_CATALOG_PATH") : (ENV["BFA_CATALOG_PATH"]=old_catalog)
            old_data===nothing ? delete!(ENV,"BFA_DATA_DIR") : (ENV["BFA_DATA_DIR"]=old_data)
        end
        @test check_catalog()===nothing
        copy=joinpath(dir,"broken.sqlite");cp(catalog_path(),copy)
        db=SQLite.DB(copy);SQLite.execute(db,"DELETE FROM functions WHERE family='APN' AND id=(SELECT MIN(id) FROM functions WHERE family='APN')");close(db)
        @test_throws ErrorException check_catalog(copy)
    end
end
end
