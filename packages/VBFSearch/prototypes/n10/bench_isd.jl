# Compare extensions_fast (isd_fast.jl) with the reference extensions_isd on the
# Gold positive controls and on real exchange cosets found by the GPU scan.
# Run: julia -O3 bench_isd.jl
include(joinpath(@__DIR__, "isd_fast.jl"))

function complement_basis(V)                            # as in gpu/coset_scan.jl
    C = UInt64[]; B = copy(V)
    for p in 0:NP-1
        e = UInt64(1) << p
        if rank_f2([B; e]) > length(B)
            push!(B, e); push!(C, e)
        end
    end
    C
end
coset_rep(idx::UInt64, C) = reduce(⊻, (C[k] for k in eachindex(C) if (idx >> (k - 1)) & 1 == 1); init = UInt64(0))

flats = all_flats()
for e in (3, 9)
    C = comp_basis(gold_lut(e)); b7, V7, _ = best_anchor(C); Vs = span(V7)
    q8 = first(q for q in span(C) if rank_f2([V7; q]) == 8 && coset_bent(q, Vs) == 178 - b7)
    U = vcat(V7, q8)
    t_ref = @elapsed (ref, L, _) = extensions_isd(U, flats; iters = 30_000)
    extensions_fast(U, flats; iters = 10)                      # compile
    t_new = @elapsed (new, _, nf) = extensions_fast(U, flats; iters = 60_000)
    println("x^$e control: |Z| = $L; reference ", length(ref), " ext in ", round(t_ref, digits = 1),
            " s (30k it); fast ", length(new), " ext in ", round(t_new, digits = 2), " s (60k it); same set = ",
            ref ⊆ new, "; contains C2 = ", canon(C) in new)
end

# Real exchange cosets of the x^3 anchor (GPU hits, need = 84).
C = comp_basis(gold_lut(3)); b7, V7, _ = best_anchor(C); Cb = complement_basis(V7)
for idx in UInt64[53184135, 57852767, 135706205]
    q = coset_rep(idx, Cb)
    U = vcat(V7, q)
    t = @elapsed (sols, L, nf) = extensions_fast(U, flats; iters = 60_000)
    println("coset $idx: count = ", coset_bent(q, span(V7)), ", |Z| = $L, candidates t = $nf, APN extensions = ",
            length(sols), " (", round(t, digits = 2), " s)")
end

pts = flat_points()
println("prefilter on the controls: ", [passes_delta8(vcat(V7, q), flats, pts) for q in (first(q for q in span(C) if rank_f2([V7; q]) == 8 && coset_bent(q, span(V7)) == 178 - b7),)])
println("prefilter on the GPU hits: ", [passes_delta8(vcat(V7, coset_rep(i, Cb)), flats, pts) for i in UInt64[53184135, 57852767, 135706205]])
