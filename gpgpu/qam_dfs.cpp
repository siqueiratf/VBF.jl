// qam_dfs.cpp — depth-first QAM enumerator with the leading-principal-submatrix
// prune, a sibling of apn_search.cpp.
//
// WHY THIS FILE EXISTS.  apn_search.cpp enumerates a *flat* F2-linear subspace
// V_A (a Gray code over 2^dim candidates) and tests each with the full is_qam
// oracle.  That is the right shape for the Kuznetsov self-equivalence census,
// but it is useless for the Yu & Perrin (2022) Conjecture-2 traversal, whose
// flat space is 2^104: the 13 free entries x_1..x_13 of the symmetric matrix
// H_8 each range over F_2^8.  The traversal is only feasible because of a
// *level-wise prune*: after fixing each entry, every completed leading
// principal submatrix must stay "proper" (Yu-Wang-Li Def. 3 / Lemma 5), and a
// candidate that breaks properness kills its whole subtree.  The paper's own
// per-level survivor counts
//     7 x 100 x 154 x 87 x 20 x 2 x 3 x 64 x 90 x 29 x 3 ~= 2^49
// are exactly the fan-out of this DFS; a flat Gray code can never reproduce
// them.  So this file is a RE-ENUMERATION of the same F2 rank oracle, not a new
// oracle: check_rank and the Gray-coded a-loop below are lifted VERBATIM (up to
// the field-element lane width) from apn_search.cpp.
//
// The QAM test.  A symmetric zero-diagonal H over F_{2^n} is a QAM iff every
// nonzero F2-linear combination of its n rows has F2-rank n-1.  "Proper of
// order k" (Def. 3) weakens this to rank >= k-1 on the k x k leading block, and
// is the incremental invariant a prefix of the DFS must preserve.  is_qam here,
// Yu-Wang-Li's is_qam, Ichanska's Thm 3 and Kuznetsov's APN criterion are the
// SAME oracle over the SAME packed representation used by apn_search.cpp.
//
// GENERIC over the construction via a "level plan" (see qam_plan.jl):
//   * FILL_ENTRY levels set one symmetric pair H[r][c]=H[c][r]=v  (Yu-Perrin
//     H_8: 13 entry levels over columns 7,8).
//   * FILL_DIAG  levels set a whole diagonal offset d by squaring v,v^2,v^4,...
//     (Yu-Li-Ichanska-Kaleyski F2-coefficient model; validates against
//     papers/Yu_202512/algorithm2.jl exhaustively at n=5,6,7).
// Each level names the leading submatrix size to re-check for properness; the
// last level checks the full n x n for the QAM (rank == n-1) condition.
//
// Build (CPU reference, no GPU needed):
//     g++ -O3 -fopenmp -o qam_dfs_cpu qam_dfs.cpp
// Build (HIP, host expands the first GPU_SPLIT_LEVELS levels into GPU jobs):
//     hipcc -O3 -DUSE_GPU --offload-arch=gfx1031 -o qam_dfs_gpu qam_dfs.cpp
//
// Usage:
//     qam_dfs <plan.bin> [--trace] [--record out.txt] [--split L]
//   --trace : follow one surviving path (fix level 0 to its first survivor,
//             then greedily descend) and print the per-level survivor counts,
//             the exact quantity to compare against the paper's product.
//   --record: append every QAM leaf found (packed row bytes, decimal) to a file.
//   --split : number of leading levels the host expands (GPU build only).

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <string>
#include <chrono>
#include <atomic>
#include <functional>
#include <algorithm>

#ifdef USE_GPU
#include <hip/hip_runtime.h>
#define HD __host__ __device__
#else
#define HD
#include <omp.h>
#endif

// ── field element lane width ─────────────────────────────────────────────────
// One field element of F_{2^n} fits in a uint16_t for all n <= 16 (we target
// n <= 12).  A packed matrix row is N such lanes.  This is the uint16_t
// generalisation of apn_search.cpp's byte-packed uint64 row (which caps at
// n <= 8); the algorithm is identical, only the lane width changed.
typedef uint16_t felt_t;
static const int MAXN = 12;

// ── check_rank (lifted from apn_search.cpp, uint16-lane form) ────────────────
// F2-rank of the k field elements cols[0..k-1] (each an n-bit vector), with the
// early exit "missed 2 pivots => rank <= k-2".  Returns the exact rank.  For
// the leaf we compare against n-1; for the proper prune against k-1.
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

// ── the QAM leaf: every nonzero row-combination has rank exactly n-1 ─────────
// H is stored row-major: H[i*n + c] = field element in row i, column c.
// This is apn_search.cpp's a_step Gray loop, verbatim in structure: bvec
// accumulates the current row-combination incrementally, one flipped row per
// Gray step, and the first combination that is not rank n-1 rejects.
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

// ── forward-checking prune for the entry-level H_8 model ─────────────────────
// The leading-principal-submatrix prune only fires when a whole leading block
// completes; for the Yu-Perrin H_8 traversal (filling columns n-1 and n entry
// by entry) that is only twice.  To prune at *every* entry we use the sound
// reachability bound behind Yu-Wang-Li's Algorithm 1: a partial fill can still
// extend to a QAM only if, for every nonzero row-combination lambda, the rank
// achievable on the columns already fully known plus the number of not-yet-known
// columns in play can still reach n-1.  Formally let rho = F2-rank over columns
// c for which every row i in supp(lambda) has H[i][c] known, and u = number of
// columns c with at least one unknown H[i][c], i in supp(lambda); if rho+u < n-1
// the combination can never reach rank n-1 and the whole subtree is dead.
// (This is the lower-bound half of the QAM condition; the "== n-1 not n" half is
//  only decidable at the leaf, where is_qam settles it.)
HD static inline bool forward_ok_ref(const felt_t* H, const uint8_t* known, int n) {
    felt_t cols[MAXN];
    const uint32_t lmax = (1u << n) - 1u;
    for (uint32_t lam = 1; lam <= lmax; lam++) {
        int u = 0, kc = 0;
        for (int c = 0; c < n; c++) {
            felt_t acc = 0; bool colknown = true;
            uint32_t s = lam;
            while (s) { int i = __builtin_ctz(s); s &= s - 1;
                if (!known[i * n + c]) { colknown = false; break; }
                acc ^= H[i * n + c];
            }
            if (colknown) cols[kc++] = acc; else u++;
        }
        int rho = f2_rank(cols, kc);
        if (rho + u < n - 1) return false;
    }
    return true;
}

// forward_ok, fast path — BYTE-FOR-BYTE identical accept/reject to forward_ok_ref,
// only cheaper per node:
//   * combos are walked in Gray order (a=1..2^n-1), so the combination vector b
//     and its support mask `combo` update by ONE row-XOR / one bit per step
//     instead of being rebuilt from scratch (this is is_qam's a-loop trick);
//   * the per-column "known?" test is a precomputed bitmask AND (unk[c] holds the
//     unknown rows of column c), replacing the inner popcount walk;
//   * rank is accumulated in an incremental xor-basis with EARLY EXIT: a combo is
//     accepted the instant rho reaches its threshold n-1-u, so most combos stop
//     after a few pivots.  rho+u<n-1 ⇔ rho<n-1-u is the identical reject test.
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
        for (int c = 0; c < n; c++) b[c] ^= H[row * n + c];   // b = combo gray(a)
        combo ^= (1u << row);
        int u = 0;
        for (int c = 0; c < n; c++) if (combo & unk[c]) u++;
        int thr = n - 1 - u;
        if (thr <= 0) continue;                               // always reachable
        uint32_t basis[MAXN]; for (int t = 0; t < n; t++) basis[t] = 0;
        int rk = 0; bool ok = false;
        for (int c = 0; c < n && !ok; c++) {
            if (combo & unk[c]) continue;                     // unknown column
            uint32_t v = b[c];
            for (int bit = n - 1; bit >= 0; bit--) {
                if (!((v >> bit) & 1u)) continue;
                if (!basis[bit]) { basis[bit] = v; rk++; break; }
                v ^= basis[bit];
            }
            if (rk >= thr) ok = true;                         // rho reached threshold
        }
        if (!ok) return false;                                // rho < n-1-u ⇒ dead
    }
    return true;
}

// ── the prune: leading k x k principal submatrix is proper (rank >= k-1) ─────
// Combines the first k rows over the first k columns; the incremental analogue
// of is_qam restricted to a prefix.  This is Yu_202512's is_proper_sub(H,k,n).
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

// ── GF(2^n) squaring, for FILL_DIAG levels (matches VBF gf_pow convention) ───
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

// ── level plan (host side) ───────────────────────────────────────────────────
enum { FILL_ENTRY = 0, FILL_DIAG = 1 };
enum { RED_NONE = 0, RED_COSET_REPS = 1, RED_INVOL_HALF = 2 };

// Dynamic Proposition-3 EA-coset reduction descriptor (Yu & Perrin 2022).
// The candidate domain of a reduced level is computed at run time from the
// current matrix: the span W is generated by the field values at `basis`
// positions (some of which — x_13, x_12 — were assigned by earlier levels), and
//   RED_COSET_REPS : one min-representative per NON-trivial coset of W        (x_7)
//   RED_INVOL_HALF : one rep per {x, x⊕t} pair in F_{2^n}\W, t = H[tr][tc]     (x_6)
// These mirror nontrivial_coset_reps / coset_involution_half in Yu_202211d.
struct RedDesc {
    int type;                 // RED_NONE / RED_COSET_REPS / RED_INVOL_HALF
    int nbasis;               // number of span generators
    int br[8], bc[8];         // generator positions (row,col)
    int tr, tc;               // t position (RED_INVOL_HALF only)
};
struct Level {
    int fill_type;
    int p0;          // entry: row r  ; diag: offset d
    int p1;          // entry: col c  ; diag: unused
    int check_size;  // leading submatrix order to re-check (0 = skip); == n at leaf
    RedDesc red;     // dynamic EA-coset reduction (RED_NONE ⇒ use static domain)
    std::vector<felt_t> domain;
};
struct Plan {
    int n;
    uint32_t modulus;
    int record;
    int prune_mode;             // 0 = leading-principal (check_size); 1 = forward-check
    std::vector<felt_t> base;   // n*n field elements (0 where free)
    std::vector<uint8_t> known; // n*n, 1 where the base entry is fixed
    std::vector<Level> levels;
};

static uint32_t rd_u32(FILE* f) { uint32_t v; if (fread(&v, 4, 1, f) != 1) { fprintf(stderr, "plan: short read\n"); exit(1);} return v; }

static Plan load_plan(const char* path) {
    FILE* f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "cannot open plan %s\n", path); exit(1); }
    uint32_t magic = rd_u32(f);
    if (magic != 0x51414d44u) { fprintf(stderr, "bad plan magic %08x\n", magic); exit(1); }
    Plan p;
    p.n = (int)rd_u32(f);
    p.modulus = rd_u32(f);
    int nlev = (int)rd_u32(f);
    p.record = (int)rd_u32(f);
    p.prune_mode = (int)rd_u32(f);
    p.base.resize((size_t)p.n * p.n);
    for (int i = 0; i < p.n * p.n; i++) p.base[i] = (felt_t)rd_u32(f);
    p.known.resize((size_t)p.n * p.n);
    for (int i = 0; i < p.n * p.n; i++) p.known[i] = (uint8_t)rd_u32(f);
    p.levels.resize(nlev);
    for (int L = 0; L < nlev; L++) {
        Level& lv = p.levels[L];
        lv.fill_type = (int)rd_u32(f);
        lv.p0 = (int)rd_u32(f);
        lv.p1 = (int)rd_u32(f);
        lv.check_size = (int)rd_u32(f);
        lv.red.type = (int)rd_u32(f);
        lv.red.nbasis = (int)rd_u32(f);
        for (int i = 0; i < lv.red.nbasis; i++) { lv.red.br[i] = (int)rd_u32(f); lv.red.bc[i] = (int)rd_u32(f); }
        lv.red.tr = (int)rd_u32(f); lv.red.tc = (int)rd_u32(f);
        int dl = (int)rd_u32(f);
        lv.domain.resize(dl);
        for (int i = 0; i < dl; i++) lv.domain[i] = (felt_t)rd_u32(f);
    }
    fclose(f);
    return p;
}

// apply level L's candidate value v to matrix H (in place)
HD static inline void apply_level(felt_t* H, int n, uint32_t mod,
                                  int fill_type, int p0, int p1, felt_t v) {
    if (fill_type == FILL_ENTRY) {
        H[p0 * n + p1] = v;
        H[p1 * n + p0] = v;
    } else { // FILL_DIAG: offset d = p0, positions (i, (i+d) mod n) = v^{2^i}
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

// Compute a reduced level's candidate domain from the current matrix H.
// Returns the number of candidates written to out[] (<= 2^n).  Mirrors the two
// partitioning routines of Yu_202211d/helpers.jl exactly (same min-rep choice
// and iteration order), so the port is faithful to the proven-complete
// Proposition-3 reduction.  Reductions only occur for the n=8 H_8 model.
HD static inline int reduction_domain(const felt_t* H, int n, const RedDesc& rd, felt_t* out) {
    uint32_t basis[16]; for (int b = 0; b < n; b++) basis[b] = 0;   // xor-basis, slot = high bit
    for (int i = 0; i < rd.nbasis; i++) {
        uint32_t v = (uint32_t)H[rd.br[i] * n + rd.bc[i]];
        for (int b = n - 1; b >= 0; b--) {
            if (!((v >> b) & 1u)) continue;
            if (!basis[b]) { basis[b] = v; break; }
            v ^= basis[b];
        }
    }
    // in-span test via the xor-basis
    #define IN_SPAN(xx) ({ uint32_t _t = (uint32_t)(xx); \
        for (int _b = n - 1; _b >= 0; _b--) { if (!((_t >> _b) & 1u)) continue; \
            if (!basis[_b]) break; _t ^= basis[_b]; } _t == 0; })
    int N2 = 1 << n, cnt = 0;
    unsigned char seen[256];
    if (rd.type == RED_COSET_REPS) {
        for (int x = 0; x < N2; x++) seen[x] = IN_SPAN(x) ? 1 : 0;   // trivial coset W first
        for (int x = 0; x < N2; x++) {
            if (seen[x]) continue;
            out[cnt++] = (felt_t)x;
            for (int w = 0; w < N2; w++) if (IN_SPAN(w)) seen[x ^ w] = 1;   // mark coset x⊕W
        }
    } else { // RED_INVOL_HALF
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

// mark the positions a level fills as "known" (for the forward-check prune)
HD static inline void mark_level(uint8_t* known, int n, int fill_type, int p0, int p1) {
    if (fill_type == FILL_ENTRY) {
        known[p0 * n + p1] = 1;
        known[p1 * n + p0] = 1;
    } else {
        int d = p0;
        for (int i = 0; i < n; i++) { int c = (i + d) % n; known[i * n + c] = 1; known[c * n + i] = 1; }
    }
}

// ────────────────────────────────────────────────────────────────────────────
// CPU recursive DFS (the reference).  Counts QAM leaves; optional per-level
// survivor histogram (whole-tree totals) and a record sink.
// ────────────────────────────────────────────────────────────────────────────
// prune decision for one interior/leaf node
HD static inline bool node_ok(const felt_t* H, const uint8_t* known, int n,
                              int prune_mode, int check_size, bool leaf) {
    if (leaf) return is_qam(H, n);
    if (prune_mode == 1) return forward_ok(H, known, n);
    return (check_size <= 1) ? true : is_proper(H, n, check_size);
}

// Effective candidate domain of a level: the dynamic EA-coset reduction when
// present (computed from H), otherwise the static domain.  `buf` must hold 2^n.
static inline int level_domain(const Level& lv, const felt_t* H, int n, felt_t* buf) {
    if (lv.red.type != RED_NONE) return reduction_domain(H, n, lv.red, buf);
    int m = (int)lv.domain.size();
    for (int i = 0; i < m; i++) buf[i] = lv.domain[i];
    return m;
}

struct DfsCtx {
    const Plan* plan;
    std::vector<std::vector<uint8_t>> known_after; // known_after[L] = base ∪ levels 0..L
    std::vector<std::atomic<uint64_t>> survivors;  // [level] nodes that passed the prune
    std::atomic<uint64_t> leaves_qam{0};
    std::atomic<uint64_t> nodes{0};
    FILE* rec = nullptr;
#ifndef USE_GPU
    omp_lock_t reclock;
#endif
    DfsCtx(const Plan* p) : plan(p), known_after(p->levels.size()), survivors(p->levels.size()) {
        std::vector<uint8_t> k = p->known;
        for (size_t L = 0; L < p->levels.size(); L++) {
            mark_level(k.data(), p->n, p->levels[L].fill_type, p->levels[L].p0, p->levels[L].p1);
            known_after[L] = k;
        }
        for (auto& s : survivors) s.store(0);
    }
};

static void dfs_rec(DfsCtx& ctx, felt_t* H, int level) {
    const Plan& p = *ctx.plan;
    int n = p.n;
    const Level& lv = p.levels[level];
    bool leaf = (level == (int)p.levels.size() - 1);
    const uint8_t* known = ctx.known_after[level].data();
    felt_t dom[4096]; int ndom = level_domain(lv, H, n, dom);
    for (int di = 0; di < ndom; di++) {
        felt_t v = dom[di];
        apply_level(H, n, p.modulus, lv.fill_type, lv.p0, lv.p1, v);
        ctx.nodes.fetch_add(1, std::memory_order_relaxed);
        bool ok = node_ok(H, known, n, p.prune_mode, lv.check_size, leaf);
        if (!ok) continue;
        ctx.survivors[level].fetch_add(1, std::memory_order_relaxed);
        if (leaf) {
            ctx.leaves_qam.fetch_add(1, std::memory_order_relaxed);
            if (ctx.rec) {
#ifndef USE_GPU
                omp_set_lock(&ctx.reclock);
#endif
                // record packed rows as byte-per-column decimals
                for (int i = 0; i < n; i++) {
                    for (int c = 0; c < n; c++)
                        fprintf(ctx.rec, "%u%s", (unsigned)H[i * n + c], c + 1 < n ? "," : "");
                    fputc(i + 1 < n ? ';' : '\n', ctx.rec);
                }
#ifndef USE_GPU
                omp_unset_lock(&ctx.reclock);
#endif
            }
        } else {
            dfs_rec(ctx, H, level + 1);
        }
    }
}

// Byte-identity proof for the fast prune: walk the plan's tree and, at every
// interior node, assert forward_ok (fast) == forward_ok_ref (reference).  Uses
// the fast prune to decide descent, so the visited tree matches the real search.
static void verify_rec(const Plan& p, felt_t* H, const std::vector<std::vector<uint8_t>>& ka,
                       int level, uint64_t& nodes, uint64_t& mism) {
    const Level& lv = p.levels[level];
    bool leaf = (level == (int)p.levels.size() - 1);
    const uint8_t* known = ka[level].data();
    felt_t dom[4096]; int ndom = level_domain(lv, H, p.n, dom);
    for (int di = 0; di < ndom; di++) {
        apply_level(H, p.n, p.modulus, lv.fill_type, lv.p0, lv.p1, dom[di]);
        nodes++;
        bool ok;
        if (leaf) ok = is_qam(H, p.n);
        else {
            bool f = forward_ok(H, known, p.n), r = forward_ok_ref(H, known, p.n);
            if (f != r) mism++;
            ok = f;
        }
        if (ok && !leaf) verify_rec(p, H, ka, level + 1, nodes, mism);
    }
}

static void verify_prune(const Plan& p) {
    std::vector<std::vector<uint8_t>> ka(p.levels.size());
    { std::vector<uint8_t> k = p.known;
      for (size_t L = 0; L < p.levels.size(); L++) {
          mark_level(k.data(), p.n, p.levels[L].fill_type, p.levels[L].p0, p.levels[L].p1);
          ka[L] = k; } }
    std::vector<felt_t> H = p.base;
    uint64_t nodes = 0, mism = 0;
    verify_rec(p, H.data(), ka, 0, nodes, mism);
    printf("prune identity: %llu interior nodes, %llu mismatches (fast vs ref)\n",
           (unsigned long long)nodes, (unsigned long long)mism);
}

// Trace one surviving path: fix each level to its first surviving candidate and
// report the survivor count of the *next* level.  This reproduces the paper's
// "one cardinality combination for a in A" tuple.
static void dfs_trace(const Plan& p) {
    int n = p.n;
    std::vector<felt_t> H = p.base;
    std::vector<uint8_t> known = p.known;
    printf("--- trace: per-level survivor counts along one path ---\n");
    for (int level = 0; level < (int)p.levels.size(); level++) {
        const Level& lv = p.levels[level];
        bool leaf = (level == (int)p.levels.size() - 1);
        mark_level(known.data(), n, lv.fill_type, lv.p0, lv.p1);
        felt_t dom[4096]; int ndom = level_domain(lv, H.data(), n, dom);
        int survivors = 0;
        felt_t first_ok = 0; bool have = false;
        for (int di = 0; di < ndom; di++) {
            felt_t v = dom[di];
            apply_level(H.data(), n, p.modulus, lv.fill_type, lv.p0, lv.p1, v);
            bool ok = node_ok(H.data(), known.data(), n, p.prune_mode, lv.check_size, leaf);
            if (ok) { survivors++; if (!have) { first_ok = v; have = true; } }
        }
        printf("  level %2d (%s p0=%d p1=%d chk=%d red=%d |dom|=%d): survivors=%d\n",
               level, lv.fill_type == FILL_ENTRY ? "entry" : "diag ",
               lv.p0, lv.p1, lv.check_size, lv.red.type, ndom, survivors);
        if (!have) { printf("  (no survivor at level %d; path dead)\n", level); return; }
        apply_level(H.data(), n, p.modulus, lv.fill_type, lv.p0, lv.p1, first_ok);
    }
}

#ifdef USE_GPU
// ── GPU DFS: host expands the first `split` levels into independent jobs, each
// GPU thread owns one (level0..level_{split-1}) prefix and iterative-stack DFSs
// the remaining levels, reusing is_proper / is_qam verbatim. ─────────────────
struct GpuLevel { int fill_type, p0, p1, check_size, dom_off, dom_len, red_slot; RedDesc red; };

// effective domain for a GPU level: dynamic EA-coset reduction, else static slice
__device__ static inline int gpu_level_domain(const GpuLevel& g, const felt_t* domains,
                                              const felt_t* H, int n, felt_t* out) {
    if (g.red.type != RED_NONE) return reduction_domain(H, n, g.red, out);
    for (int i = 0; i < g.dom_len; i++) out[i] = domains[g.dom_off + i];
    return g.dom_len;
}

__global__ void dfs_kernel(const felt_t* __restrict__ base,
                           const uint8_t* __restrict__ base_known,
                           const GpuLevel* __restrict__ levels, int nlev,
                           const felt_t* __restrict__ domains,
                           const felt_t* __restrict__ prefixes, // njobs * split felts
                           int split, int n, uint32_t mod, int prune_mode,
                           uint64_t njobs, unsigned long long* leaf_counter) {
    uint64_t job = (uint64_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (job >= njobs) return;

    felt_t H[MAXN * MAXN];
    uint8_t known[MAXN * MAXN];
    for (int i = 0; i < n * n; i++) { H[i] = base[i]; known[i] = base_known[i]; }
    for (int L = 0; L < split; L++) {                 // apply host-chosen prefix
        GpuLevel g = levels[L];
        apply_level(H, n, mod, g.fill_type, g.p0, g.p1, prefixes[job * split + L]);
        mark_level(known, n, g.fill_type, g.p0, g.p1);
    }
    // iterative DFS.  Static levels index the flat `domains` array directly; only
    // the (few) dynamic EA-reduced levels need a per-thread buffer, recomputed on
    // each fresh descent since a reduced domain depends on the parent's H.  This
    // keeps local memory small (rbuf[MAXN][128] instead of a full 256/level).
    int idx[MAXN], dl[MAXN];
    const felt_t* dptr[MAXN];
    felt_t rbuf[2][128];                              // only reduced levels need storage
    auto enter = [&](int L) {
        if (levels[L].red.type != RED_NONE) {
            dl[L] = reduction_domain(H, n, levels[L].red, rbuf[levels[L].red_slot]);
            dptr[L] = rbuf[levels[L].red_slot];
        } else { dl[L] = levels[L].dom_len; dptr[L] = domains + levels[L].dom_off; }
    };
    for (int L = 0; L < nlev; L++) idx[L] = 0;
    int level = split;
    enter(level);
    unsigned long long found = 0;
    while (level >= split) {
        GpuLevel g = levels[level];
        if (idx[level] >= dl[level]) { idx[level] = 0; level--; continue; }
        felt_t v = dptr[level][idx[level]];
        idx[level]++;
        apply_level(H, n, mod, g.fill_type, g.p0, g.p1, v);
        mark_level(known, n, g.fill_type, g.p0, g.p1);
        bool leaf = (level == nlev - 1);
        bool ok = node_ok(H, known, n, prune_mode, g.check_size, leaf);
        if (!ok) continue;
        if (leaf) { found++; }
        else { level++; enter(level); }
    }
    if (found) atomicAdd(leaf_counter, found);
}
#endif

int main(int argc, char** argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <plan.bin> [--trace] [--record out] [--split L]\n", argv[0]); return 1; }
    const char* planpath = argv[1];
    bool trace = false, verify = false; const char* recpath = nullptr; int split = 2;
    int dump_x13 = -1, dump_x12 = -1;
    for (int i = 2; i < argc; i++) {
        if (!strcmp(argv[i], "--trace")) trace = true;
        else if (!strcmp(argv[i], "--verify")) verify = true;
        else if (!strcmp(argv[i], "--record") && i + 1 < argc) recpath = argv[++i];
        else if (!strcmp(argv[i], "--split") && i + 1 < argc) split = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--dumpred") && i + 2 < argc) { dump_x13 = atoi(argv[++i]); dump_x12 = atoi(argv[++i]); }
    }
    Plan p = load_plan(planpath);
    printf("--- QAM DFS (n=%d, %zu levels, modulus=%u) ---\n", p.n, p.levels.size(), p.modulus);

    if (verify) {
#ifndef USE_GPU
        verify_prune(p);
#endif
        return 0;
    }

    // Port-faithfulness probe: set x_13/x_12, print each reduced level's domain.
    if (dump_x13 >= 0) {
        std::vector<felt_t> H = p.base;
        for (auto& lv : p.levels) {
            if (lv.p0 == 0 && lv.p1 == 6) { H[0 * p.n + 6] = H[6 * p.n + 0] = (felt_t)dump_x13; }
            if (lv.p0 == 1 && lv.p1 == 6) { H[1 * p.n + 6] = H[6 * p.n + 1] = (felt_t)dump_x12; }
        }
        for (size_t L = 0; L < p.levels.size(); L++) {
            if (p.levels[L].red.type == RED_NONE) continue;
            felt_t buf[256]; int m = reduction_domain(H.data(), p.n, p.levels[L].red, buf);
            printf("redlevel %zu type %d domain(%d):", L, p.levels[L].red.type, m);
            std::vector<int> vs(buf, buf + m); std::sort(vs.begin(), vs.end());
            for (int v : vs) printf(" %d", v);
            printf("\n");
        }
        return 0;
    }

    if (trace) { dfs_trace(p); return 0; }

    auto t0 = std::chrono::high_resolution_clock::now();

#ifndef USE_GPU
    // CPU reference: parallelise over the level-0 domain, each task its own H.
    DfsCtx ctx(&p);
    if (recpath) { ctx.rec = fopen(recpath, "w"); omp_init_lock(&ctx.reclock); }
    const Level& l0 = p.levels[0];
    bool leaf0 = (p.levels.size() == 1);
    const uint8_t* known0 = ctx.known_after[0].data();
    felt_t dom0[4096]; int ndom0 = level_domain(l0, p.base.data(), p.n, dom0);
    #pragma omp parallel for schedule(dynamic)
    for (int di = 0; di < ndom0; di++) {
        std::vector<felt_t> H = p.base;
        felt_t v = dom0[di];
        apply_level(H.data(), p.n, p.modulus, l0.fill_type, l0.p0, l0.p1, v);
        ctx.nodes.fetch_add(1, std::memory_order_relaxed);
        bool ok = node_ok(H.data(), known0, p.n, p.prune_mode, l0.check_size, leaf0);
        if (!ok) continue;
        ctx.survivors[0].fetch_add(1, std::memory_order_relaxed);
        if (leaf0) { ctx.leaves_qam.fetch_add(1, std::memory_order_relaxed); }
        else dfs_rec(ctx, H.data(), 1);
    }
    if (ctx.rec) { fclose(ctx.rec); omp_destroy_lock(&ctx.reclock); }
    auto t1 = std::chrono::high_resolution_clock::now();
    double secs = std::chrono::duration<double>(t1 - t0).count();
    printf("nodes visited : %llu\n", (unsigned long long)ctx.nodes.load());
    printf("QAM leaves    : %llu\n", (unsigned long long)ctx.leaves_qam.load());
    printf("per-level survivors (whole tree):\n");
    for (size_t L = 0; L < p.levels.size(); L++)
        printf("  level %2zu: %llu\n", L, (unsigned long long)ctx.survivors[L].load());
    printf("time          : %.3f s\n", secs);
    printf("node rate     : %.3g nodes/s\n", ctx.nodes.load() / (secs > 0 ? secs : 1));
#else
    // GPU: host DFS-expands the first `split` levels (with the prune) into a job
    // list of surviving prefixes, then one GPU thread per prefix finishes.
    if (split < 1) split = 1;
    if (split > (int)p.levels.size() - 1) split = (int)p.levels.size() - 1;
    std::vector<felt_t> prefixes; // flattened njobs*split
    std::vector<felt_t> cur(split);
    // per-depth known masks (positions are depth-determined)
    std::vector<std::vector<uint8_t>> known_after(p.levels.size());
    { std::vector<uint8_t> k = p.known;
      for (size_t L = 0; L < p.levels.size(); L++) {
          mark_level(k.data(), p.n, p.levels[L].fill_type, p.levels[L].p0, p.levels[L].p1);
          known_after[L] = k; } }
    // recursive host expansion of the first `split` levels with the prune
    std::function<void(std::vector<felt_t>&, int)> expand = [&](std::vector<felt_t>& H, int level) {
        const Level& lv = p.levels[level];
        felt_t dom[4096]; int ndom = level_domain(lv, H.data(), p.n, dom);
        for (int di = 0; di < ndom; di++) {
            felt_t v = dom[di];
            apply_level(H.data(), p.n, p.modulus, lv.fill_type, lv.p0, lv.p1, v);
            if (!node_ok(H.data(), known_after[level].data(), p.n, p.prune_mode, lv.check_size, false)) continue;
            cur[level] = v;
            if (level == split - 1) { for (int i = 0; i < split; i++) prefixes.push_back(cur[i]); }
            else expand(H, level + 1);
        }
    };
    { std::vector<felt_t> H = p.base; expand(H, 0); }
    uint64_t njobs = prefixes.size() / split;
    printf("host expanded first %d levels into %llu GPU jobs\n", split, (unsigned long long)njobs);

    // flatten domains and levels for device
    std::vector<GpuLevel> glev(p.levels.size());
    std::vector<felt_t> flatdom;
    int red_slot = 0;
    for (size_t L = 0; L < p.levels.size(); L++) {
        glev[L].fill_type = p.levels[L].fill_type; glev[L].p0 = p.levels[L].p0;
        glev[L].p1 = p.levels[L].p1; glev[L].check_size = p.levels[L].check_size;
        glev[L].dom_off = (int)flatdom.size(); glev[L].dom_len = (int)p.levels[L].domain.size();
        glev[L].red = p.levels[L].red;
        glev[L].red_slot = (p.levels[L].red.type != RED_NONE) ? red_slot++ : -1;
        for (felt_t v : p.levels[L].domain) flatdom.push_back(v);
    }
    if (red_slot > 2) { fprintf(stderr, "more than 2 reduced levels unsupported on GPU\n"); return 1; }
    felt_t *d_base, *d_dom, *d_pref; uint8_t* d_known; GpuLevel* d_lev; unsigned long long *d_cnt;
    hipMalloc(&d_base, p.base.size() * sizeof(felt_t));
    hipMalloc(&d_known, p.known.size() * sizeof(uint8_t));
    hipMalloc(&d_dom, flatdom.size() * sizeof(felt_t));
    hipMalloc(&d_pref, prefixes.size() * sizeof(felt_t));
    hipMalloc(&d_lev, glev.size() * sizeof(GpuLevel));
    hipMalloc(&d_cnt, sizeof(unsigned long long));
    hipMemcpy(d_base, p.base.data(), p.base.size() * sizeof(felt_t), hipMemcpyHostToDevice);
    hipMemcpy(d_known, p.known.data(), p.known.size() * sizeof(uint8_t), hipMemcpyHostToDevice);
    hipMemcpy(d_dom, flatdom.data(), flatdom.size() * sizeof(felt_t), hipMemcpyHostToDevice);
    hipMemcpy(d_pref, prefixes.data(), prefixes.size() * sizeof(felt_t), hipMemcpyHostToDevice);
    hipMemcpy(d_lev, glev.data(), glev.size() * sizeof(GpuLevel), hipMemcpyHostToDevice);
    hipMemset(d_cnt, 0, sizeof(unsigned long long));
    int tpb = 128; uint64_t blocks = (njobs + tpb - 1) / tpb;
    dfs_kernel<<<blocks, tpb>>>(d_base, d_known, d_lev, (int)p.levels.size(), d_dom, d_pref,
                                split, p.n, p.modulus, p.prune_mode, njobs, d_cnt);
    hipDeviceSynchronize();
    unsigned long long h_cnt = 0;
    hipMemcpy(&h_cnt, d_cnt, sizeof(unsigned long long), hipMemcpyDeviceToHost);
    auto t1 = std::chrono::high_resolution_clock::now();
    double secs = std::chrono::duration<double>(t1 - t0).count();
    printf("QAM leaves    : %llu\n", h_cnt);
    printf("time          : %.3f s\n", secs);
#endif
    return 0;
}
