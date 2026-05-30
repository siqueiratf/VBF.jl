# Reproduction: Taniguchi's quadratic APN family
# Hiroaki Taniguchi — Designs, Codes and Cryptography 2019  [Taniguchi2019]
#
# Taniguchi's Theorem 3 builds APN functions on F2^{2n} from Carlet's
# B(x,y)=x·y construction with
#     G(x,y) = x^{2^{2m}+2^{3m}} + a·x^{2^{2m}}·y^{2^m} + b·y^{2^m+1},
# APN iff x^{2^m+1}+a·x+b has no root in F2^n. On F2^8 the family has three
# CCZ-classes (the paper's Γ-ranks 13642 / 13700 / 13798): the a=0 Zhou–Pott
# member and the two NEW (a≠0) ones that "do not appear in the list by Edel and
# Pott". This script regenerates them with `taniguchi_apn_representatives` and
# checks the class structure; `apn_ea_mugshot` (the ortho-derivative invariant)
# separates the three classes.
#
# Reproduction mode: RECOMPUTES FROM THE CONSTRUCTION.
#   The family is generated from Theorem 3 at n=8 (no published data loaded to
#   obtain the functions) and cross-checked against the re-housed corpus.
#
# Run standalone:  julia --project=. papers/Taniguchi2019_construction.jl

using VBF
using VBFCatalog

"Tan19: three CCZ-classes on F2^8, two of them new (a≠0)."
const EXPECTED = (n_classes = 3, n_new = 2)

function reproduce()
    reps = taniguchi_apn_representatives(4)
    (n_classes = length(reps),
     n_new = count(r -> r.new, reps),
     all_quadratic_apn = all(differential_uniformity(r.sbox) == 2 &&
                             algebraic_degree(r.sbox) == 2 for r in reps),
     distinct_mugshots = length(unique(apn_ea_mugshot(r.sbox) for r in reps)),
     # the two new classes are exactly the re-housed Taniguchi2019 corpus members
     corpus_matches = begin
         db = load_catalog()
         try
             new = Set(apn_ea_mugshot(r.sbox) for r in reps if r.new)
             stored = Set(apn_ea_mugshot(corpus_function(db, "taniguchi2019_n8", i))
                          for i in 1:corpus_length(db, "taniguchi2019_n8"))
             new == stored
         finally
             close(db)
         end
     end)
end

function report(io::IO = stdout)
    r = reproduce()
    println(io, "# Taniguchi's quadratic APN family — Tan19")
    println(io, "- CCZ-classes on F2^8 : ", r.n_classes, " (expected ", EXPECTED.n_classes, ")")
    println(io, "- new (a≠0) classes   : ", r.n_new, " (expected ", EXPECTED.n_new, ")")
    println(io, "- all quadratic APN   : ", r.all_quadratic_apn)
    println(io, "- distinct mugshots   : ", r.distinct_mugshots)
    println(io, "- match re-housed corpus: ", r.corpus_matches)
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
