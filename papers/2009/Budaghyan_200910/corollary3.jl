# Implements Corollary 3 — the concrete APN families (6),(7),(8), n even.
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218-4229.
# Section: II.A — The case n even.
#
# Corollary 3: a∈GF(2ⁿ)*.  For n even
#   (6)  x³ + a⁻¹·trₙ(a³·x⁹)
# is APN, and for 6 | n
#   (7)  x³ + a⁻¹·trₙ³(a⁶·x¹⁸ + a¹²·x³⁶)
#   (8)  x³ + a⁻¹·trₙ³(a³·x⁹  + a⁶·x¹⁸)
# are APN. Moreover (6) gives at most two cases a=1, a=α, and for n=6,8 the
# a=1 case x³+trₙ(x⁹) is CCZ-INEQUIVALENT to the a=α case — a NEW class.
#
# Pseudocode:
#   verify APN+quadratic for (6)[n=6,8], (7),(8)[n=6];
#   sig1 = ortho-deriv spectrum of (6) with a=1;  sigα = same with a=α;
#   sig1 ≠ sigα  ⟹  CCZ-inequivalent (quadratic-APN CCZ invariant).
# VBF API used: differential_uniformity, algebraic_degree, ortho_derivative,
#               differential_spectrum, sorted_pairs

include(joinpath(@__DIR__, "helpers.jl"))

"""
    corollary3_report(io; full_search, save_results) -> NamedTuple

Verify eqs (6),(7),(8) APN (n even) and the n=6,8 new-class CCZ-inequivalence
`x³+trₙ(x⁹)` vs `x³+α⁻¹trₙ(α³x⁹)`.
"""
function corollary3_report(
    io::IO = stdout;
    full_search::Bool = false,
    save_results::Bool = false,
)
    print_section("Corollary 3 — eqs (6),(7),(8) APN (n even)", io)
    all_ok = true
    rows = Tuple{Int,Symbol,Int,Int,Int}[]
    # (6): n even.
    ns6 = full_search ? [6, 8, 10] : [6, 8]
    for n in ns6, a in (1, primitive_element(n))
        F = as_sbox(apn_eq6(n, a), n)
        du = differential_uniformity(F); deg = algebraic_degree(F)
        ok = du == 2 && deg == 2; all_ok &= ok
        print_check("eq(6) n=$n a=$a: APN (δ=$du, deg=$deg)", ok, io)
        push!(rows, (n, :eq6, a, du, deg))
    end
    # (7),(8): 6 | n.
    ns7 = full_search ? [6, 12] : [6]
    for n in ns7, (name, f) in ((:eq7, apn_eq7), (:eq8, apn_eq8)), a in (1, primitive_element(n))
        F = as_sbox(f(n, a), n)
        du = differential_uniformity(F); deg = algebraic_degree(F)
        ok = du == 2 && deg == 2; all_ok &= ok
        print_check("$name n=$n a=$a: APN (δ=$du, deg=$deg)", ok, io)
        push!(rows, (n, name, a, du, deg))
    end

    print_section("Corollary 3 — new class: x³+trₙ(x⁹) vs x³+α⁻¹trₙ(α³x⁹) (n=6,8)", io)
    newclass = Tuple{Int,Bool}[]
    for n in (6, 8)
        α = primitive_element(n)
        s1 = od_signature(apn_eq6(n, 1), n)          # a = 1
        sa = od_signature(apn_eq6(n, α), n)          # a = α
        distinct = s1 !== nothing && sa !== nothing && s1 != sa
        all_ok &= distinct
        print_check("n=$n: ortho-deriv signatures differ ⟹ CCZ-inequivalent", distinct, io)
        print_kv("n=$n sig(a=1)", s1, io)
        print_kv("n=$n sig(a=α)", sa, io)
        push!(newclass, (n, distinct))
    end
    print_kv("method", "ortho-derivative spectrum (quadratic-APN CCZ invariant; one-way)", io)

    result = (; all_ok, rows, newclass)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "corollary3.toml"), "w") do f
            println(f, "# Corollary 3\nall_ok = $all_ok")
            for (n, d) in newclass
                println(f, "[[newclass]]\nn=$n\nccz_distinct=$d")
            end
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    corollary3_report()
end
