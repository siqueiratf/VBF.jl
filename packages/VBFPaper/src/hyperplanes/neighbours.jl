using VBF
# Implements the hyperplane-neighbour graph experiments (HYPERPLANE.md, Sections 5 and 6)
# Study: census of quadratic APN functions on F_2^8 (packages/VBFSearch/data/research/archive/census/theory)
# Source: HYPERPLANE.md; Taniguchi, Polujan, Pott, Arshad (2025), Theorem 3.5
#
# Math:
#   F ~ F' (hyperplane neighbours) when F|_H and F'|_H' are EA-equivalent for some hyperplanes
#   H, H'. Equivalently F' is EA-equivalent to an APN extension G (+) L of G = F|_H. The
#   neighbours of F are the classes of the canonical extensions of F|_H over all H.
#   sigma (VBFCatalog.sigma_hash) labels classes; at n = 6, 7 it separates the catalog classes
#   (checked here), so class labels are exact there.
#
# Pseudocode:
#   gold_reach(n): x^3 on F_2^n, one hyperplane (Aut(x^3) is transitive on hyperplanes);
#     sigma of every canonical extension; number of distinct classes.
#   graph7(): for each of the 488 classes and each of the 127 hyperplanes, the classes of all
#     canonical extensions; degree of each class; connected components; per-class
#     histogram of e/64.
#   isolated8(k): k random beierle2025_n8 members (and given extra members): e(F|_H) for all
#     255 hyperplanes; a member with e = 128 on every H has no hyperplane neighbour.
# VBF API used: gold_apn, SBox, differential_uniformity (via ../check_uniqueness.jl)
# VBFCatalog API used: sigma_hash, load_catalog, corpus_function, corpus_length

isdefined(@__MODULE__, :check_uniqueness) || include(joinpath(@__DIR__, "check_uniqueness.jl"))

using Random, Printf

"sigma of every canonical extension of G (coefficients C on n-1 variables)."
function ext_sigmas(C::Matrix{UInt16}, n::Int)
    _, sols = VBF.QuadraticAPNTree.count_completions(C, n - 1, n; want_solution = true)
    extension_sigmas(C, sols, n)
end

function gold_reach(n::Int; u::Int = 1, io::IO = stdout)
    lut = lut_of(gold_apn(n, 1))
    C = restrict_coeffs(lut, hyperplane_basis(u, n))
    t = @elapsed s = ext_sigmas(C, n)
    reps = n <= 7 ? Dict(VBFCatalog.sigma_hash(SBox{n}(UInt8.(l))) => id for (_, id, l) in catalog_reps(n)) :
           Dict{String,Int}()
    cls = unique(s)
    known = n <= 7 ? count(h -> haskey(reps, h), cls) : -1
    @printf(io, "gold x^3 n=%d u=%d: canonical extensions %d, distinct sigma %d (catalog classes matched %d of %d) [%.1fs]\n",
            n, u, length(s), length(cls), known, length(reps), t)
    flush(io)
    cls
end

"Check the Example 4.2 signature against extensions of x^3; a match alone is not an equivalence proof."
function example42_check(; io::IO = stdout)
    s = VBFCatalog.sigma_hash(VBFCatalog.load_apn_function("n8_Taniguchi2025_ex4_2"))
    cls = gold_reach(8; io)
    println(io, "Example 4.2 sigma ", s, " among extension signature buckets (equivalence unresolved): ", s in cls)
    s in cls
end

"Hyperplane-neighbour signature graph on the catalog representatives; signature matches do not prove equivalence."
function graph_small(n::Int; io::IO = stdout)
    reps = catalog_reps(n)
    sig = [VBFCatalog.sigma_hash(SBox{n}(UInt8.(l))) for (_, _, l) in reps]
    @printf(io, "n=%d classes %d, distinct sigma among representatives %d\n", n, length(reps), length(unique(sig)))
    lab = Dict(h => k for (k, h) in enumerate(sig))
    nbr = [Set{Int}() for _ in reps]
    ehist = [Dict{Int,Int}() for _ in reps]
    unknown = Threads.Atomic{Int}(0)
    lk = ReentrantLock()
    Threads.@threads :dynamic for k in eachindex(reps)
        lut = reps[k][3]
        for u in 1:(1 << n) - 1
            C = restrict_coeffs(lut, hyperplane_basis(u, n))
            s = ext_sigmas(C, n)
            ehist[k][length(s)] = get(ehist[k], length(s), 0) + 1
            for h in s
                if haskey(lab, h)
                    lab[h] != k && push!(nbr[k], lab[h])
                else
                    Threads.atomic_add!(unknown, 1)
                end
            end
        end
    end
    deg = length.(nbr)
    # symmetric closure check and components
    asym = count(k -> any(j -> !(k in nbr[j]), nbr[k]), eachindex(reps))
    comp = collect(eachindex(reps))
    find(x) = (while comp[x] != x; x = comp[x]; end; x)
    for k in eachindex(reps), j in nbr[k]
        a, b = find(k), find(j)
        a != b && (comp[a] = b)
    end
    ncomp = length(unique(find(k) for k in eachindex(reps)))
    println(io, "  extensions with sigma outside the catalog classes: ", unknown[])
    println(io, "  classes with a non-symmetric neighbour list: ", asym)
    println(io, "  degree histogram: ", hist(deg))
    println(io, "  connected components: ", ncomp)
    path = joinpath(@__DIR__, "../../../../packages/VBFPaper/doc/generated/hyperplanes/graph_n$(n).tsv")
    mkpath(dirname(path))
    open(path, "w") do f
        println(f, "class_id\tdegree\tneighbours\te_over_2^(n-1)_histogram")
        for k in eachindex(reps)
            println(f, reps[k][2], '\t', deg[k], '\t', join(sort([reps[j][2] for j in nbr[k]]), ","), '\t',
                    join(["$a:$b" for (a, b) in sort(collect(ehist[k]))], ","))
        end
    end
    println(io, "  wrote ", path)
    flush(io)
    (deg = deg, ncomp = ncomp, ehist = ehist, ids = [r[2] for r in reps])
end

"|Aut| (ortho-derivative method) of the catalog classes of dimension n -> results/aut_n<n>.tsv."
function aut_small(n::Int; io::IO = stdout)
    path = joinpath(@__DIR__, "../../../../packages/VBFPaper/doc/generated/hyperplanes/aut_n$(n).tsv")
    mkpath(dirname(path))
    open(path, "w") do f
        println(f, "class_id\taut")
        for (_, id, lut) in catalog_reps(n)
            a = length(automorphisms_from_ortho_derivative(SBox{n}(UInt8.(lut))))
            println(f, id, '\t', a)
            flush(f)
        end
    end
    println(io, "wrote ", path)
end

"All 255 hyperplanes of k random beierle2025_n8 members (plus `extra`)."
function isolated8(; k::Int = 20, seed::Int = 3, extra = [3049449], io::IO = stdout)
    rng = Xoshiro(seed)
    db = VBFCatalog.load_catalog()
    cnt = VBFCatalog.corpus_length(db, "beierle2025_n8")
    ids = vcat(rand(rng, 1:cnt, k), extra)
    path = joinpath(@__DIR__, "../../../../packages/VBFPaper/doc/generated/hyperplanes/isolated_n8.tsv")
    mkpath(dirname(path))
    res = Vector{Any}(undef, length(ids))
    Threads.@threads :dynamic for t in eachindex(ids)
        lut = lut_of(VBFCatalog.corpus_function(db, "beierle2025_n8", ids[t]))
        es = [VBF.QuadraticAPNTree.count_completions(restrict_coeffs(lut, hyperplane_basis(u, 8)), 7, 8)[1] for u in 1:255]
        res[t] = es
    end
    open(path, "w") do f
        println(f, "member\thyperplanes_with_e>128\tu_list\te_list")
        for (t, es) in enumerate(res)
            big = [u for u in 1:255 if es[u] > 128]
            println(f, ids[t], '\t', length(big), '\t', join(big, ","), '\t', join(es[big], ","))
            @printf(io, "beierle2025_n8[%d]: hyperplanes with e > 128: %d %s\n", ids[t], length(big),
                    isempty(big) ? "(isolated: no hyperplane neighbour)" : string(collect(zip(big, es[big]))))
        end
    end
    println(io, "wrote ", path)
    res
end
