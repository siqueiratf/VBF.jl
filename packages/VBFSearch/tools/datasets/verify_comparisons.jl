"""Replay cached EA certificates and solve uncached pairs through VBF.

Each positive witness is checked on the complete 256-point function graph.
Output is a 35-byte record per pair: status UInt8 (1 positive, 2 exhausted
negative, 3 budget stop), 16 UInt16-LE graph columns, UInt16-LE constant.
Inputs and cache bytes are SHA256-bound. Budget stops never merge classes.
Usage under an archived inspector project: verify_comparisons.jl PAIR_DIRECTORY.
"""
module APNDatasetVerification
using VBF,JSON3,SHA,Dates
const POWTAB=VBF.monomial_power_table(8,285)
hashfile(p)=bytes2hex(open(SHA.sha256,p))
function cached_map(record)
 length(record)==35 && record[1]==1 || error("invalid positive proof record")
 values=ltoh.(reinterpret(UInt16,record[2:35]))
 F2AffineMap(F2LinearMap(UInt32.(values[1:16])),UInt32(values[17]))
end
function verify_pair(f,g,record)
 F=SBox{8,UInt8}(f);G=SBox{8,UInt8}(g)
 reused=record[1]==1
 A=if reused
  cached_map(record)
 elseif F==G
  F2AffineMap(identity_linear_map(16),0)
 else
  result=partition_refinement_equivalence(F,G;relation=:ea,algorithm=:optimized,timeout_seconds=5,max_nodes=200000)
  if result isa BudgetHit
   result=partition_refinement_equivalence(F,G;relation=:ea,algorithm=:optimized,timeout_seconds=60,max_nodes=1000000)
  end
  result isa Found || return (result isa Exhausted ? UInt8(2) : UInt8(3),zeros(UInt16,16),UInt16(0),false)
  first(result.functions)
 end
 is_invertible(A.linear) && all(iszero(c>>8) for c in A.linear.cols[1:8]) && ccz_equivalent_function(F,A)==G || error("positive certificate failed complete EA graph replay")
 (UInt8(1),UInt16.(A.linear.cols),UInt16(A.constant),reused)
end
function main(directory)
 input=joinpath(directory,"pairs.bin");cache=joinpath(directory,"cached-proofs.bin");meta=JSON3.read(read(joinpath(directory,"pairs.json"),String))
 hashfile(input)==meta.input_sha256 && hashfile(cache)==meta.cached_proofs_sha256 || error("input identity changed")
 total=Int(meta.rows);filesize(input)==513total && filesize(cache)==35total || error("input length mismatch")
 proofpath=joinpath(directory,"verified-proofs.bin");progresspath=joinpath(directory,"verification.json")
 isfile(proofpath) && error("proof output already exists; retain the previous attempt and use a new directory")
 started=time();statuses=Dict("equivalent_with_replayed_witness"=>0,"exhaustive_inequivalent"=>0,"inconclusive"=>0);reused=0
 open(input,"r") do source
  open(cache,"r") do cached
   open(proofpath,"w") do dest
    for first in 1:2048:total
     last=min(first+2047,total);data=read(source,513(last-first+1));saved=read(cached,35(last-first+1))
     results=Vector{Tuple{UInt8,Vector{UInt16},UInt16,Bool}}(undef,last-first+1)
     Threads.@threads :static for j in eachindex(results)
      offset=513(j-1);f=data[offset+2:offset+257]
      g=data[offset+1]==1 ? UInt8.(VBF.decode_quadratic_lut(data[offset+258:offset+294],8,285;powtab=POWTAB)) : data[offset+258:offset+513]
      results[j]=verify_pair(f,g,saved[35(j-1)+1:35j])
     end
     for (status,cols,constant,was_cached) in results
      write(dest,status);write(dest,htol.(cols));write(dest,htol(constant));reused+=was_cached
      key=status==1 ? "equivalent_with_replayed_witness" : status==2 ? "exhaustive_inequivalent" : "inconclusive";statuses[key]+=1
     end
     flush(dest)
     value=Dict("schema"=>"vbfsearch-pair-verification-v1","comparison"=>String(meta.comparison),"checked_pairs"=>last,"total_pairs"=>total,"complete"=>last==total,"status_counts"=>statuses,"cached_witnesses_replayed"=>reused,"all_positive_witnesses_replayed"=>true,"input_sha256"=>String(meta.input_sha256),"cached_proofs_sha256"=>String(meta.cached_proofs_sha256),"worker_sha256"=>hashfile(@__FILE__),"seconds"=>time()-started,"julia"=>string(VERSION),"threads"=>Threads.nthreads(),"updated_utc"=>string(now(UTC))*"Z")
     last==total && (value["proofs_sha256"]=hashfile(proofpath))
     open(io->JSON3.write(io,value),progresspath*".tmp","w");mv(progresspath*".tmp",progresspath;force=true)
     println(JSON3.write(value));flush(stdout)
    end
   end
  end
 end
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && APNDatasetVerification.main(only(ARGS))
