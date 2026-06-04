using TOML
using Nemo

@doc"""
    even_hamming_weight_differences(space_size::Int) -> Vector{Int}

Return the nonzero differences whose binary representation has even Hamming
weight. The linearly self-equivalent APN search uses this restricted set when
it updates the partial difference distribution table.
"""
function even_hamming_weight_differences(space_size::Int)::Vector{Int}
    return [alpha for alpha in 1:(space_size - 1) if iseven(count_ones(alpha))]
end

function updateDDTInformationUnchecked(c::Int, sbox::Vector{Int}, ddt::Matrix{Int}, delta::Int)::Bool
    delta in (-2, 2) || error("Unsupported DDT delta: $delta")

    c_value = sbox[c + 1]
    c_value != -1 || error("sbox[$c] must be assigned before updating the DDT")
    field_size = length(sbox)

    @inbounds for alpha in even_hamming_weight_differences(field_size)
        paired_x = xor(c, alpha)
        paired_value = sbox[paired_x + 1]
        paired_value == -1 && continue

        out_diff = xor(c_value, paired_value)
        ddt_value = ddt[alpha + 1, out_diff + 1] + delta
        ddt[alpha + 1, out_diff + 1] = ddt_value
        delta == 2 && ddt_value > 2 && return false
        delta == -2 && ddt_value == 2 && break
    end

    return true
end

@doc"""
    addDDTInformation(c::Int, sbox::Vector{Int}, ddt::Matrix{Int}) -> Bool

Add the contribution of the already assigned input `c` to a partial DDT.
Unassigned S-box entries must be represented by `-1`. The function returns
`false` as soon as an APN violation is detected, i.e. a DDT entry exceeds `2`.
"""
function addDDTInformation(c::Int, sbox::Vector{Int}, ddt::Matrix{Int})::Bool
    @assert length(sbox) == size(ddt, 1) == size(ddt, 2)
    return addDDTInformationUnchecked(c, sbox, ddt)
end

function addDDTInformationUnchecked(c::Int, sbox::Vector{Int}, ddt::Matrix{Int})::Bool
    return updateDDTInformationUnchecked(c, sbox, ddt, 2)
end

@doc"""
    removeDDTInformation(c::Int, sbox::Vector{Int}, ddt::Matrix{Int}) -> Bool

Remove the contribution of the assigned input `c` from a partial DDT. This is
the inverse operation of [`addDDTInformation`](@ref) and is intended for
backtracking searches over partially assigned S-boxes.
"""
function removeDDTInformation(c::Int, sbox::Vector{Int}, ddt::Matrix{Int})::Bool
    @assert length(sbox) == size(ddt, 1) == size(ddt, 2)
    return removeDDTInformationUnchecked(c, sbox, ddt)
end

function removeDDTInformationUnchecked(c::Int, sbox::Vector{Int}, ddt::Matrix{Int})::Bool
    return updateDDTInformationUnchecked(c, sbox, ddt, -2)
end

@doc"""
    isComplete(sbox::Vector{Int}) -> Bool

Return whether every entry of a partial S-box has been assigned. Unassigned
entries are represented by `-1`.
"""
function isComplete(sbox::Vector{Int})::Bool
    @inbounds for value in sbox
        value == -1 && return false
    end

    return true
end

@doc"""
    nextFreePosition(sbox::Vector{Int}) -> Int
    nextFreePosition(sbox::Vector{Int}, visit_order::Vector{Int}) -> Int

Return the next unassigned input of a partial S-box, or `-1` when the S-box is
complete. The two-argument form respects a caller-provided zero-based visit
order.
"""
function nextFreePosition(sbox::Vector{Int})::Int
    @inbounds for index in eachindex(sbox)
        sbox[index] == -1 && return index - 1
    end

    return -1
end

function nextFreePosition(sbox::Vector{Int}, visit_order::Vector{Int})::Int
    @inbounds for value in visit_order
        sbox[value + 1] == -1 && return value
    end

    return -1
end

@doc"""
    standard_visit_order(n::Int) -> Vector{Int}

Return the natural zero-based visit order `0:(2^n - 1)` for S-box searches.
"""
function standard_visit_order(n::Int)::Vector{Int}
    return collect(0:(1 << n - 1))
end

@doc"""
    offset_visit_order(n::Int, offset::Int) -> Vector{Int}

Return a cyclic shift of the natural zero-based visit order in `GF(2)^n`.
"""
function offset_visit_order(n::Int, offset::Int)::Vector{Int}
    field_size = 1 << n
    return [mod(index + offset, field_size) for index in 0:(field_size - 1)]
end

@doc"""
    c_reference_visit_order(n::Int, class_index::Union{Nothing, Int}=nothing) -> Vector{Int}

Return the visit order used to reproduce the C reference search. Most classes
use the natural order; the known exceptional `n = 7` classes use fixed offsets.
"""
function c_reference_visit_order(n::Int, class_index::Union{Nothing, Int} = nothing)::Vector{Int}
    if n == 7 && class_index == 24
        return offset_visit_order(n, 16)
    elseif n == 7 && class_index == 26
        return offset_visit_order(n, 8)
    end

    return standard_visit_order(n)
end

@doc"""
    int_matrix_to_lut(M::AbstractMatrix, n::Int) -> Vector{Int}

Convert an `n x n` integer matrix, interpreted modulo two, into the lookup
table of the corresponding linear map on `GF(2)^n`.
"""
function int_matrix_to_lut(M::AbstractMatrix, n::Int)::Vector{Int}
    @assert size(M) == (n, n) "Matrix must be $n×$n"
    field_size = 1 << n
    table = Vector{Int}(undef, field_size)

    @inbounds for x in 0:(field_size - 1)
        output = 0

        for row in 1:n
            output_bit = false

            for col in 1:n
                if isodd((x >> (col - 1)) & 1) && isodd(Int(M[row, col]))
                    output_bit = !output_bit
                end
            end

            if output_bit
                output |= 1 << (row - 1)
            end
        end

        table[x + 1] = output
    end

    return table
end

@doc"""
    linear_map_lut(M, n::Int) -> Vector{Int}

Convert a binary `n x n` integer matrix into the lookup table of its linear
map on zero-based vector encodings. Matrix entries are reduced modulo two.
"""
function linear_map_lut(M::AbstractMatrix, n::Int)::Vector{Int}
    return int_matrix_to_lut(M, n)
end

@doc"""
    orbit_orders(apply_map::Vector{Int}) -> Vector{Int}

Return a vector whose entry `x + 1` is the length of the orbit of `x` under the
zero-based map table `apply_map`.
"""
function orbit_orders(apply_map::Vector{Int})::Vector{Int}
    field_size = length(apply_map)
    orders = zeros(Int, field_size)

    @inbounds for x in 0:(field_size - 1)
        orders[x + 1] != 0 && continue

        orbit = Int[]
        current = x

        while orders[current + 1] == 0 && !(current in orbit)
            push!(orbit, current)
            current = apply_map[current + 1]
        end

        orbit_length = length(orbit)
        for value in orbit
            orders[value + 1] = orbit_length
        end
    end

    return orders
end

# ---------------------------------------------------------------------------
# TOML helpers — read and write AllTuplesMatrices{n}.toml
# ---------------------------------------------------------------------------

function _toml_int_vector(values::AbstractVector{<:Integer})::String
    "[" * join((string(Int(v)) for v in values), ", ") * "]"
end

function _write_toml_matrix(io::IO, name::String, M::AbstractMatrix{<:Integer})
    write(io, "$name = [\n")
    for row in 1:size(M, 1)
        suffix = row == size(M, 1) ? "" : ","
        write(io, "  $(_toml_int_vector(vec(M[row, :])))$suffix\n")
    end
    write(io, "]\n")
end

function _write_tuple_matrix_constants(io::IO, n::Int, blocks)
    write(io, "# This file stores precomputed tuple matrix constants for n = $n.\n")
    write(io, "# Regenerate it with generate_tuple_matrix_constants_file($n).\n")
    write(io, "# Each block stores: tuple LUT, matrix A, matrix B, and optional search result.\n\n")
    write(io, "n = $n\n")
    write(io, "n_blocks = $(length(blocks))\n\n")
    for (idx, block) in pairs(blocks)
        write(io, "[[blocks]]\n")
        write(io, "index = $idx\n")
        write(io, "tuple = $(_toml_int_vector(block.tuple))\n")
        _write_toml_matrix(io, "A", block.A)
        _write_toml_matrix(io, "B", block.B)
        block.search !== nothing && write(io, "search = $(_toml_int_vector(block.search))\n")
        write(io, "\n")
    end
end

function _toml_to_int_matrix(rows)::Matrix{Int}
    isempty(rows) && return zeros(Int, 0, 0)
    nr = length(rows)
    nc = length(rows[1])
    M = zeros(Int, nr, nc)
    for r in 1:nr
        M[r, :] = Int.(rows[r])
    end
    M
end

function _load_tuple_matrix_blocks(filename::String)
    data = TOML.parsefile(filename)
    raw = sort(get(data, "blocks", Any[]), by = b -> Int(b["index"]))
    return [
        (
            tuple  = Int.(b["tuple"]),
            A      = _toml_to_int_matrix(b["A"]),
            B      = _toml_to_int_matrix(b["B"]),
            search = haskey(b, "search") ? Int.(b["search"]) : nothing,
        )
        for b in raw
    ]
end

# ---------------------------------------------------------------------------
# Public tuple-management API (mirrors APNLib's file_utils interface)
# ---------------------------------------------------------------------------

function precomputed_tuple_matrices(n::Int, index::Int;
                                    tuples_dir::String = joinpath(@__DIR__, "tuples"))
    filename = joinpath(tuples_dir, "AllTuplesMatrices$n.toml")
    blocks = _load_tuple_matrix_blocks(filename)
    1 <= index <= length(blocks) ||
        error("Tuple index must be between 1 and $(length(blocks)) for n = $n")
    block = blocks[index]
    block.A, block.B
end

function all_precomputed_tuple_class_indices(n::Int;
                                              tuples_dir::String = joinpath(@__DIR__, "tuples"))::Vector{Int}
    filename = joinpath(tuples_dir, "AllTuplesMatrices$n.toml")
    blocks = _load_tuple_matrix_blocks(filename)
    collect(1:length(blocks))
end

function normalize_precomputed_tuple_classes(n::Int, class_indices;
                                              excluded_class_indices = Int[],
                                              tuples_dir::String = joinpath(@__DIR__, "tuples"))::Vector{Int}
    all_indices = all_precomputed_tuple_class_indices(n; tuples_dir)
    available  = Set(all_indices)
    excluded   = Set(Int.(excluded_class_indices))

    # Parse the spec
    parsed = if class_indices isa AbstractString
        s = strip(class_indices)
        if s == "all" || s == ":all"
            "all"
        else
            s = strip(s, ['[', ']'])
            isempty(s) ? Int[] :
            occursin(",", s) ?
                [parse(Int, strip(t)) for t in split(s, ",") if !isempty(strip(t))] :
                parse(Int, s)
        end
    else
        class_indices
    end

    selected = if parsed == "all" || parsed == :all
        all_indices
    elseif parsed isa Integer
        [Int(parsed)]
    elseif parsed isa AbstractVector
        Int.(parsed)
    else
        error("class_indices must be \"all\", :all, an integer, or a vector of integers")
    end

    for idx in selected
        idx in available ||
            error("Tuple index must be between 1 and $(length(available)) for n = $n")
    end

    sort!(unique([idx for idx in selected if !(idx in excluded)]))
end

function save_search_result_constant(sbox::AbstractVector{<:Integer}, n::Int, class_index::Int;
                                      tuples_dir::String = joinpath(@__DIR__, "tuples"))
    length(sbox) == 1 << n ||
        error("Search result for n = $n must have 2^$n entries, got $(length(sbox))")
    1 <= class_index || error("class_index must be positive")

    filename = joinpath(tuples_dir, "AllTuplesMatrices$n.toml")
    isfile(filename) || error("Precomputed matrix constants file not found: $filename")

    blocks = _load_tuple_matrix_blocks(filename)
    1 <= class_index <= length(blocks) ||
        error("Tuple index must be between 1 and $(length(blocks)) for n = $n")

    updated = [
        i == class_index ?
            (tuple = b.tuple, A = b.A, B = b.B, search = Int.(sbox)) :
            b
        for (i, b) in pairs(blocks)
    ]

    open(filename, "w") do io
        _write_tuple_matrix_constants(io, n, updated)
    end

    return filename
end

# ---------------------------------------------------------------------------
# APN check (does not require a compile-time N)
# ---------------------------------------------------------------------------

function _is_apn(lut::Vector{Int})::Bool
    field_size = length(lut)
    for a in 1:(field_size - 1)
        seen = Set{Int}()
        for x in 0:(field_size - 1)
            push!(seen, lut[xor(x, a) + 1] ⊻ lut[x + 1])
        end
        length(seen) == field_size >> 1 || return false
    end
    return true
end

# ---------------------------------------------------------------------------
# GF(2) matrix helpers (inlined from APNLib)
# ---------------------------------------------------------------------------

function _each_column_vector(F, n::Int)
    (matrix(F, n, 1, digits(v, base = 2, pad = n)) for v in 0:(1 << n - 1))
end

function _column_vector_to_int(v::FqMatrix)::Int
    n = nrows(v)
    value = 0
    for i in 1:n
        iszero(v[i, 1]) || (value += 1 << (i - 1))
    end
    value
end

function _matrix_to_sbox(A::FqMatrix)::Vector{Int}
    @assert size(A, 1) == size(A, 2) "Matrix must be square"
    F = base_ring(A)
    n = nrows(A)
    [_column_vector_to_int(A * v) for v in _each_column_vector(F, n)]
end

function _matrix_multiplicative_order(A::FqMatrix)::Int
    @assert size(A, 1) == size(A, 2) "Matrix must be square"
    F = base_ring(A)
    n = nrows(A)
    I = identity_matrix(F, n)
    power = I
    for k in 1:10_000_000
        power = power * A
        power == I && return k
    end
    error("Could not determine multiplicative order within 10_000_000 iterations")
end

function _polynomial_equal(a, b)
    R = parent(b)
    function to_R(p)
        coeffs = [coeff(p, i) for i in 0:degree(p)]
        R(coeffs)
    end
    to_R(a) == to_R(b)
end

function _polynomial_divides(a, b)
    R = parent(b)
    function to_R(p)
        coeffs = [coeff(p, i) for i in 0:degree(p)]
        R(coeffs)
    end
    _, r = divrem(to_R(b), to_R(a))
    iszero(r)
end

function _matrix_is_similar(A::FqMatrix, B::FqMatrix)::Bool
    @assert size(A) == size(B) "Matrices must have the same dimensions"
    ord_A = _matrix_multiplicative_order(A)
    ord_B = _matrix_multiplicative_order(B)
    ord_A == ord_B || return false
    F = base_ring(A)
    n = nrows(A)
    I = identity_matrix(F, n)
    ord_A == 1 && return true
    if ord_A == 2
        return rank(A - I) == rank(B - I)
    end
    _polynomial_equal(charpoly(A), charpoly(B))
end

# ---------------------------------------------------------------------------
# Rational canonical form enumeration (inlined from APNLib)
# ---------------------------------------------------------------------------

function _integer_partitions(n::Int)::Vector{Vector{Int}}
    result = Vector{Vector{Int}}()
    function backtrack(remaining::Int, max_part::Int, current::Vector{Int})
        if remaining == 0
            push!(result, copy(current))
            return
        end
        for part in min(remaining, max_part):-1:1
            push!(current, part)
            backtrack(remaining - part, part, current)
            pop!(current)
        end
    end
    backtrack(n, n, Int[])
    result
end

function _monic_invertible_poly_coeffs(F, d::Int)
    coeffs_list = Vector{Vector{typeof(one(F))}}()
    for value in 0:(1 << (d + 1) - 1)
        bits = digits(value, base = 2, pad = d + 1)
        bits[1] == 1 && bits[d + 1] == 1 && push!(coeffs_list, [F(b) for b in bits])
    end
    coeffs_list
end

function _companion_matrix_gf2(F, coeffs)
    d = length(coeffs) - 1
    d >= 1 || error("Degree must be at least 1")
    coeffs[1] == one(F) || error("Constant coefficient must be 1")
    coeffs[d + 1] == one(F) || error("Leading coefficient must be 1")
    M = zero_matrix(F, d, d)
    for i in 2:d
        M[i, i - 1] = one(F)
    end
    for i in 1:d
        M[i, d] = coeffs[i]
    end
    M
end

function _blocks_for_rcf(d::Int)
    F = GF(2)
    [_companion_matrix_gf2(F, coeffs) for coeffs in _monic_invertible_poly_coeffs(F, d)]
end

function _valid_rcf_block_sequence(blocks)
    isempty(blocks) && return false
    prev_poly = minpoly(blocks[1])
    for block in blocks
        cur_poly = minpoly(block)
        _polynomial_divides(cur_poly, prev_poly) || return false
        prev_poly = cur_poly
    end
    true
end

function get_rcfs(n::Int)::Vector{FqMatrix}
    n >= 1 || error("n must be positive")
    matrices = FqMatrix[]
    for partition in _integer_partitions(n)
        block_options = [_blocks_for_rcf(part) for part in partition]
        for blocks in Base.Iterators.product(block_options...)
            if _valid_rcf_block_sequence(blocks)
                reversed = FqMatrix[b for b in reverse(blocks)]
                push!(matrices, block_diagonal_matrix(reversed))
            end
        end
    end
    matrices
end

# ---------------------------------------------------------------------------
# BitMatrix helpers (pure Julia, no Nemo)
# ---------------------------------------------------------------------------

function rank_gf2(matrix::FqMatrix)::Int
    return rank(matrix)
end

function nullity_gf2(matrix::FqMatrix)::Int
    return ncols(matrix) - rank_gf2(matrix)
end

function fixed_space_dimension_gf2(M_power::FqMatrix)::Int
    field = base_ring(M_power)
    dimension = nrows(M_power)
    identity = identity_matrix(field, dimension)
    return nullity_gf2(M_power + identity)
end

function _gf2_matrix(A::AbstractMatrix, n::Int)::FqMatrix
    @assert size(A) == (n, n) "Matrix must be $n×$n"
    F = GF(2)
    M = zero_matrix(F, n, n)
    for col in 1:n, row in 1:n
        M[row, col] = F(mod(Int(A[row, col]), 2))
    end
    M
end

function gf2_bitmatrix(A::FqMatrix, n::Int; name::String = "Matrix")::BitMatrix
    @assert size(A) == (n, n) "$name must be $n×$n"
    M = falses(n, n)
    for col in 1:n, row in 1:n
        M[row, col] = !iszero(A[row, col])
    end
    M
end

function gf2_bitmatrix(A::AbstractMatrix, n::Int; name::String = "Matrix")::BitMatrix
    @assert size(A) == (n, n) "$name must be $n×$n"
    M = falses(n, n)
    for col in 1:n, row in 1:n
        M[row, col] = isodd(Int(A[row, col]))
    end
    M
end

function identity_bitmatrix(n::Int)::BitMatrix
    I = falses(n, n)
    for i in 1:n
        I[i, i] = true
    end
    I
end

function gf2_bitmul(A::BitMatrix, B::BitMatrix)::BitMatrix
    @assert size(A, 2) == size(B, 1) "Incompatible dimensions"
    d = size(A, 1)
    C = falses(d, d)
    @inbounds for col in 1:d, row in 1:d
        v = false
        for mid in 1:d
            v = xor(v, A[row, mid] & B[mid, col])
        end
        C[row, col] = v
    end
    C
end

function bitmatrix_multiplicative_order(A::BitMatrix)::Int
    @assert size(A, 1) == size(A, 2) "Matrix must be square"
    d = size(A, 1)
    I = identity_bitmatrix(d)
    power = copy(I)
    for order in 1:10_000_000
        power = gf2_bitmul(power, A)
        power == I && return order
    end
    error("Could not determine multiplicative order within 10_000_000 iterations")
end

function precompute_gf2_bit_powers(A::BitMatrix, k::Int)::Vector{BitMatrix}
    powers = Vector{BitMatrix}(undef, max(k - 1, 0))
    isempty(powers) && return powers
    powers[1] = copy(A)
    for i in 2:(k - 1)
        powers[i] = gf2_bitmul(powers[i - 1], A)
    end
    powers
end

function xor3_equals_identity(A::BitMatrix, B::BitMatrix, C::BitMatrix)::Bool
    @assert size(A) == size(B) == size(C) "Matrices must have the same dimensions"
    d = size(A, 1)
    @inbounds for col in 1:d, row in 1:d
        expected = row == col
        xor(xor(A[row, col], B[row, col]), C[row, col]) == expected || return false
    end
    true
end

function has_matching_identity_xor_triple(A_powers::Vector{BitMatrix},
                                          B_powers::Vector{BitMatrix},
                                          first_power::Int,
                                          second_power::Int,
                                          third_power::Int)::Bool
    return xor3_equals_identity(
        A_powers[first_power],
        A_powers[second_power],
        A_powers[third_power],
    ) && xor3_equals_identity(
        B_powers[first_power],
        B_powers[second_power],
        B_powers[third_power],
    )
end
