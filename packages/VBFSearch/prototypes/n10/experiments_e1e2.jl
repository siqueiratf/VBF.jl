# Controlled experiments on the Beierle-Leander 3 pilot data.
#
# E1 (recall of the ISD re-extension). For an anchor V_7 < C2(seed), every coset
# q + V_7 with q in C2(seed) and b(q + V_7) = need is a GPU hit, gives
# U_8 < C2(seed), passes the prefilter, and must extend back to C2(seed). The
# expected number of such occurrences is exact, so observed/expected is the recall.
#
# E2 (prefilter). passes_delta8 must agree with the differential uniformity of the
# (10,8)-function F_U computed from its look-up table (the prefilter claims
# "passes" <=> delta(F_U) <= 8).
#
# Run from the repository root:
#   julia -t 12 --project=. packages/VBFSearch/prototypes/n10/experiments_e1e2.jl
include(joinpath(@__DIR__, "isd_fast.jl"))
using VBF, VBFCatalog, Random

dir = joinpath(@__DIR__, "results")
anchors = [[parse(UInt64, x; base = 16) for x in split(l)[2:end]] for l in readlines(joinpath(dir, "n10_BeierleLeander2022_3.anchors"))]
needs = [parse(Int, split(l)[1]) for l in readlines(joinpath(dir, "n10_BeierleLeander2022_3.anchors"))]
db = load_catalog()
C = comp_basis(Int.(load_sbox(db, "n10_BeierleLeander2022_3").lut))
inC(q) = rank_f2([C; q]) == length(C)

# --- E1 ---------------------------------------------------------------------------
occ = [split(l, '\t') for l in readlines(joinpath(dir, "BL3", "occurrences.tsv"))[2:end]]
lastb = parse(Int, split(readlines(joinpath(dir, "BL3", "batches.tsv"))[end], '\t')[1])
hits = [split(l) for l in readlines(joinpath(dir, "BL3.partial.hits")) if length(split(l)) == 3]
# anchors whose hits are all checked: those below the anchor of the last checked hit
checked_to = maximum(parse(Int, r[2]) for r in occ)
println("E1: anchors fully checked = 1..", checked_to - 1, " (batch $lastb)")
expected = 0; observed = 0; observed_out = 0
for a in 1:checked_to-1
    V = anchors[a]; Vs = span(V)
    reps = Set(canon(vcat(V, q)) for q in span(C) if rank_f2([V; q]) == 8 && coset_bent(q, Vs) == needs[a])
    global expected += length(reps)
    rows = [r for r in occ if parse(Int, r[2]) == a]
    global observed += count(r -> inC(parse(UInt64, r[3]; base = 16)), rows)
    global observed_out += count(r -> !inC(parse(UInt64, r[3]; base = 16)), rows)
end
println("E1: in-C2 occurrences expected = $expected, observed = $observed (recall ",
        round(observed / max(expected, 1), digits = 3), "); occurrences with q outside C2 = $observed_out")

# --- E2 ---------------------------------------------------------------------------
function delta_of_space(U)                             # delta of x -> (u_1(x), ..., u_8(x))
    lut = zeros(Int, 1 << n)
    for x in 0:(1 << n)-1
        w = UInt64(0)
        for i in 1:n, j in i+1:n
            bit(x, i) & bit(x, j) == 1 && (w |= UInt64(1) << PAIR[i, j])
        end
        lut[x+1] = sum((isodd(count_ones(u & w)) ? 1 : 0) << (k - 1) for (k, u) in enumerate(U))
    end
    best = 0; cnt = zeros(Int, 1 << length(U))
    for a in 1:(1 << n)-1
        fill!(cnt, 0)
        for x in 0:(1 << n)-1
            cnt[(lut[x+1] ⊻ lut[(x ⊻ a)+1])+1] += 1
        end
        best = max(best, maximum(cnt))
    end
    best
end
flats = all_flats(); pts = flat_points()
sample = shuffle(Xoshiro(2), hits)[1:min(end, 400)]
agree = Threads.Atomic{Int}(0); npass = Threads.Atomic{Int}(0); deltas = zeros(Int, length(sample))
Threads.@threads for i in eachindex(sample)
    a = parse(Int, sample[i][1]); q = parse(UInt64, sample[i][3]; base = 16)
    U = vcat(anchors[a], q)
    p = passes_delta8(U, flats, pts); d = delta_of_space(U); deltas[i] = d
    p && Threads.atomic_add!(npass, 1)
    (p == (d <= 8)) && Threads.atomic_add!(agree, 1)
end
println("E2: prefilter agrees with direct delta on ", agree[], " of ", length(sample), " hits; passed ", npass[],
        "; delta values ", sort(collect(Set(deltas))))

# --- E1b: the missed in-C2 extensions, with more iterations -------------------------
if get(ENV, "E1B", "0") == "1"
    seen = Set((parse(Int, r[2]), canon(vcat(anchors[parse(Int, r[2])], parse(UInt64, r[3]; base = 16)))) for r in occ)
    for a in 1:checked_to-1
        V = anchors[a]; Vs = span(V)
        for U in Set(canon(vcat(V, q)) for q in span(C) if rank_f2([V; q]) == 8 && coset_bent(q, Vs) == needs[a])
            (a, U) in seen && continue
            P = ISDProblem(U, flats)
            for it in (30_000, 120_000, 480_000)
                t = @elapsed (sols, L, nf) = extensions_fast(U, flats; iters = it, rng = Xoshiro(7))
                hit = canon(C) in sols
                println("E1b: anchor $a missed U: |Z| = $L, rank = $(P.k), iters = $it -> found C2 = $hit, candidates = $nf (",
                        round(t, digits = 1), " s)")
                hit && break
            end
        end
    end
end
