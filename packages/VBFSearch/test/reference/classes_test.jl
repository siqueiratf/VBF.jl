@testset "curated_classes" begin
mktempdir() do dir
    db=create_catalog(joinpath(dir,"catalog.sqlite"))
    evidence=joinpath(dir,"classes.sqlite")
    try
        F=gold_apn(3);G=SBox{3}(F.lut .⊻ 1)
        fixture(name,sbox)=SQLite.execute(db,
            "INSERT INTO functions(family,canonical_name,n,m,lut_sha256,lut_blob,is_apn,is_permutation,is_quadratic,source_repo,contributor,added_date) VALUES('fixture',?,?,?,?,?,1,0,1,'fixture','fixture','')",
            (name,inputbits(sbox),inputbits(sbox),lut_sha256_hex(sbox),canonical_lut_bytes(sbox)))
        fixture("gold",F);fixture("translate",G)
        @test_throws ErrorException ccz_class_representatives(db;n=3,path=evidence)
        @test populate_ccz_equivalence_classes!(db;path=evidence)==1
        @test only(ccz_class_representatives(db;n=3,path=evidence)).sbox==F
        fixture("other",gold_apn(4))
        @test_throws ErrorException ccz_class_representatives(db;n=3,path=evidence)
    finally
        close(db)
    end
end
end
