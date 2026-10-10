include(joinpath(@__DIR__, "..", "gamma8_probe.jl"))
function register!(reg)
    benchmark!(reg; group="diagnostics", name="gamma_rank_unguarded", n=8, cost=3, samples=1,
         setup=()->gold_apn(8,1), call=gamma8,
         validate=(p,v)->(@assert v==11818), note="guard-bypassing research probe, ~1 GB")
end
