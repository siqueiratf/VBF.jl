# Implements the validation of the Fourier extension (n = 6 analog and n = 8 checks)
# Study: B6 = 52 extension search (census/quadratic_apn8/search_b52)
#
# Math:
#   n = 6: V = Alt(6) = F_2^15, 651 flats, (6,4) -> (6,6). All 13 CCZ classes of quadratic
#   APN functions on F_2^6 are known, so every extension found must have one of their 13
#   sigma. Brute force: all 2-dim T of V/U (2^11 points) are checked against the flats.
#   n = 8: the component space of a seed must be among the extensions of each of its
#   6-dim subspaces U with 52 bent elements; every extension must have differential
#   uniformity 2 and no flat in S^perp; random S = U + T outside the list must fail.
#   The v5 route (one 23-bit transform per V5, extensions of all U = V5 + <x>) must give
#   the same S as the U route (one 22-bit transform per U).
#
# Pseudocode:
#   check fast rank = slow rank; flats count; beta(r) by a full sweep (n = 6, n = 8)
#   n = 6: for each class rep S and each 4-dim U < S: Fourier T-list == brute-force
#          T-list; own S found; each S: DU 2, sigma in the 13; DU prefilter changes nothing
#          random U: Fourier == brute force; v5 route == U route for 3-dim V < S
#          coset bent counts == direct counts
#   n = 8: seeds with B6 = 52: own S found from every U with 52 bent; all S APN (DU and
#          flats); negative controls; v5 route == U route on the first x; timing per U
# VBF API used: SBox, differential_uniformity
# VBFCatalog API used: load_catalog, sigma_hash, DBInterface

isdefined(@__MODULE__, :run_search) || include(joinpath(@__DIR__, "search.jl"))
using Random

struct Checker
    io::IO
    fails::Vector{String}
end
function check!(ck::Checker, ok::Bool, what::AbstractString)
    println(ck.io, ok ? "  PASS  " : "  FAIL  ", what); flush(ck.io)
    ok || push!(ck.fails, what)
    ok
end

"Pure quadratic coefficients c_ij = F(e_i+e_j)+F(e_i)+F(e_j)+F(0) from a LUT."
function coeffs_from_lut(G::Geometry, lut)
    f(x) = UInt16(lut[x+1])
    [f((1 << (i - 1)) | (1 << (j - 1))) ⊻ f(1 << (i - 1)) ⊻ f(1 << (j - 1)) ⊻ f(0) for (i, j) in G.pairs]
end

"All subspaces of dimension k of span(basis) (as basis vectors), via kernels in coordinates."
function subspaces_of_span(basis::Vector{UInt32}, k::Int)
    m = length(basis)
    out = Vector{Vector{UInt32}}()
    for A in each_rref(m, m - k)
        els = [b for b in 1:(1 << m)-1 if !any(a -> isodd(count_ones(a & UInt32(b))), A)]
        bb = rref(UInt32.(els))[1]
        push!(out, [reduce(⊻, (basis[i] for i in 1:m if (b >> (i - 1)) & 1 == 1); init = UInt32(0)) for b in bb])
    end
    out
end

function flats_in_perp(G::Geometry, S::AbstractVector{UInt32})
    count(w -> all(s -> iseven(count_ones(w & s)), S), G.flats)
end

function validate_n6(ck::Checker; quick::Bool = false)
    io = ck.io
    println(io, "== n = 6: (6,4) -> (6,6) =="); flush(io)
    G = geometry(6)
    check!(ck, length(G.flats) == 651, "651 flats in Alt(6)")
    check!(ck, all(w -> form_rank(G, w) == form_rank_slow(G, w), UInt32(0):UInt32((1 << 15) - 1)),
           "fast rank = slow rank on all 2^15 forms")
    beta6 = bent_fourier(G)
    println(io, "  beta(n=6) = ", beta6, "   phi(n=6) = ", flat_fourier(G))
    db = VBFCatalog.load_catalog()
    q = "SELECT f.lut_blob FROM equivalence_classes e JOIN functions f ON f.id = e.canonical_id " *
        "WHERE e.kind = 'CCZ' AND e.n = 6 AND f.is_quadratic = 1 AND f.is_apn = 1"
    reps = [Vector{UInt8}(r.lut_blob) for r in VBFCatalog.DBInterface.execute(db, q)]
    check!(ck, length(reps) == 13, "13 quadratic APN class representatives for n = 6 (got $(length(reps)))")
    sig13 = Set(VBFCatalog.sigma_hash(SBox{6}(r)) for r in reps)
    check!(ck, length(sig13) == 13, "13 distinct sigma")
    w = ExtWork(11, 6); w5 = V5Work(12, 6)
    nU = 0; nUeq = 0; nown = 0; nall = 0; nS = 0; ndu = 0; nsig_ok = 0; nprefilter_eq = 0
    reach = Dict{Int,Int}()
    tf = 0.0; tb = 0.0
    for (ci, lut) in enumerate(reps)
        c = coeffs_from_lut(G, lut)
        S0 = coord_forms(c, 6)
        own = s_key(S0)
        Us = subspaces_of_span(S0, 4)
        quick && (Us = Us[1:7:end])
        sigs = Set{String}()
        for U in Us
            nU += 1
            tf += @elapsed r = extensions(G, U, w)
            r0 = extensions(G, U, w; du_filter = false)
            r0.Ts == r.Ts && (nprefilter_eq += 1)
            tb += @elapsed bf = extensions_bruteforce(G, U)
            r.Ts == sort(bf) && (nUeq += 1)
            found_own = false
            for (u, v) in r.Ts
                S = s_key(vcat(r.R, lift(u, r.Qmask), lift(v, r.Qmask)))
                S == own && (found_own = true)
                _, F = function_of(G, S)
                nS += 1
                differential_uniformity(F) == 2 && (ndu += 1)
                h = VBFCatalog.sigma_hash(F); push!(sigs, h)
                h in sig13 && (nsig_ok += 1)
            end
            found_own && (nown += 1)
        end
        reach[ci] = length(sigs)
    end
    check!(ck, nUeq == nU, "Fourier T-list = brute-force T-list for $nUeq / $nU subspaces U of the 13 classes")
    check!(ck, nown == nU, "own component space among the extensions for $nown / $nU U")
    check!(ck, ndu == nS, "differential uniformity 2 for $ndu / $nS extensions")
    check!(ck, nsig_ok == nS, "sigma of every extension is one of the 13 classes ($nsig_ok / $nS)")
    check!(ck, nprefilter_eq == nU, "Lemma 4.6 prefilter does not change the result ($nprefilter_eq / $nU)")
    println(io, @sprintf("  time per U: Fourier %.2f ms, brute force %.1f ms", 1e3tf / nU, 1e3tb / nU))
    println(io, "  classes reached from the 4-dim subspaces of each class: ", [reach[i] for i in 1:length(reps)])
    # random U
    rng = Xoshiro(2026)
    nr = quick ? 30 : 300; eq = 0; nonempty = 0
    for _ in 1:nr
        U = [rand(rng, UInt32(1):UInt32((1 << 15) - 1)) for _ in 1:4]
        span_dim(U) == 4 || (U = [UInt32(1), UInt32(2), UInt32(4), UInt32(8)])
        r = extensions(G, U, w; du_filter = false)
        bf = extensions_bruteforce(G, U)
        r.Ts == sort(bf) && (eq += 1)
        isempty(bf) || (nonempty += 1)
    end
    check!(ck, eq == nr, "random U: Fourier = brute force ($eq / $nr; $nonempty with extensions)")
    # coset bent counts vs direct
    okc = true
    for _ in 1:(quick ? 5 : 20)
        V = [rand(rng, UInt32(1):UInt32((1 << 15) - 1)) for _ in 1:3]
        span_dim(V) == 3 || continue
        buf = zeros(Int32, 1 << 12)
        rc = coset_bent_counts!(buf, G, V, beta6)
        for tau in UInt32(0):UInt32((1 << 12) - 1)
            x = lift(tau, rc.Qmask)
            nb = count(e -> form_rank(G, reduce(⊻, (V[i] for i in 1:3 if (e >> (i - 1)) & 1 == 1); init = x)) == 6, 0:7)
            buf[tau+1] == nb * rc.scale || (okc = false)
        end
    end
    check!(ck, okc, "coset bent counts (Fourier) = direct counts, n = 6")
    # v5 route vs U route (3-dim V < S)
    nv = 0; nveq = 0
    for lut in reps[1:(quick ? 3 : 13)]
        S0 = coord_forms(coeffs_from_lut(G, lut), 6)
        for V in subspaces_of_span(S0, 3)[1:(quick ? 10 : 40)]
            buf = zeros(Int32, 1 << 12)
            rc = coset_bent_counts!(buf, G, V, beta6)
            for need in 0:8
                X = [UInt32(t - 1) for t in 2:length(buf) if buf[t] == need * rc.scale]
                isempty(X) && continue
                nv += 1
                r5 = v5_extensions(G, V, need, w5; beta = beta6)
                SU = Set{Vector{UInt32}}()
                for x in X
                    e = extensions(G, vcat(V, lift(x, rc.Qmask)), w)
                    for (u, v) in e.Ts
                        push!(SU, s_key(vcat(e.R, lift(u, e.Qmask), lift(v, e.Qmask))))
                    end
                end
                SU == r5.Ss && (nveq += 1)
            end
        end
    end
    check!(ck, nveq == nv, "v5 route = U route, n = 6 ($nveq / $nv (V, need) pairs)")
end

function validate_n8(ck::Checker; quick::Bool = false, nseeds::Int = 10, nx::Int = 2000)
    io = ck.io
    println(io, "== n = 8: (8,6) -> (8,8) =="); flush(io)
    G = geometry(8)
    rng = Xoshiro(8)
    check!(ck, length(G.flats) == 10795, "10,795 flats in Alt(8)")
    check!(ck, all(_ -> (w = rand(rng, UInt32) & 0x0fffffff; form_rank(G, w) == form_rank_slow(G, w)), 1:200_000),
           "fast rank = slow rank on 200,000 random forms")
    phi = flat_fourier(G)
    check!(ck, phi == [10795, 2603, 555, 43, -85], "phi(r) = fhat at rank r = $phi")
    if !quick
        t = @elapsed beta = bent_fourier(G)
        check!(ck, beta == BETA8, "beta(r) by a full sweep of 2^28 forms = BETA8 ($(round(t, digits=1)) s)")
    end
    seeds = read_tsv(joinpath(RESULTS_DIR, "seeds_b52.tsv"))
    isempty(seeds) && (write_seeds(); seeds = read_tsv(joinpath(RESULTS_DIR, "seeds_b52.tsv")))
    known = filter(r -> r[2] == "known", seeds); new = filter(r -> r[2] == "new", seeds)
    sel = vcat(known, new)[1:min(quick ? 2 : nseeds, end)]
    w = ExtWork(22)
    nU = 0; nown = 0; nS = 0; ndu = 0; nflat = 0; nneg = 0; nnegok = 0; tU = 0.0; nTs = Int[]
    for r in sel
        c = coeffs_from_hex(r[4]); f = coord_forms(c, 8); comp = comp_forms(f); bent = bent_mask(G, comp)
        _, F0 = function_of(G, s_key(f))
        check!(ck, VBFCatalog.sigma_hash(F0) == r[1], "seed $(r[1][1:12]) ($(r[2])): RREF basis keeps sigma")
        own = s_key(f)
        Us = subspaces_of_comp(comp, bent, 6; keep = ==(52))
        for U in Us
            nU += 1
            tU += @elapsed e = extensions(G, U.forms, w)
            push!(nTs, length(e.Ts))
            got = false
            Tset = Set(e.Ts)
            for (u, v) in e.Ts
                S = s_key(vcat(e.R, lift(u, e.Qmask), lift(v, e.Qmask)))
                S == own && (got = true)
                _, F = function_of(G, S)
                nS += 1
                differential_uniformity(F) == 2 && (ndu += 1)
                flats_in_perp(G, S) == 0 && (nflat += 1)
            end
            got && (nown += 1)
            for _ in 1:3                       # negative controls: random T not in the list
                u = rand(rng, UInt32(1):UInt32((1 << 22) - 1)); v = rand(rng, UInt32(1):UInt32((1 << 22) - 1))
                (u == v) && continue
                a, b, _ = sort([u, v, u ⊻ v]); (a, b) in Tset && continue
                S = s_key(vcat(e.R, lift(u, e.Qmask), lift(v, e.Qmask)))
                length(S) == 8 || continue
                _, F = function_of(G, S)
                nneg += 1
                (differential_uniformity(F) > 2 && flats_in_perp(G, S) > 0) && (nnegok += 1)
            end
        end
    end
    check!(ck, nown == nU, "own component space among the extensions for $nown / $nU U with 52 bent")
    check!(ck, ndu == nS, "differential uniformity 2 for $ndu / $nS extensions")
    check!(ck, nflat == nS, "no flat in S^perp for $nflat / $nS extensions")
    check!(ck, nnegok == nneg, "negative controls: $nnegok / $nneg random S = U + T are not APN and have a flat in S^perp")
    println(io, @sprintf("  %d seeds, %d U with 52 bent (%.1f per seed), %.2f ms per U, extensions per U: %s",
                         length(sel), nU, nU / length(sel), 1e3tU / nU,
                         string(sort([k => count(==(k), nTs) for k in unique(nTs)]))))
    # v5 route vs U route
    w5 = V5Work(23)
    for r in sel[1:min(quick ? 1 : 3, end)]
        c = coeffs_from_hex(r[4]); comp = comp_forms(coord_forms(c, 8)); bent = bent_mask(G, comp)
        b5, _ = max_bent_dim(comp, bent, 5)
        V = subspaces_of_comp(comp, bent, 5; keep = ==(b5))[1]
        need = 52 - V.nbent
        nxx = quick ? 300 : nx
        t5 = @elapsed r5 = v5_extensions(G, V.forms, need, w5; beta = BETA8, max_x = nxx)
        buf = zeros(Int32, 1 << 23)
        rc = coset_bent_counts!(buf, G, V.forms, BETA8)
        X = [UInt32(t - 1) for t in 2:length(buf) if buf[t] == need * rc.scale][1:min(nxx, end)]
        okc = all(X[1:min(20, end)]) do x
            xx = lift(x, rc.Qmask)
            count(e -> form_rank(G, reduce(⊻, (V.forms[i] for i in 1:5 if (e >> (i - 1)) & 1 == 1); init = xx)) == 8, 0:31) == need
        end
        check!(ck, okc, "coset bent counts = direct counts for 20 cosets (b5 = $(V.nbent), need $need)")
        SU = Set{Vector{UInt32}}()
        tu = @elapsed for x in X
            e = extensions(G, vcat(V.forms, lift(x, rc.Qmask)), w)
            for (u, v) in e.Ts
                push!(SU, s_key(vcat(e.R, lift(u, e.Qmask), lift(v, e.Qmask))))
            end
        end
        check!(ck, SU == r5.Ss, @sprintf("v5 route = U route on %d x (%d S; %.2f s vs %.2f s; %d of %d x in total)",
                                          length(X), length(SU), t5, tu, length(X), r5.nX))
    end
end

function validate_all(; quick::Bool = false, io::IO = stdout, nseeds::Int = 10)
    ck = Checker(io, String[])
    t = @elapsed begin
        validate_n6(ck; quick)
        validate_n8(ck; quick, nseeds)
    end
    println(io, @sprintf("== %s: %d failures (%.0f s) ==", isempty(ck.fails) ? "ALL PASS" : "FAILURES", length(ck.fails), t))
    for f in ck.fails; println(io, "  failed: ", f); end
    isempty(ck.fails)
end
