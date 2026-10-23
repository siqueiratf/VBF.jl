module ClosureLauncherTests
using Test,TOML
include(joinpath(@__DIR__,"..","tools","closure_run.jl"))

@testset "Portable controller paths and supervisor STOP are explicit" begin
    mktempdir() do directory
        path=joinpath(directory,"config.toml")
        open(path,"w") do io
            TOML.print(io,Dict("run"=>"run","evidence"=>"session","concurrency"=>1,
                "stop_files"=>["operator-stop"],"storage_paths"=>["run","session"],
                "checkpoint_directory"=>"durable","quota_status_file"=>"quota.json"))
        end
        config=ClosureLauncher.read_config(path;env=Dict("VBF_CLOSURE_STOP_FILE"=>joinpath(directory,"private-stop")))
        @test config["run"]==joinpath(directory,"run")
        @test config["evidence"]==joinpath(directory,"session")
        @test config["stop_files"]==[joinpath(directory,"operator-stop"),joinpath(directory,"private-stop")]
        @test config["storage_paths"]==[joinpath(directory,"run"),joinpath(directory,"session")]
        @test config["checkpoint_directory"]==joinpath(directory,"durable")
        @test config["quota_status_file"]==joinpath(directory,"quota.json")
        @test !ispath(config["run"]) && !ispath(config["evidence"])
    end
end

@testset "Resource errors prevent controller loading and dispatch" begin
    mktempdir() do directory
        controller=joinpath(directory,"controller.jl");marker=joinpath(directory,"loaded")
        write(controller,"write("*repr(marker)*",\"loaded\")\nmodule ContinuousSeedSearch\nrun(config)=config\nend\n")
        path=joinpath(directory,"config.toml")
        function configure(extra)
            open(path,"w") do io
                TOML.print(io,merge(Dict("run"=>"run","evidence"=>"session"),extra))
            end
        end
        configure(Dict("concurrency"=>Threads.nthreads(:default)+1))
        @test_throws ArgumentError ClosureLauncher.run(path;controller_path=controller,env=Dict{String,String}())
        @test !isfile(marker)
        configure(Dict("concurrency"=>1,"cpu_allocation"=>1))
        serial=Threads.nthreads(:default)==1 && Threads.nthreads(:interactive)==0 && Threads.ngcthreads()<=1
        if serial
            allocated=ClosureLauncher.run(path;controller_path=controller,env=Dict{String,String}())
            @test isfile(marker) && allocated["concurrency"]==1
        else
            @test_throws ArgumentError ClosureLauncher.run(path;controller_path=controller,env=Dict{String,String}())
            @test !isfile(marker)
        end
        configure(Dict("concurrency"=>1))
        config=ClosureLauncher.run(path;controller_path=controller,env=Dict{String,String}())
        @test isfile(marker) && config["concurrency"]==1
        command=ClosureLauncher.worker_command(path;controller_path=controller)
        @test "--worker" in command.exec
        @test abspath(path) in command.exec
        @test any(startswith("--project="),command.exec)
    end
end

@testset "CLI process replacement stops before dispatch at an expired deadline" begin
    mktempdir() do directory
        path=joinpath(directory,"config.toml")
        open(path,"w") do io
            TOML.print(io,Dict("run"=>"absent-run","evidence"=>"fresh-evidence",
                "concurrency"=>1,"supervisor_duration_seconds"=>0.0))
        end
        worker=ClosureLauncher.worker_command(path)
        command=Cmd(filter(!=("--worker"),worker.exec))
        process=Base.run(pipeline(ignorestatus(command);stdout=devnull))
        @test process.exitcode==0
        @test !ispath(joinpath(directory,"fresh-evidence"))
        @test !ispath(joinpath(directory,"absent-run"))
    end
end
end
