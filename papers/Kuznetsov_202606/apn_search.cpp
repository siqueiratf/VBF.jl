#include <hip/hip_runtime.h>
#include <iostream>
#include <vector>
#include <fstream>
#include <chrono>
#include <string>

// Unified GPGPU APN search for purely quadratic functions, generic over the
// dimension n via -DDIM_N (default 8; build n=7 with -DDIM_N=7).
//
// A quadratic function is represented by its n×n bilinear-form matrix C, where
// C[i][j] = F(e_i ^ e_j) for i != j (each row packed as one uint64_t, byte j =
// column j). For each a != 0 the linear differential L_a has matrix R(a) =
// sum_j a_j · C[j], computed incrementally with a Gray code over a. F is APN iff
// R(a) has rank n-1 for every a != 0.
//
// Usage: apn_search <basis_rows.bin> <n_free> <total_space_pow2>
//                   [start_batch end_batch] [out_file]

#ifndef DIM_N
#define DIM_N 8
#endif

constexpr int      N           = DIM_N;
constexpr int      TARGET_RANK = N - 1;
constexpr uint32_t A_MAX       = (1u << N) - 1;
constexpr uint32_t RESULTS_CAP = 100000000u;   // per-batch device result buffer

// rank of the n×n F2 matrix packed in M (byte c = column c); APN ⇔ rank == n-1.
__device__ __forceinline__ bool check_rank(uint64_t M) {
    uint32_t cols[N];
    #pragma unroll
    for (int c = 0; c < N; c++) cols[c] = (M >> (c * 8)) & 0xFF;

    int r = 0;
    for (int bit = 0; bit < N; bit++) {
        if (bit - r > 1) return false;             // missed 2 pivots ⇒ rank ≤ n-2
        int pivot = -1;
        for (int j = r; j < N; j++) {
            if (cols[j] & (1u << bit)) { pivot = j; break; }
        }
        if (pivot != -1) {
            if (pivot != r) { uint32_t t = cols[r]; cols[r] = cols[pivot]; cols[pivot] = t; }
            // branchless elimination: ~9% faster on RDNA2 (less wavefront divergence)
            #pragma unroll
            for (int j = r + 1; j < N; j++) {
                uint32_t m = (uint32_t)0 - ((cols[j] >> bit) & 1u);
                cols[j] ^= cols[r] & m;
            }
            r++;
        }
    }
    return r == TARGET_RANK;
}

__global__ void apn_kernel(const uint64_t* __restrict__ basis,
                           const uint64_t* __restrict__ center,
                           uint64_t* results, uint32_t* counter,
                           uint64_t start_prefix, uint32_t num_gray_bits,
                           uint32_t total_basis_size) {
    int ti_id = threadIdx.x;
    uint64_t global_id = (uint64_t)blockIdx.x * blockDim.x + ti_id;

    extern __shared__ uint64_t s_basis[];        // n_free × N words
    for (int i = ti_id; i < (int)(total_basis_size * N); i += blockDim.x) {
        s_basis[i] = basis[i];
    }
    __syncthreads();

    uint64_t prefix_val = start_prefix + global_id;

    // affine slice: row = center ⊕ span(selected free generators). center=0 ⇒ the
    // homogeneous subspace search; center=F0's bilinear matrix ⇒ a full-space slice
    // through F0 that reaches outside V_A (the gateway exploration).
    uint64_t row[N];
    #pragma unroll
    for (int r = 0; r < N; r++) row[r] = center[r];

    // apply the prefix bits (the non-Gray free coordinates)
    for (uint32_t i = 1; i <= (total_basis_size - num_gray_bits); i++) {
        if (((prefix_val >> (i - 1)) & 1) == 1) {
            uint32_t basis_idx = i + num_gray_bits;
            #pragma unroll
            for (int r = 0; r < N; r++) row[r] ^= s_basis[(basis_idx - 1) * N + r];
        }
    }

    uint32_t num_iters = (1u << num_gray_bits) - 1;
    for (uint32_t step = 0; step <= num_iters; step++) {
        if (step > 0) {                            // Gray step: flip one basis vector
            uint32_t changed_bit = __builtin_ctz(step) + 1;
            #pragma unroll
            for (int r = 0; r < N; r++) row[r] ^= s_basis[(changed_bit - 1) * N + r];
        }

        // APN check: R(a) = sum a_j row[j] must have rank n-1 for all a in 1..2^n-1
        bool is_apn = true;
        uint64_t matrix_a = 0;
        for (uint32_t a_step = 1; a_step <= A_MAX; a_step++) {
            matrix_a ^= row[__builtin_ctz(a_step)];   // Gray code over a
            if (!check_rank(matrix_a)) { is_apn = false; break; }
        }

        if (is_apn) {
            uint64_t gray_val = step ^ (step >> 1);
            uint64_t actual_sample = (prefix_val << num_gray_bits) | gray_val;
            uint32_t idx = atomicAdd(counter, 1);
            if (idx < RESULTS_CAP) results[idx] = actual_sample;
        }
    }
}

int main(int argc, char** argv) {
    if (argc < 4) {
        std::cerr << "Usage: " << argv[0]
                  << " <basis_rows.bin> <n_free> <total_space_pow2> [start_batch end_batch]"
                     " [out_file] [center_rows.bin]"
                  << std::endl;
        return 1;
    }

    std::string basis_file = argv[1];
    uint32_t n_free = std::stoul(argv[2]);
    uint32_t total_space_pow2 = std::stoul(argv[3]);

    std::vector<uint64_t> h_basis(n_free * N);
    std::ifstream in(basis_file, std::ios::binary);
    if (!in) { std::cerr << "cannot open basis: " << basis_file << std::endl; return 1; }
    in.read((char*)h_basis.data(), (std::streamsize)n_free * N * sizeof(uint64_t));

    uint64_t *d_basis, *d_results, *d_center;
    uint32_t *d_counter;
    (void)hipMalloc(&d_basis, n_free * N * sizeof(uint64_t));
    (void)hipMemcpy(d_basis, h_basis.data(), n_free * N * sizeof(uint64_t), hipMemcpyHostToDevice);
    (void)hipMalloc(&d_results, (size_t)RESULTS_CAP * sizeof(uint64_t));
    (void)hipMalloc(&d_counter, sizeof(uint32_t));
    (void)hipMemset(d_counter, 0, sizeof(uint32_t));

    // optional center (argv[7]): F0's N-row bilinear matrix; default 0 (homogeneous)
    std::vector<uint64_t> h_center(N, 0);
    std::string center_file = (argc >= 8) ? argv[7] : "";
    if (!center_file.empty()) {
        std::ifstream cin_(center_file, std::ios::binary);
        if (!cin_) { std::cerr << "cannot open center: " << center_file << std::endl; return 1; }
        cin_.read((char*)h_center.data(), (std::streamsize)N * sizeof(uint64_t));
    }
    (void)hipMalloc(&d_center, N * sizeof(uint64_t));
    (void)hipMemcpy(d_center, h_center.data(), N * sizeof(uint64_t), hipMemcpyHostToDevice);

    uint32_t gray_bits = 8;
    if (n_free < 8) gray_bits = n_free;

    uint32_t batch_bits = 30;
    if (batch_bits > n_free) batch_bits = n_free;

    uint64_t threads_per_batch = 1ULL << (batch_bits - gray_bits);
    uint32_t group_size = 256;
    uint32_t num_groups = threads_per_batch / group_size;
    if (num_groups == 0) { num_groups = 1; group_size = threads_per_batch; }

    uint64_t total_space = 1ULL << total_space_pow2;
    uint64_t batch_space = 1ULL << batch_bits;
    uint32_t num_batches = total_space / batch_space;
    if (num_batches == 0) num_batches = 1;

    uint32_t start_batch = 0;
    uint32_t end_batch = num_batches;
    if (argc >= 6) { start_batch = std::stoul(argv[4]); end_batch = std::stoul(argv[5]); }

    std::string out_path = (argc >= 7) ? argv[6] : "found_apns.txt";

    std::cout << "--- APN Search (n=" << N << ") ---" << std::endl;
    std::cout << "Space: 2^" << total_space_pow2 << " | Batch: 2^" << batch_bits
              << " | Batches: " << start_batch << " to " << end_batch
              << " | out: " << out_path << std::endl;

    uint64_t total_apns = 0;
    std::ofstream out(out_path, std::ios::app);
    size_t shared_mem_size = n_free * N * sizeof(uint64_t);

    auto t0 = std::chrono::high_resolution_clock::now();
    for (uint32_t b = start_batch; b < end_batch; b++) {
        uint64_t start_prefix = (uint64_t)b * threads_per_batch;

        auto tb = std::chrono::high_resolution_clock::now();
        apn_kernel<<<num_groups, group_size, shared_mem_size>>>(
            d_basis, d_center, d_results, d_counter, start_prefix, gray_bits, n_free);
        (void)hipDeviceSynchronize();
        auto te = std::chrono::high_resolution_clock::now();
        double elapsed = std::chrono::duration<double>(te - tb).count();
        double speed = (double)batch_space / elapsed / 1e9;

        uint32_t h_counter = 0;
        (void)hipMemcpy(&h_counter, d_counter, sizeof(uint32_t), hipMemcpyDeviceToHost);
        if (h_counter > 0) {
            std::vector<uint64_t> h_results(h_counter);
            (void)hipMemcpy(h_results.data(), d_results, h_counter * sizeof(uint64_t), hipMemcpyDeviceToHost);
            for (uint32_t i = 0; i < h_counter; i++) out << h_results[i] << "\n";
            total_apns += h_counter;
            out.flush();
            (void)hipMemset(d_counter, 0, sizeof(uint32_t));
        }

        std::cout << "Batch " << b + 1 << "/" << num_batches << " done in " << elapsed
                  << "s | Speed: " << speed << " Billion ops/sec | Found " << h_counter
                  << " APNs" << std::endl;
    }
    auto t1 = std::chrono::high_resolution_clock::now();
    std::cout << "Found " << total_apns << " APNs in "
              << std::chrono::duration<double>(t1 - t0).count() << "s total." << std::endl;
    return 0;
}
