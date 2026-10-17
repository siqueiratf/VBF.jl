@testitem "catalog_reproducibility" begin
using Test, VBF, VBFCatalog, TOML, SHA

mktempdir() do dir
    sources=joinpath(dir,"sources");localdata=joinpath(dir,"local");raw=joinpath(dir,"original")
    mkpath(sources);mkpath(raw)
    write(joinpath(raw,"README"),"Pinned fixture original\n")
    # A git hook exports GIT_DIR and GIT_INDEX_FILE; drop them so the fixture
    # commits to its own repository, not to the repository under test.
    fixturegit(cmd)=setenv(cmd,Dict(k=>v for (k,v) in ENV if !startswith(k,"GIT_")))
    run(fixturegit(`git -C $raw init -q`))
    run(fixturegit(`git -C $raw add README`))
    run(fixturegit(`git -C $raw -c user.name=Fixture -c user.email=fixture@example.invalid commit -q -m fixture`))
    revision=readchomp(fixturegit(`git -C $raw rev-parse HEAD`))
    dump(path,value)=open(io->TOML.print(io,value;sorted=true),path,"w")
    F=gold_apn(3)
    dump(joinpath(sources,"apn.toml"),Dict("apn_functions"=>[
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
    dump(joinpath(sources,"sources.toml"),Dict("build"=>Dict("functions"=>Dict("APN"=>1)),
        "corpus"=>[entry,Dict("name"=>"deferred","source"=>"external",
            "count"=>1,"reader"=>"decimal_lut","notes"=>"uninstalled fixture",
            "source_repo"=>"fixture","packed_sha256"=>repeat("0",64))],
        "source"=>[Dict("name"=>"quadratic_apn_8bit","converter"=>"convert_quadratic_apn_8bit.jl",
            "env_var"=>"BFA_SBOXU_PATH","check_path"=>".","files"=>["README"],"revision"=>revision),
            Dict("name"=>"external","external"=>true)]))
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
            @test corpus_length(db,"deferred")==1
            @test_throws ErrorException corpus_function(db,"deferred",1)
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
