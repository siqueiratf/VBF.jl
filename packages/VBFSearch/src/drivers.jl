"""Execute one bounded construction unit; persistence and candidate evidence stay in the application."""
function process_unit!(store,unit,config;reference,geometry,work,known,remaining,stop_wanted)
    localref=reference
    payload=DiscoveryStore.parse_toml(unit["payload"])
    F=SBox{8,UInt8}(hex2bytes(payload["lut_hex"]))
    if unit["kind"]=="switching"
        verify_ccz_witness(hex2bytes(unit["lut_hex"]),F.lut,
            payload["ccz_columns"],payload["ccz_constant"]) || error("invalid saved parent CCZ map")
    end
    parent=classify(F.lut,localref)
    parent["apn"] || error("non-APN seed")
    parent["role"]="seed";parent["additional_signature"]=false
    get(parent,"sigma_hash",unit["sigma"])==unit["sigma"] || error("seed signature mismatch")
    register!(store,parent)
    if unit["kind"]=="prepare_ea"
        orbit=ea_class_representatives(F;prefer_permutations=false,
            subspace_algorithm=:optimized,timeout_seconds=min(config.slice,config.orbit_duration,remaining()))
        selected=0
        for (j,G) in enumerate(orbit.representatives)
            algebraic_degree(G)==2 && continue
            A=orbit.mappings[j]
            verify_ccz_witness(F.lut,G.lut,Int.(A.linear.cols),Int(A.constant)) || error("invalid orbit witness")
            add_unit!(store,unit["seed_id"],"switching",Dict("lut_hex"=>bytes2hex(G.lut),
                "ccz_columns"=>Int.(A.linear.cols),"ccz_constant"=>Int(A.constant),"orbit_index"=>j))
            selected+=1
            selected>=config.ea_representatives && break
        end
        finish!(store,unit,Dict("orbit_complete"=>orbit.complete,"available"=>length(orbit.representatives),
            "selected_nonquadratic"=>selected,"representative_cap"=>config.ea_representatives,
            "stop"=>string(orbit.stop_reason));done=true)
    elseif unit["kind"]=="prepare_v5"
        parent["quadratic"] || error("V5 requires quadratic APN")
        a=anf(F)
        c=UInt16[a[((1<<i)|(1<<j))+1] for i in 0:7 for j in (i+1):7]
        comp=Fourier.comp_forms(Fourier.coord_forms(c,8));bent=Fourier.bent_mask(geometry,comp)
        best=first(Fourier.max_bent_dim(comp,bent,5))
        want=config.bent=="max" ? Set([best]) : Set(parse.(Int,split(config.bent,',')))
        spaces=Fourier.subspaces_of_comp(comp,bent,5;keep=n->n in want)
        for V in spaces
            need=config.target_b6-V.nbent
            need<0 && continue
            add_unit!(store,unit["seed_id"],"v5",Dict("lut_hex"=>payload["lut_hex"],"forms"=>Int.(V.forms),"need"=>need))
        end
        finish!(store,unit,Dict("v5_spaces"=>length(spaces),"heuristic_pruning"=>false);done=true)
    elseif unit["kind"]=="v5"
        r=Fourier.v5_extensions(geometry,UInt32.(payload["forms"]),Int(payload["need"]),work;
            beta=Fourier.BETA8,max_kernel=23,max_x=config.chunk_size,
            start_x=Int(unit["direction"]),should_stop=()->stop_wanted() || remaining()==0)
        records=Dict{String,Any}[]
        for S in r.Ss
            _,G=Fourier.function_of(geometry,S)
            p=classify(G.lut,localref)
            p["apn"] && p["quadratic"] || error("invalid Fourier extension")
            p["additional_signature"]=!p["reference_signature_match"] && !(p["sigma_hash"] in known)
            p["role"]="generated";push!(records,p)
        end
        proof=Dict("first_x"=>Int(unit["direction"]),"next_x"=>r.next_x,"total_x"=>r.nX,
            "capped"=>r.capped,"candidate_spaces"=>length(r.Ss),"heuristic_pruning"=>false)
        if r.nX_used>0 || r.nX==0
            commit_chunk!(store,unit,proof,records;done=r.next_x>r.nX && !r.capped)
        else
            finish!(store,unit,Dict("stop"=>"time_or_external"))
        end
    elseif unit["kind"]=="switching"
        callback=function(event,value)
            p=event===:candidate_complete ? classify(value.candidate.lut,localref) : nothing
            if p!==nothing
                p["apn"]==value.apn || error("APN result disagrees with VBF")
                p["role"]="generated"
                p["additional_signature"]=p["apn"] && p["quadratic"] && !p["reference_signature_match"] && !(p["sigma_hash"] in known)
            end
            checkpoint!(store,unit,event,value,p)
        end
        r=switching_neighbors_bounded(F;max_evaluations=config.evaluations,
            timeout_seconds=min(config.slice,remaining()),start_direction=Int(unit["direction"]),
            start_combination=parse(BigInt,unit["combination"]),checkpoint=callback,
            stop_requested=()->stop_wanted() || remaining()==0)
        finish!(store,unit,Dict("nodes_this_slice"=>nodes_visited(r),"seconds_this_slice"=>elapsed_seconds(r),
            "stop"=>r isa Exhausted ? "none" : string(r.where_it_stopped.reason));done=r isa Exhausted)
    else
        error("unknown persisted construction unit: $(unit["kind"])")
    end
end
