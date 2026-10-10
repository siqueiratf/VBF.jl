@testset "GL helpers and portable evidence" begin
    include(joinpath(@__DIR__, "..", "helpers.jl"))
    f=gl_boolean_anf("ab+c",3)
    @test Int.(f.lut)==[0,0,0,1,1,1,1,0]
    @test mobius(anf(f))==f.lut
    @test gl_kappa(gl_boolean_anf("ab",2))==1
    @test gl_kappa(gl_boolean_anf("",3))==8
    @test_throws ArgumentError gl_boolean_anf("ag",6)
    @test gl_normalize_boolean(gl_boolean_anf("ab+a+b+1",2))==gl_boolean_anf("ab",2)
    @test gl_boolean_signature(gl_boolean_anf("ab+a+b+1",2))==gl_boolean_signature(gl_boolean_anf("ab",2))
    @test gl_dataset_hash([gold_apn(3)])==gl_dataset_hash([gold_apn(3)])
    @test gl_dataset_hash([gold_apn(3)])!=gl_dataset_hash([gold_apn(4)])
    saved=gl_save("__test_parameters",(;complete=false,elapsed_seconds=0.0,
        parameters=(;max_nodes=17,timeout_seconds=0.25,algorithm=:paper));save_results=true)
    metadata=TOML.parsefile(saved)
    @test metadata["parameters"]["max_nodes"]==17
    @test metadata["parameters"]["timeout_seconds"]==0.25
    @test metadata["parameters"]["algorithm"]=="paper"
    @test haskey(metadata["paper_sources"],"pdf") && haskey(metadata["source_hashes"],"packages/VBF/src/VBF.jl")
    rm(saved)
    mktempdir() do dir
        path=joinpath(dir,"anf.txt")
        write(path,"anf=\nanf=a\nanf=ab\n")
        loaded=gl_author_boolean_classes(path;n=2,limit=2)
        @test length(loaded.functions)==2
        @test loaded.functions[1]==gl_boolean_anf("",2)
        @test isempty(gl_author_boolean_classes(path;n=2,timeout_seconds=0).functions)
        F=gold_apn(6)
        A=identity_affine_map(12)
        w=Dict("kind"=>"orbit_representative","dimension"=>6,"source_label"=>"root",
            "target_index"=>1,"source_lut"=>Int.(F.lut),"target_lut"=>Int.(F.lut),
            "linear_columns"=>Int.(A.linear.cols),"constant"=>Int(A.constant))
        data=Dict("census_complete"=>true,"roots_distinct"=>true,
            "dataset"=>[Dict("label"=>"root","lut"=>Int.(F.lut))],
            "rows"=>[Dict("label"=>"root","complete"=>true,"classes"=>2,"degrees"=>Dict("2"=>2))],
            "witnesses"=>[w,copy(w)])
        evidence=joinpath(dir,"census.toml")
        open(io->TOML.print(io,data),evidence,"w")
        @test_throws ArgumentError gl_load_known_representatives(evidence;require_complete=false)
        data["witnesses"]=[merge(w,Dict("source_label"=>"unbound"))]
        open(io->TOML.print(io,data),evidence,"w")
        @test_throws ArgumentError gl_load_known_representatives(evidence;require_complete=false)
    end
end
