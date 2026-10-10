# Implements Table 4.1 and Theorem 5.1 arithmetic checks
# Paper: Beierle et al. (2025), "Millions of inequivalent quadratic APN functions in eight variables"
# Section: 4.1 and 5
#
# Pseudocode:
#   1. Encode the profile-count table printed in the paper.
#   2. Check that the profile rows sum to 32,892.
#   3. Check that prior classes plus new Zenodo classes give Theorem 5.1.
# VBF API used: none

include(joinpath(@__DIR__, "helpers.jl"))

const TABLE_4_1_PROFILE_COUNTS = [
    (count = 9, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(28,40),(50,102)]"),
    (count = 468, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(28,40),(52,96)]"),
    (count = 90, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(28,40),(54,90)]"),
    (count = 32, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(50,102)]"),
    (count = 3_128, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(52,96)]"),
    (count = 7, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(54,102)]"),
    (count = 13_480, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(54,90)]"),
    (count = 2, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(56,108)]"),
    (count = 7_549, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(56,84)]"),
    (count = 49, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(56,96)]"),
    (count = 7_008, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(58,78)]"),
    (count = 80, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(58,90)]"),
    (count = 923, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(60,72)]"),
    (count = 67, profile = "[(0,0),(1,1),(3,3),(7,7),(15,15),(30,34),(60,84)]"),
]

"Sum the paper's Table 4.1 profile counts."
table41_total() = sum(row.count for row in TABLE_4_1_PROFILE_COUNTS)

"Check Theorem 5.1's lower-bound arithmetic from the stated old and new counts."
function theorem51_counts()
    lower_bound = PRIOR_KNOWN_CLASSES + NEW_ZENODO_CLASSES
    (;
        prior_known = PRIOR_KNOWN_CLASSES,
        new_classes = NEW_ZENODO_CLASSES,
        lower_bound,
        paper_lower_bound = THEOREM_5_1_LOWER_BOUND,
        lower_bound_matches = lower_bound == THEOREM_5_1_LOWER_BOUND,
    )
end

"Report exact count checks from Table 4.1 and Theorem 5.1."
function paper_counts_report(io::IO = stdout)
    print_section("Paper Counts", io)
    table_total = table41_total()
    theorem = theorem51_counts()
    print_check("Table 4.1 profile counts sum to 32,892", table_total == PRIOR_KNOWN_CLASSES, io)
    print_kv("profile rows", length(TABLE_4_1_PROFILE_COUNTS), io)
    print_kv("profile total", table_total, io)
    print_check("32,892 + 3,775,599 = 3,808,491", theorem.lower_bound_matches, io)
    print_kv("prior known classes", theorem.prior_known, io)
    print_kv("new Zenodo classes", theorem.new_classes, io)
    print_kv("Theorem 5.1 lower bound", theorem.lower_bound, io)
    print_kv("completeness", "exact arithmetic from paper constants", io)
    (; table_total, theorem)
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    paper_counts_report()
end
