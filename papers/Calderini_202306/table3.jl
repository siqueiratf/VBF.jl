# Implements Table 3 (known-family rows) from Calderini, Li, Villa (2023).
# Paper: Calderini, Li, Villa (2023), "Extending two families of bivariate APN functions",
#        Finite Fields and Their Applications.
# Section: 4.1 — Tables 1, 2 and 3: N_F for the known APN families over F_{2^12}
#
# Recomputes the N_F EA-invariant for representatives of each known APN family
# (N. 1-12 of Tables 1 and 2) at n=12, so the paper's novelty argument
# (Table 3: F1 and F2 hit values no known family attains) is self-contained
# instead of relying on the paper's transcribed MAGMA values.
#
# Pseudocode (table3_build):
#   1. For each known family N. 1-12, construct admissible representatives over
#      F_{2^12}; for families whose Table 3 row depends on the free parameter
#      (n. 2, 6, 7, 8) enumerate parameter classes, deduplicated by the
#      ortho-derivative differential spectrum (an EA-invariant)
#   2. sig = trim_signature(nonbent_signature(F)) for each representative
#   3. Check each sig is one of the paper's Table 3 rows for that family,
#      and that all 11 known-family rows of Table 3 are attained
#   4. Check N_F1, N_F2 (recomputed in section4_1) differ from EVERY known row
# VBF API used: gold_apn, bcp_apn, taniguchi_apn, terms_to_lut, subfield_elements,
#               gf_mul, gf_pow, gf_inv, gf_trace, gf_relative_trace, gf_is_dth_power,
#               is_quadratic_apn, differential_uniformity, ortho_derivative,
#               differential_spectrum, sorted_pairs, is_permutation,
#               nonbent_signature, SBox, print_section, print_check, print_kv

include(joinpath(@__DIR__, "section4_1.jl"))

# Paper Table 3 rows for the known families (N. as in Tables 1 and 2).
# Families sharing a table row are grouped exactly as in the paper.
const TABLE3_ROW_GOLD    = [[1365, 100100, 99840, 91]]                 # family n. 1
const TABLE3_ROWS_2_3_4  = [[1365, 100100, 141700],                    # families n. 2, 3 and 4
                            [1365, 100100, 144010, 140]]
const TABLE3_ROW_5_9_10_11 = [[1365, 100100, 142932]]                  # families n. 5, 9, 10, 11
# The vertical span of the "family n. 6" / "families n. 7 and 8" labels is
# ambiguous in the PDF/tex rendering of Table 3. Recomputation settles it:
# family 6 attains BOTH [.., 139980, 152] (a=1) and [.., 138918, 103] (a=2),
# while a-scans of families 7 and 8 attain exactly the other four rows.
const TABLE3_ROWS_6      = [[1365, 100100, 139980, 152],               # family n. 6
                            [1365, 100100, 138918, 103]]
const TABLE3_ROWS_7_8    = [[1365, 100100, 144728, 184],               # families n. 7 and 8
                            [1365, 100100, 143502, 198],
                            [1365, 100100, 144584, 229],
                            [1365, 100100, 143286, 155]]
const TABLE3_ROW_12      = [[1365, 100100, 144759, 126]]               # family n. 12

const TABLE3_KNOWN_ROWS = vcat(TABLE3_ROW_GOLD, TABLE3_ROWS_2_3_4,
                               TABLE3_ROW_5_9_10_11, TABLE3_ROWS_6,
                               TABLE3_ROWS_7_8, TABLE3_ROW_12)

# EA-invariant dedup key for quadratic APN candidates (ortho-derivative
# differential spectrum): distinct keys => distinct EA classes.
_od_key(F) = sorted_pairs(differential_spectrum(ortho_derivative(F)))

# --- representatives of the known families over F_{2^12} ---------------------

# N. 1 — Gold x^{2^i+1}, gcd(i, 12) = 1 [20]  (core constructor)
table3_family1(mod12) = [(gold_apn(12, 1; modulus = mod12), "i=1")]

# N. 2 — Budaghyan-Carlet-Leander binomial [8], n = 3k = 12  (core constructor;
# VBF's bcp_apn is exactly the n=3k binomial class of [8], Theorem 1).
# Enumerate the admissible s and keep one representative per EA class.
function table3_family2(mod12)
    reps = Tuple{SBox{12},String}[]
    seen = Set{Any}()
    for s in (1, 5, 7, 11)                          # gcd(s, 12) = 1
        F = try
            bcp_apn(4, s; modulus = mod12)
        catch e
            e isa ArgumentError && continue         # APN guarantee not met
            rethrow()
        end
        is_quadratic_apn(F) || continue
        key = _od_key(F)
        key in seen && continue
        push!(seen, key)
        push!(reps, (F, "k=4 s=$s"))
    end
    reps
end

# N. 3 — Bracken-Byrne-Markin-McGuire quadrinomial [3,4]:
#   u x^{2^s+1} + u^{2^k} x^{2^{2k}+2^{k+s}} + v x^{2^{2k}+1} + w u^{2^k+1} x^{2^s+2^{k+s}}
#   n = 3k = 12, 3 | (k+s), gcd(s, 3k) = 1, u primitive, v, w in F_{2^k}, vw != 1
function table3_family3(mod12)
    k, s, u = 4, 5, 2                    # 3 | 4+5, gcd(5,12)=1, 2 primitive
    e = [(1 << s) + 1,                              # 33
         (1 << (2k)) + (1 << (k + s)),              # 768  (2^{-k} = 2^{2k})
         (1 << (2k)) + 1,                           # 257
         (1 << s) + (1 << (k + s))]                 # 544
    u2k  = gf_pow(u, 1 << k, 12; modulus = mod12)
    u2k1 = gf_mul(u2k, u, 12; modulus = mod12)
    F16  = subfield_elements(12, 4; modulus = mod12)
    for v in F16, w in F16
        gf_mul(v, w, 12; modulus = mod12) == 1 && continue
        terms = [(u, e[1]), (u2k, e[2]), (v, e[3]),
                 (gf_mul(w, u2k1, 12; modulus = mod12), e[4])]
        F = SBox{12}(terms_to_lut(terms, 12, mod12))
        is_quadratic_apn(F) && return [(F, "k=4 s=5 u=2 v=$v w=$w")]
    end
    error("table3_family3: no APN member found")
end

# N. 4 — Li-Zhou-Li-Qu [28]: L(x)^{2^m+1} + v x^{2^m+1}, n = 3m = 12,
#   L(x) = x^{2^{m+s}} + mu x^{2^s} + x permutation, mu^{2^{2m}+2^m+1} != 1,
#   gcd(s, m) = 1, v in F_{2^m}^*
function table3_family4(mod12)
    m, s = 4, 1
    e17 = (1 << m) + 1
    circ = (1 << (2m)) + (1 << m) + 1               # 273
    F16 = subfield_elements(12, 4; modulus = mod12)
    for mu in 1:4095
        gf_pow(mu, circ, 12; modulus = mod12) == 1 && continue
        L = [gf_pow(x, 1 << (m + s), 12; modulus = mod12) ⊻
             gf_mul(mu, gf_pow(x, 1 << s, 12; modulus = mod12), 12; modulus = mod12) ⊻
             x for x in 0:4095]
        is_permutation(SBox{12}(L)) || continue
        for v in F16
            v == 0 && continue
            lut = [gf_pow(L[x + 1], e17, 12; modulus = mod12) ⊻
                   gf_mul(v, gf_pow(x, e17, 12; modulus = mod12), 12; modulus = mod12)
                   for x in 0:4095]
            F = SBox{12}(lut)
            is_quadratic_apn(F) && return [(F, "m=4 s=1 mu=$mu v=$v")]
        end
    end
    error("table3_family4: no APN member found")
end

# N. 5 — Budaghyan-Carlet hexanomial [7]: q = 2^m, n = 2m = 12, gcd(i, m) = 1,
#   s x^{q+1} + x^{2^i+1} + x^{q(2^i+1)} + c x^{2^i q+1} + c^q x^{2^i+q},
#   c s.t. z^{2^i+1} + c z^{2^i} + c^q z + 1 has no root on the unit circle,
#   s in F_{2^n} \ F_q
function table3_family5(mod12)
    q, i = 64, 1
    U = [z for z in 0:4095 if gf_pow(z, q + 1, 12; modulus = mod12) == 1]
    Fq = Set(subfield_elements(12, 6; modulus = mod12))
    for c in 1:4095
        cq = gf_pow(c, q, 12; modulus = mod12)
        ok = true
        for z in U
            val = gf_pow(z, 3, 12; modulus = mod12) ⊻
                  gf_mul(c, gf_pow(z, 2, 12; modulus = mod12), 12; modulus = mod12) ⊻
                  gf_mul(cq, z, 12; modulus = mod12) ⊻ 1
            val == 0 && (ok = false; break)
        end
        ok || continue
        for s in 1:4095
            s in Fq && continue
            terms = [(s, q + 1), (1, (1 << i) + 1), (1, q * ((1 << i) + 1)),
                     (c, (1 << i) * q + 1), (cq, (1 << i) + q)]
            F = SBox{12}(terms_to_lut(terms, 12, mod12))
            is_quadratic_apn(F) && return [(F, "i=1 c=$c s=$s")]
        end
    end
    error("table3_family5: no APN member found")
end

# N. 6 — Budaghyan-Carlet-Leander [9]: x^3 + a^{-1} tr_n(a^3 x^9), a != 0.
# The EA class depends on a (two Table 3 rows); enumerate a with the same
# stalled ortho-derivative dedup as families 7/8. Both classes appear at
# a = 1, 2; the stall window is a bounded reconfirmation margin.
function table3_family6(mod12; stall = 256)
    reps = Tuple{SBox{12},String}[]
    seen = Set{Any}()
    since_new = 0
    for a in 1:4095
        since_new ≥ stall && break
        since_new += 1
        ainv = gf_inv(a, 12; modulus = mod12)
        a3   = gf_pow(a, 3, 12; modulus = mod12)
        lut = [gf_pow(x, 3, 12; modulus = mod12) ⊻
               (gf_trace(gf_mul(a3, gf_pow(x, 9, 12; modulus = mod12), 12;
                                modulus = mod12), 12; modulus = mod12) == 1 ?
                ainv : 0) for x in 0:4095]
        F = SBox{12}(lut)
        differential_uniformity(F) == 2 || continue
        key = _od_key(F)
        key in seen && continue
        push!(seen, key)
        push!(reps, (F, "a=$a"))
        since_new = 0
    end
    isempty(reps) && error("table3_family6: no APN member found")
    reps
end

# N. 7 / N. 8 — Budaghyan-Carlet-Leander [10], 3 | n:
#   N.7: x^3 + a^{-1} tr^n_3(a^3 x^9  + a^6  x^18)
#   N.8: x^3 + a^{-1} tr^n_3(a^6 x^18 + a^12 x^36)
# The EA class depends on a, and the paper attributes four Table 3 rows to the
# pair; enumerate a in F_{2^12}^* and keep one representative per EA class
# (ortho-derivative differential-spectrum dedup). `stall` bounds the scan: stop
# after that many consecutive a values yielding no new class. Both classes of
# each family appear already at a = 1, 2; a one-off full 4095-value scan of
# N.7 (~34 min) found no further classes, so the default window is a bounded
# reconfirmation margin, not the exhaustive scan.
function _table3_family78(mod12, p1, e1, p2, e2, label; stall = 256)
    pow3 = [gf_pow(x, 3, 12; modulus = mod12) for x in 0:4095]
    pe1  = [gf_pow(x, e1, 12; modulus = mod12) for x in 0:4095]
    pe2  = [gf_pow(x, e2, 12; modulus = mod12) for x in 0:4095]
    reps = Tuple{SBox{12},String}[]
    seen = Set{Any}()
    since_new = 0
    for a in 1:4095
        since_new ≥ stall && break
        since_new += 1
        ainv = gf_inv(a, 12; modulus = mod12)
        c1 = gf_pow(a, p1, 12; modulus = mod12)
        c2 = gf_pow(a, p2, 12; modulus = mod12)
        lut = Vector{Int}(undef, 4096)
        for x in 0:4095
            t = gf_mul(c1, pe1[x + 1], 12; modulus = mod12) ⊻
                gf_mul(c2, pe2[x + 1], 12; modulus = mod12)
            tr = gf_relative_trace(t, 12, 3; modulus = mod12)
            lut[x + 1] = pow3[x + 1] ⊻ gf_mul(ainv, tr, 12; modulus = mod12)
        end
        F = SBox{12}(lut)
        differential_uniformity(F) == 2 || continue
        key = _od_key(F)
        key in seen && continue
        push!(seen, key)
        push!(reps, (F, "$label a=$a"))
        since_new = 0
    end
    isempty(reps) && error("table3_family78: no APN member found ($label)")
    reps
end
table3_family7(mod12) = _table3_family78(mod12, 3, 9, 6, 18, "N.7")
table3_family8(mod12) = _table3_family78(mod12, 6, 18, 12, 36, "N.8")

# N. 9 — Zhou-Pott [31]: the a = 0 member of the Taniguchi shape
#   (xy, x^{(2^k+1)2^{2k}} + b y^{2^k+1}), b not a cube (m even), gcd(k, m) = 1
function table3_family9(mod6)
    for b in 1:63
        gf_is_dth_power(b, 3, 6; modulus = mod6) && continue
        F = taniguchi_apn(6, 1, 0, b; modulus = mod6)
        is_quadratic_apn(F) && return [(F, "k=1 b=$b (non-cube)")]
    end
    error("table3_family9: no APN member found")
end

# N. 10 — Taniguchi [29]: (xy, x^{2^{3k}+2^{2k}} + a x^{2^{2k}} y^{2^k} + b y^{2^k+1}),
#   a != 0, z^{2^k+1} + a z + b with no root in F_{2^m}  (core constructor)
function table3_family10(mod6)
    for a in 1:63, b in 1:63
        rootless = all(z -> gf_pow(z, 3, 6; modulus = mod6) ⊻
                            gf_mul(a, z, 6; modulus = mod6) ⊻ b != 0, 0:63)
        rootless || continue
        F = taniguchi_apn(6, 1, a, b; modulus = mod6)
        is_quadratic_apn(F) && return [(F, "k=1 a=$a b=$b")]
    end
    error("table3_family10: no APN member found")
end

# N. 11 — Calderini-Budaghyan-Carlet [13]:
#   (xy, x^{2^i+1} + x^{2^{i+m/2}} y^{2^{m/2}} + b x y^{2^i} + c y^{2^i+1}), m = 6, i = 1
function table3_family11(mod6)
    mul6(a, b) = gf_mul(a, b, 6; modulus = mod6)
    pow6(a, e) = gf_pow(a, e, 6; modulus = mod6)
    for b in 0:63, c in 0:63
        lut = Vector{Int}(undef, 4096)
        for x in 0:63, y in 0:63
            g = pow6(x, 3) ⊻ mul6(pow6(x, 16), pow6(y, 8)) ⊻
                mul6(b, mul6(x, pow6(y, 2))) ⊻ mul6(c, pow6(y, 3))
            lut[(x | (y << 6)) + 1] = mul6(x, y) | (g << 6)
        end
        F = SBox{12}(lut)
        is_quadratic_apn(F) && return [(F, "i=1 b=$b c=$c")]
    end
    error("table3_family11: no APN member found")
end

# N. 12 — Gologlu-Kolsch [23]:
#   (x^{2^k+1} + B y^{2^k+1}, x^{2^{k+m/2}} y + (a/B) x y^{2^{k+m/2}}),
#   m = 6 (m = 2 mod 4), k = 1, B not a cube, a in F_{2^{m/2}}^*, B^{2^k+2^{k+m/2}} != a^{2^k+1}
function table3_family12(mod6)
    mul6(u, v) = gf_mul(u, v, 6; modulus = mod6)
    pow6(u, e) = gf_pow(u, e, 6; modulus = mod6)
    F8 = subfield_elements(6, 3; modulus = mod6)
    for B in 1:63
        gf_is_dth_power(B, 3, 6; modulus = mod6) && continue
        for a in F8
            a == 0 && continue
            pow6(B, 2 + 16) == pow6(a, 3) && continue
            aB = mul6(a, gf_inv(B, 6; modulus = mod6))
            lut = Vector{Int}(undef, 4096)
            for x in 0:63, y in 0:63
                f = pow6(x, 3) ⊻ mul6(B, pow6(y, 3))
                g = mul6(pow6(x, 16), y) ⊻ mul6(aB, mul6(x, pow6(y, 16)))
                lut[(x | (y << 6)) + 1] = f | (g << 6)
            end
            F = SBox{12}(lut)
            is_quadratic_apn(F) && return [(F, "k=1 B=$B a=$a")]
        end
    end
    error("table3_family12: no APN member found")
end

const TABLE3_FAMILIES = [
    (no = 1,  rows = TABLE3_ROW_GOLD,      ref = "[20] Gold",                          build = :n12),
    (no = 2,  rows = TABLE3_ROWS_2_3_4,    ref = "[8] Budaghyan-Carlet-Leander",       build = :n12),
    (no = 3,  rows = TABLE3_ROWS_2_3_4,    ref = "[3,4] Bracken-Byrne-Markin-McGuire", build = :n12),
    (no = 4,  rows = TABLE3_ROWS_2_3_4,    ref = "[28] Li-Zhou-Li-Qu",                 build = :n12),
    (no = 5,  rows = TABLE3_ROW_5_9_10_11, ref = "[7] Budaghyan-Carlet hexanomial",    build = :n12),
    (no = 6,  rows = TABLE3_ROWS_6,        ref = "[9] Budaghyan-Carlet-Leander",       build = :n12),
    (no = 7,  rows = TABLE3_ROWS_7_8,      ref = "[10] Budaghyan-Carlet-Leander",      build = :n12),
    (no = 8,  rows = TABLE3_ROWS_7_8,      ref = "[10] Budaghyan-Carlet-Leander",      build = :n12),
    (no = 9,  rows = TABLE3_ROW_5_9_10_11, ref = "[31] Zhou-Pott",                     build = :m6),
    (no = 10, rows = TABLE3_ROW_5_9_10_11, ref = "[29] Taniguchi",                     build = :m6),
    (no = 11, rows = TABLE3_ROW_5_9_10_11, ref = "[13] Calderini-Budaghyan-Carlet",    build = :m6),
    (no = 12, rows = TABLE3_ROW_12,        ref = "[23] Gologlu-Kolsch",                build = :m6),
]

const TABLE3_BUILDERS = Dict(
    1 => table3_family1,  2 => table3_family2,  3 => table3_family3,
    4 => table3_family4,  5 => table3_family5,  6 => table3_family6,
    7 => table3_family7,  8 => table3_family8,  9 => table3_family9,
    10 => table3_family10, 11 => table3_family11, 12 => table3_family12,
)

function table3_build(; full_search::Bool = false)
    if !full_search
        return (; skipped = true,
                  note = "Set full_search=true or run 'make table3' for the known-family N_F recomputation (~10 min)")
    end
    mod12 = primitive_polynomial(12)
    mod6  = primitive_polynomial(6)

    rows = NamedTuple[]
    for fam in TABLE3_FAMILIES
        modulus = fam.build == :n12 ? mod12 : mod6
        for (F, params) in TABLE3_BUILDERS[fam.no](modulus)
            apn = differential_uniformity(F) == 2
            sig = trim_signature(nonbent_signature(F))
            push!(rows, (; fam.no, fam.ref, params, apn, sig,
                           match = sig in fam.rows))
        end
    end

    # Novelty: N_F1/N_F2 (recomputed in section4_1) differ from every known row
    s41 = section4_1_build(full_search = true)
    novel_f1 = !(s41.sig1 in TABLE3_KNOWN_ROWS)
    novel_f2 = !(s41.sig2 in TABLE3_KNOWN_ROWS)
    # ... and the representatives attain every known-family row of Table 3
    attained = unique([r.sig for r in rows])
    missing_rows = [row for row in TABLE3_KNOWN_ROWS if !(row in attained)]

    (; skipped = false, rows, s41, novel_f1, novel_f2, attained, missing_rows)
end

function table3_report(io::IO = stdout; full_search::Bool = false)
    print_section("Table 3 — N_F for the known APN families over F_{2^12}", io)
    println(io, "  Representatives of the known families (N. 1-12 of Tables 1 and 2),")
    println(io, "  recomputed so the novelty of F1/F2 does not rely on transcribed values")

    r = table3_build(; full_search = full_search)
    if r.skipped
        println(io, "  [SKIP] $(r.note)")
        return
    end

    all_match = true
    for row in r.rows
        print_kv("family n. $(row.no) $(row.ref)", row.params, io)
        print_check("  APN + N_F = $(row.sig) in paper's row(s) for family $(row.no)",
                    row.apn && row.match, io)
        all_match = all_match && row.apn && row.match
    end
    print_check("all known-family representatives reproduce their Table 3 rows", all_match, io)
    print_check("every known-family Table 3 row attained ($(length(r.attained))/$(length(TABLE3_KNOWN_ROWS)) distinct)",
                isempty(r.missing_rows), io)
    for row in r.missing_rows
        println(io, "  MISSING row: $row")
    end
    print_kv("N_F1 (recomputed)", r.s41.sig1, io)
    print_kv("N_F2 (recomputed)", r.s41.sig2, io)
    print_check("N_F1 differs from all known-family rows (F1 new)", r.novel_f1, io)
    print_check("N_F2 differs from all known-family rows (F2 new)", r.novel_f2, io)
    println(io, "  completeness: one representative per EA class found by the parameter")
    println(io, "  scans above; families sharing a Table 3 row are checked against the")
    println(io, "  shared row set, exactly as printed in the paper")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_banner()
    table3_report(; full_search = true)
end
