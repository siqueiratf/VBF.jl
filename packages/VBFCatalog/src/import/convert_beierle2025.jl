using VBF, VBFCatalog
include("load_sources.jl")
include("readers.jl")

"""Normalize the pinned Beierle et al. (2025) decimal LUT dataset with VBF.

Verification and encoding run in bounded batches; results retain original order
after exact coefficient deduplication. No index or prior catalog affects import.
"""
function stream_members(path;batch=50_000)
    modulus=conway_polynomial(8);powtab=monomial_power_table(8,modulus)
    encodings=Vector{UInt8}[];seen=Set{Vector{UInt8}}();buffer=String[]
    flush_batch() = begin
        isempty(buffer) && return
        output=Vector{Vector{UInt8}}(undef,length(buffer))
        Threads.@threads for i in eachindex(buffer)
            lut=Vector{UInt8}(undef,256)
            SourceReaders.parse_decimal_lut!(lut,buffer[i])==256 || error("malformed published LUT")
            F=SBox{8}(lut)
            differential_uniformity(F)==2 && algebraic_degree(F)==2 || error("published member is not quadratic APN")
            output[i]=encode_quadratic(F;modulus,powtab,verify=false)
        end
        for bytes in output
            bytes in seen && continue
            push!(seen,bytes);push!(encodings,bytes)
        end
        empty!(buffer)
        println("[beierle2025] verified $(length(encodings)) members");flush(stdout)
    end
    open(path,"r") do io
        for line in eachline(io)
            isempty(strip(line)) && continue
            push!(buffer,line)
            length(buffer)>=batch && flush_batch()
        end
    end
    flush_batch()
    encodings
end

function main()
    with_source("beierle2025") do root
        path=joinpath(root,"new_apns.txt")
        encodings=stream_members(path)
        entry=corpus_entry("beierle2025_n8")
        length(encodings)==entry["count"] || error("published corpus count mismatch")
        store=build_corpus_store!(entry["name"],encodings;external=true)
        store.sha256==entry["packed_sha256"] || error("published coefficient digest mismatch")
        @info "Installed external members" name=entry["name"] count=store.count path=store.path
    end
end

abspath(PROGRAM_FILE)==(@__FILE__) && main()
