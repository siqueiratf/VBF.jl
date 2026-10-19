"""A verified low-rank flat obstruction certifies an entire annihilator family.

Let B be actual decomposable bivectors and suppose every linear B→F2² map
has a zero. Put A=B-perp in the quadratic component space. For ANY U6≤A,
a quadratic APN eight-space S≥U6 would supply two extra component forms.
Their joint evaluations on B give a nowhere-zero binary-linear map, a
contradiction. Hence all six-spaces inside A are empty, whether or not they
share the original V5. This is exact containment transport, with no hash or
unverified graph-isomorphism assertion. Rank21 gives dimA7 and127 six-spaces;
only an explicitly counted subset has the campaign's b6=52 profile.
"""
module QuadraticCompletionFamily
using VBF,JSON3,Dates,SHA
include("quadratic_completion_core.jl")
const K=QuadraticCompletionCore
const Q=VBF.QuadraticExtensions

"Validate a supplied proof and compute the exact annihilator-family coverage."
function certify(G,U,flats,proof;target_bent=52,original_v5=nothing)
    p=K.S.problem(G,U);p.r==2 || throw(ArgumentError("requires codimension-two U"))
    core=UInt32.(flats)
    K.D.replay_unsat((;r=2,D=p.D,flats=core),proof) || error("flat obstruction proof failed")
    geometryindices=K.C.O.flat_indices(G,p.R)
    ambient=Dict(c=>G.flats[fi] for (c,fi) in zip(p.flats,geometryindices))
    all(c->haskey(ambient,c),core) || throw(ArgumentError("foreign residual flat"))
    original=UInt32[ambient[c] for c in core]
    A=VBF.linear_basis(VBF.kernel_f2(original;nbits=G.N);nbits=G.N)
    all(q->VBF.is_in_span(q,A;nbits=G.N),p.R) || error("original U missing from family")
    comp=Q.comp_forms(A);bent=BitVector(Q.form_rank(G,q)==G.n for q in comp)
    spaces=Q.subspaces_of_comp(comp,bent,G.n-2;keep=nb->true)
    selected=[entry for entry in spaces if entry.nbent==target_bent]
    receipts=Any[]
    for entry in spaces
        forms,pivots=Q.rref(entry.forms);_,mask=Q.pivots_masks(forms,pivots,G.N)
        all(w->all(q->!Q.par(w&q),forms),original) || error("support outside target annihilator")
        target_coords=UInt32[Q.pext(w,mask) for w in original]
        partial=VBF._PartialF2Isomorphism(p.D)
        all(VBF._partial_insert!(partial,c,d) for (c,d) in zip(core,target_coords)) ||
            error("flat linear dependencies changed under containment transport")
        transporter=VBF._partial_complete(partial)
        transporter!==nothing && VBF.is_invertible(transporter) && transporter.(core)==target_coords ||
            error("explicit flat transporter failed replay")
        low_basis=VBF.linear_basis(forms;nbits=G.N)
        contains_v5=original_v5!==nothing&&all(q->VBF.is_in_span(UInt32(q),low_basis;nbits=G.N),original_v5)
        push!(receipts,(;forms,bent_count=entry.nbent,contains_original_v5=contains_v5,
            source_to_target_columns=transporter.cols))
    end
    (;ambient_flats=original,obstruction_rank=G.N-length(A),annihilator=A,
        annihilator_dimension=length(A),all_six_space_count=length(spaces),
        target_bent,target_six_space_count=length(selected),
        target_six_spaces=[first(Q.rref(entry.forms)) for entry in selected],
        original_v5_six_spaces=count(r->r.contains_original_v5,receipts),
        original_v5_target_six_spaces=count(r->r.contains_original_v5&&r.bent_count==target_bent,receipts),
        explicit_transport_receipts=receipts,
        all_bent_histogram=Dict(string(nb)=>count(s->s.nbent==nb,spaces) for nb in unique(s.nbent for s in spaces)))
end

"Replay the three retained rank21 witnesses; enumerate only their127 hyperplanes."
function main(directory)
    source=JSON3.read(read(joinpath(directory,"followup.json"),String))
    original=JSON3.read(read(joinpath(directory,"core.json"),String));G=Q.geometry(8)
    V5=UInt32[136265460,67900911,43432498,26361691,3242677]
    families=Any[]
    for witness in source.lower_rank_cores
        family=certify(G,original.U,witness.flats,witness.proof;original_v5=V5)
        push!(families,(;functional=witness.functional,family))
    end
    target=Set(Tuple(S) for entry in families for S in entry.family.target_six_spaces)
    allspaces=Set(Tuple(r.forms) for entry in families for r in entry.family.explicit_transport_receipts)
    output=(;created_utc=string(now(UTC)),families,
        target_b6=52,target_union_count=length(target),all_six_space_union_count=length(allspaces),original_v5=V5,
        scope="Guaranteed empty quadratic completions for explicitly enumerated six-spaces; no frequency/speed claim",
        source_sha256=bytes2hex(open(sha256,@__FILE__)))
    write(joinpath(directory,"families.json"),JSON3.write(output))
    println(JSON3.write((;families=length(families),target_union_count=length(target),
        per_family=[(;rank=e.family.obstruction_rank,A_dimension=e.family.annihilator_dimension,
            all_six_spaces=e.family.all_six_space_count,b6_52=e.family.target_six_space_count,
            containing_original_v5=e.family.original_v5_six_spaces,
            target_containing_original_v5=e.family.original_v5_target_six_spaces) for e in families])))
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && QuadraticCompletionFamily.main(ARGS[1])
