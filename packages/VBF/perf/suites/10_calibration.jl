# Retain the primitive dimensions used by the historical calibration evidence.
function register!(reg)
    for n in (8,9,10)
        benchmark!(reg;group="invariants",name="is_apn_verification",n,
            setup=()->gold_apn(n,1),call=F->differential_uniformity(F)==2,
            validate=(p,v)->(@assert v),note="complete APN check on known Gold input")
        for (name,call) in (("ortho_derivative",ortho_derivative),("sigma_key",sigma_key),("sigma_hash",sigma_hash))
            haskey(reg.metadata,("invariants",name,n)) && continue
            benchmark!(reg;group="invariants",name,n,setup=()->gold_apn(n,1),call,
                note="historical calibration dimensions, fresh Gold payload")
        end
    end
end
