"""Exact dense histogram setup for the quadratic extension Fourier arrays.

The usual V5 bent counts have only 33 possible values. Count those bins without
millions of dictionary updates, retaining the original dictionary types and
keys. Unusual scales, dimensions or values use the original sparse behavior.
Separate setup functions keep their buffers out of the candidate loop.
"""

"""Return the original scaled bent-count histogram and ordered eligible cosets."""
Base.@noinline function _v5_bent_histogram(cnt,scale,need,d)
    X=UInt32[]
    if scale<=0 || !(0<=d<=12)
        h=Dict{Int32,Int}()
        @inbounds for t in 2:length(cnt)
            v=cnt[t];h[v]=get(h,v,0)+1
            v==need*scale && push!(X,UInt32(t-1))
        end
        return h,X
    end
    bins=zeros(Int,(1<<d)+1);overflow=Dict{Int32,Int}()
    shift=ispow2(scale) ? trailing_zeros(scale) : -1
    @inbounds for t in 2:length(cnt)
        v=cnt[t]
        bin=shift>=0 ? Int(v)>>shift : Int(v)÷scale
        exact=shift>=0 ? (Int(v)&(scale-1))==0 : rem(Int(v),scale)==0
        if exact && 0<=bin<length(bins)
            bins[bin+1]+=1
        else
            overflow[v]=get(overflow,v,0)+1
        end
        v==need*scale && push!(X,UInt32(t-1))
    end
    h=Dict{Int32,Int}(Int32((i-1)*scale)=>bins[i] for i in eachindex(bins) if bins[i]>0)
    merge!(h,overflow)
    h,X
end

"""Count signed Fourier values, optionally reusing exclusively owned dense bins.

Dense scratch is resized and cleared before use. The returned dictionary owns
its counts, so later calls cannot change previous results. Small inputs retain
the sparse path without touching or allocating dense scratch.
"""
Base.@noinline function _v5_flat_histogram(g5::Vector{Int16},bins::Union{Nothing,Vector{Int}}=nothing)
    if length(g5)<4096
        h=Dict{Int16,Int}()
        @inbounds for v in g5;h[v]=get(h,v,0)+1;end
        return h
    end
    counts=bins===nothing ? Vector{Int}(undef,65536) : bins
    _v5_flat_histogram_dense(g5,counts)
end

"""Keep dense scratch and histogram counts concretely typed through both loops."""
Base.@noinline function _v5_flat_histogram_dense(g5::Vector{Int16},bins::Vector{Int})
    length(bins)==65536 || resize!(bins,65536)
    fill!(bins,0)
    @inbounds for v in g5;bins[Int(v)+32769]+=1;end
    h=Dict{Int16,Int}()
    @inbounds for i in eachindex(bins)
        count=bins[i]
        count>0 && (h[Int16(i-32769)]=count)
    end
    h
end
