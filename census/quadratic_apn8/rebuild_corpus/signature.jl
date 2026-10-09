"""
Independent verification of quadratic (8,8)-APN functions and their
ortho-derivative differential/absolute-Walsh signature. Uses a Boolean Möbius
transform, rank-seven polar maps, and an integer Walsh transform; no VBF
verification or signature routines. The serialization matches
VBFCatalog.sigma_key so freshly computed hashes can be compared with its index.
See Canteaut–Couvreur–Perrin (2022) and Yoshiara (2012).
"""
module IndependentSignature
using SHA
export Workspace, signature

"""Reusable buffers for one concurrent verification task."""
struct Workspace
    anf::Vector{UInt8}
    ortho::Vector{UInt8}
    basis::Vector{UInt8}
    counts::Vector{Int}
    differential::Vector{Int}
    walsh::Vector{Int}
    transform::Vector{Int}
end
Workspace() = Workspace(zeros(UInt8, 256), zeros(UInt8, 256), zeros(UInt8, 8),
                        zeros(Int, 256), zeros(Int, 257), zeros(Int, 257), zeros(Int, 256))

"""
Verify degree exactly two and APN, then return the SHA-256 signature bytes.
For quadratic F, APN is equivalent to rank(B_a)=7 for every nonzero a, where
B_a(x)=F(x+a)+F(x)+F(a)+F(0). Its unique nonzero annihilator is π_F(a).
Throws on invalid input, so an incomplete baseline cannot silently omit it.
"""
function signature(w::Workspace, lut::Vector{UInt8})
    length(lut) == 256 || error("expected 256 LUT entries")
    copyto!(w.anf, lut)
    @inbounds for bit in 0:7
        mask = 1 << bit
        for x in 0:255
            x & mask == 0 || (w.anf[x+1] ⊻= w.anf[(x⊻mask)+1])
        end
    end
    degree = 0
    @inbounds for x in 0:255
        w.anf[x+1] == 0 || (degree = max(degree, count_ones(x)))
    end
    degree == 2 || error("degree $degree, expected 2")
    w.ortho[1] = 0
    @inbounds for a in 1:255
        fill!(w.basis, 0)
        rank = 0
        offset = lut[a+1] ⊻ lut[1]
        for bit in 0:7
            e = 1 << bit
            v = lut[(a⊻e)+1] ⊻ lut[e+1] ⊻ offset
            for pivot in 7:-1:0
                v & (1 << pivot) == 0 && continue
                if w.basis[pivot+1] == 0
                    w.basis[pivot+1] = v
                    rank += 1
                    break
                end
                v ⊻= w.basis[pivot+1]
            end
        end
        rank == 7 || error("not APN: polar rank $rank at a=$a")
        free = findfirst(iszero, w.basis) - 1
        p = UInt8(1 << free)
        for pivot in 0:7
            row = w.basis[pivot+1]
            row == 0 && continue
            isodd(count_ones(row & p)) && (p ⊻= UInt8(1 << pivot))
        end
        w.ortho[a+1] = p
    end
    fill!(w.differential, 0)
    fill!(w.walsh, 0)
    @inbounds for a in 1:255
        fill!(w.counts, 0)
        for x in 0:255
            w.counts[Int(w.ortho[x+1] ⊻ w.ortho[(x⊻a)+1])+1] += 1
        end
        for c in w.counts
            w.differential[c+1] += 1
        end
    end
    @inbounds for b in 0:255
        for x in 0:255
            w.transform[x+1] = isodd(count_ones(UInt8(b) & w.ortho[x+1])) ? -1 : 1
        end
        width = 1
        while width < 256
            for start in 0:2width:255, j in 1:width
                u, v = w.transform[start+j], w.transform[start+j+width]
                w.transform[start+j] = u + v
                w.transform[start+j+width] = u - v
            end
            width *= 2
        end
        for a in 0:255
            a == b == 0 && continue
            w.walsh[abs(w.transform[a+1])+1] += 1
        end
    end
    pairs(h) = Pair{Int,Int}[(i-1) => h[i] for i in eachindex(h) if h[i] != 0]
    SHA.sha256(string((pairs(w.differential), pairs(w.walsh))))
end
end
