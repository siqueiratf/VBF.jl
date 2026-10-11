@testset "corpus_classification" begin

mktempdir() do dir
    withenv("BFA_CATALOG_PATH"=>joinpath(dir,"catalog.sqlite"),"BFA_DATA_DIR"=>dir,"VBF_SEARCH_DATA_DIR"=>dir) do
        db=create_catalog(catalog_path())
        path=joinpath(dir,"sigma.sqlite")
        idx=SQLite.DB(path)
        SQLite.execute(idx,VBFCatalog._SIGMA_INDEX_DDL)
        SQLite.execute(idx,VBFCatalog._SIGMA_COVERAGE_DDL)
        close(idx)
        function fixture(name,n,functions)
            enc=[encode_quadratic(F;modulus=conway_polynomial(n)) for F in functions]
            store=build_corpus_store!(name,enc)
            register_corpus!(db;name,n,m=n,degree=2,modulus=conway_polynomial(n),
                encoding="quadratic-coeffs-v1",member_count=length(enc),bytes_per_member=length(first(enc)),
                store_file=store.store_file,store_sha256=store.sha256,family="fixture",bib_key=nothing,
                source_repo="fixture",contributor="fixture",added_date="fixture",notes="fixture")
            idx=SQLite.DB(path)
            try
                for (i,F) in enumerate(functions)
                    SQLite.execute(idx,"INSERT INTO ccz_sigma_index VALUES(?,?,?,?)",(sigma_hash(F),n,name,i))
                end
                SQLite.execute(idx,"INSERT INTO sigma_coverage VALUES(?,?,1)",(name,n))
            finally
                close(idx)
            end
        end
        try
            F=gold_apn(3);G=SBox{3}(F.lut .⊻ 1)
            fixture("same",3,[F,F,G])
            dedup=deduplicate_signature_buckets!(db;n=3,path)
            @test dedup.records==3 && dedup.signatures==1
            @test dedup.shared_distinct_luts==2 && dedup.duplicate_records_removed==1
            @test ismissing(dedup.exact_class_count)
            @test isequal(deduplicate_signature_buckets!(db;n=3,path),dedup)
            partial=classify_signature_buckets!(db;n=3,path,max_nodes=0,workers=1)
            @test partial.checks_this_session==1 && partial.unresolved_component_pairs==1
            @test ismissing(partial.exact_class_count)
            complete=classify_signature_buckets!(db;n=3,path,timeout_seconds=10,workers=1)
            @test complete.exact_class_count==1 && complete.shared_components==1
            @test complete.unresolved_component_pairs==0
            resumed=classify_signature_buckets!(db;n=3,path,timeout_seconds=0,workers=1)
            @test resumed.checks_this_session==0 && resumed.exact_class_count==1
            @test verify_equivalence_check(first(list_equivalence_checks(db,F,G;relation=:ea)),F,G)
            @test count_functions(db)==0

            A,B=gold_apn(5,1),gold_apn(5,2)
            @test sigma_hash(A)==sigma_hash(B)
            fixture("collision",5,[A,B])
            split=classify_signature_buckets!(db;n=5,path,timeout_seconds=30,workers=1)
            @test split.exact_class_count==2 && split.shared_components==2
            @test split.signatures==1 && split.unresolved_component_pairs==0

            SQLite.execute(db,"INSERT INTO functions(family,n,m,lut_sha256,lut_blob,is_apn,is_permutation,is_quadratic,source_repo,contributor,added_date) VALUES('fixture',3,3,?,?,1,0,1,'fixture','fixture','fixture')",
                (lut_sha256_hex(F),canonical_lut_bytes(F)))
            idx=SQLite.DB(path)
            SQLite.execute(idx,"INSERT INTO ccz_sigma_index VALUES(?,3,'functions',999)",(sigma_hash(F),))
            SQLite.execute(idx,"INSERT INTO sigma_coverage VALUES('functions',-1,1)")
            close(idx)
            @test refresh_curated_sigma_index!(db;path)==1
            @test_throws ErrorException deduplicate_signature_buckets!(db;n=3,path)
            rebound=deduplicate_signature_buckets!(db;n=3,path,rebuild=true)
            @test rebound.records==4 && rebound.shared_distinct_luts==2
            reused=classify_signature_buckets!(db;n=3,path,timeout_seconds=0,workers=1)
            @test reused.checks_this_session==0 && reused.exact_class_count==1

            idx=SQLite.DB(path)
            SQLite.execute(idx,"UPDATE ccz_sigma_index SET member_idx=99 WHERE source='same' AND member_idx=1")
            close(idx)
            @test_throws ErrorException deduplicate_signature_buckets!(db;n=3,path)
        finally
            close(db)
        end
    end
end
end
