"""Manuscript studies consuming VBF packages; package import executes no experiments."""
module VBFWorkingPaper
using CSV, SHA, TOML, VBFRepro
export workspace_root, document_root, write_audit_table, stage_paper
workspace_root()=normpath(joinpath(@__DIR__,"..","..",".."))
document_root()=normpath(joinpath(@__DIR__,"..","doc"))
include("paper.jl")
end
