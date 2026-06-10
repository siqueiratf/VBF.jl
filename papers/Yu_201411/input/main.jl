using BenchmarkTools
using FLoops
using CUDA

# Ensure CUDA is functional before running
if !CUDA.functional()
    error("CUDA-capable GPU not found or not properly configured!")
end

# 1. Setup Data (30 million elements)
const N = 30_000_000
const x = rand(Float32, N)
const y = rand(Float32, N)

# --- Define the Functions ---

# Sequential CPU Implementation
function cpu_sequential!(out, x, y)
    for i in eachindex(out)
        @inbounds out[i] = log(x[i]) * sin(y[i]) + 2.0f0
    end
end

# Multi-threaded CPU Implementation (using FLoops)
function cpu_threaded!(out, x, y)
    @floop for i in eachindex(out)
        @inbounds out[i] = log(x[i]) * sin(y[i]) + 2.0f0
    end
end

# GPU Implementation (High-level Array broadcasting)
# Julia fuses broadcasting syntax automatically into a single efficient GPU kernel.
function gpu_broadcast(x_gpu, y_gpu)
    return log.(x_gpu) .* sin.(y_gpu) .+ 2.0f0
end

# --- Benchmarking ---

println("Running Benchmarks (N = $N)...\n")
out_cpu = zeros(Float32, N)

# 1. Single-threaded CPU
println("=== 1. CPU Sequential ===")
@btime cpu_sequential!($out_cpu, $x, $y)

# 2. Multi-threaded CPU
println("\n=== 2. CPU Multi-threaded (using $(Threads.nthreads()) threads) ===")
@btime cpu_threaded!($out_cpu, $x, $y)

# 3. GPU Acceleration
# Transfer data to GPU memory
x_gpu = CuArray(x)
y_gpu = CuArray(y)

# Warmup (compiles the GPU kernel so compilation time isn't benchmarked)
gpu_broadcast(x_gpu, y_gpu) 

println("\n=== 3. GPU (CUDA) ===")
# Crucial: Use CUDA.@sync to wait for the asynchronous GPU tasks to finish!
@btime CUDA.@sync gpu_broadcast($x_gpu, $y_gpu)
