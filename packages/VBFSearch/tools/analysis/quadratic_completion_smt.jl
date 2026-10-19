"""Exact canonical linear-map encoding of quadratic APN completions.

For U in Alt(n), let C be the decomposable flats of U-perp, in canonical
quotient coordinates. Adjoining r=n-dim(U) independent forms is APN exactly
when every c in C has a nonzero joint evaluation on those r forms. The SMT
formula contains r quotient vectors and one OR of parity constraints per c.
It uses lowest-pivot reduced row-echelon form to represent each added subspace
once. Blocking a model therefore blocks its entire subspace, not just a basis.

SAT models are replayed using existing VBF geometry, GF(2), construction and
APN tests. Native V5 searches have a narrower target: at least one nonzero
coset in the completion must have the requested bent count. Model replay
computes all such coset counts separately; an untargeted SMT model is never
mistaken for a native target discovery. External UNSAT/unknown responses are
kept distinct from independently replayed positive witnesses.

Only installed command-line solvers are used; no dependency is installed.
"""
module QuadraticCompletionSMT
using VBF,JSON3,SHA,Dates
const Q=VBF.QuadraticExtensions

"Canonical residual-flat coordinates, reusing the existing VBF geometry."
function problem(G,U)
    R,piv=Q.rref(UInt32.(U));_,mask=Q.pivots_masks(R,piv,G.N)
    r=G.n-length(R);D=G.N-length(R)
    1<=r<=3 || throw(ArgumentError("this bounded prototype supports one to three added coordinates"))
    flats=UInt32[Q.pext(w,mask) for w in G.flats if all(q->!Q.par(w&q),R)]
    (;G,R,piv,mask,r,D,flats)
end

bv(value,width)="(_ bv$(UInt64(value)) $width)"

"SMT-LIB bit-vector parity, with one-bit result."
function parity_expression(row,variable)
    bits=["((_ extract $i $i) $variable)" for i in 0:31 if isodd(row>>i)]
    isempty(bits) && return "#b0"
    foldl((a,b)->"(bvxor $a $b)",bits)
end

"Exact SMT-LIB formula for canonical added subspaces, plus optional model blocks."
function formula(p;blocked=Vector{Vector{UInt32}}())
    io=IOBuffer();println(io,"(set-logic QF_BV)")
    for i in 0:p.r-1
        println(io,"(declare-fun v$i () (_ BitVec $(p.D)))")
        println(io,"(define-fun p$i () (_ BitVec $(p.D)) (bvand v$i (bvneg v$i)))")
        println(io,"(assert (distinct v$i $(bv(0,p.D))))")
    end
    for i in 0:p.r-2,j in i+1:p.r-1
        println(io,"(assert (bvult p$i p$j))")
        println(io,"(assert (= (bvand v$i p$j) $(bv(0,p.D))))")
    end
    for c in p.flats
        expressions=[parity_expression(c,"v$i") for i in 0:p.r-1]
        joint=foldl((a,b)->"(bvor $a $b)",expressions)
        println(io,"(assert (= $joint #b1))")
    end
    for rows in blocked
        length(rows)==p.r && VBF.linear_basis(rows;nbits=p.D)==rows ||
            throw(ArgumentError("blocked model must use canonical lowest-pivot RREF"))
        tests=["(= v$(i-1) $(bv(row,p.D)))" for (i,row) in enumerate(rows)]
        println(io,"(assert (not (and $(join(tests,' ')))))")
    end
    println(io,"(check-sat)")
    String(take!(io))
end

"Replay a canonical model and separately test the native bent-coset target."
function replay_model(p,rows;need=nothing)
    vectors=UInt32.(rows)
    length(vectors)==p.r || throw(ArgumentError("wrong number of added coordinates"))
    all(q->q<1<<p.D,vectors) || throw(ArgumentError("quotient vector outside its dimension"))
    VBF.linear_basis(vectors;nbits=p.D)==vectors &&
        VBF.rank_f2(vectors;nbits=p.D)==p.r || throw(ArgumentError("noncanonical or dependent model"))
    all(c->any(v->Q.par(c&v),vectors),p.flats) || error("SMT model misses a residual flat")
    S=first(Q.rref(vcat(p.R,[Q.lift(v,p.mask) for v in vectors])))
    length(S)==p.G.n || error("completion rank mismatch")
    _,F=Q.function_of(p.G,S)
    differential_uniformity(F)==2 && algebraic_degree(F)==2 || error("VBF rejected an SMT completion")
    base=Q.comp_forms(p.R);cosets=Q.comp_forms(vectors)[2:end]
    bent_counts=[count(u->Q.form_rank(p.G,Q.lift(v,p.mask)⊻u)==p.G.n,base) for v in cosets]
    (;vectors,S,lut_hex=bytes2hex(F.lut),bent_counts,
        target_match=need===nothing || need in bent_counts)
end

"Extract the canonical quotient model from an existing completed component space."
function model_of_space(p,S)
    coordinates=UInt32[Q.pext(VBF._quadratic_coset_remainder(UInt32(q),p.R,p.piv),p.mask) for q in S]
    VBF.linear_basis(coordinates;nbits=p.D)
end

"Parse ordinary constant bit-vector definitions from the installed solver's model."
function parse_model(output,r)
    values=Dict{Int,UInt32}()
    pattern=r"\(define-fun\s+v([0-9]+)\s+\(\)\s+\(_\s+BitVec\s+[0-9]+\)\s+(#b[01]+|#x[0-9a-fA-F]+|\(_\s+bv[0-9]+\s+[0-9]+\))\s*\)"
    for m in eachmatch(pattern,output)
        value=m.captures[2]
        values[parse(Int,m.captures[1])]=startswith(value,"#b") ? parse(UInt32,value[3:end];base=2) :
            startswith(value,"#x") ? parse(UInt32,value[3:end];base=16) :
            parse(UInt32,only(match(r"bv([0-9]+)",value).captures))
    end
    all(i->haskey(values,i),0:r-1) || return nothing
    UInt32[values[i] for i in 0:r-1]
end

"Run one bounded installed solver query and retain its exact input/output."
function query(p,directory;solver="cvc4",timeout_ms=250,blocked=Vector{Vector{UInt32}}())
    executable=Sys.which(solver);executable===nothing && throw(ArgumentError("solver unavailable: $solver"))
    mkpath(directory);input=joinpath(directory,"query.smt2")
    stdout_path=joinpath(directory,"stdout.txt");stderr_path=joinpath(directory,"stderr.txt")
    write(input,formula(p;blocked))
    args=solver=="cvc4" ? [executable,"--lang=smt2","--tlimit-per=$timeout_ms","--dump-models",input] :
        solver=="yices-smt2" ? [executable,"--timeout=$(max(1,cld(timeout_ms,1000)))","--dump-models",input] :
        throw(ArgumentError("unsupported installed solver"))
    command=Cmd(vcat(["timeout","$(max(3,cld(timeout_ms,1000)+1))s"],args))
    start=time_ns();code=0
    open(stdout_path,"w") do out
        open(stderr_path,"w") do err
            process=run(pipeline(ignorestatus(command);stdout=out,stderr=err))
            code=process.exitcode
        end
    end
    seconds=(time_ns()-start)*1e-9
    output=read(stdout_path,String);matched=match(r"(?m)^(sat|unsat|unknown)\s*$",output)
    status=matched===nothing ? (code==124 ? "unknown_process_timeout" : "solver_error") : matched.captures[1]
    rows=status=="sat" ? parse_model(output,p.r) : nothing
    Dict("solver"=>solver,"solver_sha256"=>bytes2hex(open(sha256,executable)),
        "query_sha256"=>bytes2hex(open(sha256,input)),"seconds"=>seconds,
        "status"=>status,"vectors"=>rows,"return_code"=>code,
        "timeout_ms"=>timeout_ms,"blocked_models"=>length(blocked))
end
end
