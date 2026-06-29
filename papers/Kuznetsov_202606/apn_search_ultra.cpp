#include <hip/hip_runtime.h>
#include <iostream>
#include <vector>
#include <fstream>
#include <chrono>
#include <string>

// Ultra-optimized APN search for purely quadratic functions using the Bilinear Form rank property.
// Instead of storing 256-byte LUTs, we represent each quadratic function as its 8x8 bilinear 
// form matrix C (where C[i][j] = F(e_i ^ e_j) for i != j).
// For each a != 0, the linear differential L_a(x) has an 8x8 matrix R(a).
// It turns out R(a) = \sum_j a_j C_{j, .}, so we can compute it using a Gray code over a!
// F is APN iff R(a) has rank 7 for all a != 0.

__device__ __forceinline__ bool check_rank_7(uint64_t M) {
    uint32_t cols[8];
    cols[0] = M & 0xFF;
    cols[1] = (M >> 8) & 0xFF;
    cols[2] = (M >> 16) & 0xFF;
    cols[3] = (M >> 24) & 0xFF;
    cols[4] = (M >> 32) & 0xFF;
    cols[5] = (M >> 40) & 0xFF;
    cols[6] = (M >> 48) & 0xFF;
    cols[7] = (M >> 56) & 0xFF;

    int r = 0;
    for (int bit = 0; bit < 8; bit++) {
        if (bit - r > 1) return false; // Early exit: missed 2 pivots, rank <= 6
        int pivot = -1;
        for (int j = r; j < 8; j++) {
            if (cols[j] & (1 << bit)) {
                pivot = j;
                break;
            }
        }
        if (pivot != -1) {
            if (pivot != r) {
                uint32_t tmp = cols[r];
                cols[r] = cols[pivot];
                cols[pivot] = tmp;
            }
            #pragma unroll
            for (int j = r + 1; j < 8; j++) {
                if (cols[j] & (1 << bit)) {
                    cols[j] ^= cols[r];
                }
            }
            r++;
        }
    }
    return r == 7;
}

__global__ void apn_kernel_ultra(const uint64_t* __restrict__ basis,
                                 uint64_t* results, uint32_t* counter,
                                 uint64_t start_prefix, uint32_t num_gray_bits,
                                 uint32_t total_basis_size) {
    int ti_id = threadIdx.x;
    uint64_t global_id = blockIdx.x * blockDim.x + ti_id;
    
    // Shared memory: only store the basis (40 * 8 = 320 uint64_t words = 2.5 KB!)
    extern __shared__ uint64_t s_basis[];
    
    for (int i = ti_id; i < total_basis_size * 8; i += blockDim.x) {
        s_basis[i] = basis[i];
    }
    __syncthreads();
    
    uint64_t prefix_val = start_prefix + global_id;
    
    // The current function's bilinear form matrix (8 rows)
    uint64_t row[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    
    // Apply prefix bits
    for (uint32_t i = 1; i <= (total_basis_size - num_gray_bits); i++) {
        if (((prefix_val >> (i - 1)) & 1) == 1) {
            uint32_t basis_idx = i + num_gray_bits;
            #pragma unroll
            for (int r = 0; r < 8; r++) {
                row[r] ^= s_basis[(basis_idx - 1) * 8 + r];
            }
        }
    }
    
    uint32_t num_iters = (1u << num_gray_bits) - 1;
    for (uint32_t step = 0; step <= num_iters; step++) {
        if (step > 0) {
            uint32_t changed_bit = __builtin_ctz(step) + 1;
            #pragma unroll
            for (int r = 0; r < 8; r++) {
                row[r] ^= s_basis[(changed_bit - 1) * 8 + r];
            }
        }
        
        // APN check: check if R(a) = \sum a_j row[j] has rank 7 for all a in 1..255
        bool is_apn = true;
        uint64_t matrix_a = 0;
        
        // We can loop over a using a Gray code to compute matrix_a in 1 XOR per step!
        for (int a_step = 1; a_step <= 255; a_step++) {
            int a_changed_bit = __builtin_ctz(a_step);
            matrix_a ^= row[a_changed_bit];
            
            if (!check_rank_7(matrix_a)) {
                is_apn = false;
                break;
            }
        }
        
        if (is_apn) {
            uint64_t gray_val = step ^ (step >> 1);
            uint64_t actual_sample = (prefix_val << num_gray_bits) | gray_val;
            
            uint32_t idx = atomicAdd(counter, 1);
            if (idx < 100000000) {
                results[idx] = actual_sample;
            }
        }
    }
}

int main(int argc, char** argv) {
    if (argc < 4) {
        std::cerr << "Usage: " << argv[0] << " <basis_bin> <n_free> <total_space_pow2> [start_batch end_batch]" << std::endl;
        return 1;
    }
    
    std::string basis_file = argv[1];
    uint32_t n_free = std::stoul(argv[2]);
    uint32_t total_space_pow2 = std::stoul(argv[3]);
    
    std::vector<uint64_t> h_basis(n_free * 8);
    std::ifstream in(basis_file, std::ios::binary);
    in.read((char*)h_basis.data(), n_free * 8 * sizeof(uint64_t));
    
    uint64_t* d_basis;
    uint64_t* d_results;
    uint32_t* d_counter;
    (void)hipMalloc(&d_basis, n_free * 8 * sizeof(uint64_t));
    (void)hipMemcpy(d_basis, h_basis.data(), n_free * 8 * sizeof(uint64_t), hipMemcpyHostToDevice);
    
    (void)hipMalloc(&d_results, 100000000 * sizeof(uint64_t)); // Allocate 800MB for up to 100 million APNs
    (void)hipMalloc(&d_counter, sizeof(uint32_t));
    (void)hipMemset(d_counter, 0, sizeof(uint32_t));
    
    uint32_t gray_bits = 8;
    if (n_free < 8) gray_bits = n_free;
    
    uint32_t batch_bits = 30; // Max batch size!
    if (batch_bits > n_free) batch_bits = n_free;
    
    uint64_t threads_per_batch = 1ULL << (batch_bits - gray_bits);
    uint32_t group_size = 256; // Standard block size, no LDS bottleneck anymore!
    uint32_t num_groups = threads_per_batch / group_size;
    if (num_groups == 0) {
        num_groups = 1;
        group_size = threads_per_batch;
    }
    
    uint64_t total_space = 1ULL << total_space_pow2;
    uint64_t batch_space = 1ULL << batch_bits;
    uint32_t num_batches = total_space / batch_space;
    if (num_batches == 0) num_batches = 1;
    
    uint32_t start_batch = 0;
    uint32_t end_batch = num_batches;
    if (argc >= 6) {
        start_batch = std::stoul(argv[4]);
        end_batch = std::stoul(argv[5]);
    }

    std::cout << "--- ULTRA APN Search ---" << std::endl;
    std::cout << "Space: 2^" << total_space_pow2 << " | Batch size: 2^" << batch_bits << " | Batches: " << start_batch << " to " << end_batch << std::endl;
    
    uint64_t total_apns = 0;
    std::ofstream out("found_apns.txt", std::ios::app);
    
    auto t0 = std::chrono::high_resolution_clock::now();
    for (uint32_t b = start_batch; b < end_batch; b++) {
        uint64_t start_prefix = (uint64_t)b * threads_per_batch;
        
        size_t shared_mem_size = n_free * 8 * sizeof(uint64_t);
        auto tb = std::chrono::high_resolution_clock::now();
        apn_kernel_ultra<<<num_groups, group_size, shared_mem_size>>>(d_basis, d_results, d_counter, start_prefix, gray_bits, n_free);
        (void)hipDeviceSynchronize();
        auto te = std::chrono::high_resolution_clock::now();
        double elapsed = std::chrono::duration<double>(te - tb).count();
        double speed = (double)batch_space / elapsed / 1e9;
        
        uint32_t h_counter = 0;
        (void)hipMemcpy(&h_counter, d_counter, sizeof(uint32_t), hipMemcpyDeviceToHost);
        
        if (h_counter > 0) {
            std::vector<uint64_t> h_results(h_counter);
            (void)hipMemcpy(h_results.data(), d_results, h_counter * sizeof(uint64_t), hipMemcpyDeviceToHost);
            for (uint32_t i = 0; i < h_counter; i++) {
                out << h_results[i] << "\n";
            }
            total_apns += h_counter;
            out.flush();
            // Reset counter for next batch
            (void)hipMemset(d_counter, 0, sizeof(uint32_t));
        }
        
        std::cout << "Batch " << b+1 << "/" << num_batches << " done in " << elapsed << "s | Speed: " << speed << " Billion ops/sec | Found " << h_counter << " APNs" << std::endl;
    }
    auto t1 = std::chrono::high_resolution_clock::now();
    double total_elapsed = std::chrono::duration<double>(t1 - t0).count();
    
    std::cout << "Found " << total_apns << " APNs in " << total_elapsed << "s total." << std::endl;
    
    return 0;
}
