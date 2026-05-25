"""
    BFA

Reproducible Boolean Function Analysis in Julia.

Implements the algorithmic content of the BFA literature (`sboxU`,
`apn-ccz-graph-framework`, `ea-equivalence`, `self_equivalent_apn`,
`APN-Repository`) as native Julia, without runtime dependency on those
upstream repositories.

Loaded in tiers (later tiers depend on earlier):

1. Types       — `SBox`, `F2LinearMap`, `F2AffineMap`, `Spectrum`
2. F₂ⁿ         — bit arithmetic, ANF (Möbius), Walsh transform
3. Statistics  — DDT, LAT, BCT, FBCT, anomaly probability models
4. Equivalence — linear / affine / EA / CCZ / self-equivalence
5. APN tools   — ortho-derivative, ODDS/ODWS, Δ-rank, Γ-rank, σ-multiplicities

See `papers/` for per-paper reproduction notebooks.
"""
module BFA

# tier 1 — types (no dependencies within BFA)
include("types/sbox.jl")
include("types/f2_linear_map.jl")
include("types/f2_affine_map.jl")
include("types/spectrum.jl")

# tier 2 — F₂ⁿ primitives (depends on tier 1)
include("f2/arith.jl")
include("f2/anf.jl")
include("f2/walsh.jl")

# tier 3 — data layer (depends on tier 1 only; never calls tier 2+)
include("data/literature.jl")

# tier 4 — statistics (depends on tiers 1 + 2)
include("statistics/differential.jl")
include("statistics/linear.jl")
include("statistics/boomerang.jl")
include("statistics/algebraic.jl")
include("statistics/linear_structures.jl")
include("statistics/anomaly.jl")

# tier 3..5 — added in later phases

include("exports.jl")

end # module BFA
