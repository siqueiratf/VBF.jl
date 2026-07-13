// qam_frontier.cpp — BFS frontier-expansion GPU scheduler for the QAM search.
//
// WHY.  qam_dfs.cpp's GPU path is a per-thread depth-first search: the host
// splits the first few levels into a few hundred independent giant-subtree jobs,
// one GPU thread each.  On a 40-CU / 1280-wavefront card that is ~684 threads
// (~1% occupancy), and the prune makes subtrees differ by orders of magnitude,
// so the long-pole threads run alone while the rest idle.  This file re-schedules
// the SAME oracle breadth-first: it holds the frontier of surviving partial
// matrices at level k and, in one kernel launch, tests every (frontier-node,
// candidate) pair for the level-(k+1) prune, then stream-compacts the survivors
// into the level-(k+1) frontier.  The H_8 middle levels have a frontier of
// MILLIONS of partial matrices -> millions of uniform, independent work items per
// launch -> the GPU actually fills.  It is a re-schedule, not new math: check_rank
// / forward_ok / is_qam / reduction_domain below are copied VERBATIM from
// qam_dfs.cpp (which is left untouched), so the result set is identical by
// construction.
//
// A frontier node is stored as its prefix of assigned level-values (nlev felt),
// ~26 bytes for H_8; H is reconstructed per thread from the fixed base + prefix
// (cheap: entry fills).  Stream compaction is atomic-slot (order-independent,
// which BFS does not care about).  One thread per frontier node; each loops its
// level's candidate domain (uniform per level: 256, or the EA-reduced 3 / 96),
// so lanes in a wavefront run the same candidate count and the same rank test.
//
// Build:  hipcc -O3 -munsafe-fp-atomics --offload-arch=gfx1031 -o qam_frontier qam_frontier.cpp
// Usage:  qam_frontier <plan.bin> [--bench] [--tpb 256] [--cap Mnodes]
//
// ── MEASURED RESULT (gfx1031, RX 6750 XT; h8 bench plan, 36.7M nodes) ─────────
// Correctness: IDENTICAL per-level survivor counts and leaf counts to qam_dfs on
//   diagonal n=5,6,7 (72/32/4410) and the H_8 model incl. the EA-reduced levels
//   (x_7=3, x_6 whole-tree=216) — 5/5 plans match.
// Throughput (rocprofv3 --kernel-trace, GPU compute time):
//   per-thread DFS (qam_dfs_gpu, split=2): 0.143 s  -> 2.57e8 nodes/s
//   this BFS frontier                     : 1.86  s  -> 1.97e7 nodes/s   (13x SLOWER)
// The frontier does NOT beat the DFS here.  Bottleneck (measured, not projected):
//   the shared oracle keeps H in SCRATCH (1280 B/lane, from -Rpass-analysis; H is
//   288 B of uint16 lanes, too big for the 39 VGPRs).  The DFS launches only ~684
//   threads (~21 wavefronts, ~1% occupancy) whose ~1 MB scratch working set stays
//   in cache -> compute-bound and fast.  The frontier launches millions of threads
//   so the scratch working set blows the L2/Infinity cache -> VRAM-bandwidth bound;
//   the level-3 kernel (107800 threads) and the tail kernels (up to 8.8M threads)
//   BOTH run at ~1.5-2e7 nodes/s, i.e. MORE THREADS DO NOT HELP -> saturated.
//   Shrinking H to uint8 (-DFELT8 -DMAXN_=8) cuts scratch to 688 B but spikes VGPRs
//   to 128 -> occupancy 16->8 -> still slower (2.19 s).  So the wall is the oracle's
//   per-thread H footprint, not the schedule: BFS exposes more parallelism than the
//   scratch-resident oracle can feed.  The fix is the wavefront-per-node variant
//   (one H in LDS per wavefront, the 255-combination rank bit-sliced across 32
//   lanes) so per-lane state is tiny and H reads hit LDS, not VRAM.  That is the
//   prerequisite to either schedule filling this GPU; it is a separate kernel.
// (rocprofv3 --pmc hardware counters — OccupancyPercent/VALUBusy/MemUnitStalled —
//  could not be collected: counter replay timed out (>90 s) even on a 3-kernel run,
//  likely the card's low-power state; kernel-trace timing + the compiler's static
//  VGPR/scratch/occupancy above stand in for them.)

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <string>
#include <chrono>
#include <hip/hip_runtime.h>
#define HD __host__ __device__

// ═══════════════════════════════════════════════════════════════════════════
// BEGIN verbatim core from qam_dfs.cpp (commit b109145) — the shared oracle.
// ═══════════════════════════════════════════════════════════════════════════
// Representation is compile-time selectable to probe the scratch/bandwidth wall:
//   default: uint16 lanes, MAXN=12 (n<=12).   -DFELT8 -DMAXN_=8: uint8, n<=8 only,
// which shrinks H[MAXN*MAXN] from 288 B to 64 B so it can stay off scratch.
#ifndef MAXN_
#define MAXN_ 12
#endif
#ifdef FELT8
typedef uint8_t felt_t;
#else
typedef uint16_t felt_t;
#endif
static const int MAXN = MAXN_;

HD static inline int f2_rank(felt_t* cols, int k) {
    int r = 0;
    for (int bit = 0; bit < MAXN; bit++) {
        int pivot = -1;
        for (int j = r; j < k; j++) {
            if (cols[j] & (felt_t)(1u << bit)) { pivot = j; break; }
        }
        if (pivot != -1) {
            if (pivot != r) { felt_t t = cols[r]; cols[r] = cols[pivot]; cols[pivot] = t; }
            for (int j = r + 1; j < k; j++) {
                felt_t m = (felt_t)0 - (felt_t)((cols[j] >> bit) & 1u);
                cols[j] ^= (felt_t)(cols[r] & m);
            }
            r++;
            if (r == k) break;
        }
    }
    return r;
}

HD static inline bool is_qam(const felt_t* H, int n) {
    felt_t bvec[MAXN];
    for (int c = 0; c < n; c++) bvec[c] = 0;
    felt_t work[MAXN];
    const uint32_t amax = (1u << n) - 1u;
    for (uint32_t a = 1; a <= amax; a++) {
        int row = __builtin_ctz(a);
        for (int c = 0; c < n; c++) bvec[c] ^= H[row * n + c];
        for (int c = 0; c < n; c++) work[c] = bvec[c];
        if (f2_rank(work, n) != n - 1) return false;
    }
    return true;
}

HD static inline bool forward_ok(const felt_t* H, const uint8_t* known, int n) {
    uint32_t unk[MAXN];
    for (int c = 0; c < n; c++) {
        uint32_t m = 0;
        for (int i = 0; i < n; i++) if (!known[i * n + c]) m |= (1u << i);
        unk[c] = m;
    }
    felt_t b[MAXN]; for (int c = 0; c < n; c++) b[c] = 0;
    uint32_t combo = 0;
    const uint32_t amax = (1u << n) - 1u;
    for (uint32_t a = 1; a <= amax; a++) {
        int row = __builtin_ctz(a);
        for (int c = 0; c < n; c++) b[c] ^= H[row * n + c];
        combo ^= (1u << row);
        int u = 0;
        for (int c = 0; c < n; c++) if (combo & unk[c]) u++;
        int thr = n - 1 - u;
        if (thr <= 0) continue;
        uint32_t basis[MAXN]; for (int t = 0; t < n; t++) basis[t] = 0;
        int rk = 0; bool ok = false;
        for (int c = 0; c < n && !ok; c++) {
            if (combo & unk[c]) continue;
            uint32_t v = b[c];
            for (int bit = n - 1; bit >= 0; bit--) {
                if (!((v >> bit) & 1u)) continue;
                if (!basis[bit]) { basis[bit] = v; rk++; break; }
                v ^= basis[bit];
            }
            if (rk >= thr) ok = true;
        }
        if (!ok) return false;
    }
    return true;
}

HD static inline bool is_proper(const felt_t* H, int n, int k) {
    if (k <= 1) return true;
    felt_t bvec[MAXN];
    for (int c = 0; c < k; c++) bvec[c] = 0;
    felt_t work[MAXN];
    const uint32_t mmax = (1u << k) - 1u;
    for (uint32_t m = 1; m <= mmax; m++) {
        int row = __builtin_ctz(m);
        for (int c = 0; c < k; c++) bvec[c] ^= H[row * n + c];
        for (int c = 0; c < k; c++) work[c] = bvec[c];
        if (f2_rank(work, k) < k - 1) return false;
    }
    return true;
}

HD static inline felt_t gf_mul(felt_t a, felt_t b, int n, uint32_t mod) {
    uint32_t res = 0, x = a;
    uint32_t hib = 1u << n;
    for (int i = 0; i < n; i++) {
        if ((b >> i) & 1u) res ^= x;
        x <<= 1;
        if (x & hib) x ^= mod;
    }
    return (felt_t)res;
}
HD static inline felt_t gf_sq(felt_t a, int n, uint32_t mod) { return gf_mul(a, a, n, mod); }

enum { FILL_ENTRY = 0, FILL_DIAG = 1 };
enum { RED_NONE = 0, RED_COSET_REPS = 1, RED_INVOL_HALF = 2 };
struct RedDesc { int type; int nbasis; int br[8], bc[8]; int tr, tc; };

HD static inline void apply_level(felt_t* H, int n, uint32_t mod,
                                  int fill_type, int p0, int p1, felt_t v) {
    if (fill_type == FILL_ENTRY) {
        H[p0 * n + p1] = v;
        H[p1 * n + p0] = v;
    } else {
        int d = p0;
        felt_t cur = v;
        for (int i = 0; i < n; i++) {
            int c = (i + d) % n;
            H[i * n + c] = cur;
            H[c * n + i] = cur;
            cur = gf_sq(cur, n, mod);
        }
    }
}

HD static inline int reduction_domain(const felt_t* H, int n, const RedDesc& rd, felt_t* out) {
    uint32_t basis[16]; for (int b = 0; b < n; b++) basis[b] = 0;
    for (int i = 0; i < rd.nbasis; i++) {
        uint32_t v = (uint32_t)H[rd.br[i] * n + rd.bc[i]];
        for (int b = n - 1; b >= 0; b--) {
            if (!((v >> b) & 1u)) continue;
            if (!basis[b]) { basis[b] = v; break; }
            v ^= basis[b];
        }
    }
    #define IN_SPAN(xx) ({ uint32_t _t = (uint32_t)(xx); \
        for (int _b = n - 1; _b >= 0; _b--) { if (!((_t >> _b) & 1u)) continue; \
            if (!basis[_b]) break; _t ^= basis[_b]; } _t == 0; })
    int N2 = 1 << n, cnt = 0;
    unsigned char seen[256];
    if (rd.type == RED_COSET_REPS) {
        for (int x = 0; x < N2; x++) seen[x] = IN_SPAN(x) ? 1 : 0;
        for (int x = 0; x < N2; x++) {
            if (seen[x]) continue;
            out[cnt++] = (felt_t)x;
            for (int w = 0; w < N2; w++) if (IN_SPAN(w)) seen[x ^ w] = 1;
        }
    } else {
        uint32_t t = (uint32_t)H[rd.tr * n + rd.tc];
        for (int x = 0; x < N2; x++) seen[x] = 0;
        for (int x = 0; x < N2; x++) {
            if (IN_SPAN(x) || seen[x]) continue;
            out[cnt++] = (felt_t)x;
            seen[x] = 1; seen[x ^ t] = 1;
        }
    }
    #undef IN_SPAN
    return cnt;
}

HD static inline void mark_level(uint8_t* known, int n, int fill_type, int p0, int p1) {
    if (fill_type == FILL_ENTRY) {
        known[p0 * n + p1] = 1;
        known[p1 * n + p0] = 1;
    } else {
        int d = p0;
        for (int i = 0; i < n; i++) { int c = (i + d) % n; known[i * n + c] = 1; known[c * n + i] = 1; }
    }
}
// ═══════════════════════════════════════════════════════════════════════════
// END verbatim core.
// ═══════════════════════════════════════════════════════════════════════════

struct GpuLevel { int fill_type, p0, p1, check_size, dom_off, dom_len; RedDesc red; };

// Host-side plan loader (identical binary format to qam_dfs.cpp / qam_plan.jl).
struct Level { int fill_type, p0, p1, check_size; RedDesc red; std::vector<felt_t> domain; };
struct Plan { int n; uint32_t modulus; int record, prune_mode;
              std::vector<felt_t> base; std::vector<uint8_t> known; std::vector<Level> levels; };
static uint32_t rd_u32(FILE* f){ uint32_t v; if(fread(&v,4,1,f)!=1){fprintf(stderr,"plan short read\n");exit(1);} return v; }
static Plan load_plan(const char* path){
    FILE* f=fopen(path,"rb"); if(!f){fprintf(stderr,"cannot open %s\n",path);exit(1);}
    if(rd_u32(f)!=0x51414d44u){fprintf(stderr,"bad magic\n");exit(1);}
    Plan p; p.n=rd_u32(f); p.modulus=rd_u32(f); int nlev=rd_u32(f); p.record=rd_u32(f); p.prune_mode=rd_u32(f);
    p.base.resize((size_t)p.n*p.n); for(int i=0;i<p.n*p.n;i++) p.base[i]=(felt_t)rd_u32(f);
    p.known.resize((size_t)p.n*p.n); for(int i=0;i<p.n*p.n;i++) p.known[i]=(uint8_t)rd_u32(f);
    p.levels.resize(nlev);
    for(int L=0;L<nlev;L++){ Level& lv=p.levels[L];
        lv.fill_type=rd_u32(f); lv.p0=rd_u32(f); lv.p1=rd_u32(f); lv.check_size=rd_u32(f);
        lv.red.type=rd_u32(f); lv.red.nbasis=rd_u32(f);
        for(int i=0;i<lv.red.nbasis;i++){ lv.red.br[i]=rd_u32(f); lv.red.bc[i]=rd_u32(f);}
        lv.red.tr=rd_u32(f); lv.red.tc=rd_u32(f);
        int dl=rd_u32(f); lv.domain.resize(dl); for(int i=0;i<dl;i++) lv.domain[i]=(felt_t)rd_u32(f);
    }
    fclose(f); return p;
}

#define HIPOK(x) do{ hipError_t _e=(x); if(_e!=hipSuccess){ \
    fprintf(stderr,"HIP error %s at %s:%d\n",hipGetErrorString(_e),__FILE__,__LINE__); exit(1);} }while(0)

// One thread per frontier node.  Reconstruct H from base+prefix, expand this
// level's candidate domain, prune each, atomically append survivors' prefixes.
__global__ void expand_kernel(
        const felt_t* __restrict__ fin, uint64_t n_in, int stride,
        felt_t* __restrict__ fout, unsigned long long* out_counter,
        unsigned long long* node_counter,
        const GpuLevel* __restrict__ levels, int level, int nlev,
        const felt_t* __restrict__ domains, const uint8_t* __restrict__ known_lvl,
        const felt_t* __restrict__ base, int n, uint32_t mod, int prune_mode) {
    uint64_t node = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (node >= n_in) return;
    bool leaf = (level == nlev - 1);

    felt_t H[MAXN * MAXN];
    for (int i = 0; i < n * n; i++) H[i] = base[i];
    for (int L = 0; L < level; L++) {
        GpuLevel g = levels[L];
        apply_level(H, n, mod, g.fill_type, g.p0, g.p1, fin[node * stride + L]);
    }
    GpuLevel g = levels[level];
    felt_t dom[256]; int dsz;
    if (g.red.type != RED_NONE) dsz = reduction_domain(H, n, g.red, dom);
    else { dsz = g.dom_len; for (int j = 0; j < dsz; j++) dom[j] = domains[g.dom_off + j]; }

    unsigned long long local_nodes = 0;
    for (int j = 0; j < dsz; j++) {
        apply_level(H, n, mod, g.fill_type, g.p0, g.p1, dom[j]);
        local_nodes++;
        bool ok = leaf ? is_qam(H, n)
                       : (prune_mode == 1 ? forward_ok(H, known_lvl, n)
                                          : (g.check_size <= 1 ? true : is_proper(H, n, g.check_size)));
        if (!ok) continue;
        unsigned long long idx = atomicAdd(out_counter, 1ULL);
        if (!leaf) {
            for (int L = 0; L < level; L++) fout[idx * stride + L] = fin[node * stride + L];
            fout[idx * stride + level] = dom[j];
        }
    }
    if (node_counter && local_nodes) atomicAdd(node_counter, local_nodes);
}

int main(int argc, char** argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <plan.bin> [--bench] [--tpb N] [--cap Mnodes]\n", argv[0]); return 1; }
    bool bench = false; int tpb = 256; uint64_t cap_M = 64;   // frontier buffer cap in millions of nodes
    for (int i = 2; i < argc; i++) {
        if (!strcmp(argv[i], "--bench")) bench = true;
        else if (!strcmp(argv[i], "--tpb") && i + 1 < argc) tpb = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--cap") && i + 1 < argc) cap_M = atoll(argv[++i]);
    }
    Plan p = load_plan(argv[1]);
    int n = p.n, nlev = (int)p.levels.size(), stride = nlev;
    printf("--- QAM frontier (n=%d, %d levels, modulus=%u) ---\n", n, nlev, p.modulus);

    // per-level known masks (depth-determined)
    std::vector<uint8_t> known_all((size_t)nlev * n * n);
    { std::vector<uint8_t> k = p.known;
      for (int L = 0; L < nlev; L++) {
          mark_level(k.data(), n, p.levels[L].fill_type, p.levels[L].p0, p.levels[L].p1);
          memcpy(&known_all[(size_t)L * n * n], k.data(), (size_t)n * n); } }

    // flatten levels + static domains
    std::vector<GpuLevel> glev(nlev); std::vector<felt_t> flatdom;
    for (int L = 0; L < nlev; L++) {
        glev[L] = { p.levels[L].fill_type, p.levels[L].p0, p.levels[L].p1, p.levels[L].check_size,
                    (int)flatdom.size(), (int)p.levels[L].domain.size(), p.levels[L].red };
        for (felt_t v : p.levels[L].domain) flatdom.push_back(v);
    }

    // device constants
    felt_t *d_base, *d_dom; uint8_t* d_known; GpuLevel* d_lev;
    HIPOK(hipMalloc(&d_base, p.base.size() * sizeof(felt_t)));
    HIPOK(hipMemcpy(d_base, p.base.data(), p.base.size() * sizeof(felt_t), hipMemcpyHostToDevice));
    HIPOK(hipMalloc(&d_dom, (flatdom.empty()?1:flatdom.size()) * sizeof(felt_t)));
    if (!flatdom.empty()) HIPOK(hipMemcpy(d_dom, flatdom.data(), flatdom.size() * sizeof(felt_t), hipMemcpyHostToDevice));
    HIPOK(hipMalloc(&d_known, known_all.size()));
    HIPOK(hipMemcpy(d_known, known_all.data(), known_all.size(), hipMemcpyHostToDevice));
    HIPOK(hipMalloc(&d_lev, glev.size() * sizeof(GpuLevel)));
    HIPOK(hipMemcpy(d_lev, glev.data(), glev.size() * sizeof(GpuLevel), hipMemcpyHostToDevice));

    // ping-pong frontier buffers
    uint64_t cap = cap_M * 1000000ull;
    size_t buf_elems = cap * (size_t)stride;
    felt_t *d_fin, *d_fout;
    HIPOK(hipMalloc(&d_fin, buf_elems * sizeof(felt_t)));
    HIPOK(hipMalloc(&d_fout, buf_elems * sizeof(felt_t)));
    unsigned long long *d_out, *d_nodes;
    HIPOK(hipMalloc(&d_out, sizeof(unsigned long long)));
    HIPOK(hipMalloc(&d_nodes, sizeof(unsigned long long)));
    HIPOK(hipMemset(d_nodes, 0, sizeof(unsigned long long)));

    // initial frontier: 1 empty node
    HIPOK(hipMemset(d_fin, 0, (size_t)stride * sizeof(felt_t)));
    uint64_t n_in = 1, total_leaves = 0;

    auto t0 = std::chrono::high_resolution_clock::now();
    for (int L = 0; L < nlev; L++) {
        bool leaf = (L == nlev - 1);
        int maxdom = (p.levels[L].red.type != RED_NONE) ? 256 : (int)p.levels[L].domain.size();
        if (!leaf && n_in * (uint64_t)maxdom > cap) {
            fprintf(stderr, "level %d: output UB %llu exceeds cap %llu nodes; raise --cap or tile\n",
                    L, (unsigned long long)(n_in * maxdom), (unsigned long long)cap);
            return 2;
        }
        HIPOK(hipMemset(d_out, 0, sizeof(unsigned long long)));
        if (n_in > 0) {                              // guard: no 0-grid launch
            uint64_t blocks = (n_in + tpb - 1) / tpb;
            expand_kernel<<<blocks, tpb>>>(d_fin, n_in, stride, d_fout, d_out, d_nodes,
                                           d_lev, L, nlev, d_dom, d_known + (size_t)L * n * n,
                                           d_base, n, p.modulus, p.prune_mode);
            HIPOK(hipGetLastError());
            HIPOK(hipDeviceSynchronize());
        }
        unsigned long long cnt = 0;
        HIPOK(hipMemcpy(&cnt, d_out, sizeof(unsigned long long), hipMemcpyDeviceToHost));
        printf("  level %2d: survivors=%llu\n", L, cnt);
        if (leaf) { total_leaves = cnt; break; }
        std::swap(d_fin, d_fout);
        n_in = cnt;   // n_in==0 => remaining levels launch 0 blocks and print survivors=0
    }
    HIPOK(hipDeviceSynchronize());
    auto t1 = std::chrono::high_resolution_clock::now();
    double secs = std::chrono::duration<double>(t1 - t0).count();
    unsigned long long nodes = 0;
    HIPOK(hipMemcpy(&nodes, d_nodes, sizeof(unsigned long long), hipMemcpyDeviceToHost));

    printf("QAM leaves    : %llu\n", total_leaves);
    printf("nodes visited : %llu\n", nodes);
    printf("time          : %.4f s\n", secs);
    printf("node rate     : %.4g nodes/s\n", nodes / (secs > 0 ? secs : 1));
    if (bench) printf("BENCH nodes=%llu time=%.4f rate=%.6g\n", nodes, secs, nodes / (secs > 0 ? secs : 1));
    return 0;
}
