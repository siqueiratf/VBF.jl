# Pilot step 3 (local CPU): for every hit of gpu/scan_anchors.jl, apply the
# delta-8 prefilter, re-extend U_8 = V_7 + <q> with ISD, and compare each APN
# extension with the n = 10 classes of the catalog by sigma.
# Run from the repository root:
#   julia -t 12 --project=. packages/VBFSearch/prototypes/n10/pilot_check.jl <file.anchors> <file.hits> [iters]
include(joinpath(@__DIR__, "isd_fast.jl"))
using VBF, VBFCatalog

lut_of(S) = [reduce(|, (UInt16(isodd(count_ones(s & qx))) << (k - 1) for (k, s) in enumerate(S)); init = UInt16(0))
             for qx in (begin w = UInt64(0)
                 for i in 1:n, j in i+1:n
                     bit(x, i) & bit(x, j) == 1 && (w |= UInt64(1) << PAIR[i, j])
                 end; w end for x in 0:(1 << n)-1)]

function pilot_check(anchorfile, hitfile; iters = 60_000)
    anchors = [[parse(UInt64, x; base = 16) for x in split(l)[2:end]] for l in readlines(anchorfile)]
    hits = [(parse(Int, f[1]), parse(UInt64, f[3]; base = 16)) for f in split.(readlines(hitfile))]
    flats = all_flats(); pts = flat_points()
    db = load_catalog()
    known = Set(sigma_hash(F) for F in (load_sbox(db, r.id) for r in list_functions(db; n = 10))
                if VBF.algebraic_degree(F) == 2)           # sigma needs a quadratic APN function
    println("hits = ", length(hits), ", known n = 10 sigma = ", length(known)); flush(stdout)

    passed = Threads.Atomic{Int}(0)
    spaces = [Set{Vector{UInt64}}() for _ in 1:Threads.maxthreadid()]
    t = @elapsed Threads.@threads :dynamic for (a, q) in hits
        U = vcat(anchors[a], q)
        passes_delta8(U, flats, pts) || continue
        Threads.atomic_add!(passed, 1)
        sols, _, _ = extensions_fast(U, flats; iters, rng = Xoshiro(hash(q)))
        union!(spaces[Threads.threadid()], sols)
    end
    S = reduce(union, spaces)
    println("prefilter passed = ", passed[], " of ", length(hits), "; distinct APN spaces = ", length(S),
            " (", round(t / 60, digits = 1), " min)"); flush(stdout)

    classes = Dict{String,Vector{UInt16}}()
    for s in S
        lut = lut_of(s)
        F = SBox{10}(lut)
        VBF.differential_uniformity(F) == 2 || error("an extension is not APN")
        h = sigma_hash(F)
        haskey(classes, h) || (classes[h] = lut)
    end
    new = [h for h in keys(classes) if !(h in known)]
    println("distinct sigma = ", length(classes), "; known = ", length(classes) - length(new), "; NEW = ", length(new))
    out = replace(hitfile, r"\.hits$" => "") * ".new"
    open(out, "w") do io
        for h in new
            println(io, h, " ", join(Int.(classes[h]), ","))
        end
    end
    println("new classes written to $out")
end

if abspath(PROGRAM_FILE) == @__FILE__
    pilot_check(ARGS[1], ARGS[2]; iters = length(ARGS) > 2 ? parse(Int, ARGS[3]) : 60_000)
end
