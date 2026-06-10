# Paper-local helpers for the Yu-Wang-Li (2014) QAM paper reproduction.
# Paper: Yu, Wang, Li (2014), "A Matrix Approach for Constructing Quadratic
#        APN Functions", Des. Codes Cryptogr. 73:587-600.
# Section: General - shared helpers, result I/O, formatting
#
# VBF API used by included files: SBox, QAM construction/search primitives.

using VBF
using TOML

"""Print paper title, authors, and venue."""
function print_header(io::IO = stdout)
    println(io, "=" ^ 72)
    println(io, "Yu, Wang, Li (2014): A Matrix Approach for Constructing")
    println(io, "Quadratic APN Functions")
    println(io, "Designs, Codes and Cryptography 73:587-600")
    println(io, "=" ^ 72)
end

"""Print a titled section separator."""
function print_section(title::AbstractString, io::IO = stdout)
    println(io, "\n-- ", title, " ", "-" ^ max(0, 70 - length(title) - 4))
end

"""Stable PASS/FAIL label used by reports."""
status_str(ok::Bool) = ok ? "PASS" : "FAIL"

"""Print pass/fail indicator with label."""
function print_check(label::AbstractString, ok::Bool, io::IO = stdout)
    tag = ok ? "[ OK ]" : "[FAIL]"
    println(io, "  ", tag, " ", label)
end

"""Print a key-value pair."""
function print_kv(label::AbstractString, value, io::IO = stdout)
    println(io, "  ", label, ": ", value)
end

function paper_results_dir()
    d = joinpath(@__DIR__, "results")
    mkpath(d)
    d
end

paper_results_path(filename::AbstractString) = joinpath(paper_results_dir(), filename)

toml_safe(x::Bool) = x
toml_safe(x::Integer) = typemin(Int) <= x <= typemax(Int) ? Int(x) : string(x)
toml_safe(x::AbstractFloat) = Float64(x)
toml_safe(x::AbstractString) = String(x)
toml_safe(x::Symbol) = String(x)
toml_safe(::Nothing) = "nothing"
toml_safe(x::Tuple) = Any[toml_safe(v) for v in x]
toml_safe(x::AbstractVector) = Any[toml_safe(v) for v in x]
function toml_safe(x::NamedTuple)
    d = Dict{String,Any}()
    for k in keys(x)
        d[String(k)] = toml_safe(x[k])
    end
    d
end
function toml_safe(x::AbstractDict)
    d = Dict{String,Any}()
    for (k, v) in x
        d[k isa Symbol ? String(k) : string(k)] = toml_safe(v)
    end
    d
end
toml_safe(x) = string(x)

"""
    write_results_toml(data, filename) -> String

Write a deterministic TOML result artifact under `results/`.
"""
function write_results_toml(data, filename::AbstractString)
    path = paper_results_path(filename)
    open(path, "w") do io
        TOML.print(io, toml_safe(data); sorted = true)
    end
    path
end
