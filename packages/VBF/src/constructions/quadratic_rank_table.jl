"""Concrete read-only polar-rank lookup implementations used by Fourier setup."""
abstract type _PolarRankLookup end

"""
    PolarRankTable(G::Geometry)

Explicit, reusable table of alternating-form ranks for the geometry `G`.
The entry `table.ranks[Int(q)+1]` equals `form_rank(G, q)`. Construction uses
the existing rank routine in at most 256 disjoint chunks; it creates no global
cache. An eight-variable table occupies 256 MiB and can be shared read-only by
search workers. Treat the `ranks` vector as read-only after construction.

Only geometries on two through eight variables are supported. The constructor
accepts a geometry rather than an unchecked rank vector.
"""
struct PolarRankTable <: _PolarRankLookup
    n::Int
    ranks::Vector{UInt8}

    function PolarRankTable(G::Geometry)
        2<=G.n<=8 || throw(ArgumentError("rank-table dimension must be between 2 and 8"))
        G.N==G.n*(G.n-1)÷2 || throw(ArgumentError("inconsistent alternating-form geometry"))
        entries=1<<G.N
        ranks=Vector{UInt8}(undef,entries)
        chunks=min(256,entries)
        chunk_size=entries÷chunks
        Threads.@threads :dynamic for chunk in 1:chunks
            first_form=(chunk-1)*chunk_size
            last_form=chunk*chunk_size-1
            @inbounds for q in first_form:last_form
                ranks[q+1]=UInt8(form_rank(G,UInt32(q)))
            end
        end
        new(G.n,ranks)
    end
end

"""
    PackedPolarRankTable(G::Geometry)

Exact two-bit polar-rank lookup for geometries on two through eight variables.
Every nonzero alternating form has rank 2, 4, 6 or 8, represented by codes
0, 1, 2 or 3. The zero form is decoded separately. The `codes` vector occupies
64 MiB at eight variables and must be treated as read-only after construction.

Construction uses the existing rank routine and assigns complete bytes to
disjoint worker chunks. It allocates no temporary unpacked rank table.
"""
struct PackedPolarRankTable <: _PolarRankLookup
    n::Int
    codes::Vector{UInt8}

    function PackedPolarRankTable(G::Geometry)
        2<=G.n<=8 || throw(ArgumentError("rank-table dimension must be between 2 and 8"))
        G.N==G.n*(G.n-1)÷2 || throw(ArgumentError("inconsistent alternating-form geometry"))
        entries=1<<G.N;bytes=cld(entries,4)
        codes=Vector{UInt8}(undef,bytes)
        chunks=min(256,bytes);chunk_size=bytes÷chunks
        Threads.@threads :dynamic for chunk in 1:chunks
            first_byte=(chunk-1)*chunk_size;last_byte=chunk*chunk_size-1
            @inbounds for byte_index in first_byte:last_byte
                bits=UInt8(0)
                for offset in 0:3
                    q=4byte_index+offset
                    q<entries || break
                    q==0 && continue
                    rank=form_rank(G,UInt32(q))
                    code=UInt8((rank>>1)-1)
                    bits|=code<<(2offset)
                end
                codes[byte_index+1]=bits
            end
        end
        new(G.n,codes)
    end
end

"""Decode an exact rank; a table is used only with its validated geometry."""
@inline _polar_rank(table::PolarRankTable,q::UInt32)=Int(@inbounds table.ranks[Int(q)+1])

"""Decode a nonzero rank code, keeping the unique zero form distinct."""
@inline function _polar_rank(table::PackedPolarRankTable,q::UInt32)
    q==0 && return 0
    code=@inbounds table.codes[Int(q>>2)+1]
    2(Int((code>>(2Int(q&UInt32(3))))&0x03)+1)
end
