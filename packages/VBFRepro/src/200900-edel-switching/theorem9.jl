# Implements Theorem 9 — the switching APN criterion.
# Paper: Edel, Pott (2009), "A new almost perfect nonlinear function which is
#        not quadratic", Adv. Math. Commun. 3(1):59-81.
# Section: 3 — Dillon's switching construction (Theorem 9, Proposition 3).
#
# Pseudocode (Theorem 9): F APN, u≠0, f: F_2^n → F_2. Then v ↦ F(v)+f(v)·u is
#   APN  ⇔  f(x)+f(x+a)+f(y)+f(y+a)=0 for every 4-tuple with
#           F(x)+F(x+a)+F(y)+F(y+a)=u.
#
#   1. Given a base APN F and a switching neighbour H, recover (u, f) by
#      Proposition 3: the LUT difference H(v)-F(v) ∈ {0, u}, f(v)=[H(v)≠F(v)].
#   2. Verify the Theorem-9 constraint holds for f (so H is APN — forward dir).
#   3. Flip one f-value: constraint is violated AND the perturbed function is no
#      longer APN (Δ-uniformity 4) — the "only if" direction.
# VBF API used: differential_uniformity, print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

# Recover the switching pair (u, f-vector) from base F and neighbour H (Prop 3).
function _recover_switch(F::SBox, H::SBox)
    diffs = F.lut .⊻ H.lut
    nz = filter(!=(0), diffs)
    u = isempty(nz) ? 0 : first(nz)
    all(d -> d == 0 || d == u, diffs) || error("not a narrow-sense switch pair")
    f = Int[d == 0 ? 0 : 1 for d in diffs]
    return u, f
end

# Theorem 9 constraint check: returns (all_satisfied, n_constraints).
function _switching_constraint(F::SBox{N}, u::Integer, f::AbstractVector) where {N}
    lut = F.lut
    n = 1 << N
    ok = true
    cnt = 0
    for a = 1:(n - 1)
        buckets = [Int[] for _ = 0:(n - 1)]
        for x = 0:(n - 1)
            v = lut[x + 1] ⊻ lut[(x ⊻ a) + 1]      # D_a(x) = F(x)+F(x+a)
            push!(buckets[v + 1], x)
        end
        for v = 0:(n - 1)
            w = v ⊻ Int(u)
            v < w || continue                        # each {v,w} pair once (u≠0)
            bx, by = buckets[v + 1], buckets[w + 1]
            (isempty(bx) || isempty(by)) && continue
            for x in bx, y in by
                cnt += 1
                (f[x + 1] ⊻ f[(x ⊻ a) + 1] ⊻ f[y + 1] ⊻ f[(y ⊻ a) + 1]) == 0 || (ok = false)
            end
        end
    end
    return ok, cnt
end

"""
    theorem9_report(io = stdout; save_results = false) -> NamedTuple

Demonstrate Theorem 9 (the iff switching criterion) on the `2.3 → 2.11` switch:
recover `(u, f)`, verify the constraint holds (H APN), then perturb `f` to break
both the constraint and the APN property.
"""
function theorem9_report(io::IO = stdout; save_results::Bool = false)
    print_section("Theorem 9 — switching APN criterion (iff), demo on 2.3 → 2.11", io)
    rows = edelpott_table5()
    F = only(r.sbox for r in rows if r.name == "2.3")     # base APN
    H = only(r.sbox for r in rows if r.name == "2.11")    # switching neighbour

    u, f = _recover_switch(F, H)
    print_kv("recovered switch vector u", "u^19 = $u", io)
    print_check("H = F + f·u is APN (Δ-uniformity=$(differential_uniformity(H)))",
        differential_uniformity(H) == 2, io)

    ok, ncon = _switching_constraint(F, u, f)
    print_check("Theorem 9 constraint holds for f ⇒ F+f·u APN ($ncon constraints)",
        ok, io)

    # "only if": flip one f-value → constraint broken and APN lost.
    fbad = copy(f)
    fbad[1] ⊻= 1
    okbad, _ = _switching_constraint(F, u, fbad)
    Hbad = SBox([F.lut[x + 1] ⊻ (fbad[x + 1] == 1 ? Int(u) : 0) for x = 0:(1 << EP_N) - 1])
    dubad = differential_uniformity(Hbad)
    print_check("perturbed f violates the constraint (Theorem 9 'only if')", !okbad, io)
    print_check("perturbed function is no longer APN (Δ-uniformity=$dubad > 2)",
        dubad > 2, io)

    # Forward direction across the whole catalogue: every listed switch stays APN.
    all_apn = all(differential_uniformity(r.sbox) == 2 for r in rows)
    print_check("every Table-5 switching neighbour is APN (forward direction)", all_apn, io)
    print_kv("completeness", "exhaustive constraint enumeration (n=6)", io)

    result = (; u, n_constraints = ncon, constraint_ok = ok,
        perturbed_apn_lost = dubad > 2, all_apn)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "theorem9.toml"), "w") do fh
            println(fh, "# Edel–Pott (2009) Theorem 9 — switching APN criterion")
            println(fh, "switch_vector_u = $u")
            println(fh, "n_constraints = $ncon")
            println(fh, "constraint_satisfied = $ok")
            println(fh, "perturbed_apn_lost = $(dubad > 2)")
        end
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem9_report()
end
