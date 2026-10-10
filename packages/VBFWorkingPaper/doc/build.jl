using VBFWorkingPaper
output=isempty(ARGS) ? joinpath(workspace_root(),"data","working-paper","paper") : abspath(ARGS[1])
compile=!("--stage-only" in ARGS)
println(stage_paper(;output,compile))
