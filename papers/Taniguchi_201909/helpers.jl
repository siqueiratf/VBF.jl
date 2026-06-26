using Dates

function print_header(io::IO = stdout)
    println(io, "=" ^ 70)
    println(io, "Taniguchi (2019), \"On some quadratic APN functions\"")
    println(io, "Julia $(VERSION)  |  $(today())")
    println(io, "=" ^ 70)
    println(io)
    println(io, "Scope:")
    println(io, "  [exact]  Theorem 3: APN iff P(x) rootless (half=4,5)")
    println(io, "  [exact]  Theorem 4: alternate form, EA-equiv to Thm 3")
    println(io, "  [exact]  Fact (Helleseth-Kholosha): rootless-b count n=5,6,7")
    println(io, "  [exact]  Section 2: Carlet Thm 1 + Zhou-Pott Cor 1 (small n)")
    println(io, "  [exact]  Theorem 5: presemifield no-zero-divisors (GF(2⁴)/GF(2²))")
    println(io, "  [loaded] Γ-ranks 13200/13642/13700/13798 on F₂⁸ (Magma, paper Table)")
    println(io, "  [skip]   Theorem 6: nuclei ≅ K (algebraic proof only)")
    println(io)
end

