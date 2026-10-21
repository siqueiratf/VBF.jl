#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=192
#SBATCH --partition=debug
#SBATCH --time=00:30:00
#SBATCH --signal=B:USR1@900
#SBATCH --job-name=vbf-cpu-pilot
#SBATCH --output=vbf-cpu-%j.log

set -euo pipefail
: "${VBF_WORKSPACE:?Set the staged VBF.jl checkout on SCRATCH}"
exec python3 "$VBF_WORKSPACE/packages/VBFSearch/tools/trillium_fresh.py" "$@"
