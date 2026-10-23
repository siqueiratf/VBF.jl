"""Initialize and run the ordinary closure engine inside its signal supervisor."""
module VBFSearchWorker
using TOML

"""Observe supervisor STOP before initialization and after its bounded input audit."""
stop_requested(env=ENV)=haskey(env,"VBF_CLOSURE_STOP_FILE") && isfile(env["VBF_CLOSURE_STOP_FILE"])

"""Publish single-file output after the ordinary controller has closed its store."""
function finish(owner,config,result)
    if get(config,"output_format","directory")=="sqlite"
        println("Finalizing SQLite output…");flush(stdout)
        try
            Base.include(owner,joinpath(@__DIR__,"vbfsearch_output.jl"))
            Base.invokelatest() do
                getfield(getfield(owner,:VBFSearchOutput),:publish)(config,result)
            end
        catch
            println(stderr,"Output finalization failed; working data retained at ",config["workspace"])
            rethrow()
        end
    end
    println("Results: ",config["output"])
end

"""Load the engine once, then reuse its audited initializer and threaded launcher."""
function run(path)
    config=TOML.parsefile(path)
    single=get(config,"output_format","directory")=="sqlite"
    if stop_requested() && !single
        println("Stopped before search initialization. Output: ",config["output"])
        return
    end
    owner=Module(gensym(:SearchWorker))
    Base.eval(owner,:(using VBFSearch))
    Base.invokelatest() do
        engine=getfield(owner,:VBFSearch)
        if stop_requested()
            println("Stopped before search initialization. Output: ",config["output"])
            finish(owner,config,Dict("state"=>"stopped_before_initialization","processed_packets"=>0))
            return
        end
        println("Verifying audited seed inputs and creating a fresh search…");flush(stdout)
        engine.closure_init(config["campaign"];output=config["run"],
            root_first=Int(config["root_first"]),root_last=Int(config["root_last"]),
            extension_cosets=65536,switching_directions=64)
        if stop_requested()
            println("Stopped before search dispatch. Initialized results: ",config["output"])
            finish(owner,config,Dict("state"=>"stopped_before_dispatch","processed_packets"=>0))
            return
        end
        Base.include(owner,joinpath(@__DIR__,"closure_run.jl"))
        result=Base.invokelatest() do
            getfield(getfield(owner,:ClosureLauncher),:run)(path)
        end
        reason=stop_requested() ? strip(read(ENV["VBF_CLOSURE_STOP_FILE"],String)) : ""
        label=reason=="deadline" ? "time limit" : isempty(reason) ? result["state"] : reason
        println("Finished: ",label,"; work packets: ",result["processed_packets"])
        finish(owner,config,result)
    end
end
end

if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==1 || error("vbfsearch worker needs its generated command file")
    VBFSearchWorker.run(only(ARGS))
end
