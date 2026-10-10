function register!(reg)
    for n in (8, 10)
        benchmark!(reg; group="invariants", name="sigma_hash", n, setup=()->gold_apn(n,1),
             call=sigma_hash, note="ortho-derivative signature")
    end
    benchmark!(reg; group="invariants", name="ccz_fingerprint_hash", n=8,
         setup=()->gold_apn(8,1), call=ccz_fingerprint_hash, note="tier 2 fingerprint")
    for n in (6,7)
        benchmark!(reg; group="invariants", name="ccz_fingerprint_key", n, cost=n==7 ? 3 : 1,
             setup=()->gold_apn(n,1), call=ccz_fingerprint_key,
             samples=n==7 ? 3 : 0, note="tier 1 fingerprint with design ranks")
    end
end
