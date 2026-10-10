# Named-source comparison is coverage-aware; an exact EA witness is required
# for positive equivalence. This report makes no literature-completeness claim.
include(joinpath(@__DIR__, "theorem6.jl"))
novelty_report(io::IO = stdout) = theorem6_report(io)
if abspath(PROGRAM_FILE) == @__FILE__
    novelty_report()
end
