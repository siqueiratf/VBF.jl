# Implements §6 — Using quadratic functions to search for APN functions of
# higher algebraic degree (Table 3 examples: stacked APN functions).
# Paper: Kalgin, Idrisova (2020), "The classification of quadratic APN functions
#        in 7 variables", Cryptography and Communications 14, pp. 691–715.
# Section: §6.1 — Definition 1 (stacked APN), Table 3 examples.
#
# Pseudocode:
#   1. Definition 1: F = F^{(2)} + ... + F^{(d)} is stacked APN iff
#      F - F^{(d)}, F - F^{(d)} - F^{(d-1)}, ..., F^{(2)} are all APN.
#   2. For d=3: F is stacked APN iff both F and F^{(2)} are APN.
#   3. Table 3 gives examples for n=4,5,6: verify F is APN (deg 3),
#      F^{(2)} is APN (deg 2), and F ≠ F^{(2)}.
#
# VBF API used: SBox, differential_uniformity, algebraic_degree, quadratic_part (helpers)

include(joinpath(@__DIR__, "helpers.jl"))

# ── Table 3 data ─────────────────────────────────────────────────────────────

"""
    stacked_n4() -> SBox{4}

Table 3 n=4 example: cubic stacked APN function F (deg 3).
"""
stacked_n4() = SBox{4}([0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 6, 3, 8, 14, 11, 12])

"""
    stacked_n4_quadpart() -> SBox{4}

Table 3 n=4 example: quadratic part F^{(2)} (deg 2, APN).
"""
stacked_n4_quadpart() = SBox{4}([0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 6, 3, 8, 14, 10, 13])

"""
    stacked_n5() -> SBox{5}

Table 3 n=5 example: cubic stacked APN function F (deg 3).
"""
stacked_n5() = SBox{5}([
    0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 10, 15, 19, 21, 28, 27,
    0, 8, 16, 25, 11, 1, 29, 22, 15, 3, 17, 28, 31, 17, 6, 9,
])

"""
    stacked_n5_quadpart() -> SBox{5}

Table 3 n=5 example: quadratic part F^{(2)} (deg 2, APN).
"""
stacked_n5_quadpart() = SBox{5}([
    0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 10, 15, 19, 21, 29, 26,
    0, 8, 16, 25, 11, 1, 31, 20, 15, 3, 21, 24, 23, 25, 9, 6,
])

"""
    stacked_n6() -> SBox{6}

Table 3 n=6 example: cubic stacked APN function F (deg 3).
"""
stacked_n6() = SBox{6}([
    0, 0, 0, 1, 0, 2, 4, 13, 0, 4, 8, 7, 16, 22, 28, 27,
    0, 8, 16, 19, 9, 3, 29, 22, 45, 33, 53, 56, 52, 58, 40, 45,
    0, 16, 60, 45, 26, 8, 34, 59, 55, 35, 3, 28, 61, 43, 13, 26,
    5, 29, 41, 58, 22, 12, 62, 37, 31, 3, 59, 38, 28, 2, 60, 41,
])

"""
    stacked_n6_quadpart() -> SBox{6}

Table 3 n=6 example: quadratic part F^{(2)} (deg 2, APN).
"""
stacked_n6_quadpart() = SBox{6}([
    0, 0, 0, 1, 0, 2, 4, 7, 0, 4, 8, 13, 16, 22, 28, 27,
    0, 8, 16, 25, 9, 3, 29, 22, 45, 33, 53, 56, 52, 58, 40, 39,
    0, 16, 60, 45, 26, 8, 34, 49, 55, 35, 3, 22, 61, 43, 13, 26,
    5, 29, 41, 48, 22, 12, 62, 37, 31, 3, 59, 38, 28, 2, 60, 35,
])

# ── Verification ─────────────────────────────────────────────────────────────

"""
    verify_stacked_cubic(F, F2, io; label) -> NamedTuple

Verify the stacked APN property for a cubic APN F and its quadratic part F^{(2)}:
- F is APN (differential_uniformity = 2)
- F has algebraic_degree = 3
- F^{(2)} is APN
- F^{(2)} has algebraic_degree = 2
- quadratic_part(F) == F2 (matches the provided quadratic part)
- F ≠ F^{(2)} (they differ somewhere)
"""
function verify_stacked_cubic(F::SBox{N}, F2_ref::SBox{N}, io::IO = stdout; label::String = "") where N
    tag = isempty(label) ? "" : " ($label)"
    du_F  = differential_uniformity(F)
    deg_F = algebraic_degree(F)
    du_F2 = differential_uniformity(F2_ref)
    deg_F2 = algebraic_degree(F2_ref)
    F2_computed = quadratic_part(F)
    F2_match = F2_computed == F2_ref
    not_equal = F != F2_ref

    print_check("F$tag: APN (du=2)", du_F == 2, io)
    print_check("F$tag: cubic (deg=3)", deg_F == 3, io)
    print_check("F^(2)$tag: APN (du=2)", du_F2 == 2, io)
    print_check("F^(2)$tag: quadratic (deg=2)", deg_F2 == 2, io)
    print_check("quadratic_part(F)$tag == F^(2) from paper", F2_match, io)
    print_check("F$tag ≠ F^(2)$tag", not_equal, io)

    (;
        du_F, deg_F, du_F2, deg_F2,
        F2_match, not_equal,
        ok = du_F == 2 && deg_F == 3 && du_F2 == 2 && deg_F2 == 2 && F2_match && not_equal,
    )
end

# ── Section report ───────────────────────────────────────────────────────────

"""
    table3_report(io; save_results) -> NamedTuple

§6 Table 3 reproduction: verify all three stacked APN examples.
"""
function table3_report(io::IO = stdout; save_results::Bool = false) :: NamedTuple
    print_section("§6 — Stacked APN functions (Table 3)", io)

    print_kv(
        "Definition 1 (stacked APN)",
        "F = F^{(2)}+...+F^{(d)} is stacked APN iff all truncations are APN",
        io,
    )
    print_kv("Table 3 scope", "cubic stacked APN (d=3): both F and F^{(2)} are APN", io)

    print_section("n=4 example", io)
    r4 = verify_stacked_cubic(stacked_n4(), stacked_n4_quadpart(), io; label = "n=4")

    print_section("n=5 example", io)
    r5 = verify_stacked_cubic(stacked_n5(), stacked_n5_quadpart(), io; label = "n=5")

    print_section("n=6 example", io)
    r6 = verify_stacked_cubic(stacked_n6(), stacked_n6_quadpart(), io; label = "n=6")

    print_section("Summary", io)
    all_ok = r4.ok && r5.ok && r6.ok
    print_check("all three Table 3 examples verified as stacked cubic APN", all_ok, io)

    result = (;
        n4_ok = r4.ok,
        n5_ok = r5.ok,
        n6_ok = r6.ok,
        all_ok,
    )

    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "table3.toml"), "w") do f
            println(f, "# table3 results")
            for (k, v) in pairs(result)
                println(f, "$k = $v")
            end
        end
    end

    result
end
