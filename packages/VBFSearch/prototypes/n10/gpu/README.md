# n = 10 coset scan on the GPU

`coset_scan.jl` is a preliminary GPU version of the bottleneck of the exchange
move at n = 10. For an anchor V_7 < Q_10 (128 forms), it examines all 2^38
cosets q + V_7 and keeps the cosets that have exactly `need` bent forms
(rank 10). Then U_8 = V_7 + <q> has the target bent count. The re-extension of
U_8 (information-set decoding) stays on the CPU, in `../exchange_n10.jl`.

One KernelAbstractions kernel runs on three backends:

| `N10_BACKEND` | Device | Package |
|---|---|---|
| `cuda` (default) | NVIDIA, for example the GTX 1060 | CUDA.jl |
| `amdgpu` | AMD, for example the RX 6700 / 6700 XT / 6750 XT | AMDGPU.jl |
| `cpu` | CPU threads | KernelAbstractions only |

## Method

- A form is stored as the 10 rows of its alternating matrix (10 × `UInt16`).
  Thus rows(q + v) = rows(q) xor rows(v).
- Each GPU thread scans an aligned block of 2^logK cosets in Gray-code order.
  Consecutive cosets differ by one complement basis vector, so one step costs
  10 xor operations.
- The bent test keeps the 10 rows in registers. For each column, the first row
  with that bit is the pivot, and every row with that bit is reduced by it.
  There is no swap and no dynamic index. A version with swaps put the rows in
  local memory and was 4.4 times slower.
- The production mode stops a coset when its count cannot reach `need` any
  more. The validation mode (`exact = true`) fills the full histogram.

## Setup

Use the environment in this folder. `Manifest.toml` and `LocalPreferences.toml`
are local files, and git ignores them.

1. Install the packages:

   ```
   julia --project=. -e 'using Pkg; Pkg.instantiate()'
   ```

2. On an NVIDIA Pascal GPU (GTX 10xx, sm_61), pin the CUDA 12 runtime. CUDA 13
   does not support Pascal.

   ```
   julia --project=. -e 'using CUDA; CUDA.set_runtime_version!(v"12.6")'
   ```

3. On the RX 6700 / 6700 XT / 6750 XT (gfx1031), install ROCm 6 on the server.
   ROCm does not list gfx1031 as supported. If `AMDGPU.functional()` is false,
   set the override to the gfx1030 code before you start Julia:

   ```
   export HSA_OVERRIDE_GFX_VERSION=10.3.0
   ```

## Run

Run the scan of 2^28 cosets on the GPU:

```
N10_BACKEND=cuda julia -O3 --project=. coset_scan.jl 28
```

On the AMD server, set `N10_BACKEND=amdgpu`. Each run does these steps:

1. It compares the GPU histogram of 2^18 cosets with the CPU reference.
2. It measures the speed of the production mode.
3. It checks the first hits on the CPU.

## Results (anchor of Gold x^3: b(V_7) = 94, need = 84)

| Backend | Speed | Full scan of 2^38 cosets |
|---|---|---|
| GTX 1060 6 GB, CUDA 12.6 | 25.2 M cosets/s | 3.0 h per anchor |
| Ryzen 5 5600G, 12 threads (same kernel) | 0.7 M cosets/s | 117 h per anchor |
| Ryzen 5 5600G, 1 thread (`exchange_n10.jl`) | 0.065 M cosets/s | 49 days per anchor |

The GPU histogram is equal to the CPU reference, and each hit has a CPU count of
84. A scan of 2^28 cosets gave 4 hits, so a full anchor gives about 4,000
cosets U_8.

The RX 6700 XT was not measured. Its 32-bit integer throughput is about 2.8
times that of the GTX 1060, so the estimate is 1–1.5 h per anchor. Measure it
before you plan a long run.

To split a scan over several devices or machines, give each one a different
`base` index range. The ranges are independent.
