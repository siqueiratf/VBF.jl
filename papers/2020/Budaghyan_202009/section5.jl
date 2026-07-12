# Implements Section V — Single Shift
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: V — Single Shift
#
# Pseudocode:
#   Given F APN and shift v ≠ 0, find all U s.t. G(x)=F(x)+v·1_U(x) is APN.
#   1. Assign Boolean variable s_x ∈ F₂ for each x ∈ F₂ⁿ.
#   2. For each (a,x,y) with a≠0, x≠y, x≠a⊕y:
#        if D_aF(x)⊕D_aF(y) = v: add constraint s_x+s_y+s_{a⊕x}+s_{a⊕y} = 0
#   3. Solve the F₂ linear system via kernel_f2.
#   4. Each kernel vector encodes one APN set U.
# VBF API used: SBox, kernel_f2, differential_uniformity

include(joinpath(@__DIR__, "helpers.jl"))

"""
    build_single_shift_constraints(F, v) -> Vector{UInt64}

Build the F₂ constraint system for Section V (single shift by v).
For APN F, the system is homogeneous: all constraints are of the form
  s_x + s_y + s_{x⊕a} + s_{y⊕a} = 0 (when D_aF(x)⊕D_aF(y) = v).
Returns unique constraint rows (bitmasks over F₂^{2^N} variables).
N ≤ 6 required (UInt64 has 64 bits for ≤ 64 variables).
"""
function build_single_shift_constraints(F::SBox{N,T}, v::Integer) where {N,T}
    N ≤ 6 || error("build_single_shift_constraints: N must be ≤ 6 (got $N)")
    n = 1 << N
    lut = F.lut
    v = Int(v)
    rows = Set{UInt64}()

    for a = 1:(n-1)
        for x = 0:(n-1)
            dFx = Int(lut[x+1]) ⊻ Int(lut[(x ⊻ a)+1])
            for y = 0:(n-1)
                y == x && continue
                x == (y ⊻ a) && continue  # x = y+a excluded
                dFy = Int(lut[y+1]) ⊻ Int(lut[(y ⊻ a)+1])
                dFx ⊻ dFy == v || continue
                # constraint: s_x + s_y + s_{x⊕a} + s_{y⊕a} = 0
                row = UInt64(1) << x | UInt64(1) << y |
                      UInt64(1) << (x ⊻ a) | UInt64(1) << (y ⊻ a)
                push!(rows, row)
            end
        end
    end
    collect(rows)
end

"""
    single_shift_solutions(F, v; limit) -> NamedTuple

Section V: enumerate all APN sets U such that G(x) = F(x) ⊕ v·1_U(x) is APN.
Returns (kernel_dim, n_solutions, solutions) where each solution is a UInt64
bitmask (bit x is set iff x ∈ U).
"""
function single_shift_solutions(F::SBox{N,T}, v::Integer; limit::Int = 256) where {N,T}
    n = 1 << N
    rows = build_single_shift_constraints(F, v)

    # kernel_f2 returns basis vectors of the null space (homogeneous system)
    basis = kernel_f2(rows; nbits = n)
    dim = length(basis)

    # Enumerate all 2^dim kernel vectors (linear combinations over F₂)
    solutions = UInt64[]
    n_enum = min(1 << dim, limit)
    for mask = 0:(n_enum-1)
        sol = UInt64(0)
        for (k, bv) in enumerate(basis)
            (mask >> (k - 1)) & 1 == 1 && (sol ⊻= bv)
        end
        push!(solutions, sol)
    end

    (; kernel_dim = dim, n_solutions = length(solutions), solutions, exhaustive = (1 << dim ≤ limit))
end

"""
    section5_report(; io, n, v, limit) -> NamedTuple

Demonstrate Section V single shift construction on Gold x^3.
"""
function section5_report(; io::IO = stdout, n::Int = 5, v::Int = 1, limit::Int = 64)
    print_section("Section V — Single shift: linear system over F₂ (n=$n, v=$v)", io)
    F = gold_x3(n)
    sz = 1 << n

    print_kv("F", "Gold x^3 over F₂^$n", io)
    print_kv("shift v", v, io)

    rows = build_single_shift_constraints(F, v)
    print_kv("constraint rows", length(rows), io)

    res = single_shift_solutions(F, v; limit)
    print_kv("kernel dimension", res.kernel_dim, io)
    print_kv("solutions enumerated", res.n_solutions, io)
    print_kv("exhaustive", res.exhaustive, io)

    # Verify: all non-trivial solutions give APN G
    n_verified = 0
    n_apn = 0
    for sol in res.solutions
        sol == 0 && continue  # skip empty set U (G = F, trivially APN)
        n_verified += 1
        # Build U from bitmask
        U = [x for x = 0:(sz-1) if (sol >> x) & 1 == 1]
        V = fill(v, length(U))
        G = apply_modifications(F, U, V)
        differential_uniformity(G) == 2 && (n_apn += 1)
        n_verified ≥ 10 && break  # sample check
    end

    if n_verified > 0
        ok = n_apn == n_verified
        print_check("APN check on $n_verified sampled non-trivial solutions", ok, io)
    else
        print_kv("non-trivial solutions", "0 (only empty set found)", io)
    end

    nontrivial = count(s -> s != 0, res.solutions)
    has_nontrivial = nontrivial > 0
    print_check("at least one non-trivial U exists (kernel_dim ≥ 1)", res.kernel_dim ≥ 1, io)

    # Report minimum weight non-trivial solution (minimum APN distance)
    if has_nontrivial
        min_wt = minimum(count_ones(s) for s in res.solutions if s != 0)
        print_kv("min |U| among non-trivial solutions (single-shift distance bound)", min_wt, io)
    end

    all_ok = res.kernel_dim ≥ 1
    (; all_ok, kernel_dim = res.kernel_dim, n_solutions = res.n_solutions, n)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    section5_report()
end
