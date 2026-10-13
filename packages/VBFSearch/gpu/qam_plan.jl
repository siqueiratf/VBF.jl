# qam_plan.jl — emit binary "level plans" consumed by qam_dfs.cpp.
#
# Two model families, one DFS:
#   * diagonal  : the Yu-Li-Ichanska-Kaleyski (2025) F2-coefficient QAM model.
#     Free variables are diagonal offsets d=1..floor(n/2); each fills a whole
#     diagonal by squaring (v, v^2, v^4, ...). The prune is the leading-principal
#     "is_proper_sub(H, d+1, n)" of packages/VBFRepro/src/202512-yu-dimension-ten/algorithm2.jl, which fires
#     at every level (each level completes one leading principal block). Used to
#     VALIDATE qam_dfs exhaustively at n=5,6,7 against generate_apn_f2.
#   * h8        : the Yu & Perrin (2022) Conjecture-2 model. The upper-left 6x6
#     block is the fixed QAM of x^3; the 13 free entries x_1..x_13 fill columns
#     7 and 8 one at a time (order x_13, x_12, ..., x_1). Leading principal
#     blocks complete only twice here, so the prune is the forward-checking
#     reachability bound (prune_mode=1 in qam_dfs.cpp), which fires every level.
#
# Plan binary (little-endian):
#   u32 magic=0x51414d44, u32 n, u32 modulus, u32 n_levels, u32 record,
#   u32 prune_mode, u32 base[n*n] (row-major), u32 known[n*n] (row-major 0/1),
#   then per level: u32 fill_type(0=entry,1=diag), u32 p0, u32 p1, u32 check_size,
#   u32 dom_len, u32 domain[dom_len].  Positions are 0-based.

# NOTE: this is the one codebase-COUPLED file in the toolkit — the reference
# plan generator. It needs VBF and the paper reductions (Yu_202211d's Prop-3
# EA-coset partitioning, Yu_202512's is_proper_sub). Everything else in gpu/
# is agnostic and consumes the plan binary this emits. Any generator writing the
# format documented above works; this one just mirrors the papers exactly. Run
# it from anywhere — paths are resolved relative to the repo root below.

import TOML
using VBF

const THIS_DIR  = @__DIR__
const REPO_ROOT = normpath(joinpath(THIS_DIR, "..", "..", ".."))   # packages/VBFSearch/gpu/ -> repo root
const YU2211    = joinpath(REPO_ROOT, "packages", "VBFRepro", "src", "202211-yu-qam")
const YU2512    = joinpath(REPO_ROOT, "packages", "VBFRepro", "src", "202512-yu-dimension-ten")

# ── plan writer ──────────────────────────────────────────────────────────────
# red = (type, basis::Vector{(r,c)} 0-based, t::(r,c)); type 0 none / 1 coset-reps / 2 invol-half
struct PlanLevel
    fill_type::Int   # 0 entry, 1 diag
    p0::Int          # entry row / diag offset (0-based)
    p1::Int          # entry col (0-based) / unused
    check_size::Int
    domain::Vector{Int}
    red_type::Int
    red_basis::Vector{Tuple{Int,Int}}
    red_t::Tuple{Int,Int}
end
PlanLevel(ft, p0, p1, cs, dom) = PlanLevel(ft, p0, p1, cs, dom, 0, Tuple{Int,Int}[], (0, 0))

function write_plan(path::AbstractString; n::Int, modulus::Int, prune_mode::Int,
                    base::AbstractMatrix{<:Integer}, known::AbstractMatrix{Bool},
                    levels::Vector{PlanLevel})
    open(path, "w") do io
        write(io, UInt32(0x51414d44))
        write(io, UInt32(n)); write(io, UInt32(modulus))
        write(io, UInt32(length(levels))); write(io, UInt32(0))
        write(io, UInt32(prune_mode))
        for i in 1:n, j in 1:n; write(io, UInt32(base[i, j])); end        # row-major
        for i in 1:n, j in 1:n; write(io, UInt32(known[i, j] ? 1 : 0)); end
        for lv in levels
            write(io, UInt32(lv.fill_type)); write(io, UInt32(lv.p0))
            write(io, UInt32(lv.p1)); write(io, UInt32(lv.check_size))
            write(io, UInt32(lv.red_type)); write(io, UInt32(length(lv.red_basis)))
            for (r, c) in lv.red_basis; write(io, UInt32(r)); write(io, UInt32(c)); end
            write(io, UInt32(lv.red_t[1])); write(io, UInt32(lv.red_t[2]))
            write(io, UInt32(length(lv.domain)))
            for v in lv.domain; write(io, UInt32(v)); end
        end
    end
    path
end

# ── diagonal model (Yu_202512 Algorithm 2) ───────────────────────────────────
# Reuse the paper's exact domain construction so leaf counts are comparable.
function diagonal_plan(n::Int; path::AbstractString = joinpath(THIS_DIR, "plan_diag_n$n.bin"))
    isdefined(@__MODULE__, :fn_set) || include(joinpath(YU2512, "algorithm2.jl"))
    modulus = conway_polynomial(n)
    num_vars = n ÷ 2
    fn = Base.invokelatest(fn_set, n; modulus = modulus)
    dom(k) = k == 1 ? fn :
             2k == n ? Base.invokelatest(subfield_nonzero, k, n; modulus = modulus) :
             collect(1:(1 << n) - 1)
    base  = zeros(Int, n, n)
    known = falses(n, n)
    for i in 1:n; known[i, i] = true; end                # zero diagonal is fixed
    levels = PlanLevel[]
    for k in 1:num_vars
        cs = k < num_vars ? k + 1 : n                     # is_proper_sub(H, d+1, n); leaf=is_qam
        push!(levels, PlanLevel(1, k, 0, cs, dom(k)))
    end
    write_plan(path; n = n, modulus = modulus, prune_mode = 0,
               base = base, known = known, levels = levels)
    (path = path, num_vars = num_vars, domain_sizes = [length(dom(k)) for k in 1:num_vars])
end

# ── H_8 model (Yu & Perrin 2022 Conjecture 2) ────────────────────────────────
function h8_plan(; path::AbstractString = joinpath(THIS_DIR, "plan_h8.bin"),
                   use_prop3::Bool = true)
    isdefined(@__MODULE__, :h8_base) || include(joinpath(YU2211, "proposition3_partitions.jl"))
    n = 8
    modulus = 285                                          # Magma default g^8+g^4+g^3+g^2+1
    base = Matrix{Int}(Base.invokelatest(h8_base))
    known = falses(n, n)
    for i in 1:6, j in 1:6; known[i, j] = true; end        # fixed 6x6 block
    for i in 1:n; known[i, i] = true; end

    # position of x_i (1-based) -> 0-based (row,col)
    pos1 = H8_VAR_POSITION           # Vector of (r,c), defined by the include above
    pos0(i) = (pos1[i][1] - 1, pos1[i][2] - 1)

    # Proposition-3 EA reductions.  x_13, x_12 are STATIC coset sets (independent
    # of the path).  x_7, x_6 are DYNAMIC: their span depends on x_13 / x_12, so
    # they are emitted as reduction descriptors the DFS evaluates at run time.
    A = use_prop3 ? Base.invokelatest(prop3_candidates_x13) : collect(0:255)  # x_13, |A|=7
    B = use_prop3 ? Base.invokelatest(prop3_candidates_x12) : collect(0:255)  # x_12, |B|=112
    full = collect(0:255)
    # V = col-1 rows 2..6 (0-based) + x_13 pos ;  U = col-2 rows 1,3..6 + x_12 pos
    V0 = [(1, 0), (2, 0), (3, 0), (4, 0), (5, 0)]
    U0 = [(0, 1), (2, 1), (3, 1), (4, 1), (5, 1)]
    x13pos = pos0(13); x12pos = pos0(12); g34pos = (1, 0)   # g^34 = H[2,1] (1-based)

    order = 13:-1:1                                         # x_13 first (Algorithm 1)
    levels = PlanLevel[]
    for i in order
        r, c = pos0(i)
        if use_prop3 && i == 7                              # x_7 ∈ coset reps of Span(V, x_13)
            push!(levels, PlanLevel(0, r, c, 0, full, 1, vcat(V0, [x13pos]), (0, 0)))
        elseif use_prop3 && i == 6                          # x_6 ∈ half of F∖Span(U, x_12), t=g^34
            push!(levels, PlanLevel(0, r, c, 0, full, 2, vcat(U0, [x12pos]), g34pos))
        else
            dom = i == 13 ? A : i == 12 ? B : full
            push!(levels, PlanLevel(0, r, c, 0, dom))
        end
    end
    write_plan(path; n = n, modulus = modulus, prune_mode = 1,
               base = base, known = known, levels = levels)
    (path = path, nA = length(A), nB = length(B))
end

# Completeness-test plan: pin column 7 (x_13..x_8) to the x^3 seed, then search
# column 8 (x_7..x_1) either with the Prop-3 EA reduction (reduced=true) or over
# full F_2^8 (reduced=false). Reduced and unreduced must yield the SAME set of
# EA/CCZ classes — the empirical completeness certificate for the reduction.
function h8_col8_plan(; reduced::Bool, path::AbstractString)
    isdefined(@__MODULE__, :h8_base) || include(joinpath(YU2211, "proposition3_partitions.jl"))
    n = 8; modulus = 285
    base = Matrix{Int}(Base.invokelatest(h8_base))
    seed = Base.invokelatest(h8_base_vars)
    known = falses(n, n)
    for i in 1:6, j in 1:6; known[i, j] = true; end
    for i in 1:n; known[i, i] = true; end
    pos1 = H8_VAR_POSITION; pos0(i) = (pos1[i][1] - 1, pos1[i][2] - 1)
    V0 = [(1, 0), (2, 0), (3, 0), (4, 0), (5, 0)]
    U0 = [(0, 1), (2, 1), (3, 1), (4, 1), (5, 1)]
    x13pos = pos0(13); x12pos = pos0(12); g34pos = (1, 0)
    full = collect(0:255)
    levels = PlanLevel[]
    for i in 13:-1:1
        r, c = pos0(i)
        if i >= 8                                           # column 7: pin to seed
            push!(levels, PlanLevel(0, r, c, 0, [seed[i]]))
        elseif reduced && i == 7
            push!(levels, PlanLevel(0, r, c, 0, full, 1, vcat(V0, [x13pos]), (0, 0)))
        elseif reduced && i == 6
            push!(levels, PlanLevel(0, r, c, 0, full, 2, vcat(U0, [x12pos]), g34pos))
        else
            push!(levels, PlanLevel(0, r, c, 0, full))
        end
    end
    write_plan(path; n = n, modulus = modulus, prune_mode = 1,
               base = base, known = known, levels = levels)
    path
end

# Bounded H_8 plan for throughput measurement: full domains on the first
# `wide` free levels, the remaining levels pinned to their x^3 seed value so the
# subtree completes quickly while still exercising the forward-check at depth.
function h8_bench_plan(; path::AbstractString = joinpath(THIS_DIR, "plan_h8_bench.bin"),
                         wide::Int = 4, reduced::Bool = false)
    isdefined(@__MODULE__, :h8_base) || include(joinpath(YU2211, "proposition3_partitions.jl"))
    n = 8; modulus = 285
    base = Matrix{Int}(Base.invokelatest(h8_base))
    seed = Base.invokelatest(h8_base_vars)          # x^3 seed values x_1..x_13
    known = falses(n, n)
    for i in 1:6, j in 1:6; known[i, j] = true; end
    for i in 1:n; known[i, i] = true; end
    pos1 = H8_VAR_POSITION; pos0(i) = (pos1[i][1] - 1, pos1[i][2] - 1)
    A = Base.invokelatest(prop3_candidates_x13)
    B = Base.invokelatest(prop3_candidates_x12)
    V0 = [(1, 0), (2, 0), (3, 0), (4, 0), (5, 0)]; U0 = [(0, 1), (2, 1), (3, 1), (4, 1), (5, 1)]
    x13pos = pos0(13); x12pos = pos0(12); g34pos = (1, 0)
    order = collect(13:-1:1)
    levels = PlanLevel[]
    for (li, i) in enumerate(order)
        r, c = pos0(i)
        wideL = li <= wide
        if wideL && reduced && i == 7
            push!(levels, PlanLevel(0, r, c, 0, collect(0:255), 1, vcat(V0, [x13pos]), (0, 0)))
        elseif wideL && reduced && i == 6
            push!(levels, PlanLevel(0, r, c, 0, collect(0:255), 2, vcat(U0, [x12pos]), g34pos))
        else
            dom = wideL ? (i == 13 ? A : i == 12 ? B : collect(0:255)) : [seed[i]]
            push!(levels, PlanLevel(0, r, c, 0, dom))
        end
    end
    write_plan(path; n = n, modulus = modulus, prune_mode = 1,
               base = base, known = known, levels = levels)
    path
end

if abspath(PROGRAM_FILE) == @__FILE__
    what = length(ARGS) >= 1 ? ARGS[1] : "all"
    if what == "diag" || what == "all"
        for n in (5, 6, 7)
            r = diagonal_plan(n)
            println("wrote $(r.path)  num_vars=$(r.num_vars)  domain_sizes=$(r.domain_sizes)")
        end
    end
    if what == "h8" || what == "all"
        r = h8_plan()
        println("wrote $(r.path)  |A|=$(r.nA)  |B|=$(r.nB)")
    end
    if what == "bench" || what == "all"
        println("wrote $(h8_bench_plan())")
    end
end
