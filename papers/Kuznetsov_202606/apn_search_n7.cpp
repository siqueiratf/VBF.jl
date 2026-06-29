#include <hip/hip_runtime.h>
#include <iostream>
#include <vector>
#include <fstream>
#include <chrono>
#include <string>

// Ultra-optimized APN search for n=7 purely quadratic functions.
// F is APN iff R(a) has rank 6 for all a != 0.

__device__ __forceinline__ bool check_rank_6(uint64_t M) {
    uint32_t cols[7];
    cols[0] = M & 0xFF;
    cols[1] = (M >> 8) & 0xFF;
    cols[2] = (M >> 16) & 0xFF;
    cols[3] = (M >> 24) & 0xFF;
    cols[4] = (M >> 32) & 0xFF;
    cols[5] = (M >> 40) & 0xFF;
    cols[6] = (M >> 48) & 0xFF;

    int r = 0;
    for (int bit = 0; bit < 7; bit++) {
        if (bit - r > 1) return false; // Early exit: missed 2 pivots, rank <= 5
        int pivot = -1;
        for (int j = r; j < 7; j++) {
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
            for (int j = r + 1; j < 7; j++) {
                if (cols[j] & (1 << bit)) {
                    cols[j] ^= cols[r];
                }
            }
            r++;
        }
    }
    return r == 6;
}

__global__ void apn_kernel_n7(const uint64_t* __restrict__ basis,
                              uint64_t* results, uint32_t* counter,
                              uint64_t start_prefix, uint32_t num_gray_bits,
                              uint32_t total_basis_size) {
    int ti_id = threadIdx.x;
    uint64_t global_id = blockIdx.x * blockDim.x + ti_id;
    
    // Shared memory: only store the basis (45 * 7 = 315 uint64_t words)
    extern __shared__ uint64_t s_basis[];
    
    for (int i = ti_id; i < total_basis_size * 7; i += blockDim.x) {
        s_basis[i] = basis[i];
    }
    __syncthreads();
    
    uint64_t prefix_val = start_prefix + global_id;
    
    // The current function's bilinear form matrix (7 rows)
    uint64_t row[7] = {0, 0, 0, 0, 0, 0, 0};
    
    // Apply prefix bits
    for (uint32_t i = 1; i <= (total_basis_size - num_gray_bits); i++) {
        if (((prefix_val >> (i - 1)) & 1) == 1) {
            uint32_t basis_idx = i + num_gray_bits;
            #pragma unroll
            for (int r = 0; r < 7; r++) {
                row[r] ^= s_basis[(basis_idx - 1) * 7 + r];
            }
        }
    }
    
    uint32_t num_iters = (1u << num_gray_bits) - 1;
    for (uint32_t step = 0; step <= num_iters; step++) {
        if (step > 0) {
            uint32_t changed_bit = __builtin_ctz(step) + 1;
            #pragma unroll
            for (int r = 0; r < 7; r++) {
                row[r] ^= s_basis[(changed_bit - 1) * 7 + r];
            }
        }
        
        bool is_apn = true;
        uint64_t matrix_a = 0;
        
        // Loop over 1..127
        for (int a_step = 1; a_step <= 127; a_step++) {
            int a_changed_bit = __builtin_ctz(a_step);
            matrix_a ^= row[a_changed_bit];
            
            if (!check_rank_6(matrix_a)) {
                is_apn = false;
                break;
            }
        }
        
        if (is_apn) {
            uint64_t gray_val = step ^ (step >> 1);
            uint64_t actual_sample = (prefix_val << num_gray_bits) | gray_val;
            
            uint32_t idx = atomicAdd(counter, 1);
            if (idx < 1000000) {
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
    
    uint32_t start_batch = 0;
    uint32_t end_batch = (1 << (total_space_pow2 - 30));
    if (argc >= 6) {
        start_batch = std::stoul(argv[4]);
        end_batch = std::stoul(argv[5]);
    }

    std::vector<uint64_t> h_basis(n_free * 7);
    std::ifstream in(basis_file, std::ios::binary);
    in.read((char*)h_basis.data(), n_free * 7 * sizeof(uint64_t));
    
    uint64_t* d_basis;
    uint64_t* d_results;
    uint32_t* d_counter;
    (void)hipMalloc(&d_basis, n_free * 7 * sizeof(uint64_t));
    (void)hipMemcpy(d_basis, h_basis.data(), n_free * 7 * sizeof(uint64_t), hipMemcpyHostToDevice);
    
    (void)hipMalloc(&d_results, 1000000 * sizeof(uint64_t));
    (void)hipMalloc(&d_counter, sizeof(uint32_t));
    
    uint32_t gray_bits = 8;
    if (n_free < 8) gray_bits = n_free;
    
    uint32_t batch_bits = 30; // Max batch size!
    if (batch_bits > n_free) batch_bits = n_free;
    
    uint64_t threads_per_batch = 1ULL << (batch_bits - gray_bits);
    uint32_t group_size = 256; 
    uint32_t num_groups = threads_per_batch / group_size;
    if (num_groups == 0) {
        num_groups = 1;
        group_size = threads_per_batch;
    }
    
    uint64_t total_space = 1ULL << total_space_pow2;
    uint64_t batch_space = 1ULL << batch_bits;
    uint32_t num_batches = total_space / batch_space;
    if (num_batches == 0) num_batches = 1;
    
    uint32_t num_gray_bits = gray_bits; 
    uint32_t threads = group_size;
    uint32_t blocks = num_groups;
    
    size_t shared_mem = n_free * 7 * sizeof(uint64_t);
    std::vector<uint64_t> h_results;
    uint64_t total_found = 0;
    
    std::ofstream out_file("found_apns_n7.txt", std::ios::app);

    for (uint32_t batch = start_batch; batch < end_batch; batch++) {
        uint32_t zero = 0;
        (void)hipMemcpy(d_counter, &zero, sizeof(uint32_t), hipMemcpyHostToDevice);
        
        uint64_t start_prefix = ((uint64_t)batch);
        
        auto t0 = std::chrono::high_resolution_clock::now();
        apn_kernel_n7<<<blocks, threads, shared_mem>>>(d_basis, d_results, d_counter, start_prefix, num_gray_bits, n_free);
        (void)hipDeviceSynchronize();
        auto t1 = std::chrono::high_resolution_clock::now();
        
        uint32_t found = 0;
        (void)hipMemcpy(&found, d_counter, sizeof(uint32_t), hipMemcpyDeviceToHost);
        
        if (found > 0) {
            h_results.resize(found);
            (void)hipMemcpy(h_results.data(), d_results, found * sizeof(uint64_t), hipMemcpyDeviceToHost);
            for (uint32_t i = 0; i < found; i++) {
                out_file << h_results[i] << "\n";
            }
            out_file.flush();
            total_found += found;
        }
        
        double dt = std::chrono::duration<double>(t1 - t0).count();
        double speed = (double)(1u << num_gray_bits) * threads * blocks / dt / 1e9;
        std::cout << "Batch " << (batch+1) << "/" << end_batch 
                  << " done in " << dt << "s | Speed: " << speed << " Billion ops/sec" 
                  << " | Found " << found << " APNs" << std::endl;
    }
    
    std::cout << "Found " << total_found << " APNs in total." << std::endl;
    return 0;
}
