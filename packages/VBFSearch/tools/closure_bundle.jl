"""Small command adapter for verified checkpoint staging; no process manager required."""
using VBFSearch, TOML

function closure_bundle_main(args=ARGS)
    isempty(args) && error("usage: closure_bundle.jl verify BUNDLE | export RUN OUTPUT [FROZEN_PROJECT] | relocate RUN [FROZEN_PROJECT]")
    action=first(args);rest=args[2:end]
    result=if action=="verify"
        length(rest)==1 || error("verify needs BUNDLE")
        VBFSearch.closure_verify_checkpoint(only(rest))
    elseif action=="export"
        length(rest) in (2,3) || error("export needs RUN OUTPUT [FROZEN_PROJECT]")
        VBFSearch.closure_export_checkpoint(rest[1];output=rest[2],active_project=length(rest)==3 ? rest[3] : nothing)
    elseif action=="relocate"
        length(rest) in (1,2) || error("relocate needs RUN [FROZEN_PROJECT]")
        VBFSearch.closure_relocate!(rest[1];active_project=length(rest)==2 ? rest[2] : nothing)
    else
        error("unknown checkpoint operation: $action")
    end
    TOML.print(stdout,result);println()
end

abspath(PROGRAM_FILE)==@__FILE__ && closure_bundle_main()
