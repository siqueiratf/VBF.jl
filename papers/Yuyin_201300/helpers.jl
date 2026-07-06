# Implements paper-local helpers for Yu, Wang, Li (2013) reproduction.
# Paper: Yu, Wang, Li (2013), "Constructing Differentially 4 Uniform
#        Permutations from Known Ones"
# Section: General — shared helpers
#
# VBF API used: dillon_apn_permutation, SBox, differential_uniformity,
#               nonlinearity, gf_inv, gf_mul, gf_trace, print_banner

using VBF
using Dates

function print_header(io::IO = stdout)
    print_banner(io,
        "Yu, Wang, Li (2013)",
        "Constructing Differentially 4 Uniform Permutations from Known Ones",
        "Julia $(VERSION)  |  $(today())")
    println(io)
    println(io, "Scope:")
    println(io, "  [exact]   Proposition 1: APN swap → δ∈{2,4} (Dillon n=6)")
    println(io, "  [exact]   Example 1: F_{(0,1)}, δ=4, A=54; 1176 examples")
    println(io, "  [exact]   Proposition 3: I_{(0,v)} formula + δ characterization")
    println(io, "  [exact]   Theorem 1: trace condition for I_{(u,v)}")
    println(io, "  [exact]   Remark 2: n=8 exhaustive (32385 pairs, 9180 with δ=4)")
    println(io)
end

"""
Build the swap function F_{(p1,p2)}: exchange F(p1) and F(p2).
"""
function swap_function(F::SBox, p1::Int, p2::Int)
    lut = copy(collect(Int, F.lut))
    lut[p1+1], lut[p2+1] = lut[p2+1], lut[p1+1]
    SBox(lut)
end

"""
Build inverse function I(x) = x^{2^n-2} on GF(2^n), with I(0)=0.
"""
function inverse_function_lut(n::Int; modulus::Int = primitive_polynomial(n))
    N = 1 << n
    lut = Vector{Int}(undef, N)
    lut[1] = 0  # I(0) = 0
    for x in 1:N-1
        lut[x+1] = gf_inv(x, n; modulus=modulus)
    end
    lut
end

"""
Build I_{(u,v)}: swap values of inverse function at u and v.
"""
function inverse_swap(u::Int, v::Int, n::Int; modulus::Int = primitive_polynomial(n))
    lut = inverse_function_lut(n; modulus=modulus)
    lut[u+1], lut[v+1] = lut[v+1], lut[u+1]
    SBox(lut)
end

"""
Compute parameter A = #{(a,b) : δ_F(a,b) = 4, a ≠ 0} for a function F.
"""
function parameter_A(F::SBox{N}) where N
    count = 0
    sz = 1 << N
    for a in 1:sz-1
        for b in 0:sz-1
            n_solutions = 0
            for x in 0:sz-1
                if (Int(F.lut[(x ⊻ a)+1]) ⊻ Int(F.lut[x+1])) == b
                    n_solutions += 1
                end
            end
            if n_solutions == 4
                count += 1
            end
        end
    end
    count
end

"""
Compute parameter A from DDT (faster).
"""
function parameter_A_from_ddt(F::SBox{N}) where N
    D = ddt(F)
    sz = 1 << N
    count = 0
    for a in 2:sz  # rows 2..sz correspond to a=1..sz-1
        for b in 1:sz
            if D[a, b] == 4
                count += 1
            end
        end
    end
    count
end
