using VBFSearch,TOML
length(ARGS) in (3,4) || error("usage: closure_compact.jl SOURCE OUTPUT COMPILED_HELPER [PREPARED_DIRECTORY]")
TOML.print(stdout,VBFSearch.closure_compact(ARGS[1];output=ARGS[2],helper=ARGS[3],prepared=length(ARGS)==4 ? ARGS[4] : nothing))
