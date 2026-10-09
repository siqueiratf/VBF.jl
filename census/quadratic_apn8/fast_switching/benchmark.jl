"""Compare complete switching constraint assembly with the ordered-pair oracle."""
const FAST_SWITCHING_BENCHMARK_USAGE = nothing
using VBF, TOML, SHA

function ordered_pair_constraints!(systems,lut)
    q = length(lut)
    for a in 1:(q-1), x in 0:(q-1), y in 0:(q-1)
        x == y && continue
        x == (y ⊻ a) && continue
        u = lut[x+1] ⊻ lut[(x⊻a)+1] ⊻ lut[y+1] ⊻ lut[(y⊻a)+1]
        iszero(u) || VBF._sn_add_equation!(systems[Int(u)],(x⊻a,x,y⊻a,y))
    end
end

function main_benchmark(args)
    isempty(args) && error("usage: benchmark.jl OUTPUT.toml [parent_N.toml ...]")
    isfile(args[1]) && error("output already exists")
    seeds = [("Gold",gold_apn(8))]
    for path in args[2:end]
        record = TOML.parsefile(path)
        push!(seeds,(record["parent_sigma"],SBox{8,UInt8}(hex2bytes(record["parent_lut_hex"]))))
    end
    for builder in (ordered_pair_constraints!,VBF._sn_constraints!)
        builder([VBF._sn_system(16) for _ in 1:15],gold_apn(4).lut)
    end
    rows = Dict{String,Any}[]
    for (name,F) in seeds
        reference = [VBF._sn_system(256) for _ in 1:255]
        optimized = [VBF._sn_system(256) for _ in 1:255]
        before = @elapsed ordered_pair_constraints!(reference,F.lut)
        after = @elapsed VBF._sn_constraints!(optimized,F.lut)
        @assert all(reference[u].pivot_rows == optimized[u].pivot_rows &&
            reference[u].pivot_cols == optimized[u].pivot_cols for u in 1:255)
        push!(rows,Dict("seed"=>name,"reference_seconds"=>before,
            "optimized_seconds"=>after,"speedup"=>before/after,"systems_identical"=>true))
        println(last(rows)); flush(stdout)
    end
    source = normpath(joinpath(@__DIR__,"../../../packages/VBF/src/constructions/switching_neighbors.jl"))
    open(args[1],"w") do io
        TOML.print(io,Dict("julia"=>string(VERSION),"cpu"=>Sys.cpu_info()[1].model,
            "constraints"=>rows,"core_sha256"=>bytes2hex(open(SHA.sha256,source)));
            sorted=true)
    end
end

abspath(PROGRAM_FILE) == (@__FILE__) && main_benchmark(ARGS)
