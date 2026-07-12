# Implements §4 — On a cyclic approach to search for quadratic APN functions.
# Paper: Kalgin, Idrisova (2020), "The classification of quadratic APN functions
#        in 7 variables", Cryptography and Communications 14, pp. 691–715.
# Section: §4 — Cyclic matrix T construction, APN search, new n=7 function.
#
# Pseudocode:
#   1. Define cyclic matrix T(n): T[i,j] = e_{i+j-2} = 2^{i+j-3} when i+j ≤ n+2,
#      unknown (0) otherwise. Symmetric, zero diagonal.
#   2. For modified T (remove_e_n=true): also treat positions with i+j = n+2
#      as unknown (removes the sub-diagonal containing e_n).
#   3. Backtrack over unknown entries in {0,...,2^n-1}, check is_qam at completion.
#   4. New n=7 function: given in paper as univariate polynomial over GF(2^7)
#      with primitive element a (min poly x^7+x+1). Convert via polynomial_to_lut.
#   5. Verify: new function is APN (differential_uniformity=2), quadratic (deg=2),
#      CCZ-distinct from Gold in n=7 (different apn_ea_mugshot).
#
# VBF API used: is_qam, qam_to_sbox, quadratic_apn_matrix, apn_ea_mugshot,
#               gold_apn, differential_uniformity, algebraic_degree,
#               polynomial_to_lut, primitive_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

# ── Cyclic matrix T ──────────────────────────────────────────────────────────

"""
    kalgin_T(n; remove_e_n) -> (Matrix{Int}, Matrix{Bool})

The cyclic matrix T for dimension n (§4, eq. before §4.1):
  T[i,j] = e_{i+j-2} = 2^{i+j-3}  when  i+j ≤ n+2  (or i+j < n+2 if remove_e_n)
  T[i,j] = 0 (unknown)             otherwise.

Returns (M, known): M[i,j] is the value; known[i,j] is true iff the entry is fixed.
Symmetric, zero diagonal.
"""
function kalgin_T(n::Int; remove_e_n::Bool = false)
    M = zeros(Int, n, n)
    known = trues(n, n)
    threshold = remove_e_n ? (n + 1) : (n + 2)   # i+j ≤ threshold ⟹ fixed
    @inbounds for i = 1:n, j = (i+1):n
        if i + j <= threshold
            v = 1 << (i + j - 3)     # e_{i+j-2}
            M[i, j] = M[j, i] = v
        else
            known[i, j] = known[j, i] = false
        end
    end
    (M, known)
end

"""
    unknown_positions(known::Matrix{Bool}) -> Vector{Tuple{Int,Int}}

Return (i,j) pairs with i < j for which known[i,j] == false.
"""
function unknown_positions(known::AbstractMatrix{Bool})
    n = size(known, 1)
    [(i, j) for i = 1:n for j = (i+1):n if !known[i, j]]
end

# ── Cyclic search ────────────────────────────────────────────────────────────

"""
    cyclic_apn_search(n; remove_e_n, limit) -> Vector{SBox}

Search for APN functions with the cyclic matrix T structure for dimension n.
Backtracks over unknown positions, using is_qam at completion.
Returns up to limit APN SBox-es (deduplicated by EA-class internally).
"""
function cyclic_apn_search(
    n::Int;
    remove_e_n::Bool = false,
    limit::Int = typemax(Int),
)
    M, known = kalgin_T(n; remove_e_n = remove_e_n)
    upos = unknown_positions(known)
    field_size = 1 << n
    results = SBox[]
    seen_sigs = Set{Any}()

    function rec!(k)
        length(results) >= limit && return
        if k > length(upos)
            is_qam(M) || return
            f = qam_to_sbox(M)
            sig = apn_ea_mugshot(f)
            sig ∉ seen_sigs && (push!(seen_sigs, sig); push!(results, f))
            return
        end
        i, j = upos[k]
        for v = 0:(field_size-1)
            M[i, j] = M[j, i] = v
            rec!(k + 1)
            length(results) >= limit && return
        end
        M[i, j] = M[j, i] = 0
    end

    rec!(1)
    results
end

# ── New n=7 function (§4) ────────────────────────────────────────────────────

"""
    new_apn_function_n7() -> SBox{7}

The new CCZ-class representative for n=7 from §4, given in univariate form:
  F(x) = a^100 x + a^88 x^2 + ... + a^20 x^96
where a is the primitive element of GF(2^7) with min poly x^7+x+1.
VBF's primitive_polynomial(7) = 0b10000011 = x^7+x+1, generator a = 2.
"""
function new_apn_function_n7()
    n = 7
    modulus = primitive_polynomial(n)   # x^7+x+1 = 0b10000011 = 131
    poly = join(
        [
            "a^100*x",
            "a^88*x^2", "a^89*x^3", "a^107*x^4", "a^57*x^5", "a^98*x^6",
            "a^56*x^8", "a^9*x^9", "a^58*x^10", "a^60*x^12",
            "a^109*x^16", "a^47*x^17", "a^44*x^18", "a^27*x^20", "a^91*x^24",
            "a^71*x^32", "a^96*x^33", "a^101*x^34", "a^7*x^36",
            "a^12*x^40", "a^34*x^48",
            "a^66*x^64", "a^4*x^65", "a^4*x^66", "a^73*x^68", "a^73*x^72",
            "a^56*x^80", "a^20*x^96",
        ],
        " + ",
    )
    lut = polynomial_to_lut(poly, n, modulus)
    SBox{n}(lut)
end

# ── Section report ───────────────────────────────────────────────────────────

"""
    section4_report(io; save_results) -> NamedTuple

§4 reproduction:
- Verify cyclic T for n=3,4,5 gives ≥1 APN function.
- Verify the new n=7 function from the paper is APN and quadratic.
- Verify it is CCZ-distinct from Gold n=7.
"""
function section4_report(io::IO = stdout; save_results::Bool = false) :: NamedTuple
    print_section("§4 — Cyclic matrix T construction", io)

    # n=3: T has no unknowns → unique function
    M3, known3 = kalgin_T(3)
    upos3 = unknown_positions(known3)
    print_kv("n=3 cyclic T unknowns", length(upos3), io)
    n3_apn = is_qam(M3)
    print_check("n=3 cyclic T represents an APN function", n3_apn, io)

    # n=4: 1 unknown
    M4, known4 = kalgin_T(4)
    upos4 = unknown_positions(known4)
    print_kv("n=4 cyclic T unknowns", length(upos4), io)
    fns4 = cyclic_apn_search(4; limit = 50)
    print_kv("n=4 cyclic T search: EA-classes found", length(fns4), io)
    print_check("n=4 cyclic T: ≥1 APN function found", length(fns4) >= 1, io)

    # n=5: 2 unknowns
    M5, known5 = kalgin_T(5)
    upos5 = unknown_positions(known5)
    print_kv("n=5 cyclic T unknowns", length(upos5), io)
    fns5 = cyclic_apn_search(5; limit = 100)
    print_kv("n=5 cyclic T search: EA-classes found", length(fns5), io)
    print_check("n=5 cyclic T: ≥1 APN function found", length(fns5) >= 1, io)
    print_kv(
        "  note",
        "standard T for n=5 covers $(length(fns5)) CCZ-class(es); paper §4 claims all 3 via general construction",
        io,
    )

    # New n=7 function
    print_section("§4 — New n=7 APN function (paper's key result)", io)
    F7 = new_apn_function_n7()
    du7 = differential_uniformity(F7)
    deg7 = algebraic_degree(F7)
    print_kv("differential_uniformity", du7, io)
    print_kv("algebraic_degree", deg7, io)
    print_check("new n=7 function: APN (differential_uniformity = 2)", du7 == 2, io)
    print_check("new n=7 function: quadratic (algebraic_degree = 2)", deg7 == 2, io)

    # CCZ-distinctness from Gold
    gold7 = gold_apn(7)
    sig_new = apn_ea_mugshot(F7)
    sig_gold = apn_ea_mugshot(gold7)
    distinct = sig_new != sig_gold
    print_check("new n=7 function: CCZ-distinct from Gold n=7", distinct, io)
    print_kv("completeness note", "exhaustive classification (488 classes) is out-of-scope", io)

    result = (;
        n3_is_apn = n3_apn,
        n4_ea_classes = length(fns4),
        n5_ea_classes = length(fns5),
        new_n7_du = du7,
        new_n7_deg = deg7,
        new_n7_distinct_from_gold = distinct,
    )

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "section4.toml"), "w") do f
            println(f, "# section4 results")
            for (k, v) in pairs(result)
                println(f, "$k = $v")
            end
        end
    end

    result
end
