"""Include adapter for the catalog rebuild tools; all mathematics is supplied by VBF."""
module IndependentSignature
using VBF
export Workspace, signature
mutable struct Workspace
    ortho::Vector{UInt8}
end
Workspace() = Workspace(UInt8[])
function signature(w::Workspace, lut::Vector{UInt8})
    length(lut)==256 || error("expected 256 LUT entries")
    F=SBox{8}(lut)
    degree=algebraic_degree(F)
    degree==2 || error("degree $degree, expected 2")
    differential_uniformity(F)==2 || error("not APN")
    w.ortho=UInt8.(ortho_derivative(F).lut)
    hex2bytes(VBF.sigma_hash(F))
end
end
