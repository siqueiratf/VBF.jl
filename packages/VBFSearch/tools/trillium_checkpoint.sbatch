#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=192
#SBATCH --partition=compute
#SBATCH --time=03:00:00
#SBATCH --signal=B:USR1@2400
#SBATCH --job-name=vbf-cpu-pilot
#SBATCH --output=vbf-cpu-%j.log

set -euo pipefail

: "${VBF_CHECKPOINT:?Set an immutable sealed checkpoint generation on SCRATCH}"
: "${VBF_LAUNCHER_DIR:?Set the frozen launcher directory including launch-plan.json}"
: "${VBF_JOB_TOOLS:?Set the directory containing trillium_stage.jl}"
: "${VBF_DEPOT:?Set the offline Julia depot prepared on SCRATCH}"
: "${SLURM_CPUS_PER_TASK:?Submit this script through Slurm}"
: "${SLURM_TMPDIR:?This job requires node-local temporary storage}"
: "${SCRATCH:?Set the persistent writable scratch directory}"

runtime="${VBF_JULIA:-julia}"
mark_threads="${VBF_GC_MARK_THREADS:-8}"
sweep_threads=1
interactive_threads=1
reserved_cpus="${VBF_RESERVED_CPUS:-2}"
[[ "$SLURM_CPUS_PER_TASK" =~ ^[0-9]+$ && "$mark_threads" =~ ^[0-9]+$ && "$reserved_cpus" =~ ^[0-9]+$ ]]
compute_threads="${VBF_COMPUTE_THREADS:-$((SLURM_CPUS_PER_TASK-mark_threads-sweep_threads-interactive_threads-reserved_cpus))}"
[[ "$compute_threads" =~ ^[0-9]+$ ]]
(( compute_threads > 0 && mark_threads > 0 && reserved_cpus >= 0 ))
(( compute_threads+mark_threads+sweep_threads+interactive_threads+reserved_cpus <= SLURM_CPUS_PER_TASK ))

export JULIA_DEPOT_PATH="$VBF_DEPOT"
export JULIA_PKG_OFFLINE=true JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_PRECOMPILE_TASKS=1
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1

# Trillium's local working database is RAM-backed; keep WAL off shared scratch.
local_type=$(stat -f -c %T "$SLURM_TMPDIR")
[[ "$local_type" == tmpfs || "$local_type" == ramfs ]] || {
    printf 'Expected a node-local RAM filesystem, got %s\n' "$local_type" >&2
    exit 1
}
working="$SLURM_TMPDIR/vbf-cpu-$SLURM_JOB_ID/run"
output="${VBF_OUTPUT:-$SCRATCH/vbfsearch/pilot-$SLURM_JOB_ID}"
early_stop="$SLURM_TMPDIR/vbf-cpu-$SLURM_JOB_ID.stop"
trap 'touch "$early_stop"' USR1 TERM INT

"$runtime" --startup-file=no --compiled-modules=existing --threads=1,0 --gcthreads=1,0 \
    --heap-size-hint=2G --project="$VBF_CHECKPOINT/replay/workspace/docs/inspector" \
    "$VBF_JOB_TOOLS/trillium_stage.jl" "$VBF_CHECKPOINT" "$working" "$output" \
    "$VBF_LAUNCHER_DIR" "$compute_threads" "$SLURM_CPUS_PER_TASK"
[[ ! -f "$early_stop" ]] || exit 0
export SQLITE_TMPDIR="$SLURM_TMPDIR"
VBF_WORKSPACE="$working/replay/workspace"
VBF_CONFIG="$output/config.toml"
VBF_LAUNCHER="$VBF_LAUNCHER_DIR/closure_run.jl"

cd "$VBF_WORKSPACE"
printf 'job=%s CPUs=%s compute=%s GC=%s,%s interactive=%s\n' \
    "$SLURM_JOB_ID" "$SLURM_CPUS_PER_TASK" "$compute_threads" "$mark_threads" "$sweep_threads" "$interactive_threads"

# exec preserves the Slurm signal target through the launcher's POSIX supervisor.
exec "$runtime" --startup-file=no --compiled-modules=existing \
    --threads="$compute_threads,$interactive_threads" --gcthreads="$mark_threads,$sweep_threads" \
    --heap-size-hint="${VBF_HEAP_HINT:-32G}" --project="$VBF_WORKSPACE/docs/inspector" \
    "$VBF_LAUNCHER" "$VBF_CONFIG"
