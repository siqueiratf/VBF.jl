using Test,TOML
using VBFSearch
const APNCommand=VBFSearch.CLI

@testset "search command parsing and frozen resume configuration" begin
    @test APNCommand.duration("8h")=="28800.0"
    @test APNCommand.duration("1.5m")=="90.0"
    @test_throws ErrorException APNCommand.duration("Inf")
    @test_throws ErrorException APNCommand.duration("0h")
    @test_throws ErrorException APNCommand.search_configuration("search",["--output","x","--typo","1"])
    @test_throws ArgumentError APNCommand.search_configuration("search",["--output","x","--threads","0"])
    @test_throws ErrorException APNCommand.search_configuration("search",["--output","x","--duration"])
    @test_throws ErrorException APNCommand.search_configuration("search",["--output","x","--duration","1h","--duration","2h"])
    @test_throws ArgumentError APNCommand.search_configuration("search",["--output","x","--method","unknown"])
    mktempdir() do dir
        output=joinpath(dir,"run")
        config=APNCommand.search_configuration("search",["--output",output,"--duration","8h","--threads","30"])
        cfg=VBFSearch.config_dict(config)
        @test config.workers==30 && config.output==output
        @test cfg["wall-seconds"]=="28800.0" && cfg["workers"]=="30"
        @test cfg["method"]=="v5"
        @test !isdir(output)
        mkpath(output)
        config=Dict("method"=>"v5","limit"=>"37","seed"=>"123","target-b6"=>"52",
            "v5-bent"=>"max","orbit-seconds"=>"0","ea-representatives"=>"0")
        identity=Dict("configuration"=>config,"reference_locations"=>Dict("baseline"=>"/reference","supplement"=>"/supplement"))
        open(io->TOML.print(io,Dict("identity"=>identity)),joinpath(output,"manifest.toml"),"w")
        @test !isfile(joinpath(output,"session_1.toml"))
        touch(joinpath(output,"STOP"))
        config=APNCommand.search_configuration("resume",[output,"--duration","2h","--threads","4"])
        cfg=VBFSearch.config_dict(config)
        @test config.workers==4 && cfg["limit"]=="37" && cfg["seed"]=="123"
        @test cfg["baseline"]=="/reference" && cfg["supplement"]=="/supplement"
        @test cfg["resume"]=="true" && cfg["wall-seconds"]=="7200.0"
        @test isfile(joinpath(output,"STOP"))
        @test_throws ErrorException APNCommand.search_configuration("resume",[output,"--method","switching"])
        @test_throws ErrorException APNCommand.search_configuration("search",["--output",output])
    end
end
