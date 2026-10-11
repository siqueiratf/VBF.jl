@testitem "reference_snapshot" begin
    using VBF
    using VBFCatalog
    using SQLite, DBInterface, SHA, TOML, Test

    @test VBF.sigma_key === VBFCatalog.sigma_key
    @test VBF.ccz_fingerprint_hash === VBFCatalog.ccz_fingerprint_hash
    F = gold_apn(8, 1)
    hash = sigma_hash(F)
    G = gold_apn(8, 3)
    supplement_hash = sigma_hash(G)
    @test hash != supplement_hash
    mktempdir() do dir
        path = joinpath(dir, "fresh_union.sqlite")
        db = SQLite.DB(path)
        DBInterface.execute(db, "CREATE TABLE signatures(sigma_hash TEXT PRIMARY KEY)")
        DBInterface.execute(db, "INSERT INTO signatures VALUES(?)", (hash,))
        SQLite.close(db)
        manifest = Dict("scope"=>"quadratic (8,8)-APN", "provenance_complete"=>true,
            "fresh_union_sha256"=>bytes2hex(open(SHA.sha256, path)),
            "fresh_union_distinct_signatures"=>1)
        write_manifest() = open(joinpath(dir, "comparison.toml"), "w") do io
            TOML.print(io, manifest)
        end
        write_manifest()
        supplement_path = joinpath(dir, "supplement.tsv")
        write(supplement_path, "sigma_hash\tlut_hex\n$supplement_hash\t$(bytes2hex(G.lut))\n")

        r = open_apn_reference(dir; supplement_path, required_signatures=[hash])
        try
            @test reference_contains_signature(r, hash)
            @test reference_contains_signature(r, supplement_hash)
            @test !reference_contains_signature(r, "not-a-signature")
            @test reference_exact_lut_match(r, supplement_hash, G.lut)
            @test !reference_exact_lut_match(r, supplement_hash, F.lut)
            metadata = reference_metadata(r)
            @test metadata["literature_complete"] === false
            @test metadata["required_signatures"] == [hash]
            @test metadata["supplement_sha256"] == bytes2hex(open(SHA.sha256, supplement_path))
            metadata["literature_complete"] = true
            @test reference_metadata(r)["literature_complete"] === false
            @test_throws SQLite.SQLiteException DBInterface.execute(r.db, "INSERT INTO signatures VALUES('write')")
        finally
            close_apn_reference(r)
        end
        @test close_apn_reference(r) === nothing
        @test_throws ErrorException reference_contains_signature(r, hash)

        # Supplemental entries cannot substitute for coverage of the rebuilt corpus.
        @test_throws ErrorException open_apn_reference(dir; supplement_path,
            required_signatures=[supplement_hash])
        called = Ref(0)
        independent = lut -> begin
            called[] += 1
            @test lut == G.lut
            supplement_hash
        end
        r = open_apn_reference(dir; supplement_path, supplement_signature=independent)
        close_apn_reference(r)
        @test called[] == 1

        # Multiple published LUTs may share an invariant; retain every exact match.
        H = SBox{8,UInt8}(G.lut .⊻ 0x01)
        write(supplement_path, "sigma_hash\tlut_hex\n$supplement_hash\t$(bytes2hex(G.lut))\n$supplement_hash\t$(bytes2hex(H.lut))\n")
        r = open_apn_reference(dir; supplement_path)
        try
            @test reference_exact_lut_match(r, supplement_hash, G.lut)
            @test reference_exact_lut_match(r, supplement_hash, H.lut)
        finally
            close_apn_reference(r)
        end

        manifest["scope"] = "unrelated corpus"
        write_manifest()
        @test_throws ErrorException open_apn_reference(dir)
        manifest["scope"] = "quadratic (8,8)-APN"
        manifest["provenance_complete"] = false
        write_manifest()
        @test_throws ErrorException open_apn_reference(dir)
        manifest["provenance_complete"] = true
        manifest["fresh_union_distinct_signatures"] = 2
        write_manifest()
        @test_throws ErrorException open_apn_reference(dir)
        manifest["fresh_union_distinct_signatures"] = 1
        manifest["fresh_union_sha256"] = "wrong-digest"
        write_manifest()
        @test_throws ErrorException open_apn_reference(dir)
        manifest["fresh_union_sha256"] = bytes2hex(open(SHA.sha256, path))
        write_manifest()
        write(supplement_path, "sigma_hash\tlut_hex\nwrong-hash\t$(bytes2hex(G.lut))\n")
        @test_throws ErrorException open_apn_reference(dir; supplement_path)
        write(supplement_path, "sigma_hash\tlut_hex\nwrong-hash\t$(bytes2hex(UInt8.(0:255)))\n")
        @test_throws ErrorException open_apn_reference(dir; supplement_path)
    end
end

@testitem "reference_snapshot_catalog" begin
    using Test,VBF,VBFCatalog,SQLite,DBInterface,SHA
    mktempdir() do dir
        withenv("BFA_DATA_DIR"=>dir,"BFA_CATALOG_PATH"=>joinpath(dir,"catalog.sqlite")) do
            db=create_catalog(catalog_path())
            F=gold_apn(8);G=gold_apn(8,3)
            try
                SQLite.execute(db,"INSERT INTO functions(family,n,m,lut_sha256,lut_blob,is_apn,is_permutation,is_quadratic,source_repo,contributor,added_date) VALUES('fixture',8,8,?,?,1,0,1,'fixture','fixture','fixture')",
                    (lut_sha256_hex(F),canonical_lut_bytes(F)))
                build_sigma_index!(db;corpora=[])
                ref=open_catalog_reference(;required_signatures=[sigma_hash(F)])
                before=reference_metadata(ref)
                @test reference_contains_signature(ref,sigma_hash(F))
                @test !reference_contains_signature(ref,sigma_hash(G))
                @test before["sources"]==["functions"]
                @test_throws SQLite.SQLiteException SQLite.execute(ref.db,"DELETE FROM ccz_sigma_index")
                close_apn_reference(ref)
                file=joinpath(dir,"extra.tsv")
                write(file,"sigma_hash\tlut_hex\n$(sigma_hash(G))\t$(bytes2hex(G.lut))\n")
                entry=Dict("file"=>"extra.tsv","sha256"=>bytes2hex(open(sha256,file)),"count"=>1,
                    "name"=>"extra","source_repo"=>"fixture","notes"=>"fixture")
                import_lut_corpus!(db,entry)
                @test_throws ErrorException open_catalog_reference()
                build_sigma_index!(db;rebuild=false,corpora=["extra"],include_functions=false)
                current=open_catalog_reference()
                @test reference_contains_signature(current,sigma_hash(G))
                @test reference_metadata(current)["sha256"]!=before["sha256"]
                close_apn_reference(current)
                frozen=open_catalog_reference(;sources=before["sources"])
                @test reference_metadata(frozen)["sha256"]==before["sha256"]
                @test !reference_contains_signature(frozen,sigma_hash(G))
                close_apn_reference(frozen)
                @test candidate_lut(bytes2hex(F.lut))==F.lut
                records=[]
                each_candidate(r->push!(records,r),IOBuffer(read(file,String)))
                @test only(records).hash==sigma_hash(G)
                entry["sha256"]=repeat("0",64)
                @test_throws ErrorException import_lut_corpus!(db,entry)
                SQLite.execute(db,"UPDATE functions SET lut_sha256='wrong'")
                @test_throws ErrorException open_catalog_reference(;sources=before["sources"])
            finally
                close(db)
            end
        end
    end
end
