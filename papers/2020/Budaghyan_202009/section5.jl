# Implements Section V — Single Shift
# Paper: Budaghyan, Carlet, Helleseth, Kaleyski (2020),
#        "On the Distance Between APN Functions", IEEE Trans. Inf. Theory
# Section: V — Single Shift
#
# Pseudocode (the paper's seven-step procedure, valid for an *arbitrary* F):
#   Given F over F₂ⁿ and a shift v ≠ 0, find all U with G(x)=F(x)+v·1_U(x) APN.
#   1. Assign a Boolean variable s_x ∈ F₂ to every x ∈ F₂ⁿ (s_x = [x ∈ U]).
#   2. Find all (x,y,a), a≠0, x≠y, x≠a⊕y, with D_aF(x)⊕D_aF(y) = v;
#   3.   for each, emit  s_x + s_y + s_{a⊕x} + s_{a⊕y} = 0.
#   4. Find all (x,y,a), a≠0, x≠y, x≠a⊕y, with D_aF(x)⊕D_aF(y) = 0;
#   5.   for each, emit  s_x + s_y + s_{a⊕x} + s_{a⊕y} = 1.
#   6. Solve the F₂ system (kernel_f2 on the augmented matrix).
#   7. The solutions are exactly the sets U for which G is APN.
#   When F is APN, step 4 finds nothing (no D_aF(x)=D_aF(y) with x+y≠a), so the
#   system is homogeneous — that is the *only* case in which U=∅ is a solution.
# VBF API used: SBox, kernel_f2, differential_uniformity, gold_apn

include(joinpath(@__DIR__, "helpers.jl"))

"""
    build_single_shift_system(F, v) -> (rows::Vector{UInt64}, rhs::Vector{Bool})

Steps 1–5 for an arbitrary `F` (APN or not). Each constraint is a row-bitmask
over the `2^N` variables `s_x`, together with its right-hand side:

  * `rhs = false` (step 3) when `D_aF(x) ⊕ D_aF(y) = v`;
  * `rhs = true`  (step 5) when `D_aF(x) ⊕ D_aF(y) = 0`.

Duplicate `(row, rhs)` pairs are collapsed. A row occurring with *both* right-hand
sides makes the system inconsistent, which [`single_shift_solutions`](@ref)
detects (no APN `G` exists for that `v`).

`N ≤ 6` is required (a row must fit a `UInt64`) and `v ≠ 0` (the paper takes
`v ∈ F₂ⁿ*`; at `v = 0` steps 3 and 5 would contradict each other).
"""
function build_single_shift_system(F::SBox{N,T}, v::Integer) where {N,T}
    N ≤ 6 || error("build_single_shift_system: N must be ≤ 6 (got $N)")
    Int(v) != 0 || throw(ArgumentError("build_single_shift_system: v must be nonzero"))
    n = 1 << N
    lut = F.lut
    v = Int(v)
    seen = Set{Tuple{UInt64,Bool}}()

    for a = 1:(n-1)
        for x = 0:(n-1)
            dFx = Int(lut[x+1]) ⊻ Int(lut[(x ⊻ a)+1])
            for y = 0:(n-1)
                y == x && continue
                x == (y ⊻ a) && continue  # x = y+a excluded
                dFy = Int(lut[y+1]) ⊻ Int(lut[(y ⊻ a)+1])
                d = dFx ⊻ dFy
                (d == v || d == 0) || continue
                row = UInt64(1) << x | UInt64(1) << y |
                      UInt64(1) << (x ⊻ a) | UInt64(1) << (y ⊻ a)
                # D_aF(x)+D_aF(y) = v ⇒ N_{a,x,y} = 0;  = 0 ⇒ N_{a,x,y} = 1
                push!(seen, (row, d == 0))
            end
        end
    end

    rows = UInt64[]
    rhs = Bool[]
    for (row, b) in seen
        push!(rows, row)
        push!(rhs, b)
    end
    rows, rhs
end

"""
    build_single_shift_constraints(F, v) -> Vector{UInt64}

The homogeneous half of the system (steps 1–3 only), for an **APN** `F`. Errors
if `F` is not APN: a non-APN `F` produces non-empty step 4–5 rows, and silently
dropping them yields a wrong system — one that always admits `U = ∅`, i.e. that
claims the non-APN `F` is APN. Use [`build_single_shift_system`](@ref) for an
arbitrary `F`.
"""
function build_single_shift_constraints(F::SBox{N,T}, v::Integer) where {N,T}
    du = differential_uniformity(F)
    du == 2 || error(
        "build_single_shift_constraints: F must be APN (differential_uniformity = $du); " *
        "use build_single_shift_system for arbitrary F (Section V, steps 4-5)",
    )
    rows, rhs = build_single_shift_system(F, v)
    @assert !any(rhs) "APN F must yield a homogeneous system"
    rows
end

"""
    single_shift_solutions(F, v; limit) -> NamedTuple

Steps 6–7: every set `U ⊆ F₂ⁿ` for which `G(x) = F(x) ⊕ v·1_U(x)` is APN, as
`UInt64` bitmasks (bit `x` set iff `x ∈ U`). Works for arbitrary `F`.

The affine system `rows · s = rhs` is solved by appending `rhs` as one extra
column and taking `kernel_f2` of the augmented matrix: a kernel vector whose
extra coordinate is 1 is exactly a particular solution, and one exists iff the
system is consistent. The full solution set is that particular solution plus the
homogeneous kernel.

Returns `(; kernel_dim, n_solutions, solutions, exhaustive, consistent)`;
`consistent = false` means **no** `U` works for this `v`.
"""
function single_shift_solutions(F::SBox{N,T}, v::Integer; limit::Int = 1 << 20) where {N,T}
    nb = 1 << N                       # number of variables s_x
    rows, rhs = build_single_shift_system(F, v)

    # Particular solution via the augmented column (bit index `nb`).
    tbit = UInt128(1) << nb
    aug = UInt128[UInt128(rows[i]) | (rhs[i] ? tbit : UInt128(0)) for i in eachindex(rows)]
    kaug = kernel_f2(aug; nbits = nb + 1)
    idx = findfirst(k -> (k & tbit) != zero(UInt128), kaug)
    if idx === nothing
        # No kernel vector sets the augmented coordinate ⇒ rows·s = rhs is unsolvable.
        return (; kernel_dim = 0, n_solutions = 0, solutions = UInt64[],
            exhaustive = true, consistent = false)
    end
    x0 = UInt64(kaug[idx] & (tbit - UInt128(1)))

    # Homogeneous kernel: the direction space of the solution coset.
    basis = kernel_f2(rows; nbits = nb)
    dim = length(basis)

    solutions = UInt64[]
    n_enum = min(1 << dim, limit)
    for mask = 0:(n_enum-1)
        sol = x0
        for (k, bv) in enumerate(basis)
            (mask >> (k - 1)) & 1 == 1 && (sol ⊻= bv)
        end
        push!(solutions, sol)
    end

    (; kernel_dim = dim, n_solutions = length(solutions), solutions,
        exhaustive = (1 << dim ≤ limit), consistent = true)
end

"""
    min_single_shift_distance(F; verify) -> NamedTuple

The "minimum single-shift distance" column of Tables II and III: the smallest
`|U| > 0` over **all** shifts `v ∈ F₂ⁿ*` and **all** solutions of the Section V
system — the Hamming distance from `F` to the closest APN function obtainable by
shifting some set of points by one common value.

The search is exhaustive in both `v` and the solution set (the kernel is fully
enumerated, `2^dim` vectors per `v`). With `verify = true` the minimiser is
re-checked with `differential_uniformity`.
"""
function min_single_shift_distance(F::SBox{N,T}; verify::Bool = true) where {N,T}
    sz = 1 << N
    best = typemax(Int)
    best_v = 0
    best_U = UInt64(0)
    n_shifts = 0          # number of v admitting a non-trivial U
    for v = 1:(sz-1)
        res = single_shift_solutions(F, v)
        res.consistent || continue
        @assert res.exhaustive "kernel enumeration truncated: raise `limit`"
        found = false
        for sol in res.solutions
            sol == 0 && continue      # U = ∅ ⇒ G = F
            found = true
            w = count_ones(sol)
            if w < best
                best, best_v, best_U = w, v, sol
            end
        end
        found && (n_shifts += 1)
    end
    best == typemax(Int) &&
        return (; distance = -1, v = 0, U = Int[], n_shifts, apn = false)

    U = [x for x = 0:(sz-1) if (best_U >> x) & 1 == 1]
    apn = true
    if verify
        G = apply_modifications(F, U, fill(best_v, length(U)))
        apn = differential_uniformity(G) == 2 && hamming_distance(F, G) == best
    end
    (; distance = best, v = best_v, U, n_shifts, apn)
end

"""
    section5_report(; io, n, v) -> NamedTuple

Demonstrate Section V on Gold x^3: the system for one shift `v`, then the
exhaustive minimum-weight search over every `v` and every solution.
"""
function section5_report(; io::IO = stdout, n::Int = 5, v::Int = 1)
    print_section("Section V — Single shift: linear system over F₂ (n=$n, v=$v)", io)
    F = gold_apn(n, 1)
    sz = 1 << n

    print_kv("F", "Gold x^3 over F₂^$n", io)
    print_kv("shift v", v, io)

    rows, rhs = build_single_shift_system(F, v)
    print_kv(
        "constraint rows",
        "$(length(rows)) (steps 2-3: $(count(!, rhs)), steps 4-5: $(count(rhs)))",
        io,
    )

    res = single_shift_solutions(F, v)
    print_kv("kernel dimension", res.kernel_dim, io)
    print_kv("solutions enumerated", res.n_solutions, io)
    print_kv("exhaustive", res.exhaustive, io)

    # Verify every solution (not a sample): each non-trivial U must give an APN G.
    n_verified = 0
    n_apn = 0
    for sol in res.solutions
        sol == 0 && continue          # U = ∅ ⇒ G = F, trivially APN
        n_verified += 1
        U = [x for x = 0:(sz-1) if (sol >> x) & 1 == 1]
        G = apply_modifications(F, U, fill(v, length(U)))
        differential_uniformity(G) == 2 && (n_apn += 1)
    end
    sols_ok = n_verified > 0 && n_apn == n_verified
    print_check("all $n_verified non-trivial solutions give an APN G", sols_ok, io)
    print_check("at least one non-trivial U exists (kernel_dim ≥ 1)", res.kernel_dim ≥ 1, io)

    # Minimum |U| — exhaustive over every v ∈ F₂ⁿ* and the full kernel of each.
    mss = min_single_shift_distance(F)
    print_section("Section V — minimum single-shift distance (exhaustive in v and kernel)", io)
    print_kv("min |U| over all v and all solutions", mss.distance, io)
    print_kv("attained at", "v=$(mss.v), U=$(mss.U)", io)
    print_kv("shifts v admitting a non-trivial U", "$(mss.n_shifts) / $(sz - 1)", io)
    print_check("minimiser re-verified APN by differential_uniformity", mss.apn, io)

    all_ok = res.kernel_dim ≥ 1 && sols_ok && mss.apn
    (; all_ok, kernel_dim = res.kernel_dim, n_solutions = res.n_solutions, n,
        min_single_shift = mss.distance)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    section5_report()
end
