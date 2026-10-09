# Implements 5.2 — Invariants; Table 3.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 5.2 — Invariants; Table 3
#
# Pseudocode:
#   1. Evaluate graph quadratic annihilator nullity, Γ/Δ ranks and a selected valuation invariant.
#   2. Expose the author’s unspecified RM/base-invariant/transvection parameters.
# VBF API used: rank_f2, walsh_hadamard, gamma_rank, delta_rank

if !isdefined(@__MODULE__,:gl_paper_roots)
    include("table2.jl")
end

"""Compute degree-two graph annihilator nullity, the explicit X₂,₀ interpretation."""
function gl_multiplicative20(F::SBox)
    N=inputbits(F)
    masks=[m for m in 0:(1<<(2N))-1 if count_ones(m)<=2]
    length(masks)<=128 || throw(ArgumentError("packed annihilator test supports at most128 monomials"))
    rows=UInt128[]
    for x in 0:length(F)-1
        point=(x<<N)|Int(F(x))
        row=UInt128(0)
        for (j,m) in enumerate(masks)
            point&m==m && (row|=UInt128(1)<<(j-1))
        end
        push!(rows,row)
    end
    return length(masks)-rank_f2(rows;nbits=length(masks))
end

"""Evaluate GL’s dynamic valuation invariant with the explicitly selected base invariant."""
function gl_valuation(F::SBox;J=gl_kappa)
    N=inputbits(F)
    q=1<<(2N)
    graph=zeros(UInt8,q)
    for x in 0:length(F)-1
        graph[((x<<N)|Int(F(x)))+1]=1
    end
    W=walsh_hadamard([v==0 ? 1 : -1 for v in graph])
    return Tuple(J(VBFTable{2N,1}(UInt8[w==0 ? v==-1 : trailing_zeros(abs(w))==v
        for w in W])) for v in -1:2N)
end

"""Measure specified GL Table 3 invariants and expose the unresolved author definitions."""
function gl_table3(;limit=14,timeout_seconds=60,base_invariant=gl_kappa,save_results=false)
    started=time_ns()
    rows=NamedTuple[]
    for (i,F) in enumerate(Iterators.take(gl_paper_roots(),limit))
        (time_ns()-started)*1e-9>=timeout_seconds && break
        push!(rows,(;label=i,multiplicative20=gl_multiplicative20(F),
            valuation=gl_valuation(F;J=base_invariant),gamma_rank=gamma_rank(F),delta_rank=delta_rank(F)))
    end
    executed_complete=length(rows)==min(limit,14)
    distinct=(;multiplicative20=length(Set(r.multiplicative20 for r in rows)),
        valuation=length(Set(r.valuation for r in rows)),gamma_rank=length(Set(r.gamma_rank for r in rows)),
        delta_rank=length(Set(r.delta_rank for r in rows)))
    r=(;parameters=(;limit,timeout_seconds,base_invariant=string(base_invariant)),complete=false,executed_complete,processed=length(rows),rows,distinct,
        base_invariant="caller-selected; default exact normalized fourth moment",
        multiplicative_interpretation="degree≤2 annihilators of graph; source RM parameters require correction",
        transvection_executed=false,unresolved="paper does not specify base J or transvection stabilizer sufficiently",
        elapsed_seconds=(time_ns()-started)*1e-9,stop_reason=:unresolved_author_parameters)
    gl_save("table3",r;save_results)
    return r
end

function gl_table3_report(io::IO=stdout;kwargs...)
    return gl_report("Table 3 — numerical invariants",gl_table3(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_table3_report(limit=1)
end
