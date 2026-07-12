# Paper-local helpers for the Yu–Perrin 2022 (QAM method) reproduction.
# Include from each script: include(joinpath(@__DIR__, "helpers.jl"))
#
# ── Pseudocode / paper mapping ─────────────────────────────────────────────
# This file collects the primitives the paper's routines share:
#
#   * The finite field F_{2^8} exactly as the authors use it (Section
#     "Notation"): g is "the default primitive element (g^8+g^4+g^3+g^2+1=0)
#     in Magma". That polynomial is VBF's `conway_polynomial(8) == 285`, and
#     g is the field element `2` (the root x of the defining polynomial). So
#     g^k = `gf_pow(2, k, 8; modulus = 285)`.
#
#   * The normal basis the authors build M_alpha from (Section "Notation"):
#     alpha = {gamma, gamma^2, ..., gamma^{2^{n-1}}} with gamma = g^11.
#
#   * F_2 span / coset partitioning, used by Proposition 3 to restrict the
#     candidate sets for x_13, x_12, x_7, x_6.
#
#   * report formatting helpers (PASS/FAIL, sections, key/value lines).

using VBF
using TOML

# ── Field of the paper: F_{2^8} with Magma's default primitive element g ────

"Modulus of F_{2^8} used by Yu–Perrin: g^8+g^4+g^3+g^2+1 (Magma default)."
const MAGMA_MODULUS = conway_polynomial(8)   # == 285 == 0b100011101

"The primitive element g of the paper is the field element x (integer 2)."
const PAPER_G = 2

"Exponent of the normal-basis generator gamma = g^11 (Section \"Notation\")."
const NORMAL_BASIS_EXP = 11

"""
    gpow(k; n = 8, modulus = MAGMA_MODULUS) -> Int

The field element `g^k` of the paper, as an integer bit-vector. `k` is reduced
modulo `2^n - 1`. With `n = 8` this is Magma's `g^k` under `g^8+g^4+g^3+g^2+1`.
"""
gpow(k::Integer; n::Int = 8, modulus::Integer = MAGMA_MODULUS) =
    gf_pow(PAPER_G, mod(Int(k), (1 << n) - 1), n; modulus = modulus)

"""
    normal_basis(; n = 8, modulus = MAGMA_MODULUS) -> Vector{Int}

The normal basis `alpha_u = gamma^{2^{u-1}}` (`u = 1..n`) with `gamma = g^11`,
as the authors construct `M_alpha` in Section "Notation".
"""
function normal_basis(; n::Int = 8, modulus::Integer = MAGMA_MODULUS)
    gamma = gpow(NORMAL_BASIS_EXP; n = n, modulus = modulus)
    [gf_pow(gamma, 1 << (u - 1), n; modulus = modulus) for u = 1:n]
end

"""
    gold3_polar(x, y; n = 8, modulus = MAGMA_MODULUS) -> Int

The polar (bilinear) form of the Gold map `F(x) = x^3`:
`B_F(x,y) = F(x+y)+F(x)+F(y) = x^2 y + x y^2`. Evaluating it on a basis gives
the QAM of `x^3` (the upper-left 6x6 block of `H_8` in Conjecture 2).
"""
function gold3_polar(x::Integer, y::Integer; n::Int = 8, modulus::Integer = MAGMA_MODULUS)
    xy2 = gf_mul(Int(x), gf_mul(Int(y), Int(y), n; modulus = modulus), n; modulus = modulus)
    x2y = gf_mul(gf_mul(Int(x), Int(x), n; modulus = modulus), Int(y), n; modulus = modulus)
    x2y ⊻ xy2
end

# ── F_2 linear algebra over field elements seen as bit-vectors ──────────────

"""
    f2_span(vecs) -> Set{Int}

The F_2-linear span of integer bit-vectors `vecs` (including 0).
"""
function f2_span(vecs)
    s = Set{Int}((0,))
    for v in vecs
        vi = Int(v)
        for e in collect(s)
            push!(s, e ⊻ vi)
        end
    end
    s
end

"""
    nontrivial_coset_reps(basis_vecs; n = 8) -> Vector{Int}

One representative for each non-trivial coset of `W = span(basis_vecs)` in
`F_{2^n}`, i.e. the smallest element of each coset `W + a` with `a ∉ W`. There
are `2^n / |W| - 1` of them. This is the partitioning routine behind the
`A = {a_1,…,a_7}` candidate set for `x_13` in Proposition 3.
"""
function nontrivial_coset_reps(basis_vecs; n::Int = 8)
    W = f2_span(basis_vecs)
    seen = copy(W)
    reps = Int[]
    for x = 0:((1 << n) - 1)
        x in seen && continue
        push!(reps, x)
        for w in W
            push!(seen, x ⊻ w)
        end
    end
    reps
end

"""
    coset_involution_half(basis_vecs, t; n = 8) -> Vector{Int}

A set `B` such that `B ∪ (B + t)` partitions `F_{2^n} ∖ span(basis_vecs)`, where
`t ∈ span(basis_vecs)` so that `x ↦ x + t` is a fixed-point-free involution on
the complement. Returns the smaller representative of each pair. This is the
partitioning routine behind the `B` (for `x_12`) and `G` (for `x_6`) candidate
sets in Proposition 3.
"""
function coset_involution_half(basis_vecs, t::Integer; n::Int = 8)
    W = f2_span(basis_vecs)
    ti = Int(t)
    half = Int[]
    used = falses(1 << n)
    for x = 0:((1 << n) - 1)
        x in W && continue
        used[x + 1] && continue
        push!(half, x)
        used[x + 1] = true
        used[(x ⊻ ti) + 1] = true
    end
    half
end

# ── result paths ───────────────────────────────────────────────────────────

function paper_results_dir()
    d = joinpath(@__DIR__, "results")
    mkpath(d)
    d
end

function paper_results_path(filename::AbstractString)
    joinpath(paper_results_dir(), filename)
end

# ── TOML result artifacts ───────────────────────────────────────────────────
# Structured, machine-readable results, mirroring the TOML convention used in
# papers/Beierle_202107. `toml_safe` coerces the report's values (NamedTuples,
# Symbols, tuples, BigInts, nothing) into the scalar/array/table types that
# `TOML.print` can emit.

toml_safe(x::Bool) = x
toml_safe(x::Integer) = typemin(Int) <= x <= typemax(Int) ? Int(x) : string(x)
toml_safe(x::AbstractFloat) = float(x)
toml_safe(x::AbstractString) = String(x)
toml_safe(x::Symbol) = String(x)
toml_safe(::Nothing) = "nothing"
toml_safe(x::AbstractVector) = Any[toml_safe(v) for v in x]
toml_safe(x::Tuple) = Any[toml_safe(v) for v in x]
function toml_safe(x::NamedTuple)
    d = Dict{String,Any}()
    for k in keys(x)
        d[String(k)] = toml_safe(x[k])
    end
    d
end
function toml_safe(x::AbstractDict)
    d = Dict{String,Any}()
    for (k, v) in x
        d[k isa Symbol ? String(k) : string(k)] = toml_safe(v)
    end
    d
end
toml_safe(x) = string(x)   # fallback: anything else becomes its string form

"""
    write_results_toml(data, filename) -> String

Write `data` (a Dict/NamedTuple tree) as a TOML artifact under `results/`,
returning the path. Values are coerced with [`toml_safe`](@ref) so NamedTuples
become tables, Symbols/BigInts become strings, etc. Keys are sorted for a
deterministic, diff-friendly file.
"""
function write_results_toml(data, filename::AbstractString)
    path = paper_results_path(filename)
    open(path, "w") do io
        TOML.print(io, toml_safe(data); sorted = true)
    end
    path
end

# ── report formatting ───────────────────────────────────────────────────────

function print_header(io::IO = stdout)
    println(io, "# Reproduction: Yu and Perrin (2022)")
    println(io, "# \"Constructing more quadratic APN functions with the QAM method\"")
    println(io)
end

function search_completeness_label(exhaustive::Bool, evaluated::Int, budget::Int)
    if exhaustive
        "exhaustive ($(evaluated) candidates evaluated)"
    else
        "budget-limited ($(evaluated)/$(budget) candidates evaluated)"
    end
end
