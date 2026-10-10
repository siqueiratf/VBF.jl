function register!(reg)
    benchmark!(reg; group="diagnostics", name="gamma_rank", n=8, cost=3, samples=1,
         setup=()->gold_apn(8,1),
         call=F->gamma_rank(F;allow_large=true,max_memory_bytes=2*1024^3,timeout_seconds=600),
         validate=(p,v)->(@assert v==11818),
         note="public opt-in n8 rank, 2 GiB estimated-storage budget and 600-second deadline")
end
