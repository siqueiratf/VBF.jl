"""Standard-library-only independent verification of an EA/CCZ graph map or quadratic signature separation."""
const CERTIFICATE_USAGE=nothing
using SHA,TOML
include("verification/signature.jl")
include("verification/ea_witness.jl")
using .IndependentSignature,.IndependentEAWitness
function independently_verify_certificate(path)
    r=TOML.parsefile(path)
    r["relation"] in ("ea","ccz") || error("unknown relation")
    f,g=hex2bytes(r["candidate_lut_hex"]),hex2bytes(r["target_lut_hex"])
    bytes2hex(sha256(f))==r["candidate_sha256"] && bytes2hex(sha256(g))==r["target_sha256"] || error("LUT digest mismatch")
    if r["status"]=="equivalent_with_verified_witness"
        r["equivalent"]===true || error("inconsistent positive verdict")
        check=r["relation"]=="ea" ? verify_ea_witness : verify_ccz_witness
        check(f,g,r["graph_map_columns"],r["graph_map_constant"]) || error("invalid affine graph map")
    elseif r["status"]=="inequivalent_by_quadratic_invariant"
        r["equivalent"]===false || error("inconsistent negative verdict")
        left,right=bytes2hex(signature(Workspace(),f)),bytes2hex(signature(Workspace(),g))
        left==r["candidate_sigma"] && right==r["target_sigma"] && left!=right || error("invalid invariant separation")
    else
        error("this outcome has no independently checkable certificate; budget stops are unresolved, exhaustive negatives require solver replay")
    end
    println("Independently verified: ",r["status"]," (",r["relation"],")")
    true
end
if abspath(PROGRAM_FILE)==(@__FILE__)
    length(ARGS)==1 || error("usage: verify_certificate.jl CERTIFICATE.toml")
    independently_verify_certificate(ARGS[1])
end
