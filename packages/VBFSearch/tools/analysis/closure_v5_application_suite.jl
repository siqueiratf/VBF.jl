"""Run application-only configurations sequentially with one loaded Julia runtime.

Usage: julia --project=<frozen implementation> closure_v5_application_suite.jl CONFIG1.json CONFIG2.json ...
Each arm retains a new module, fresh stores, its own compiler warmup, and separate
evidence. Shared package loading reduces startup without overlapping any arms.
"""
configs=copy(ARGS)
for config in configs
    empty!(ARGS);push!(ARGS,config)
    Base.include(Module(gensym(:V5ApplicationArm)),joinpath(@__DIR__,"closure_v5_application_replay.jl"))
end
