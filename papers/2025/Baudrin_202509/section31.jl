# Implements Section 3.1: An Exact Representation of a CCZ-Equivalence Class.
# Paper: Baudrin, Galissant and Perrin (2025), "Exploring the Set of APN Functions", BFA 2025
# Section: 3.1 — An Exact Representation of a CCZ-Equivalence Class
#
# Pseudocode:
#   1. Discover native graph automorphism generators or load the ortho-derivative route.
#   2. Enumerate Walsh-zero subspaces and compute their automorphism orbits.
#   3. Construct and verify one admissible graph map per orbit; retain completeness.
# VBF API used: ea_class_orbits, ea_class_representatives, partition_refinement_automorphisms
isdefined(@__MODULE__, :bgp_verify_graph_map) || include(joinpath(@__DIR__, "helpers.jl"))

"""Run the Section 3.1 orbit pipeline of Baudrin–Galissant–Perrin (2025)."""
function section31(; dimension=4, F=gold_apn(dimension), limit=1, max_evaluations=1 << 16,
    sample_size=1, max_nodes=10^6, timeout_seconds=30.0, max_subspaces=4096,
    max_memory_bytes=512 * 1024^2, save_results=false, seed=940,
    full_search=false, compare_legacy=true, automorphisms=nothing)
    bgp_validate_limits(; limit, max_evaluations, sample_size, max_nodes,
        timeout_seconds, max_subspaces, max_memory_bytes)
    active = limit > 0 && sample_size > 0
    started = time_ns()
    H = automorphisms === nothing ? partition_refinement_automorphisms(F;
        relation=:ccz, max_nodes=active ? max_nodes : 0,
        timeout_seconds, max_memory_bytes, rng=Xoshiro(seed)) : automorphisms
    for A in H.generators
        bgp_verify_graph_map(F,F,A) || error("automorphism failed independent graph validation")
        is_quadratic_apn(F) && inputbits(F) >= 4 &&
            !bgp_verify_graph_map(F,F,A;relation=:ea) && error("quadratic APN automorphism is not EA")
    end
    group_nodes = automorphisms === nothing ? H.nodes_visited : 0
    remaining = max(0.0,timeout_seconds-(time_ns()-started)*1e-9)
    native = ea_class_representatives(F; backend=:partition_refinement,
        max_nodes=active ? max(0,max_nodes-group_nodes) : 0, timeout_seconds=remaining,
        max_subspaces, max_memory_bytes, automorphisms=H, rng=Xoshiro(seed))
    certificates = [bgp_witness(F, G, A; kind="orbit_representative", target=i,
        source_label="Section 3.1 root", target_label="EA orbit $(native.orbit_indices[i])")
        for (i,(G,A)) in enumerate(zip(native.representatives, native.mappings))]
    legacy = nothing
    legacy_agrees = nothing
    if active && compare_legacy && is_quadratic_apn(F)
        remaining = max(0.0, timeout_seconds - (time_ns() - started) * 1e-9)
        if remaining > 0
            legacy_nodes = max(0,max_nodes-group_nodes-native.orbit_result.nodes_visited)
            legacy = ea_class_orbits(F; backend=:ortho_derivative, max_nodes=legacy_nodes,
                timeout_seconds=remaining, max_subspaces, max_memory_bytes)
            if native.orbit_result.complete && legacy.complete
                legacy_agrees = native.orbit_result.bases == legacy.bases &&
                    bgp_partition(native.orbit_result.orbits) == bgp_partition(legacy.orbits)
                legacy_agrees || error("native and ortho-derivative orbit partitions disagree")
            end
        end
    end
    exact = native.complete
    # APN n>=2 has no nontrivial constant derivative, so the affine group
    # and its image of linear parts have the same order (paper Theorem 2).
    bounds = if exact && inputbits(F) >= 2 && H.order !== nothing && differential_uniformity(F) == 2
        lower = Int(cld(BigInt(native.orbit_result.nspaces),H.order))
        upper = native.orbit_result.nspaces
        observed = length(native.orbit_result.orbits)
        lower <= observed <= upper || error("Theorem 2 orbit-count bounds failed")
        (;lower,upper,observed)
    else
        nothing
    end
    crosscheck_complete = !compare_legacy || !is_quadratic_apn(F) ||
        (legacy !== nothing && legacy.complete && legacy_agrees === true)
    data = bgp_metadata("section31", seed, (; limit, max_evaluations, sample_size,
        max_nodes, timeout_seconds, max_subspaces, max_memory_bytes, full_search))
    merge!(data, Dict("complete" => exact, "crosscheck_complete" => crosscheck_complete,
        "source_lut" => Int.(F.lut), "dimension" => inputbits(F),
        "automorphisms_complete" => native.orbit_result.automorphisms_complete,
        "subspaces_complete" => native.orbit_result.subspaces_complete,
        "actions_complete" => native.orbit_result.actions_complete,
        "representatives_complete" => native.complete,
        "bound_checked" => bounds !== nothing,
        "group_result_complete" => H.complete, "group_relation" => string(H.relation),
        "graph_group_order" => string(H.graph_order), "pointwise_kernel_order" => string(H.kernel_order),
        "automorphism_generators" => [Dict("linear_columns"=>Int.(A.linear.cols),
            "constant"=>Int(A.constant)) for A in H.generators],
        "elapsed_seconds" => (time_ns()-started)*1e-9,
        "subspaces" => native.orbit_result.nspaces,
        "group_order" => string(native.orbit_result.group_order),
        "acting_maps" => native.orbit_result.nauts,
        "ea_classes_returned" => length(native.representatives),
        "stop_reason" => string(native.stop_reason),
        "witnesses" => certificates))
    if bounds !== nothing
        data["orbit_count_bounds"] = Dict("lower"=>bounds.lower,"upper"=>bounds.upper,
            "observed"=>bounds.observed)
    end
    path = bgp_save("section31", data; save_results)
    return (; status=exact ? :exact : :bounded, exhaustive=exact, seed, native,
        automorphisms=H,
        bounds,
        legacy, legacy_agrees, crosscheck_complete, certificates, saved_path=path,
        elapsed_seconds=(time_ns() - started) * 1e-9)
end

"""Report Section 3.1 of Baudrin–Galissant–Perrin (2025)."""
function section31_report(io::IO=stdout; kwargs...)
    r = section31(; kwargs...)
    print_section(io, "Section 3.1 — CCZ-class representation")
    print_kv(io, "status", r.status)
    print_kv(io, "seed", r.seed)
    print_kv(io, "Walsh-zero subspaces", r.native.orbit_result.nspaces)
    print_kv(io, "EA representatives returned", length(r.native.representatives))
    print_kv(io, "complete group / subspaces / orbit actions",
        (r.native.orbit_result.automorphisms_complete,
         r.native.orbit_result.subspaces_complete, r.native.orbit_result.actions_complete))
    print_kv(io, "legacy cross-check", r.legacy_agrees)
    print_kv(io, "independently verified certificates", length(r.certificates))
    print_kv(io, "stop reason", r.native.stop_reason)
    return r
end
