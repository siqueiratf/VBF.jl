using Test
using VBF

# Each test file loads the implementation it exercises. Budgets are small; the
# exhaustive Δ-rank / large-n statements live in paper_report, not here.
include("test_helpers.jl")
include("test_theorem1.jl")
include("test_proposition1.jl")
include("test_corollary1.jl")
include("test_proposition2.jl")
include("test_theorem2.jl")
include("test_corollary2.jl")
include("test_section2_1.jl")
include("test_theorem3.jl")
include("test_corollary3.jl")
include("test_corollary4.jl")
include("test_proposition3.jl")
