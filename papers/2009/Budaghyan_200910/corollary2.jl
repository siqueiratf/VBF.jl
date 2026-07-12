# Implements Corollary 2 — parametric APN family from a permutation x+L(x³).
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218-4229.
# Section: II.A — The case n even.
#
# Corollary 2: n even, a∈GF(2ⁿ)*, b∈GF(2ⁿ), L linear. If x+L(x³) is a
#   permutation then  a·x³ + L(a³·x⁹ + a²b·x⁶ + ab²·x³)  is APN on GF(2ⁿ).
#
# Pseudocode:
#   L = trₙ (class-1 permutation);  for sampled (a,b): build the trinomial-arg
#   function; assert δ==2 and deg==2.
# VBF API used: differential_uniformity, algebraic_degree, SBox

include(joinpath(@__DIR__, "helpers.jl"))

"""
    corollary2_report(io; save_results) -> NamedTuple

Verify Corollary 2 for L=trₙ over a small deterministic grid of (a,b), n=6,8.
"""
function corollary2_report(io::IO = stdout; save_results::Bool = false)
    print_section("Corollary 2 — n even: a·x³+L(a³x⁹+a²b·x⁶+ab²·x³) APN", io)
    all_ok = true
    rows = Tuple{Int,Int,Int,Int,Int}[]
    for n in (6, 8)
        Llut = L_class_lut(:trace, n)                 # x+trₙ(x³) is a permutation
        α = primitive_element(n)
        for a in (1, α), b in (0, 1, α)
            F = as_sbox(apn_corollary2(n, a, b, Llut), n)
            du = differential_uniformity(F)
            deg = algebraic_degree(F)
            ok = du == 2 && deg == 2
            all_ok &= ok
            print_check("n=$n a=$a b=$b: APN (δ=$du, deg=$deg)", ok, io)
            push!(rows, (n, a, b, du, deg))
        end
    end
    print_kv("completeness", "sampled (a∈{1,α}, b∈{0,1,α}) — illustrative, not exhaustive", io)
    result = (; all_ok, rows)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "corollary2.toml"), "w") do f
            println(f, "# Corollary 2\nall_ok = $all_ok")
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    corollary2_report()
end
