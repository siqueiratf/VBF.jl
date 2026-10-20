# E3: all quadratic Edel-Pott switching neighbours of the quadratic n = 10 seeds.
#
# For a quadratic APN F with component forms c_1..c_10, the sum of F on the flat
# with bivector w is u(w) = (<c_k, w>)_k, never 0. For a quadratic s, the function
# H = F + u*s fails on that flat exactly when u(w) = u and <s, w> = 1. So the
# quadratic u-switching space is
#     K_u = { s in Q_10 : <s, w> = 0 for every flat w with u(w) = u }   (45 unknowns),
# the trivial part is T_u = { sum_k b_k c_k : b.u = 0 } (dimension 9), and every
# nonzero class s in K_u / T_u gives C2(H) = span{ c_k + u_k s }. This is exact and
# complete for quadratic neighbours; neighbours with deg s > 2 are not covered.
#
# Each class is labelled by sigma and confirmed with are_ea_equivalent (EA = CCZ
# for quadratic APN functions). Results go at once to results/switching/quad.tsv;
# seeds already in the file are skipped on restart.
#
# Run from the repository root:
#   julia --project=. packages/VBFSearch/prototypes/n10/e3_quadswitch.jl
include(joinpath(@__DIR__, "pilot_check.jl"))           # lut_of, canon, flats, VBF, VBFCatalog
using Dates

# Kernel basis of { s : <s, w> = 0 for w in rows } inside F_2^45.
function nullspace45(rows)
    R = UInt64[]; piv = Int[]
    for w in rows                                       # RREF by lowest bit
        x = w
        for (r, p) in zip(R, piv)
            (x >> p) & 1 == 1 && (x ⊻= r)
        end
        x == 0 && continue
        p = trailing_zeros(x)
        for i in eachindex(R)
            (R[i] >> p) & 1 == 1 && (R[i] ⊻= x)
        end
        push!(R, x); push!(piv, p)
    end
    free = setdiff(0:NP-1, piv)
    [begin
        v = UInt64(1) << f
        for (r, p) in zip(R, piv)
            (r >> f) & 1 == 1 && (v |= UInt64(1) << p)
        end
        v
    end for f in free]
end

# A basis of K modulo T (both given by bases, T inside K).
function quotient_basis(K, T)
    B = copy(T); Q = UInt64[]
    for k in K
        if rank_f2([B; k]) > length(B)
            push!(B, k); push!(Q, k)
        end
    end
    Q
end

function e3_main()
    db = load_catalog()
    quad = Dict{String,Tuple{String,SBox{10,UInt16}}}()
    seeds = Tuple{String,SBox{10,UInt16}}[]
    for r in list_functions(db; n = 10)
        F = load_sbox(db, r.id)
        VBF.algebraic_degree(F) == 2 || continue
        s = sigma_hash(F); haskey(quad, s) && continue
        quad[s] = (r.canonical_name, F); push!(seeds, (r.canonical_name, F))
    end
    flats = all_flats()
    dir = joinpath(@__DIR__, "results", "switching"); mkpath(joinpath(dir, "new"))
    out = joinpath(dir, "quad.tsv")
    isfile(out) || write(out, "seed\tdirections_nontrivial\tneighbour_spaces\tclasses\tlabels\n")
    done = Set(split(l, '\t')[1] for l in readlines(out)[2:end])
    newreps = Dict{String,SBox{10,UInt16}}()
    for (name, F) in seeds
        name in done && continue
        t0 = time()
        C = comp_basis(Int.(F.lut))
        byu = Dict{Int,Vector{UInt64}}()
        for w in flats
            u = sum((isodd(count_ones(C[k] & w)) ? 1 : 0) << (k - 1) for k in 1:10)
            u == 0 && error("$name is not APN")
            push!(get!(byu, u, UInt64[]), w)
        end
        spaces = Set{Vector{UInt64}}(); nontrivial = 0
        for (u, ws) in byu
            K = nullspace45(ws)
            T = [reduce(⊻, (C[k] for k in 1:10 if (b >> (k - 1)) & 1 == 1); init = UInt64(0))
                 for b in 1:1023 if iseven(count_ones(b & u))]
            Tb = UInt64[]
            for x in T
                rank_f2([Tb; x]) > length(Tb) && push!(Tb, x)
            end
            Q = quotient_basis(K, Tb)
            isempty(Q) && continue
            nontrivial += 1
            for s in span(Q)[2:end]
                S = [C[k] ⊻ ((u >> (k - 1)) & 1 == 1 ? s : UInt64(0)) for k in 1:10]
                rank_f2(S) == 10 && is_apn_space(S, flats) && push!(spaces, canon(S))
            end
        end
        labels = Dict{String,String}()
        for S in spaces
            G = SBox{10}(lut_of(S)); sg = sigma_hash(G)
            haskey(labels, sg) && continue
            if haskey(quad, sg) && are_ea_equivalent(G, quad[sg][2])
                labels[sg] = quad[sg][1]
            elseif haskey(newreps, sg) && are_ea_equivalent(G, newreps[sg])
                labels[sg] = "NEW(seen before)"
            else
                labels[sg] = "NEW"; newreps[sg] = G
                write(joinpath(dir, "new", "$(sg[1:16]).lut"), join(Int.(G.lut), ','))
                println(now(), " NEW class sigma ", sg[1:16], "... from $name"); flush(stdout)
            end
        end
        line = join([name, nontrivial, length(spaces), length(labels), join(sort(collect(values(labels))), ";")], '\t')
        open(io -> println(io, line), out, "a")
        println(now(), " $name: $nontrivial nontrivial directions, ", length(spaces), " neighbour spaces, ",
                length(labels), " classes (", round(time() - t0, digits = 1), " s): ",
                join(sort(collect(values(labels))), ", ")); flush(stdout)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    e3_main()
end
