# Packed wide rows are stored as columns: words × equations, low bits first.
function _check_packed_f2(A::AbstractMatrix{UInt64}, nbits::Integer)
    Base.require_one_based_indexing(A)
    0 <= nbits <= 64size(A,1) || throw(ArgumentError("nbits exceeds packed row capacity"))
    Int(nbits)
end

function _rref_packed_f2!(A::AbstractMatrix{UInt64}, nbits::Int, rhs=nothing)
    nw,nr=size(A)
    # Bits outside the declared coefficient width have no mathematical meaning.
    for w in (cld(nbits,64)+1):nw; fill!(view(A,w,:),0); end
    if nbits>0 && nbits%64!=0
        view(A,cld(nbits,64),:) .&= (UInt64(1) << (nbits%64))-1
    end
    pivots=Int[]
    for c in 0:(nbits-1)
        r=length(pivots)+1; r>nr && break
        w=(c>>6)+1;bit=UInt64(1)<<(c&63)
        p=findfirst(i->A[w,i]&bit!=0,r:nr)
        p===nothing && continue
        p+=r-1
        if p!=r
            for k in 1:nw;A[k,r],A[k,p]=A[k,p],A[k,r];end
            rhs===nothing || ((rhs[r],rhs[p])=(rhs[p],rhs[r]))
        end
        for i in 1:nr
            i==r && continue
            if A[w,i]&bit!=0
                for k in w:nw;A[k,i] ⊻= A[k,r];end
                rhs===nothing || (rhs[i] ⊻= rhs[r])
            end
        end
        push!(pivots,c+1)
    end
    pivots
end

"""
    rref_f2!(A::AbstractMatrix{UInt64}; nbits=64size(A,1)) -> (pivot_cols, free_cols)
    rref_f2!(A::AbstractMatrix{Bool}) -> (pivot_cols, free_cols)

Reduced row echelon form over GF(2), mutating `A`. Column indices are 1-based.
A Boolean matrix uses ordinary equations × unknowns layout. A packed matrix
uses **words × equations**: bit `c-1` of packed column `i` is coefficient `(i,c)`.
Unused padding bits are cleared. Width is not limited to a machine word.
"""
function rref_f2!(A::AbstractMatrix{UInt64};nbits::Integer=64size(A,1))
    n=_check_packed_f2(A,nbits)
    pivots=_rref_packed_f2!(A,n)
    pivots,setdiff(1:n,pivots)
end

function _pack_f2(A::AbstractMatrix{Bool})
    Base.require_one_based_indexing(A)
    nr,nc=size(A);out=zeros(UInt64,cld(nc,64),nr)
    for i in 1:nr,c in 1:nc
        A[i,c] && (out[((c-1)>>6)+1,i] |= UInt64(1)<<((c-1)&63))
    end
    out
end

function rref_f2!(A::AbstractMatrix{Bool})
    work=_pack_f2(A);pivots,free=rref_f2!(work;nbits=size(A,2))
    for i in axes(A,1),c in axes(A,2)
        A[i,c]=(work[((c-1)>>6)+1,i]>>((c-1)&63))&1==1
    end
    pivots,free
end

function rank_f2(A::AbstractMatrix{UInt64};nbits::Integer=64size(A,1))
    length(first(rref_f2!(copy(A);nbits)))
end
rank_f2(A::AbstractMatrix{Bool})=rank_f2(_pack_f2(A);nbits=size(A,2))

"""
    solve_f2(A::AbstractMatrix{UInt64}, b::AbstractVector{Bool}; nbits=64size(A,1))
    solve_f2(A::AbstractMatrix{Bool}, b::AbstractVector{Bool})

One solution of `A*x=b`, or `nothing` for an inconsistent system. Packed layout
is words × equations as in [`rref_f2!`](@ref); its solution is a `Vector{UInt64}`.
Boolean layout is equations × unknowns; its solution is a `BitVector`.
Inputs are preserved. Free variables are set to zero; no augmented RHS bit is
stored inside a coefficient word, so exact 64/128-bit widths are supported.
"""
function solve_f2(A::AbstractMatrix{UInt64},b::AbstractVector{Bool};nbits::Integer=64size(A,1))
    n=_check_packed_f2(A,nbits)
    length(b)==size(A,2) || throw(DimensionMismatch("RHS length must equal number of equations"))
    work=copy(A);rhs=collect(b);pivots=_rref_packed_f2!(work,n,rhs)
    any(view(rhs,(length(pivots)+1):length(rhs))) && return nothing
    x=zeros(UInt64,cld(n,64))
    for (i,c) in enumerate(pivots)
        rhs[i] && (x[((c-1)>>6)+1] |= UInt64(1)<<((c-1)&63))
    end
    x
end

_unpack_f2(v,n)=BitVector((v[((c-1)>>6)+1]>>((c-1)&63))&1==1 for c in 1:n)
function solve_f2(A::AbstractMatrix{Bool},b::AbstractVector{Bool})
    x=solve_f2(_pack_f2(A),b;nbits=size(A,2))
    x===nothing ? nothing : _unpack_f2(x,size(A,2))
end

"""
    kernel_f2(A::AbstractMatrix{UInt64}; nbits=64size(A,1))
    kernel_f2(A::AbstractMatrix{Bool})

A nullspace basis with exactly `nbits-rank(A)` vectors, in the same packed or
Boolean solution representation as [`solve_f2`](@ref). Inputs are preserved.
"""
function kernel_f2(A::AbstractMatrix{UInt64};nbits::Integer=64size(A,1))
    n=_check_packed_f2(A,nbits);work=copy(A);pivots,free=rref_f2!(work;nbits=n)
    out=Vector{UInt64}[]
    for f in free
        v=zeros(UInt64,cld(n,64));v[((f-1)>>6)+1] |= UInt64(1)<<((f-1)&63)
        for (i,c) in enumerate(pivots)
            (work[((f-1)>>6)+1,i]>>((f-1)&63))&1==1 &&
                (v[((c-1)>>6)+1] |= UInt64(1)<<((c-1)&63))
        end
        push!(out,v)
    end
    out
end
kernel_f2(A::AbstractMatrix{Bool})=[_unpack_f2(v,size(A,2)) for v in kernel_f2(_pack_f2(A);nbits=size(A,2))]
