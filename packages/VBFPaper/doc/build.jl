using VBFPaper
output=isempty(ARGS) ? joinpath(workspace_root(),"packages","VBFPaper","doc","generated","paper") : abspath(ARGS[1])
compile=!("--stage-only" in ARGS)
println(stage_paper(;output,compile))
