# survey.jl — feasibility map: dim(V_A) for every BBL2021 class at n=7,8.
# Search cost is 2^dim; GPU ~1e9 cand/s ⇒ exhaustible iff dim ≲ 42.
include(joinpath(@__DIR__, "va_generic.jl"))
using .VAGeneric
import TOML

function survey()
    for n in (7, 8)
        f = joinpath(VAGeneric.TUPLES_DIR, "AllTuplesMatrices$n.toml")
        nclass = length(get(TOML.parsefile(f), "blocks", Any[]))
        println("=== n=$n : $nclass classes ===")
        for c in 1:nclass
            d = va_dim(n, c)
            tag = d <= 42 ? "exhaustible" : (d <= 50 ? "marginal" : "infeasible")
            println("  class $c: dim(V_A)=$d  2^dim≈1e$(round(Int, d*0.301))  $tag")
        end
    end
end

abspath(PROGRAM_FILE) == @__FILE__() && survey()
