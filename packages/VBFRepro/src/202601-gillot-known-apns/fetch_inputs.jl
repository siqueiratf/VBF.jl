# Implements retrieval of pinned primary inputs used in Tables 1 and 7.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 2 — Boolean functions; source provenance
#
# Pseudocode:
#   1. Retrieve primary source/data files only into ignored input/.
#   2. Verify their pinned SHA-256 before replacing local cached copies.
# VBF API used: none; Downloads and SHA are Julia standard libraries.
using Downloads, SHA

"""Retrieve pinned GL primary sources and author data into ignored input/."""
function gl_fetch_inputs(;timeout_seconds=60)
    directory=joinpath(@__DIR__, "input")
    mkpath(joinpath(directory,"author_data"))
    sources=[
        ("https://arxiv.org/pdf/2601.11247v1","paper.pdf","d09cca1f7f0fcec991d00b53e4c5ec030fb6625a57a1ffc81a676a601b657eec"),
        ("https://arxiv.org/src/2601.11247v1","source.tar","37b9d61a457d2f33ce82f018eec29e2b57dd6118e68700b88f523e4ed5d8443f"),
        ("https://langevin.univ-tln.fr/data/bst/class-2-6.txt","author_data/class-2-6.txt","74cee20ea2db689ea6cebe4cc4f482e44d64eae4444b83cb93a32a425ce43628"),
        ("https://langevin.univ-tln.fr/data/bst/baby-1-5-5.dat","author_data/baby-1-5-5.dat","07a3a896ee032c63041caa5914928c43ca7767f182bf4a3bd6441482bd8b89aa")]
    for (url,name,expected) in sources
        path=joinpath(directory,name)
        isfile(path) && bytes2hex(sha256(read(path)))==expected && continue
        temporary=path*".partial"
        Downloads.download(url,temporary;timeout=timeout_seconds)
        bytes2hex(sha256(read(temporary)))==expected || error("primary artifact checksum changed: $(url)")
        mv(temporary,path;force=true)
    end
    tex_directory=joinpath(directory,"tex_source")
    mkpath(tex_directory)
    run(`tar xf $(joinpath(directory,"source.tar")) -C $tex_directory`)
    return sources
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_fetch_inputs()
end
