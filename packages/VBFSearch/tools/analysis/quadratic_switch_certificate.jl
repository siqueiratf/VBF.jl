"""Certify when the complete Boolean switching space of a quadratic APN is quadratic.

Let H_u={b.F : b.u=0}, modulo affine terms, and let K_u be the homogeneous
quadratic forms q for which q(w)=0 on every decomposable bivector w with
B_F(w)=u. These are precisely the quadratic solutions of the complete switching
constraints (Edel--Pott); H_u is contained in K_u.

For a quadratic APN with independent n component forms:
  * dim(K_u)=n-1 implies that the full Boolean solution space is Aff(n)+H_u;
  * dim(K_u)=n and K_u contains a bent form implies that it is Aff(n)+K_u.

Proof. The complete Boolean constraint kernel is translation invariant, so it
is closed under every derivative. A solution of degree at least three can be
differentiated to a solution with a nonzero cubic top part T. Its quadratic
derivatives span A_T={i_a T:a in F2^n}, a space of dimension r>=3. Every i_a T
lies in K_u. If T has a nonzero radical vector z, then all forms in A_T vanish
polarly on z. The component forms in A_T intersect H_u in at most one dimension:
their output masks annihilate Im(B_F(z,.)), whose dimension is n-1 by APN.
If dim(K_u)<=n, this gives r<=dim(K_u)-dim(H_u)+1<=2, a contradiction.
Thus T has no radical and r=n. This is impossible when dim(K_u)=n-1; when
dim(K_u)=n it gives A_T=K_u. Every i_a T has a in its radical, so all nonzero
elements of A_T are singular, contradicting the assumed bent form in K_u.
All lower affine terms satisfy the constraints and do not affect this proof.

A further sufficient test forms the cubic symbol
  L_u={T in Lambda^3(V*): i_a T in K_u for every a}.
If this 56-variable system has zero kernel at n=8, the same differentiation
argument rules out every Boolean solution of degree at least three, regardless
of dim(K_u). A nonzero symbol is inconclusive: lower-degree constraints may
still obstruct its integration to an actual Boolean solution.

This tool measures these sufficient certificates. It never enumerates switching
candidates or changes a campaign. Uncertified directions remain unknown and
must retain the existing complete Boolean algorithm.

  julia --project=docs/inspector quadratic_switch_certificate.jl \
    parents.json output.json [parent_limit=1152] [full_boolean_checks=3]
"""
module QuadraticSwitchCertificate
using VBF, JSON3, SHA, Dates
const QE=VBF.QuadraticExtensions

file_sha(path)=bytes2hex(open(SHA.sha256,path))

"Compute exact quadratic switching dimensions from existing VBF flat geometry."
function quadratic_kernels(F,G=QE.geometry(trailing_zeros(length(F.lut))))
    n=G.n
    algebraic_degree(F)==2 && differential_uniformity(F)==2 ||
        throw(ArgumentError("expected a quadratic APN"))
    a=anf(F)
    forms=QE.coord_forms(UInt16[a[((1<<i)|(1<<j))+1]
        for i in 0:n-1 for j in i+1:n-1],n)
    VBF.rank_f2(forms;nbits=G.N)==n ||
        throw(ArgumentError("component forms are not independent"))
    comp=QE.comp_forms(forms)
    bent=QE.bent_mask(G,comp)
    rows=[UInt32[] for _ in 1:(1<<n)-1]
    for (w,(x,y,z)) in zip(G.flats,G.flatpts)
        u=Int(F.lut[x+1]⊻F.lut[y+1]⊻F.lut[z+1]⊻F.lut[1])
        u>0 || error("APN polar map vanishes on a flat")
        push!(rows[u],w)
    end
    dimensions=[G.N-VBF.rank_f2(r;nbits=G.N) for r in rows]
    all(d->d>=n-1,dimensions) || error("quadratic kernel lost H_u")
    bent_in_H=[count(b->bent[b+1] && iseven(count_ones(b&u)),1:(1<<n)-1)
        for u in 1:(1<<n)-1]
    certificates=[d==n-1 ? "affine_plus_component_hyperplane" :
        d==n && bent_in_H[u]>0 ? "affine_plus_quadratic_kernel" : "unknown"
        for (u,d) in enumerate(dimensions)]
    cubic_symbols=Dict{String,Int}()
    for u in eachindex(certificates)
        certificates[u]=="unknown" || continue
        symbol=cubic_symbol_dimension(G,rows[u])
        cubic_symbols[string(u)]=symbol
        symbol==0 && (certificates[u]="affine_plus_quadratic_kernel_by_cubic_symbol")
    end
    return (; dimensions,bent_in_H,certificates,
        flat_counts=length.(rows),forms,cubic_symbols)
end

"Dimension of cubic top parts whose every first contraction lies in K_u."
function cubic_symbol_dimension(G,flat_rows)
    triples=[(i,j,k) for i in 1:G.n for j in i+1:G.n for k in j+1:G.n]
    length(triples)<=64 || throw(ArgumentError("cubic symbol exceeds packed word"))
    isempty(triples) && return 0
    equations=UInt64[]
    for flat in flat_rows,a in 1:G.n
        row=UInt64(0)
        for (t,(i,j,k)) in enumerate(triples)
            pair=a==i ? G.pair[j,k] : a==j ? G.pair[i,k] : a==k ? G.pair[i,j] : -1
            pair>=0 && isodd(flat>>pair) && (row|=UInt64(1)<<(t-1))
        end
        push!(equations,row)
    end
    length(triples)-VBF.rank_f2(equations;nbits=length(triples))
end

"Raw dimensions from the existing, complete 2^n-variable Boolean implementation."
function full_boolean_dimensions(F)
    nsize=length(F.lut)
    systems=[VBF._sn_system(nsize) for _ in 1:nsize-1]
    VBF._sn_constraints!(systems,F.lut)
    return [nsize-length(s.pivot_rows) for s in systems]
end

"Compare all certified directions against the independent existing Boolean path."
function compare_boolean(F,kernels=quadratic_kernels(F))
    n=trailing_zeros(length(F.lut))
    start=time_ns()
    full=full_boolean_dimensions(F)
    checked=Int[]
    for u in eachindex(full)
        kernels.certificates[u]=="unknown" && continue
        full[u]==n+1+kernels.dimensions[u] ||
            error("Boolean kernel dimension contradicts certificate at u=$u")
        push!(checked,u)
    end
    return Dict("boolean_dimensions"=>full,"checked_directions"=>checked,
        "all_certificates_match"=>true,"seconds"=>(time_ns()-start)*1e-9)
end

function histogram(values)
    h=Dict{String,Int}()
    for value in values
        key=string(value);h[key]=get(h,key,0)+1
    end
    h
end

function audit(input,output;parent_limit=1152,full_boolean_checks=3,max_seconds=280.0)
    source_before=file_sha(input)
    document=JSON3.read(read(input,String),Dict{String,Any})
    get(document,"complete",false)===true || error("incomplete parent sample")
    population=document["parents"]
    parents=population[1:min(parent_limit,length(population))]
    G=QE.geometry(8);results=Dict{String,Any}[]
    start=time_ns()
    for parent in parents
        (time_ns()-start)*1e-9>max_seconds && break
        F=SBox{8,UInt8}(hex2bytes(parent["lut_hex"]))
        bytes2hex(sha256(F.lut))==parent["candidate_id"] || error("parent LUT digest mismatch")
        kernels=quadratic_kernels(F,G)
        row=Dict{String,Any}("parent_id"=>parent["parent_id"],
            "candidate_id"=>parent["candidate_id"],
            "uniform_parent_sample"=>parent["uniform_parent_sample"],
            "queued_parent"=>parent["queued_parent"],"origin"=>parent["origin"],
            "quadratic_dimensions"=>kernels.dimensions,
            "quadratic_dimension_histogram"=>histogram(kernels.dimensions),
            "certificates"=>kernels.certificates,
            "certificate_histogram"=>histogram(kernels.certificates),
            "cubic_symbols"=>kernels.cubic_symbols,
            "minimum_bent_in_H"=>minimum(kernels.bent_in_H),
            "all_directions_certified"=>all(!=("unknown"),kernels.certificates))
        push!(results,row)
    end
    for row in results[1:min(full_boolean_checks,length(results))]
        (time_ns()-start)*1e-9>max_seconds && break
        parent=only(p for p in parents if p["parent_id"]==row["parent_id"])
        F=SBox{8,UInt8}(hex2bytes(parent["lut_hex"]))
        row["boolean_comparison"]=compare_boolean(F)
    end
    directions=vcat([r["quadratic_dimensions"] for r in results]...)
    certificates=vcat([r["certificates"] for r in results]...)
    source_after=file_sha(input)
    source_before==source_after || error("sample changed during audit")
    report=Dict("schema"=>"quadratic-switch-certificate-audit-v1",
        "created_utc"=>string(Dates.now(Dates.UTC)),"input"=>abspath(input),
        "input_sha256"=>source_before,"tool_sha256"=>file_sha(@__FILE__),
        "julia_version"=>string(VERSION),"parent_population"=>length(population),
        "requested_parents"=>length(parents),"parents_measured"=>length(results),
        "complete"=>length(results)==length(parents),
        "quadratic_dimension_histogram"=>histogram(directions),
        "certificate_histogram"=>histogram(certificates),
        "all_directions_certified_parents"=>count(r->r["all_directions_certified"],results),
        "boolean_comparison_parents"=>count(r->haskey(r,"boolean_comparison"),results),
        "elapsed_seconds"=>(time_ns()-start)*1e-9,"parents"=>results,
        "scope"=>"Sufficient certificates only; no APN search or campaign write")
    mkpath(dirname(output))
    open(output,"w") do io;JSON3.pretty(io,report);end
    println(JSON3.write(Dict(k=>v for (k,v) in report if k!="parents")))
    report
end

function main(args)
    2<=length(args)<=4 || error("expected parents.json output.json [parent_limit] [full_boolean_checks]")
    audit(args[1],args[2];parent_limit=length(args)>=3 ? parse(Int,args[3]) : 1152,
        full_boolean_checks=length(args)>=4 ? parse(Int,args[4]) : 3)
end
end

if abspath(PROGRAM_FILE)==(@__FILE__)
    QuadraticSwitchCertificate.main(ARGS)
end
