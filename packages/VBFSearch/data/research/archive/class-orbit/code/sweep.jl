# search/sweep.jl — exhaustive sweep of a V_A subspace, with checkpointing.
#
# Strategy
# --------
# V_A is a d-dimensional F_2 space with an explicit RREF basis, so the map
# b in F_2^d -> F = XOR_{i: b_i=1} basis[i] is a bijection onto V_A. That is the
# uniform parameterisation Phase 3 needs, and iterating b over 0:2^d-1 walks the
# subspace exactly once — no sampling, no duplicates, no gaps.
#
# L_a is linear in the coefficient vector, so L_a(F) = XOR_{i: b_i=1} P[i][a].
# A Gray-code walk therefore updates each maintained L_a with ONE xor per step.
#
# Rejection cascade: about 71% of candidates fail on a = 1 alone (a random
# alternating form has rank exactly 7 with probability ~0.29), so `nprobe`
# incrementally-maintained probes cut the survivors to a handful, and only those
# pay the full 255-value test. Survivors are then re-verified with
# VBF.differential_uniformity — a different code path — before being recorded.
#
# Resumability: the b-space is cut into 2^(d - lo_bits) blocks by the high bits.
# A block is walked with a Gray code over the low bits, and the checkpoint file
# records the highest completed block. A kill and restart resumes at the next
# block rather than restarting the sweep.

include(joinpath(@__DIR__, "apn_subspace.jl"))

using VBF
using Printf
using Base.Threads

"""
    la_tables(basis) -> Vector{Vector{UInt64}}

`P[i][a]` = `L_a` of basis vector `i`, laid out so `P[i]` is a contiguous
255-word run (the Gray-code inner loop xors along it).
"""
function la_tables(basis::Vector{BitVector})
    d = length(basis)
    P = Vector{Vector{UInt64}}(undef, d)
    for i = 1:d
        col = Vector{UInt64}(undef, NPTS - 1)
        for a = 1:(NPTS-1)
            col[a] = la_of_coeffs(basis[i], a)
        end
        P[i] = col
    end
    P
end

"""Full L_a vector for the subset `b` (bitmask over basis indices)."""
function la_full(P::Vector{Vector{UInt64}}, b::UInt64, d::Int)
    out = zeros(UInt64, NPTS - 1)
    @inbounds for i = 1:d
        ((b >> (i - 1)) & 1) == 1 || continue
        Pi = P[i]
        for a = 1:(NPTS-1)
            out[a] ⊻= Pi[a]
        end
    end
    out
end

"""Coefficient vector for the subset `b`."""
function coeffs_of(basis::Vector{BitVector}, b::UInt64, d::Int)
    c = falses(NCOEF)
    @inbounds for i = 1:d
        ((b >> (i - 1)) & 1) == 1 && (c .⊻= basis[i])
    end
    c
end

"""
    lut_of(basis, b, d) -> Vector{Int}

Materialise the function at subspace coordinate `b`. `sweep_subspace` returns
coordinates rather than LUTs to keep memory bounded; this turns one back into a
truth table.
"""
lut_of(basis::Vector{BitVector}, b::UInt64, d::Int) = coeffs_to_lut(coeffs_of(basis, b, d))

"""
    sweep_subspace(basis, region; nprobe, lo_bits, budget_seconds,
                   checkpoint_path, on_hit, progress_every) -> SearchOutcome

Walk every element of the subspace spanned by `basis` and return the three-case
outcome. `Exhausted` means every point was tested — an empty solution list is
then a proof that the subspace contains no APN function.
"""
function sweep_subspace(
    basis::Vector{BitVector},
    region::SearchRegion;
    nprobe::Int = 16,
    lo_bits::Int = 16,
    max_hits::Int = 20_000_000,
    budget_seconds::Union{Nothing,Float64} = nothing,
    checkpoint_path::Union{Nothing,String} = nothing,
    on_hit::Function = (b, c, lut) -> nothing,
    progress_every::Float64 = 1800.0,
    log_io::Union{Nothing,IO} = nothing,
)
    d = length(basis)
    d <= 62 || error("sweep_subspace: d = $d too large for a UInt64 walk")
    P = la_tables(basis)
    nprobe = min(nprobe, NPTS - 1)
    lo = min(lo_bits, d)
    hi = d - lo
    nblocks = UInt64(1) << hi
    lo_count = UInt64(1) << lo

    # Hits live in an append-only sidecar, NOT inside the checkpoint. Embedding
    # them made every block rewrite the whole list: at dim 32 that is already a
    # multi-MB file rewritten 4096 times, and at dim 40 it would be gigabytes
    # rewritten a million times. The checkpoint now carries only counters.
    hits_path = checkpoint_path === nothing ? nothing :
                replace(checkpoint_path, r"\.ckpt\.toml$" => "") * ".hits"

    start_block = UInt64(0)
    found_b = UInt64[]
    resumed_tested = UInt64(0)
    # `tested` is cumulative across resumes, so elapsed must be too — otherwise
    # any rate or ETA derived from the checkpoint is nonsense after a restart.
    resumed_elapsed = 0.0
    if checkpoint_path !== nothing && isfile(checkpoint_path)
        st = TOML.parsefile(checkpoint_path)
        if get(st, "d", -1) == d && get(st, "region_id", "") == region.id
            start_block = UInt64(get(st, "next_block", 0))
            # Restore the tested count too: without it a resumed-and-complete
            # sweep reports "coverage 0/2^d" while correctly tagging itself
            # Exhausted, which reads like a contradiction in the progress log.
            resumed_tested = UInt64(get(st, "tested", 0))
            resumed_elapsed = Float64(get(st, "elapsed_seconds", 0.0))
            # Legacy checkpoints inlined the hits; newer ones use the sidecar.
            found_b = UInt64.(get(st, "found_b", Int[]))
            if hits_path !== nothing && isfile(hits_path)
                for line in eachline(hits_path)
                    isempty(strip(line)) && continue
                    push!(found_b, parse(UInt64, strip(line)))
                end
            end
            # A crash mid-block can leave hits past the last checkpointed block;
            # those blocks get re-walked, so drop duplicates.
            unique!(found_b)
            _log(log_io, "resume: block $start_block / $nblocks, $(length(found_b)) hits, " *
                         "$(resumed_tested) points already tested")
        end
    end

    probe = zeros(UInt64, nprobe)
    # A solution is stored as its subspace COORDINATE b (8 bytes), not as a
    # 256-entry LUT (2 KB). A dim-32 sweep can produce ~10^6 hits; keeping LUTs
    # would need gigabytes, keeping coordinates needs megabytes, and b -> LUT is
    # a cheap pure function (`coeffs_to_lut(coeffs_of(basis, b, d))`).
    # `found_b` is restored from the checkpoint above, so `solutions` is exactly
    # it — non-empty iff at least one hit occurred, which is what
    # proves_emptiness depends on.
    solutions = found_b

    t0 = time()
    last_report = t0
    tested = resumed_tested
    full_checks = 0
    blk = start_block

    block_hits = UInt64[]
    while blk < nblocks
        empty!(block_hits)
        base = blk << lo
        # seed the maintained probes at the block's base point
        fill!(probe, 0)
        @inbounds for i = 1:d
            ((base >> (i - 1)) & 1) == 1 || continue
            Pi = P[i]
            for t = 1:nprobe
                probe[t] ⊻= Pi[t]
            end
        end

        gray_prev = UInt64(0)
        @inbounds for step = UInt64(0):(lo_count-1)
            g = step ⊻ (step >> 1)            # Gray code of `step`
            diff = g ⊻ gray_prev
            if diff != 0
                i = trailing_zeros(diff) + 1  # exactly one bit changes
                Pi = P[i]
                for t = 1:nprobe
                    probe[t] ⊻= Pi[t]
                end
                gray_prev = g
            end
            tested += 1

            ok = true
            for t = 1:nprobe
                if rank8(probe[t]) != 7
                    ok = false
                    break
                end
            end
            ok || continue

            # survived the probes — pay for the complete test
            b = base | g
            full_checks += 1
            la = la_full(P, b, d)
            is_apn_from_la(la) || continue

            c = coeffs_of(basis, b, d)
            lut = coeffs_to_lut(c)
            # independent confirmation on a different code path
            if !is_apn_reference(lut)
                error("sweep_subspace: fast test and differential_uniformity disagree " *
                      "at b = $b in region $(region.id) — engine bug, refusing to continue")
            end
            push!(found_b, b)
            push!(block_hits, b)
            on_hit(b, c, lut)

            # Too many hits to hold: stop and say so. Truncating the list while
            # still returning Exhausted would make the result a lie about the
            # subspace's contents, so this is a BudgetHit.
            if length(solutions) >= max_hits
                return BudgetHit(
                    StopPoint(:solutions, "max_hits = $max_hits reached";
                              resume_key = Dict{String,Any}("next_block" => Int(blk), "d" => d)),
                    region, solutions; nodes_visited = Int(tested),
                    elapsed_seconds = time() - t0,
                )
            end
        end

        blk += 1
        now = time()
        if checkpoint_path !== nothing
            # Append this block's hits FIRST, then advance the block counter.
            # In that order a crash between the two re-walks one block and finds
            # the same hits again (deduped on load); the reverse order would lose
            # them silently.
            if !isempty(block_hits)
                open(hits_path, "a") do io
                    for b in block_hits
                        println(io, Int(b))
                    end
                end
            end
            _write_checkpoint(checkpoint_path, region, d, blk, tested, resumed_elapsed + (now - t0))
        end
        if now - last_report >= progress_every
            frac = Float64(blk) / Float64(nblocks)
            eta = frac > 0 ? (now - t0) * (1 - frac) / frac : NaN
            _log(log_io, @sprintf("progress %s: block %d/%d (%.4f%%), tested %d, hits %d, full-checks %d, elapsed %.0fs, eta %.0fs",
                                  region.id, blk, nblocks, 100frac, tested, length(solutions), full_checks, now - t0, eta))
            last_report = now
        end
        if budget_seconds !== nothing && now - t0 >= budget_seconds
            return BudgetHit(
                StopPoint(:time, @sprintf("budget %.0f s expired after block %d/%d", budget_seconds, blk, nblocks);
                          resume_key = Dict{String,Any}("next_block" => Int(blk), "d" => d)),
                region, solutions; nodes_visited = Int(tested), elapsed_seconds = resumed_elapsed + (now - t0),
            )
        end
    end

    return Exhausted(region, solutions; nodes_visited = Int(tested),
                     elapsed_seconds = resumed_elapsed + (time() - t0))
end

"""
    walk_block!(probe, P, basis, d, base, lo, nprobe, region) -> Vector{UInt64}

Walk one block: Gray-code the low `lo` bits above `base`, returning the subspace
coordinates of the APN functions in it. `probe` is a caller-owned scratch buffer
(one per thread). Pure apart from `probe`, which is why the threaded driver can
run blocks concurrently.
"""
function walk_block!(probe::Vector{UInt64}, P::Vector{Vector{UInt64}},
                     basis::Vector{BitVector}, d::Int, base::UInt64, lo::Int,
                     nprobe::Int, region::SearchRegion)
    hits = UInt64[]
    fill!(probe, 0)
    @inbounds for i = 1:d
        ((base >> (i - 1)) & 1) == 1 || continue
        Pi = P[i]
        for t = 1:nprobe
            probe[t] ⊻= Pi[t]
        end
    end
    gray_prev = UInt64(0)
    lo_count = UInt64(1) << lo
    @inbounds for step = UInt64(0):(lo_count-1)
        g = step ⊻ (step >> 1)
        diff = g ⊻ gray_prev
        if diff != 0
            i = trailing_zeros(diff) + 1
            Pi = P[i]
            for t = 1:nprobe
                probe[t] ⊻= Pi[t]
            end
            gray_prev = g
        end
        ok = true
        for t = 1:nprobe
            if rank8(probe[t]) != 7
                ok = false
                break
            end
        end
        ok || continue
        b = base | g
        is_apn_from_la(la_full(P, b, d)) || continue
        lut = coeffs_to_lut(coeffs_of(basis, b, d))
        if !is_apn_reference(lut)
            error("walk_block!: fast test and differential_uniformity disagree at " *
                  "b = $b in region $(region.id) — engine bug, refusing to continue")
        end
        push!(hits, b)
    end
    hits
end

"""
    sweep_subspace_threaded(basis, region; ...) -> SearchOutcome

Same contract and same results as [`sweep_subspace`], with the block loop spread
over threads. Blocks are independent (each seeds its own probe state from its
base point), so the only shared work is per-chunk: blocks are processed in
ordered chunks, and after a chunk completes every block below it is done — which
keeps the checkpoint's single `next_block` frontier meaningful and resume
semantics identical to the serial walk.
"""
function sweep_subspace_threaded(
    basis::Vector{BitVector},
    region::SearchRegion;
    nprobe::Int = 8,
    lo_bits::Int = 20,
    max_hits::Int = 20_000_000,
    budget_seconds::Union{Nothing,Float64} = nothing,
    checkpoint_path::Union{Nothing,String} = nothing,
    progress_every::Float64 = 1800.0,
    log_io::Union{Nothing,IO} = nothing,
    chunk_blocks::Int = 4 * nthreads(),
)
    d = length(basis)
    d <= 62 || error("sweep_subspace_threaded: d = $d too large for a UInt64 walk")
    P = la_tables(basis)
    nprobe = min(nprobe, NPTS - 1)
    lo = min(lo_bits, d)
    hi = d - lo
    nblocks = UInt64(1) << hi
    lo_count = UInt64(1) << lo

    hits_path = checkpoint_path === nothing ? nothing :
                replace(checkpoint_path, r"\.ckpt\.toml$" => "") * ".hits"
    start_block = UInt64(0)
    found_b = UInt64[]
    resumed_tested = UInt64(0)
    # `tested` is cumulative across resumes, so elapsed must be too — otherwise
    # any rate or ETA derived from the checkpoint is nonsense after a restart.
    resumed_elapsed = 0.0
    if checkpoint_path !== nothing && isfile(checkpoint_path)
        st = TOML.parsefile(checkpoint_path)
        if get(st, "d", -1) == d && get(st, "region_id", "") == region.id
            start_block = UInt64(get(st, "next_block", 0))
            resumed_tested = UInt64(get(st, "tested", 0))
            resumed_elapsed = Float64(get(st, "elapsed_seconds", 0.0))
            found_b = UInt64.(get(st, "found_b", Int[]))
            if hits_path !== nothing && isfile(hits_path)
                for line in eachline(hits_path)
                    isempty(strip(line)) && continue
                    push!(found_b, parse(UInt64, strip(line)))
                end
            end
            unique!(found_b)
            _log(log_io, "resume: block $start_block / $nblocks, $(length(found_b)) hits, " *
                         "$(resumed_tested) points already tested")
        end
    end

    solutions = found_b
    t0 = time()
    last_report = t0
    tested = resumed_tested
    blk = start_block

    while blk < nblocks
        chunk_end = min(blk + UInt64(chunk_blocks), nblocks)
        nb = Int(chunk_end - blk)
        per_block = Vector{Vector{UInt64}}(undef, nb)
        @threads for t = 1:nb
            # One scratch buffer per block, not per thread: `threadid()` may
            # exceed `nthreads()` (interactive pool) and tasks can migrate
            # between threads, so threadid-indexed state is unsafe. A block runs
            # 2^lo points, so a 64-byte allocation per block is free.
            base = (blk + UInt64(t - 1)) << lo
            per_block[t] = walk_block!(zeros(UInt64, nprobe), P, basis, d, base, lo, nprobe, region)
        end
        chunk_hits = reduce(vcat, per_block)
        append!(solutions, chunk_hits)
        tested += UInt64(nb) * lo_count
        blk = chunk_end

        now = time()
        if checkpoint_path !== nothing
            if !isempty(chunk_hits)
                open(hits_path, "a") do io
                    for b in chunk_hits
                        println(io, Int(b))
                    end
                end
            end
            _write_checkpoint(checkpoint_path, region, d, blk, tested, resumed_elapsed + (now - t0))
        end
        if !isempty(chunk_hits)
            _log(log_io, "$(length(chunk_hits)) hit(s) in blocks $(blk - UInt64(nb)):$(blk-1) (total $(length(solutions)))")
        end
        if now - last_report >= progress_every
            frac = Float64(blk) / Float64(nblocks)
            eta = frac > 0 ? (now - t0) * (1 - frac) / frac : NaN
            _log(log_io, @sprintf("progress %s: block %d/%d (%.4f%%), tested %d, hits %d, elapsed %.0fs, eta %.0fs",
                                  region.id, blk, nblocks, 100frac, tested, length(solutions), now - t0, eta))
            last_report = now
        end
        if length(solutions) >= max_hits
            return BudgetHit(
                StopPoint(:solutions, "max_hits = $max_hits reached";
                          resume_key = Dict{String,Any}("next_block" => Int(blk), "d" => d)),
                region, solutions; nodes_visited = Int(tested), elapsed_seconds = resumed_elapsed + (now - t0))
        end
        if budget_seconds !== nothing && now - t0 >= budget_seconds
            return BudgetHit(
                StopPoint(:time, @sprintf("budget %.0f s expired after block %d/%d", budget_seconds, blk, nblocks);
                          resume_key = Dict{String,Any}("next_block" => Int(blk), "d" => d)),
                region, solutions; nodes_visited = Int(tested), elapsed_seconds = resumed_elapsed + (now - t0))
        end
    end

    return Exhausted(region, solutions; nodes_visited = Int(tested),
                     elapsed_seconds = resumed_elapsed + (time() - t0))
end

_log(io::Nothing, msg) = println(stderr, "[sweep] ", msg)
function _log(io::IO, msg)
    stamp = string(round(Int, time()))
    println(io, "[", stamp, "] ", msg)
    flush(io)
    println(stderr, "[sweep] ", msg)
end

function _write_checkpoint(path, region, d, next_block, tested, elapsed)
    tmp = path * ".tmp"
    open(tmp, "w") do io
        println(io, "region_id = ", repr(region.id))
        println(io, "d = ", d)
        println(io, "next_block = ", Int(next_block))
        println(io, "tested = ", Int(tested))
        println(io, "elapsed_seconds = ", elapsed)
    end
    mv(tmp, path; force = true)     # atomic replace, never a torn file
end
