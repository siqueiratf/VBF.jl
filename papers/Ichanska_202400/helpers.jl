# Implements shared helpers for Ichanska et al. (2024/2025)
# Paper: Ichanska, Berg, Kaleyski, Yu, "Pushing the QAM method for finding APN functions further"
#
# Pseudocode:
#   odds(F)                    — differential spectrum of ortho_derivative(F)
#   subfield_elements(n, m)    — elements of F₂ᵐ ⊆ F₂ⁿ (including 0)
#   is_in_cat1(α, n, m)        — test α + α^{2^m} = 0 (α in Category 1)
#   find_normal_element(n)     — smallest b s.t. {b,b²,...,b^{2^{n-1}}} is F₂-basis
#   normal_basis_deriv_matrix  — derivative matrix of F in normal basis
#   cyclic_shift_matrix(M, s)  — shift matrix indices cyclically by s (mod n)
#   linear_perms_subfield      — enumerate linear perms with F₂ᵐ coefficients
#   orbit_partition            — partition elements under group action
# VBF API used: gf_pow, gf_mul, conway_polynomial, ortho_derivative,
#               differential_spectrum, sorted_pairs, SBox

using VBF

function odds(F::SBox)
    π = ortho_derivative(F)
    differential_spectrum(π)
end

function subfield_elements(n::Int, m::Int; modulus::Int = conway_polynomial(n))
    @assert m <= n && rem(n, m) == 0 "m must divide n"
    step = (1 << n - 1) ÷ (1 << m - 1)
    vcat([0], [gf_pow(2, k * step, n; modulus = modulus) for k in 0:(1<<m)-2])
end

function is_in_cat1(α::Int, n::Int, m::Int; modulus::Int = conway_polynomial(n))
    α == 0 && return false
    α ⊻ gf_pow(α, 1 << m, n; modulus = modulus) == 0
end

function find_normal_element(n::Int; modulus::Int = conway_polynomial(n))
    function _is_normal(b)
        basis = [gf_pow(b, 1 << i, n; modulus = modulus) for i in 0:n-1]
        mat = zeros(UInt8, n, n)
        for i in 1:n, bit in 0:n-1
            mat[bit+1, i] = (basis[i] >> bit) & 1
        end
        rank = 0
        for col in 1:n
            piv = findfirst(r -> mat[r, col] == 1, col:n)
            piv === nothing && continue
            row = piv + col - 1
            mat[[col, row], :] = mat[[row, col], :]
            rank += 1
            for r in 1:n
                r != col && mat[r, col] == 1 && (mat[r, :] .⊻= mat[col, :])
            end
        end
        rank == n
    end
    b = findfirst(_is_normal, 1:(1<<n)-1)
    b === nothing && error("no normal element found for n=$n mod=$modulus")
    b
end

function normal_basis_deriv_matrix(F::SBox{N}, b::Int;
                                   modulus::Int = conway_polynomial(N)) where {N}
    basis = [gf_pow(b, 1 << i, N; modulus = modulus) for i in 0:N-1]
    M = zeros(Int, N, N)
    for i in 1:N, j in (i+1):N
        v = Int(F(basis[i] ⊻ basis[j])) ⊻ Int(F(basis[i])) ⊻ Int(F(basis[j]))
        M[i, j] = v
        M[j, i] = v
    end
    M
end

function cyclic_shift_matrix(M::Matrix{Int}, s::Int)
    n = size(M, 1)
    M2 = similar(M)
    for i in 1:n, j in 1:n
        M2[i, j] = M[mod1(i + s, n), mod1(j + s, n)]
    end
    M2
end

function apply_linear_map(coeffs::Vector{Int}, x::Int, n::Int;
                          modulus::Int = conway_polynomial(n))
    val = 0
    for (i, α) in enumerate(coeffs)
        α == 0 && continue
        xi = gf_pow(x, 1 << (i - 1), n; modulus = modulus)
        val ⊻= gf_mul(α, xi, n; modulus = modulus)
    end
    val
end

function linear_perms_subfield(n::Int, m::Int;
                                modulus::Int = conway_polynomial(n))
    sf = subfield_elements(n, m; modulus = modulus)
    N = 1 << n
    perms = Vector{Vector{Int}}()
    for coeffs in Iterators.product(ntuple(_ -> sf, n)...)
        lut = zeros(Int, N)
        for x in 1:N-1
            lut[x+1] = apply_linear_map(collect(coeffs), x, n; modulus = modulus)
        end
        length(Set(lut)) == N && push!(perms, lut)
    end
    perms
end

function orbit_partition(elements::AbstractVector{Int},
                         perms::Vector{Vector{Int}})
    remaining = Set(elements)
    orbits = Vector{Set{Int}}()
    while !isempty(remaining)
        el = first(remaining)
        orb = Set{Int}()
        for lut in perms
            push!(orb, lut[el+1])
        end
        push!(orbits, orb)
        setdiff!(remaining, orb)
    end
    orbits
end

function print_section(io::IO, title::String)
    println(io, "\n## ", title)
end

function print_check(io::IO, desc::String, pass::Bool = true)
    println(io, "  [", pass ? "PASS" : "FAIL", "] ", desc)
end

function print_kv(io::IO, key::String, val)
    println(io, "  ", key, ": ", val)
end
