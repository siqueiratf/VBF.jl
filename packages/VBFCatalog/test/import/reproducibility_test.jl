@testitem "catalog_reproducibility" begin
using Test, VBF, VBFCatalog, TOML, SHA

mktempdir() do dir
    sources=joinpath(dir,"sources");localdata=joinpath(dir,"local");raw=joinpath(dir,"original")
    mkpath(joinpath(sources,"apn"));mkpath(raw)
    write(joinpath(raw,"README"),"Pinned fixture original\n")
    run(`git -C $raw init -q`)
    run(`git -C $raw add README`)
    run(`git -C $raw -c user.name=Fixture -c user.email=fixture@example.invalid commit -q -m fixture`)
    revision=readchomp(`git -C $raw rev-parse HEAD`)
    dump(path,value)=open(io->TOML.print(io,value;sorted=true),path,"w")
    F=gold_apn(3)
    dump(joinpath(sources,"apn","n3_apn.toml"),Dict("apn_functions"=>[
        Dict("name"=>"fixture","n"=>3,"m"=>3,"is_permutation"=>true,"lut"=>Int.(F.lut),
            "bib_key"=>"Gold_196801","description"=>"fixture")]))
    dump(joinpath(sources,"literature_sboxes.toml"),Dict("sboxes"=>[]))
    dump(joinpath(sources,"sporadic.toml"),Dict("functions"=>[]))
    cp(bibliography_path(),joinpath(sources,"bibliography.bib"))
    input=joinpath(sources,"promoted.coeffs.gz")
    encodings=[encode_quadratic(gold_apn(8))]
    write_corpus_input(input,encodings)
    copy=joinpath(dir,"same.coeffs.gz");write_corpus_input(copy,encodings)
    @test read(input)==read(copy)
    entry=Dict("name"=>"promoted","source"=>"quadratic_apn_8bit","reader"=>"quadratic_coeffs",
        "file"=>"promoted.coeffs.gz","count"=>1,"separating"=>true,"notes"=>"VBFSearch fixture",
        "source_repo"=>"VBFSearch:search/fixture","family"=>"discovery",
        "sha256"=>bytes2hex(open(SHA.sha256,input)),"packed_sha256"=>bytes2hex(SHA.sha256(only(encodings))))
    dump(joinpath(sources,"corpora.toml"),Dict("corpus"=>[entry]))
    dump(joinpath(sources,"sources.toml"),Dict("build"=>Dict("functions"=>Dict("APN"=>1)),
        "source"=>[Dict("name"=>"quadratic_apn_8bit","converter"=>"convert_quadratic_apn_8bit.jl",
            "env_var"=>"BFA_SBOXU_PATH","check_path"=>".","files"=>["README"],"revision"=>revision)]))
    script=joinpath(pkgdir(VBFCatalog),"src","import","build_catalog.jl")
    project=joinpath(pkgdir(VBFCatalog),"src","import")
    withenv("BFA_SOURCE_DIR"=>sources,"BFA_DATA_DIR"=>localdata,"BFA_SBOXU_PATH"=>raw) do
        @test apn_catalog_names()==["fixture"]
        @test isempty(literature_sbox_names())
        first=joinpath(dir,"first.sqlite");second=joinpath(dir,"second.sqlite")
        cmd(path)=`$(Base.julia_cmd()) --startup-file=no --compiled-modules=existing --project=$project $script --output $path`
        run(cmd(first))
        # A prior catalog and unrelated local evidence cannot influence the build.
        write(second,"unusable previous database")
        mkpath(localdata);write(joinpath(localdata,"imports.toml"),"unrelated = true\n")
        run(cmd(second))
        @test read(first)==read(second)
        db=load_catalog(first)
        try
            @test corpus_function(db,"promoted",1)==gold_apn(8)
            @test corpus_info(db,"promoted").source_repo=="VBFSearch:search/fixture"
        finally
            close(db)
        end
        original=read(second)
        write(input,UInt8[0])
        @test !success(pipeline(cmd(second);stdout=devnull,stderr=devnull))
        @test read(second)==original
        @test !isfile(second*".building")
    end
end
end

@testitem "curated_classes" begin
using Test, VBF, VBFCatalog, SQLite
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
