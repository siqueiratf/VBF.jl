# n = 10 coset scan on the GPU

`coset_scan.jl` is the GPU version of the bottleneck of the exchange move at
n = 10. For an anchor V_7 < Q_10 (128 forms), it examines all 2^38 cosets
q + V_7 and keeps the cosets that have exactly `need` bent forms (rank 10).
Then U_8 = V_7 + <q> has the target bent count. The re-extension of U_8 stays
on the CPU: `../isd_fast.jl` (prefilter `passes_delta8`, then information-set
decoding).

The same KernelAbstractions kernels run on three backends:

| `N10_BACKEND` | Device | Environment |
|---|---|---|
| `cuda` (default) | NVIDIA, for example the GTX 1060 | this folder (`--project=.`) |
| `amdgpu` | AMD, for example the RX 6750 XT | `amd/` (`--project=amd`) |
| `cpu` | CPU threads | either |

## Method

- A form is stored as the 10 rows of its alternating matrix (10 × `UInt16`).
  Thus rows(q + v) = rows(q) xor rows(v).
- Each GPU thread scans an aligned block of 2^logK cosets in Gray-code order.
  Consecutive cosets differ by one complement basis vector, so one step costs
  10 xor operations.
- Two bent tests are available (`N10_KERNEL=regs`, `sliced` or `regs,sliced`):
  - `regs`: the 10 rows of one form stay in registers. For each column, the
    first row with that bit is the pivot, and every row with that bit is
    reduced by it. There is no swap and no dynamic index.
  - `sliced` (production): each `UInt32` word holds one matrix entry of 32
    forms, so one thread tests 32 forms with mask operations. Only the columns
    j >= c are updated. The code is generated and fully unrolled.
- The production mode stops a coset when its count cannot reach `need` any
  more. The validation mode (`exact = true`) fills the full histogram.

## Setup

`Manifest.toml` and `LocalPreferences.toml` are local files, and git ignores
them.

### NVIDIA

1. Install the packages: `julia --project=. -e 'using Pkg; Pkg.instantiate()'`
2. On a Pascal GPU (GTX 10xx, sm_61), pin the CUDA 12 runtime. CUDA 13 does not
   support Pascal.

   ```
   julia --project=. -e 'using CUDA; CUDA.set_runtime_version!(v"12.6")'
   ```

### AMD

Use the separate environment `amd/`. It does not contain CUDA.jl. In the
environment of this folder, the compat bounds of CUDA.jl hold KernelAbstractions
at 0.9 and AMDGPU.jl at 2.8.0, and on Julia 1.13 that AMDGPU.jl version cannot
compile any kernel (`kernel_state()` / `jl_f_throw_methoderror` in the IR).
`amd/` resolves AMDGPU.jl 2.9.1 and KernelAbstractions 0.10.1, which work.

1. Install the system packages of ROCm, including the HIP runtime. On Arch:
   `hsa-rocr`, `rocm-device-libs`, `hip-runtime-amd`, `rocminfo`. AMDGPU.jl
   takes LLD and the device libraries from its own artifacts.
2. Install the Julia packages: `julia --project=amd -e 'using Pkg; Pkg.instantiate()'`
3. Check: `julia --project=amd -e 'using AMDGPU; @show AMDGPU.functional()'`.
   With ROCm 7.2.4 the RX 6750 XT (gfx1031) works without
   `HSA_OVERRIDE_GFX_VERSION`.

## Run

```
N10_BACKEND=cuda   julia -O3 --project=.   coset_scan.jl 28
N10_BACKEND=amdgpu julia -O3 --project=amd coset_scan.jl 30
```

Each run does these steps for every kernel in `N10_KERNEL`:

1. It compares the GPU histogram of 2^18 cosets with the CPU reference.
2. It measures the speed of the production mode on 2^ARG cosets.
3. It checks the first hits on the CPU.

## Results (anchor of Gold x^3: b(V_7) = 94, need = 84)

| Device | Kernel | Speed | Full scan of 2^38 cosets |
|---|---|---|---|
| RX 6750 XT, ROCm 7.2.4, AMDGPU.jl 2.9.1 | sliced | 819.8 M cosets/s | 0.09 h (5.6 min) per anchor |
| RX 6750 XT | regs | 76.5 M cosets/s | 1.0 h per anchor |
| GTX 1060 6 GB, CUDA 12.6 | sliced | 198.9 M cosets/s | 0.38 h (23 min) per anchor |
| GTX 1060 6 GB | regs | 25.2 M cosets/s | 3.0 h per anchor |
| Ryzen 5 5600G, 12 threads | regs | 0.7 M cosets/s | 117 h per anchor |
| Ryzen 5 5600G, 1 thread (`../exchange_n10.jl`) | — | 0.065 M cosets/s | 49 days per anchor |

On each device, the GPU histogram is equal to the CPU reference, and each hit
has a CPU count of 84. A scan of 2^30 cosets gave 14 hits, so a full anchor
gives about 3,600 cosets U_8.

To split a scan over several devices or machines, give each one a different
`base` index range. The ranges are independent.
