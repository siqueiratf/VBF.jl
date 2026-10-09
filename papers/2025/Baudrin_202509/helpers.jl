# Implements report support for Section 3.
# Paper: Baudrin, Galissant and Perrin (2025), "Exploring the Set of APN Functions", BFA 2025
# Section: 3 — Towards a Practical Classification of all Known APN Functions
#
# Pseudocode:
#   1. Load reusable VBF primitives and print the paper-specific scope banner.
# VBF API used: print_banner, print_section, print_check, print_kv
using VBF
using Random
using TOML
using SHA
using Dates

const BGP_SOURCE_CAPTURE = let
    repository_root = normpath(joinpath(@__DIR__, "..", "..", ".."))
    source_paths = String[]
    for (directory, _, names) in walkdir(joinpath(repository_root, "packages", "VBF", "src"))
        append!(source_paths, [joinpath(directory,name) for name in names if endswith(name,".jl")])
    end
    append!(source_paths, [joinpath(@__DIR__,name) for name in readdir(@__DIR__) if endswith(name,".jl")])
    hashes = Dict(relpath(path,repository_root)=>bytes2hex(sha256(read(path)))
        for path in sort!(source_paths))
    paper_path = joinpath(@__DIR__, "input", "main.pdf")
    paper = Dict{String,Any}("path"=>relpath(paper_path,repository_root),
        "available"=>isfile(paper_path),
        "sha256"=>isfile(paper_path) ? bytes2hex(sha256(read(paper_path))) : "unavailable")
    (; hashes, paper, captured_at_utc=string(Dates.now(Dates.UTC)) * "Z")
end

"""Print the experiment scope for Baudrin–Galissant–Perrin (2025), Section 3."""
function paper_header(io::IO=stdout)
    print_banner(io, "Baudrin, Galissant and Perrin (2025)",
        "Exploring the Set of APN Functions — BFA 2025",
        "Native automorphism generators; bounded switching; Conjecture 1 unproved",
        "Julia $(VERSION); UTC $(Dates.now(Dates.UTC))")
    return nothing
end

"""Check a graph certificate point by point for the Section 3.1 experiment."""
function bgp_verify_graph_map(F::SBox, G::SBox, A; relation=:ccz)
    N = inputbits(F)
    inputbits(G) == N || return false
    inputbits(A) == 2N || return false
    rank_f2(UInt32.(A.linear.cols);nbits=2N) == 2N || return false
    if relation === :ea
        all(j -> (UInt32(A.linear(UInt32(1) << j)) >> N) == 0, 0:(N-1)) || return false
    end
    image = sort!(UInt32[UInt32(A((UInt32(x) << N) | UInt32(F.lut[x+1])))
        for x in 0:(length(F)-1)])
    target = sort!(UInt32[(UInt32(x) << N) | UInt32(G.lut[x+1])
        for x in 0:(length(G)-1)])
    return image == target
end

"""Record an independently checked Section 3 graph mapping in portable form."""
function bgp_witness(F, G, A; relation=:ccz, kind="equivalence", parent=0,
    target=0, source_label="", target_label="")
    bgp_verify_graph_map(F, G, A; relation) || error("graph certificate failed independent validation")
    return Dict{String,Any}("relation" => string(relation), "kind" => kind,
        "parent_index" => parent, "target_index" => target,
        "source_label" => source_label, "target_label" => target_label,
        "dimension" => inputbits(F), "source_lut" => Int.(F.lut),
        "target_lut" => Int.(G.lut), "linear_columns" => Int.(A.linear.cols),
        "constant" => Int(A.constant), "independently_verified" => true)
end

"""Describe a bounded Section 3 run with deterministic parameters and provenance."""
function bgp_metadata(kind, seed, parameters)
    return Dict{String,Any}("schema" => "vbf-baudrin-202509-v2", "experiment" => kind,
        "paper" => "Baudrin, Galissant and Perrin, Exploring the Set of APN Functions, BFA 2025",
        "paper_url" => "https://hal.science/hal-05376704v2",
        "native_algorithm" => "Nikolay Kaleyski and Joakim Sunde, Efficiently deciding and recovering CCZ and EA equivalence for arbitrary vectorial Boolean functions using the partition refinement framework, ePrint 2026/940",
        "native_algorithm_url" => "https://eprint.iacr.org/2026/940",
        "algorithm_profile" => "paper",
        "julia_version" => string(VERSION), "seed" => seed,
        "source_hashes" => copy(BGP_SOURCE_CAPTURE.hashes),
        "source_hash_capture" => "once_when_helpers_loaded",
        "source_hashes_captured_at_utc" => BGP_SOURCE_CAPTURE.captured_at_utc,
        "paper_source" => copy(BGP_SOURCE_CAPTURE.paper),
        "parameters" => Dict(string(k) => v for (k,v) in pairs(parameters)),
        "packing" => "graph=(x<<n)|F(x), Walsh=(a<<n)|b", "conjecture_proved" => false)
end

"""Optionally save reproducible Section 3 evidence under the paper results directory."""
function bgp_save(name, data; save_results=false)
    save_results || return nothing
    directory = joinpath(@__DIR__, "results")
    mkpath(directory)
    path = joinpath(directory, name * ".toml")
    open(path, "w") do io
        TOML.print(io, data; sorted=true)
    end
    return path
end

"""Validate common nonnegative bounds for Section 3 experiments."""
function bgp_validate_limits(; limit, max_evaluations, sample_size, max_nodes,
    timeout_seconds, max_subspaces, max_memory_bytes)
    all(x -> x >= 0, (limit, max_evaluations, sample_size, max_nodes,
        timeout_seconds, max_subspaces, max_memory_bytes)) ||
        throw(ArgumentError("experiment limits must be nonnegative"))
    isnan(timeout_seconds) && throw(ArgumentError("timeout_seconds must not be NaN"))
    return nothing
end

"""Canonicalize an orbit partition for the Section 3.1 backend cross-check."""
bgp_partition(orbits) = sort!([sort(copy(orbit)) for orbit in orbits]; by=first)
