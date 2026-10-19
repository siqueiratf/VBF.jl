"""Opt-in exact odd-five-circuit filtering, using immutable source-bound VBF code.

Each circuit is replayed as five distinct residual flats with xor zero. Its
rank-four span has no all-one functional. An APN completion of V5+<x,t>
therefore cannot annihilate that span in both x and t. The bit-parallel state
for a quotient representative records exactly which circuit spans it
annihilates. A nonempty intersection of two states is a certified rejection.

The source body is copied in memory from the installed VBF at load time; the
source hash and function body are exposed for benchmark provenance. Both
enabled and disabled variants use that identical body. No package source or
campaign is edited. Incomplete circuit discovery only weakens the filter.
"""
module OddFlatCircuitPrototype
using VBF, SHA
using VBF.QuadraticExtensions
include("odd_flat_circuit_audit.jl")
const A=OddFlatCircuitAudit
const Q=VBF.QuadraticExtensions
for name in (:hist_key,:par,:solve_ones,:sort3,:pext,:_du7_prepare,:_DU7Bits,
        :_du7_valid_indices!,:_du7_state,:_du7_triangle_reject,:_DU7ValidIndices,
        :_solve_ones_annihilating)
    @eval const $(name)=getfield(Q,$(QuoteNode(name)))
end
for name in names(Q;all=true,imported=false)
    startswith(String(name),"_") && isdefined(Q,name) && !isdefined(@__MODULE__,name) || continue
    @eval const $(name)=getfield(Q,$(QuoteNode(name)))
end

Base.@kwdef mutable struct CircuitStats
    preparation_seconds::Float64=0.0
    discovery_seconds::Float64=0.0
    circuit_count::Int=0
    discovery_complete::Bool=true
    positions_tested::Int=0
    positions_rejected::Int=0
    cosets_tested::Int=0
    states_bytes::Int=0
end

struct CircuitPlan
    circuits::Vector{A.OddFiveCircuit}
    tables::Array{UInt64,4}
    validmask::Vector{UInt64}
    states::Matrix{UInt64}
    xstate::Vector{UInt64}
end

"Exact annihilator bitset word from three byte lookup tables."
@inline function state_word(plan::CircuitPlan,t::UInt32,word::Int)
    b1=Int(t&0xff)+1;b2=Int((t>>8)&0xff)+1;b3=Int((t>>16)&0xff)+1
    @inbounds begin
        a=plan.tables[1,word,b1,1]⊻plan.tables[1,word,b2,2]⊻plan.tables[1,word,b3,3]
        b=plan.tables[2,word,b1,1]⊻plan.tables[2,word,b2,2]⊻plan.tables[2,word,b3,3]
        c=plan.tables[3,word,b1,1]⊻plan.tables[3,word,b2,2]⊻plan.tables[3,word,b3,3]
        d=plan.tables[4,word,b1,1]⊻plan.tables[4,word,b2,2]⊻plan.tables[4,word,b3,3]
        ~(a|b|c|d)&plan.validmask[word]
    end
end

"Build byte tables once, then annotate the existing sorted-L positions."
function prepare(circuits,L)
    all(c->all(b->b<1<<24,c.basis),circuits) ||
        throw(ArgumentError("circuit coordinates exceed the three-byte implementation"))
    words=cld(length(circuits),64)
    validmask=fill(typemax(UInt64),words)
    words>0 && length(circuits)%64!=0 &&
        (validmask[end]=(UInt64(1)<<(length(circuits)%64))-1)
    columns=zeros(UInt64,4,words,24)
    for (i,circuit) in enumerate(circuits)
        word=((i-1)>>6)+1;bit=UInt64(1)<<((i-1)&63)
        for plane in 1:4,j in 0:23
            isodd(circuit.basis[plane]>>j) && (columns[plane,word,j+1]|=bit)
        end
    end
    tables=zeros(UInt64,4,words,256,3)
    @inbounds for chunk in 0:2,value in 1:255
        previous=(value&(value-1))+1
        column=chunk*8+trailing_zeros(value)+1
        for word in 1:words,plane in 1:4
            tables[plane,word,value+1,chunk+1]=
                tables[plane,word,previous,chunk+1]⊻columns[plane,word,column]
        end
    end
    plan=CircuitPlan(circuits,tables,validmask,zeros(UInt64,words,length(L)),zeros(UInt64,words))
    @inbounds for i in eachindex(L),word in 1:words
        plan.states[word,i]=state_word(plan,L[i],word)
    end
    plan
end

"Replay discovery before constructing a private per-invocation filter."
function prepare(C,Cidx,G,L,stats::CircuitStats)
    start=time_ns()
    discovery=A.odd_five_circuits(C,Cidx,G;maximum_circuits=4096,max_seconds=5.0)
    stats.discovery_seconds=discovery.seconds
    stats.circuit_count=length(discovery.circuits)
    stats.discovery_complete=discovery.complete
    plan=prepare(discovery.circuits,L)
    stats.preparation_seconds=(time_ns()-start)*1e-9
    stats.states_bytes=sizeof(plan.states)+sizeof(plan.tables)
    plan
end

"Prepare one x without allocating per-candidate scratch."
function set_x!(plan::CircuitPlan,x::UInt32,stats::CircuitStats)
    stats.cosets_tested+=1
    @inbounds for word in eachindex(plan.xstate)
        plan.xstate[word]=state_word(plan,x,word)
    end
    nothing
end

"Reject only a state intersection containing a verified odd circuit."
@inline function rejects(plan::CircuitPlan,index::Int,stats::CircuitStats)
    stats.positions_tested+=1
    @inbounds for word in eachindex(plan.xstate)
        if !iszero(plan.xstate[word]&plan.states[word,index])
            stats.positions_rejected+=1
            return true
        end
    end
    false
end

const SOURCE_PATH=joinpath(pkgdir(VBF),"src","constructions","quadratic_extensions.jl")
const SOURCE_SHA256=bytes2hex(open(sha256,SOURCE_PATH))
const SOURCE_BODY=let source=read(SOURCE_PATH,String)
    first=only(findall("function v5_extensions(",source))
    after=only(findall("\n\"\"\"Construct a square quadratic SBox",source))
    source[first.start:after.start-1]
end

function rewrite_once(source,from,to)
    length(findall(from,source))==1 || error("VBF source anchor changed: $from")
    replace(source,from=>to;count=1)
end

body=rewrite_once(SOURCE_BODY,"function v5_extensions(","function circuit_v5_extensions(")
body=rewrite_once(body,"rank_table::Union{Nothing,_PolarRankLookup}=nothing)",
    "rank_table::Union{Nothing,_PolarRankLookup}=nothing, circuit_filter::Bool=true, circuit_stats::CircuitStats=CircuitStats())")
body=rewrite_once(body,"du7_bits=du7_plan===nothing ? nothing : _DU7Bits(du7_plan)",
    "du7_bits=du7_plan===nothing ? nothing : _DU7Bits(du7_plan)\n    circuit_plan=circuit_filter ? prepare(C,Cidx,G,L,circuit_stats) : nothing")
body=rewrite_once(body,"last_candidate=searchsortedlast(Lv,fld(-nWU,3))",
    "circuit_plan===nothing || set_x!(circuit_plan,x,circuit_stats)\n        last_candidate=searchsortedlast(Lv,fld(-nWU,3))")
body=rewrite_once(body,"ncand += 1",
    "circuit_plan===nothing || !rejects(circuit_plan,i,circuit_stats) || continue\n            ncand += 1")
Base.include_string(@__MODULE__,body,"odd_flat_circuit_prototype_generated.jl")
end
