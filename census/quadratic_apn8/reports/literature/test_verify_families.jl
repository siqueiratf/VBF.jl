using Test,SHA,TOML,VBF
include("verify_families.jl")

@testset "family evidence replay rejects forged certificates" begin
    mktempdir() do dir
        f=UInt8.(gf_monomial_lut(8,3;modulus=285))
        id=bytes2hex(sha256(f));sigma=bytes2hex(VerifyFamilies.signature(VerifyFamilies.Workspace(),f))
        lutline=join((id,bytes2hex(f),"true","2",sigma,"true",""),'\t')
        luts=joinpath(dir,"luts.tsv");params=joinpath(dir,"parameters.tsv");output=joinpath(dir,"report.toml")
        write(luts,"lut_sha256\tlut_hex\tapn\tdegree\tsigma_hash\treference_signature_match\tnon_apn_witness\n"*lutline*"\n")
        write(params,"family\tparameters\tlut_sha256\tapn\tquadratic\tsigma_hash\treference_signature_match\n"*join(("gold","d=3",id,"true","true",sigma,"true"),'\t')*"\n")
        r=Dict("completed"=>true,"parameters_sha256"=>VerifyFamilies.sha(params),"luts_sha256"=>VerifyFamilies.sha(luts),
            "unique_exact_luts"=>1,"parameters"=>1,"distinct_absent_signatures"=>0,"missing_luts"=>Dict{String,String}(),
            "families"=>Dict("gold"=>Dict("parameters"=>1,"apn"=>1,"quadratic_apn"=>1,"absent"=>0)),
            "family_signatures"=>Dict("gold"=>[sigma]))
        save()=open(io->TOML.print(io,r),output,"w")
        save();@test VerifyFamilies.verify(dir)
        write(luts,replace(read(luts,String),"\t2\t"=>"\t3\t"))
        @test_throws ErrorException VerifyFamilies.verify(dir)
        r["luts_sha256"]=VerifyFamilies.sha(luts);save()
        @test_throws ErrorException VerifyFamilies.verify(dir)
        write(luts,"header\n"*lutline*"\n")
        r["luts_sha256"]=VerifyFamilies.sha(luts);r["families"]["gold"]["parameters"]=2;save()
        @test_throws ErrorException VerifyFamilies.verify(dir)
    end
end
