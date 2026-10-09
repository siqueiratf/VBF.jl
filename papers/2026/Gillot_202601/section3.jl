# Implements 3 — Counting functions.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 3 — Counting functions
#
# Pseudocode:
#   1. For each nonzero input difference, mark output differences occurring twice.
#   2. Check its Walsh coefficients against component autocorrelations.
# VBF API used: differential_uniformity, walsh_hadamard, algebraic_degree

if !isdefined(@__MODULE__, :gl_kappa)
    include("helpers.jl")
end

"""Build GL counting Boolean functions for every nonzero input difference (Section 3)."""
function gl_counting_functions(F::SBox{N};verify_identity=true) where {N}
    differential_uniformity(F)==2 || throw(ArgumentError("counting function identity requires APN"))
    q=length(F)
    functions=VBFTable{N,1,UInt8}[]
    identity_checked=true
    component_walsh=verify_identity ? [walsh_hadamard([iszero(v) ? 1 : -1
        for v in gl_component(F,b).lut]) for b in 1:q-1] : Vector{Int}[]
    for u in 1:q-1
        counts=zeros(Int,q)
        for x in 0:q-1
            counts[Int(F(x)⊻F(x⊻u))+1]+=1
        end
        f=VBFTable{N,1}(UInt8.(counts.==2))
        push!(functions,f)
        if verify_identity
            W=walsh_hadamard([iszero(v) ? 1 : -1 for v in f.lut])
            identity_checked &= W[1]==0
            for b in 1:q-1
                autocorrelation=sum((isodd(parity(a&u)) ? -1 : 1)*component_walsh[b][a+1]^2
                    for a in 0:q-1)÷q
                identity_checked &= W[b+1]==-autocorrelation
            end
        end
    end
    return (;functions,identity_checked,verified=verify_identity)
end

"""Run the exact counting identity check of GL Section 3 on one finite APN input."""
function gl_section3(F=gold_apn(4);save_results=false)
    started=time_ns()
    c=gl_counting_functions(F)
    r=(;parameters=(;verify_identity=true),complete=true,processed=length(c.functions),identity_checked=c.identity_checked,
        degrees=[algebraic_degree(f) for f in c.functions],elapsed_seconds=(time_ns()-started)*1e-9,
        stop_reason=:none)
    gl_save("section3",r;save_results)
    return r
end

function gl_section3_report(io::IO=stdout;kwargs...)
    return gl_report("Section 3 — counting functions",gl_section3(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_section3_report()
end
