# search/phase0b_certificate.jl — PHASE 0b warm-up certificate.
#
# Claim under test (audit finding F001): the curated catalog entry
# n8_Taniguchi2025_ex4_2 is EA-equivalent to Budaghyan–Carlet–Leander (2009)
# eq. (6) with a = alpha over GF(2^8).
#
# This script does NOT re-run a search and trust its "3072 mappings" count. It
# takes ONE mapping and checks the composition pointwise on all 256 inputs:
#
#     G(x) == A1( F( A2(x) ) ) XOR A(x)      for every x in 0:255
#
# with F = apn_eq6(8, alpha)  and  G = n8_Taniguchi2025_ex4_2.
#
# Why a graph map has to be unpacked first
# ----------------------------------------
# ea_mappings_from_ortho_derivative returns F2-linear maps L on the *graph*
# (2n = 16 bits, packed as (x << 8) | F(x)), satisfying
#
#     graph(G) = L(graph(F)) XOR c
#
# with the constant c NOT returned. Writing the 16-bit input as (u, v) — u the
# high 8 bits, v the low 8 — and L in 8x8 blocks,
#
#     L(u, v) = (P u + Q v,  R u + S v),      c = (c1, c2)
#
# a point (x, F(x)) of graph(F) maps to
#
#     x' = P x + Q F(x) + c1,   G(x') = R x + S F(x) + c2.
#
# The map is an EA (not merely CCZ) map exactly when Q = 0; then x' = P x + c1
# is a bijection of the input, x = P^-1(x' + c1), and substituting gives
#
#     G(x') = S( F( P^-1(x' + c1) ) ) + R( P^-1(x' + c1) ) + c2
#
# i.e. A1 = S (linear), A2 = P^-1(. + c1) (affine), A = R.P^-1(. + c1) + c2
# (affine drift). That is the triple this script writes out.
#
# Writes: certificates/taniguchi_ea.json
# Checkpoint: certificates/.phase0b_maps.json (raw graph maps; the ~400 s part)

using VBF
using VBFCatalog
using JSON3

const ROOT = normpath(joinpath(@__DIR__, ".."))
const N = 8
const NPTS = 1 << N
const MASK = UInt32(NPTS - 1)

log_line(msg) = println(stderr, "[phase0b ", _stamp(), "] ", msg)
_stamp() = string(round(Int, time()))

# ── The two functions ────────────────────────────────────────────────────────

# BCL 2009 eq. (6): x^3 + a^-1 * tr_n(a^3 * x^9).  Mirrors
# papers/2009/Budaghyan_200910/helpers.jl:apn_eq6 (read, not modified).
function apn_eq6_lut(n::Int, a::Int; modulus::Int)
    M = 1 << n
    ai = gf_inv(a, n; modulus)
    a3 = gf_pow(a, 3, n; modulus)
    out = Vector{Int}(undef, M)
    for x = 0:(M-1)
        x3 = gf_pow(x, 3, n; modulus)
        x9 = gf_pow(x, 9, n; modulus)
        t = gf_trace(gf_mul(a3, x9, n; modulus), n; modulus)
        out[x+1] = x3 ⊻ gf_mul(ai, t, n; modulus)
    end
    out
end

# ── Block algebra on the packed 16-bit graph maps ────────────────────────────

hi(p::Integer) = UInt32((UInt32(p) >> N) & MASK)   # the x / x' half
lo(p::Integer) = UInt32(UInt32(p) & MASK)          # the y / y' half

# Apply an 8x8 F2 map given as 8 column images to an 8-bit vector.
function applymat(cols::Vector{UInt32}, x::Integer)
    r = UInt32(0)
    xx = UInt32(x)
    @inbounds for j = 0:(N-1)
        if (xx >> j) & 1 == 1
            r ⊻= cols[j+1]
        end
    end
    r
end

# Invert an 8x8 F2 map (columns) by Gauss-Jordan on [M | I]; nothing if singular.
function invmat(cols::Vector{UInt32})
    # rows[i] = bit-row i of M, augmented with identity in bits 8..15
    rows = zeros(UInt32, N)
    for i = 0:(N-1)
        r = UInt32(0)
        for j = 0:(N-1)
            ((cols[j+1] >> i) & 1) == 1 && (r |= UInt32(1) << j)
        end
        rows[i+1] = r | (UInt32(1) << (N + i))
    end
    piv = 1
    for col = 0:(N-1)
        p = findfirst(k -> (rows[k] >> col) & 1 == 1, piv:N)
        p === nothing && return nothing
        p += piv - 1
        rows[piv], rows[p] = rows[p], rows[piv]
        for k = 1:N
            k != piv && ((rows[k] >> col) & 1) == 1 && (rows[k] ⊻= rows[piv])
        end
        piv += 1
    end
    # inverse columns: column j of M^-1 is read off the augmented half
    inv_cols = zeros(UInt32, N)
    for i = 0:(N-1)          # row i of M^-1
        aug = (rows[i+1] >> N) & MASK
        for j = 0:(N-1)
            ((aug >> j) & 1) == 1 && (inv_cols[j+1] |= UInt32(1) << i)
        end
    end
    inv_cols
end

# ── Main ─────────────────────────────────────────────────────────────────────

function main()
    modulus_eq6 = Int(primitive_polynomial(N))          # 283
    Flut = apn_eq6_lut(N, 2; modulus = modulus_eq6)     # a = alpha = x = 2
    F = SBox{N}(Flut)
    G = load_apn_function("n8_Taniguchi2025_ex4_2")

    log_line("F  = apn_eq6(8, alpha) mod $modulus_eq6 : du=$(differential_uniformity(F)) deg=$(algebraic_degree(F))")
    log_line("G  = n8_Taniguchi2025_ex4_2            : du=$(differential_uniformity(G)) deg=$(algebraic_degree(G))")
    @assert differential_uniformity(F) == 2 && algebraic_degree(F) == 2
    @assert differential_uniformity(G) == 2 && algebraic_degree(G) == 2

    Glut = [Int(G.lut[x+1]) for x = 0:(NPTS-1)]

    ckpt = joinpath(ROOT, "certificates", ".phase0b_maps.json")
    local maps_cols::Vector{Vector{UInt32}}
    if isfile(ckpt)
        log_line("resuming from checkpoint $ckpt")
        raw = JSON3.read(read(ckpt, String))
        maps_cols = [UInt32.(collect(m)) for m in raw.maps]
    else
        log_line("computing ea_mappings_from_ortho_derivative(G, F) — expect ~400 s ...")
        t0 = time()
        maps = ea_mappings_from_ortho_derivative(G, F)
        el = time() - t0
        log_line("got $(length(maps)) graph mappings in $(round(el, digits=1)) s")
        maps_cols = [UInt32.(m.cols) for m in maps]
        open(ckpt, "w") do io
            JSON3.write(io, (; count = length(maps_cols), seconds = el,
                             maps = maps_cols))
        end
    end

    n_maps = length(maps_cols)
    if n_maps == 0
        println(JSON3.write((; ok = false,
            reason = "ea_mappings_from_ortho_derivative returned 0 mappings — the claimed EA-equivalence does NOT hold")))
        return 1
    end

    graphF = [(UInt32(x) << N) | UInt32(Flut[x+1]) for x = 0:(NPTS-1)]
    graphG_set = Set{UInt32}((UInt32(x) << N) | UInt32(Glut[x+1]) for x = 0:(NPTS-1))

    # Find the first mapping in EA form (Q = 0) whose constant c we can pin down.
    chosen = nothing
    n_ea_form = 0
    for (idx, cols) in enumerate(maps_cols)
        Q = UInt32[hi(cols[j+1]) for j = 0:(N-1)]        # y -> x' block
        all(iszero, Q) || continue                        # not an EA-form map
        n_ea_form += 1
        S = UInt32[lo(cols[j+1]) for j = 0:(N-1)]        # y -> y'
        P = UInt32[hi(cols[N+i+1]) for i = 0:(N-1)]      # x -> x'
        R = UInt32[lo(cols[N+i+1]) for i = 0:(N-1)]      # x -> y'
        Pinv = invmat(P)
        Pinv === nothing && continue

        image = UInt32[]
        for p in graphF
            x, y = hi(p), lo(p)
            push!(image, (applymat(P, x) << N) | (applymat(R, x) ⊻ applymat(S, y)))
        end
        # 0 in image (L linear, (0,0) in graph F) => c must lie in graph(G).
        imgset = Set(image)
        cfound = nothing
        for c in graphG_set
            if Set(UInt32(v ⊻ c) for v in imgset) == graphG_set
                cfound = c
                break
            end
        end
        cfound === nothing && continue
        chosen === nothing && (chosen = (; idx, P, Q, R, S, Pinv, c = cfound))
    end

    if chosen === nothing
        println(JSON3.write((; ok = false, n_maps,
            reason = "no returned mapping was in EA block form with a consistent constant")))
        return 1
    end

    P, R, S, Pinv, c = chosen.P, chosen.R, chosen.S, chosen.Pinv, chosen.c
    c1, c2 = hi(c), lo(c)
    k = applymat(Pinv, c1)                     # constant of A2

    # A2(x) = Pinv.x + k ;  A1 = S ;  A(x) = R(Pinv.x + k) + c2
    A2 = [Int(applymat(Pinv, x) ⊻ k) for x = 0:(NPTS-1)]
    A1 = [Int(applymat(S, y)) for y = 0:(NPTS-1)]
    Adrift = [Int(applymat(R, UInt32(A2[x+1])) ⊻ c2) for x = 0:(NPTS-1)]

    # ── The actual pointwise check, all 256 inputs ──────────────────────────
    mismatches = Int[]
    for x = 0:(NPTS-1)
        lhs = Glut[x+1]
        rhs = A1[Flut[A2[x+1]+1]+1] ⊻ Adrift[x+1]
        lhs == rhs || push!(mismatches, x)
    end
    ok = isempty(mismatches)

    # A1 and A2's linear part must be bijections for this to be an EA-equivalence.
    a1_bij = length(Set(A1)) == NPTS
    a2_bij = length(Set(A2)) == NPTS

    log_line("mappings=$n_maps  in_EA_form=$n_ea_form  chosen=#$(chosen.idx)  c=0x$(string(c, base=16))")
    log_line("pointwise check on 256 inputs: " * (ok ? "PASS" : "FAIL at $(length(mismatches)) points"))
    log_line("A1 bijective: $a1_bij   A2 bijective: $a2_bij")

    cert = (;
        phase = "0b",
        claim = "n8_Taniguchi2025_ex4_2 is EA-equivalent to Budaghyan-Carlet-Leander (2009) eq. (6) with a = alpha over GF(2^8)",
        audit_finding = "F001",
        verified = ok && a1_bij && a2_bij,
        identity_checked = "G(x) == A1[ F[ A2[x] ] ] XOR A(x) for all x in 0:255",
        n_inputs_checked = NPTS,
        n_mismatches = length(mismatches),
        mismatching_inputs = mismatches,
        A1_bijective = a1_bij,
        A2_bijective = a2_bij,
        F = (; name = "apn_eq6(8, a=alpha)", source = "Budaghyan-Carlet-Leander 2009, eq. (6), Corollary 3",
               modulus = modulus_eq6, a = 2, lut = Flut),
        G = (; name = "n8_Taniguchi2025_ex4_2",
               source = "Taniguchi-Polujan-Pott-Arshad 2025, Example 4.2", lut = Glut),
        A1 = (; kind = "linear", lut = A1, matrix_columns = Int.(S)),
        A2 = (; kind = "affine", lut = A2, matrix_columns = Int.(Pinv), constant = Int(k)),
        A  = (; kind = "affine_drift", lut = Adrift,
                matrix_columns = [Int(applymat(R, applymat(Pinv, UInt32(1) << j))) for j = 0:(N-1)],
                constant = Int(Adrift[1])),
        provenance = (;
            mappings_returned = n_maps,
            mappings_in_EA_block_form = n_ea_form,
            chosen_mapping_index = chosen.idx,
            graph_constant_c = Int(c),
            method = "ea_mappings_from_ortho_derivative(G, F), unpacked to an EA triple, then re-checked pointwise",
            note = "the pointwise check is independent of the search that produced the mapping",
        ),
    )
    open(joinpath(ROOT, "certificates", "taniguchi_ea.json"), "w") do io
        JSON3.pretty(io, cert)
    end
    log_line("wrote certificates/taniguchi_ea.json  verified=$(ok && a1_bij && a2_bij)")
    return (ok && a1_bij && a2_bij) ? 0 : 1
end

exit(main())
