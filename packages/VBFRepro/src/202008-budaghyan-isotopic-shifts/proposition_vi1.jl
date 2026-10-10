# Implements Proposition VI.1 — scalar/Frobenius normalization of Gold shifts.
# Paper: Budaghyan et al. (2020), Constructing APN Functions Through Isotopic Shifts.
# Pseudocode:
#   1. Transform b_j to (b_j ζ^(k(2^j-1)))^(2^t).
#   2. Construct explicit input/output linear permutations for the shift identity.
#   3. Find the lexicographic minimum over this finite group orbit with budgets.
# VBF API used: gf_primitive_element, gf_pow, gf_mul, gf_inv, terms_to_lut,
#   gold_apn, is_permutation, SBox.

include(joinpath(@__DIR__, "helpers.jl"))

function proposition_vi1_coefficients(coefficients::AbstractVector{<:Integer},n::Int;
    k::Int=0,t::Int=0,modulus::Int=primitive_polynomial(n))
    2 <= n <= 16 || throw(ArgumentError("dimension must be between 2 and 16"))
    length(coefficients)==n && all(0 <= b < 1 << n for b in coefficients) ||
        throw(ArgumentError("need n field coefficients, ordered b_0,...,b_(n-1)"))
    z=gf_primitive_element(n;modulus)
    a=gf_pow(z,mod(k,(1 << n)-1),n;modulus)
    [gf_pow(gf_mul(b,gf_pow(a,(1 << (index-1))-1,n;modulus),n;modulus),
        1 << mod(t,n),n;modulus) for (index,b) in enumerate(coefficients)]
end

"""
    proposition_vi1_witness(coefficients,n,i; k=0,t=0,modulus)

Exact linear identity for Proposition VI.1, independently evaluated at every x:
G_M(x) = A_out(G_L(A_in(x))), where
A_in(x)=ζ^k x^(2^(-t mod n)),
A_out(y)=(ζ^(-k(2^i+1)) y)^(2^t).
The return includes full permutation LUTs and both shift LUTs. This identity
holds for arbitrary linear L; APN is not presumed by the witness verifier.
"""
function proposition_vi1_witness(coefficients::AbstractVector{<:Integer},n::Int,i::Int;
    k::Int=0,t::Int=0,modulus::Int=primitive_polynomial(n))
    1 <= i < n && gcd(i,n)==1 || throw(ArgumentError("Gold exponent needs 1<=i<n and gcd(i,n)=1"))
    cs=proposition_vi1_coefficients(coefficients,n;k,t,modulus)
    z=gf_primitive_element(n;modulus)
    a=gf_pow(z,mod(k,(1 << n)-1),n;modulus)
    scale=gf_pow(gf_inv(a,n;modulus),(1 << i)+1,n;modulus)
    input=[gf_mul(a,gf_pow(x,1 << mod(-t,n),n;modulus),n;modulus) for x in 0:(1 << n)-1]
    output=[gf_pow(gf_mul(scale,y,n;modulus),1 << mod(t,n),n;modulus) for y in 0:(1 << n)-1]
    build(c)=terms_to_lut([(c[j+1],1 << j) for j in 0:n-1],n,modulus)
    G=gold_apn(n,i;modulus).lut
    source=isotopic_shift_lut(G,build(coefficients))
    target=isotopic_shift_lut(G,build(cs))
    verified=is_permutation(SBox{n}(input)) && is_permutation(SBox{n}(output)) &&
        all(target[x+1]==output[source[input[x+1]+1]+1] for x in 0:(1 << n)-1)
    (;coefficients=cs,k=mod(k,(1 << n)-1),t=mod(t,n),modulus,
        input_lut=input,output_lut=output,source_lut=source,target_lut=target,verified)
end

"""
    proposition_vi1_normalize(coefficients,n; max_evaluations=2^20,timeout_seconds=60)

Lexicographic minimum in the scalar/Frobenius orbit, not an EA canonical form.
Only `complete=true` licenses calling it an orbit minimum. Budget-limited results
retain a valid equivalent representative, but must not be used for pruning.
"""
function proposition_vi1_normalize(coefficients::AbstractVector{<:Integer},n::Int;
    modulus::Int=primitive_polynomial(n),max_evaluations::Int=1 << 20,
    timeout_seconds::Real=60)
    max_evaluations>=0 && timeout_seconds>=0 || throw(ArgumentError("budgets must be nonnegative"))
    best=proposition_vi1_coefficients(coefficients,n;k=0,t=0,modulus)
    best_key=Tuple(best); best_k=0;best_t=0;evaluations=0;start=time()
    for k in 0:(1 << n)-2,t in 0:n-1
        if evaluations >= max_evaluations || time()-start >= timeout_seconds
            return (;coefficients=best,k=best_k,t=best_t,evaluations,complete=false,
                space_size=n*((1 << n)-1),modulus)
        end
        candidate=proposition_vi1_coefficients(coefficients,n;k,t,modulus)
        evaluations+=1
        if isless(Tuple(candidate),best_key)
            best=candidate;best_key=Tuple(best);best_k=k;best_t=t
        end
    end
    (;coefficients=best,k=best_k,t=best_t,evaluations,complete=true,
        space_size=n*((1 << n)-1),modulus)
end

function proposition_vi1_report(io::IO=stdout)
    coefficients=[5,2,7,0,1]
    result=proposition_vi1_normalize(coefficients,5)
    witness=proposition_vi1_witness(coefficients,5,1;k=result.k,t=result.t)
    print_section(io,"Proposition VI.1 — explicit normalization witness")
    print_kv(io,"source / normalized coefficients","$coefficients / $(result.coefficients)")
    print_kv(io,"orbit transformations evaluated","$(result.evaluations) / $(result.space_size)")
    print_check(io,"complete scalar/Frobenius orbit minimum",result.complete)
    print_check(io,"input/output linear witness verified at every field element",witness.verified)
    print_kv(io,"scope","orbit normalization only; does not classify all EA or CCZ classes")
    (;result,witness)
end

if abspath(PROGRAM_FILE)==@__FILE__
    proposition_vi1_report()
end
