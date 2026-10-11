"""Decode an eight-bit LUT or one of VBF's two quadratic coefficient encodings."""
function candidate_lut(encoded;powtab=nothing)
    bytes=hex2bytes(encoded)
    length(bytes)==256 && return bytes
    length(bytes)==37 && return UInt8.(decode_quadratic_lut(bytes,8,conway_polynomial(8);powtab))
    length(bytes)==28 || error("expected 28/37 coefficient bytes or 256 LUT bytes")
    UInt8.(VBF.QuadraticAPNTree.lut(VBF.QuadraticAPNTree.decode_coeffs(encoded,8),8))
end

"""Normalize an immutable candidate TSV into the catalog's compact corpus store.

The declared byte digest, count, every quadratic APN signature and the VBF
encoding are checked before registration. Used by both importers and VBFSearch.
"""
function import_lut_corpus!(db::SQLite.DB,entry;data=catalog_source_dir())
    path=joinpath(data,entry["file"])
    _reference_filehash(path)==entry["sha256"] || error("changed LUT corpus input: $path")
    encodings=Vector{UInt8}[];modulus=conway_polynomial(8);powtab=monomial_power_table(8,modulus)
    if get(entry,"reader","lut_tsv")=="quadratic_coeffs"
        open(`gzip -dc -- $path`,"r") do io
            while !eof(io)
                bytes=read(io,37)
                length(bytes)==37 || error("truncated quadratic coefficient input")
                push!(encodings,bytes)
            end
        end
        hashes=Vector{String}(undef,length(encodings))
        Threads.@threads for i in eachindex(encodings)
            F=SBox{8}(decode_quadratic_lut(encodings[i],8,modulus;powtab))
            algebraic_degree(F)==2 || error("nonquadratic corpus input")
            hashes[i]=sigma_hash(F)
        end
        get(entry,"separating",false) && length(Set(hashes))!=length(hashes) &&
            error("repeated separating signature")
    else
        each_candidate(path) do row
            F=SBox{8}(candidate_lut(row.payload;powtab))
            algebraic_degree(F)==2 && sigma_hash(F)==row.hash || error("invalid quadratic APN/signature at $path:$(row.line)")
            push!(encodings,encode_quadratic(F;modulus,powtab))
        end
    end
    length(encodings)==entry["count"] || error("source member count mismatch: $path")
    if haskey(entry,"packed_sha256")
        ctx=SHA.SHA2_256_CTX()
        foreach(bytes->SHA.update!(ctx,bytes),encodings)
        bytes2hex(SHA.digest!(ctx))==entry["packed_sha256"] || error("packed corpus digest mismatch")
    end
    _reference_filehash(path)==entry["sha256"] || error("source changed during import")
    store=withenv("BFA_CATALOG_PATH"=>catalog_path(db)) do
        build_corpus_store!(entry["name"],encodings)
    end
    _register_declared_corpus!(db,entry,store)
    store
end

"""Write a reproducible gzip stream of VBF's 37-byte quadratic coefficients."""
function write_corpus_input(path,encodings)
    mkpath(dirname(path));partial=path*".partial"
    try
        open(pipeline(`gzip -n -9`;stdout=partial),"w") do io
            for bytes in encodings
                length(bytes)==37 || error("expected eight-bit quadratic coefficients")
                write(io,bytes)
            end
        end
        mv(partial,path;force=true)
    finally
        rm(partial;force=true)
    end
    path
end

"""Stream candidate TSV records, retaining original fields and line numbers.

Supports plain TSV and gzip TSV (through the same gzip utility as the original
source fetchers). Decoding does not imply APN verification or trust old labels.
"""
function each_candidate(f,path::AbstractString)
    input=endswith(path,".gz") ? `gzip -dc -- $path` : path
    open(input,"r") do io
        each_candidate(f,io)
    end
end

function each_candidate(f,io::IO)
    payloadcol,statuscol=2,nothing
    names=String[];firstrow=true
    for (number,line) in enumerate(eachline(io))
        isempty(strip(line)) && continue
        cols=split(line,'\t')
        if firstrow && cols[1] in ("sigma","sigma_hash")
            names=String.(cols)
            payloadcol=something(findfirst(c->c in ("coeffs","lut_hex","lut"),cols))
            statuscol=findfirst(==("status"),cols)
            firstrow=false
            continue
        end
        firstrow=false
        col=length(cols)>=3 && length(cols[3])==512 ? 3 : payloadcol
        col<=length(cols) || error("missing candidate payload at line $number")
        f((hash=String(cols[1]),payload=String(cols[col]),
            status=statuscol===nothing ? "unlabelled" : String(cols[statuscol]),line=number,
            fields=isempty(names) ? Dict("original_row"=>String(line)) : Dict(k=>String(v) for (k,v) in zip(names,cols))))
    end
end
