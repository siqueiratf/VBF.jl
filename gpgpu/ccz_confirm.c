/* ccz_confirm.c — split a sigma-bucket of quadratic APN functions into true
 * CCZ-equivalence classes, in native C, multithreaded (OpenMP).
 *
 * WHY. The catalog first buckets quadratic APN by the ortho-derivative sigma
 * signature (a CCZ-invariant; see ortho_sigma.c). A sigma MATCH does not prove
 * CCZ-equivalence: Gold x^3 and x^5 over F2^5 (and x^3, x^9 over F2^7) share a
 * sigma — and a Gamma-rank and a Delta-rank — yet are CCZ-inequivalent. Each
 * multi-member sigma bucket therefore has to be split by the COMPLETE decision.
 *
 * THE COMPLETE DECISION (quadratic APN). By Yoshiara, CCZ = EA for quadratic
 * APN; by Canteaut-Couvreur-Perrin (2022), two quadratic APN F, G are
 * EA-equivalent IFF their ortho-derivatives pi_F, pi_G are LINEAR-equivalent,
 * i.e. there exist invertible F2-linear A, B with pi_G = B . pi_F . A. This is
 * exactly the non-empty condition of VBF's ea_mappings_from_ortho_derivative:
 * it enumerates the linear equivalences of the two ortho-derivatives (via VBF's
 * linear_equivalences / linear_equivalences_general) and lifts them to CCZ
 * maps; the set is non-empty iff such a linear equivalence exists.
 *
 * WHAT THIS PORTS (semantics-for-semantics against VBF):
 *   1. ortho_derivative  (VBF/src/invariants/ortho_derivative.jl) — the DDT /
 *      hyperplane-annihilator construction of pi_F, pi_F(0)=0.
 *   2. linear_equivalences_general (VBF/src/equivalence/linear/general_equivalence.jl)
 *      — the propagation-pruned backtracking that decides invertible-linear
 *      equivalence of two ARBITRARY (non-permutation) functions. It subsumes
 *      the permutation variant `linear_equivalences` used for odd-n Gold, whose
 *      yes/no verdict it reproduces (linear-equivalence existence is one
 *      well-defined predicate; both VBF routines are complete deciders of it).
 *   We only need EXISTENCE, so the search early-exits on the first VALIDATED
 *   witness (a complete invertible L2 with a fully-determined invertible L1
 *   satisfying G = L1.F.L2) — exactly the collect-all "records a solution"
 *   condition of linear_equivalences_general.
 *
 * PARALLELISM. The top of the backtracking tree branches over L2(e_0) in
 * 2^n-1 ways; each is an independent subtree. We build one OpenMP task per
 * (pair, L2(e_0)-candidate) over ALL pairs of ALL buckets, and run them in a
 * single dynamic parallel-for. A per-pair "found" flag lets every subtree of an
 * equivalent pair short-circuit as soon as one witness turns up, while an
 * inequivalent pair exhausts its subtrees spread across all cores. This gives
 * near-linear core scaling on exactly the hard (splitting) buckets.
 *
 * PARTITION. Pairwise verdicts -> union-find into CCZ classes, per bucket.
 *
 * GPU. Not warranted here: with this parallelization the whole catalog test set
 * (n<=8, 2^n<=256) finishes in seconds on a desktop CPU — the working set is a
 * 256-entry LUT, far too small to amortize a HIP launch. The natural GPU target
 * on this branch is the *upstream* APN search (apn_search.cpp / qam_dfs.cpp),
 * not this per-bucket confirmer.
 *
 * Build:  gcc -O3 -fopenmp -o ccz_confirm ccz_confirm.c
 * Usage:  ccz_confirm <luts.tsv> <buckets.tsv>
 *   luts.tsv    lines:  ID\tN\tNAME\tv0 v1 ... v_{2^N-1}
 *   buckets.tsv lines:  N\tSIGMAHASH\tid,id,...
 * Output: per-pair verdict lines  "PAIR <id1> <id2> <0|1>"  (id1<id2),
 *         partition lines         "CLASS <N> <sigma8> <id> <id> ..."  (one/class),
 *         and a summary with wall-clock timing on stderr.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#ifdef _OPENMP
#include <omp.h>
#endif

#define MAXFIELD 4096      /* 2^12, generous upper bound on the field size 2^n */

/* ------------------------------------------------------------------ */
/* function store                                                     */
/* ------------------------------------------------------------------ */
typedef struct {
    int  id;
    int  n;
    int  N;              /* 1<<n */
    char name[128];
    int  lut[MAXFIELD];
    int  ortho[MAXFIELD];/* pi_F, ortho[0]=0 */
    int  ortho_ok;       /* 1 iff a valid ortho-derivative was built */
} Func;

static Func  *g_funcs = NULL;
static int    g_nfuncs = 0;
static int    g_id2idx[8192];   /* id -> index into g_funcs (ids are small) */

/* highest set bit of a positive int, as a mask (matches Julia's
 * `1 << (8*sizeof(Int)-1 - leading_zeros(p))`). */
static inline int highbit(unsigned int p) { return 1 << (31 - __builtin_clz(p)); }

/* ------------------------------------------------------------------ */
/* ortho-derivative — faithful port of VBF ortho_derivative           */
/* For each a!=0: DDT row; H_a = {b!=0 : DDT(a,b) != DDT(a,0)}; the    */
/* smallest cand in [1,2^n-1] with <cand,b>=1 for every b in H_a.      */
/* ------------------------------------------------------------------ */
static int ortho_derivative(const int *F, int n, int *out) {
    int N = 1 << n;
    int ddt[MAXFIELD];
    int hp[MAXFIELD];
    out[0] = 0;
    for (int a = 1; a < N; a++) {
        for (int b = 0; b < N; b++) ddt[b] = 0;
        for (int x = 0; x < N; x++) ddt[F[x] ^ F[x ^ a]]++;
        int row0 = ddt[0];
        int hc = 0;
        for (int b = 1; b < N; b++) if (ddt[b] != row0) hp[hc++] = b;
        if (hc != (N >> 1)) return 0;           /* |H_a| != 2^{n-1} -> not APN */
        int found = 0;
        for (int cand = 1; cand < N && !found; cand++) {
            int ok = 1;
            for (int j = 0; j < hc; j++)
                if ((__builtin_popcount(cand & hp[j]) & 1) == 0) { ok = 0; break; }
            if (ok) { out[a] = cand; found = 1; }
        }
        if (!found) return 0;                   /* no annihilator -> not APN */
    }
    return 1;
}

/* ------------------------------------------------------------------ */
/* linear-equivalence existence — port of linear_equivalences_general */
/* Decide whether invertible F2-linear L1, L2 exist with G = L1.F.L2. */
/* ------------------------------------------------------------------ */
typedef struct {
    const int *F;
    const int *G;
    int  n;
    int  N;
    volatile int *found;   /* shared per-pair early-exit flag */
    int  L2[MAXFIELD];     /* running L2 over the span, L2[0]=0 */
    int  used[16];         /* chosen L2 basis images, index = basis bit */
    int  nused;
} LEState;

/* Fold the constraint L1(u)=v into the partial map (bin -> bout), a triangular
 * F2 basis keyed by each row's HIGH bit. Returns 0 on contradiction. May append
 * a row. `len` is updated. (Port of _lin_add!.) */
static inline int lin_add(int *bin, int *bout, int *len, int u, int v) {
    int r = u, o = 0;
    for (int k = 0; k < *len; k++) {
        int hb = highbit((unsigned)bin[k]);
        if (r & hb) { r ^= bin[k]; o ^= bout[k]; }
    }
    if (r == 0) return (v == o);
    bin[*len]  = r;
    bout[*len] = v ^ o;
    (*len)++;
    return 1;
}

/* Is `v` independent of the L2 basis images chosen so far? (Port of `indep`.) */
static inline int indep(const LEState *st, int v) {
    if (v == 0) return 0;
    int r = v;
    for (int k = 0; k < st->nused; k++) {
        int hb = highbit((unsigned)st->used[k]);
        if (r & hb) r ^= st->used[k];
    }
    return r != 0;
}

/* rank over F2 of a list of vectors */
static int rank_f2(const int *vals, int m) {
    int basis[64], bn = 0;
    for (int i = 0; i < m; i++) {
        int x = vals[i];
        for (int j = 0; j < bn; j++) {
            int hb = highbit((unsigned)basis[j]);
            if (x & hb) x ^= basis[j];
        }
        if (x) basis[bn++] = x;
    }
    return bn;
}

/* At a complete L2 (i==n): reconstruct L1 from the propagated constraints and
 * accept iff it is a genuine, fully-determined invertible witness — exactly the
 * condition under which linear_equivalences_general records a solution. */
static int leaf_accept(LEState *st, const int *bin, const int *bout, int len) {
    int n = st->n, N = st->N;
    if (len != n) return 0;                 /* L1 underdetermined -> skipped */
    if (rank_f2(bout, len) != n) return 0;  /* L1 not invertible */
    int cols[16];
    for (int i = 0; i < n; i++) {
        int r = 1 << i, o = 0, changed = 1;
        while (changed && r != 0) {
            changed = 0;
            for (int k = 0; k < len; k++) {
                int hb = highbit((unsigned)bin[k]);
                if (r & hb) { r ^= bin[k]; o ^= bout[k]; changed = 1; }
            }
        }
        if (r != 0) return 0;               /* not determined (cannot happen) */
        cols[i] = o;
    }
    for (int x = 0; x < N; x++) {           /* full validation L1(F(L2 x))=G(x) */
        int y = st->F[st->L2[x]];
        int l1y = 0;
        for (int i = 0; i < n; i++) if (y & (1 << i)) l1y ^= cols[i];
        if (l1y != st->G[x]) return 0;
    }
    return 1;
}

/* backtracking over the L2 basis images; returns 1 on first witness. */
static int le_recurse(LEState *st, int i, const int *bin, const int *bout, int len) {
    if (*st->found) return 1;               /* another subtree already won */
    if (i == st->n) return leaf_accept(st, bin, bout, len);
    int N = st->N, b = 1 << i;
    int bin2[MAXFIELD], bout2[MAXFIELD], newpos[MAXFIELD];
    for (int img = 1; img < N; img++) {
        if (!indep(st, img)) continue;
        int len2 = len;
        for (int t = 0; t < len; t++) { bin2[t] = bin[t]; bout2[t] = bout[t]; }
        int ok = 1, np = 0;
        for (int x = 0; x < N; x++) {
            if ((x >> i) != 0) continue;    /* x < 2^i : current subspace */
            int nx = x ^ b;
            st->L2[nx] = st->L2[x] ^ img;
            newpos[np++] = nx;
            if (!lin_add(bin2, bout2, &len2, st->F[st->L2[nx]], st->G[nx])) { ok = 0; break; }
        }
        if (ok) {
            st->used[st->nused++] = img;
            if (le_recurse(st, i + 1, bin2, bout2, len2)) return 1;
            st->nused--;
        }
        for (int t = 0; t < np; t++) st->L2[newpos[t]] = -1;
        if (*st->found) return 1;
    }
    return 0;
}

/* One top-level subtree: fix L2(e_0) = img, then search levels 1..n-1.
 * Returns 1 if this subtree contains a witness. */
static int le_subtree(const int *F, const int *G, int n, int img, volatile int *found) {
    LEState st;
    st.F = F; st.G = G; st.n = n; st.N = 1 << n; st.found = found; st.nused = 0;
    for (int x = 0; x < st.N; x++) st.L2[x] = -1;
    st.L2[0] = 0;                           /* L2(0)=0 */
    int bin[MAXFIELD], bout[MAXFIELD], len = 0;
    lin_add(bin, bout, &len, F[0], G[0]);   /* seed F(0) |-> G(0) */
    /* level 0: subspace {0}, new point nx = 1, L2(1) = img */
    st.L2[1] = img;
    if (!lin_add(bin, bout, &len, F[img], G[1])) return 0;
    st.used[0] = img; st.nused = 1;
    return le_recurse(&st, 1, bin, bout, len);
}

/* ------------------------------------------------------------------ */
/* union-find                                                         */
/* ------------------------------------------------------------------ */
static int uf_find(int *p, int i) { while (p[i] != i) { p[i] = p[p[i]]; i = p[i]; } return i; }

/* ------------------------------------------------------------------ */
/* global pair / task tables                                          */
/* ------------------------------------------------------------------ */
typedef struct { int fa, fb; int n; int bucket; } Pair;   /* fa,fb are func indices */

static Pair *g_pairs = NULL;
static int   g_npairs = 0, g_pcap = 0;
static int  *g_found  = NULL;     /* per-pair witness flag */

typedef struct { int pair; int img; } Task;

/* ------------------------------------------------------------------ */
/* IO                                                                 */
/* ------------------------------------------------------------------ */
static void load_luts(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) { fprintf(stderr, "cannot open %s\n", path); exit(1); }
    memset(g_id2idx, 0xFF, sizeof(g_id2idx));
    size_t cap = 64; g_funcs = malloc(cap * sizeof(Func));
    char *line = NULL; size_t lc = 0; ssize_t ll;
    while ((ll = getline(&line, &lc, f)) != -1) {
        if (ll <= 1) continue;
        char *save; char *tid = strtok_r(line, "\t", &save);
        char *tn  = strtok_r(NULL, "\t", &save);
        char *tnm = strtok_r(NULL, "\t", &save);
        char *tl  = strtok_r(NULL, "\t\n", &save);
        if (!tid || !tn || !tnm || !tl) continue;
        if (g_nfuncs == (int)cap) { cap *= 2; g_funcs = realloc(g_funcs, cap * sizeof(Func)); }
        Func *F = &g_funcs[g_nfuncs];
        F->id = atoi(tid); F->n = atoi(tn); F->N = 1 << F->n;
        strncpy(F->name, tnm, sizeof(F->name) - 1); F->name[sizeof(F->name)-1] = 0;
        int k = 0;
        for (char *p = tl; *p && k < F->N; ) {
            if (*p >= '0' && *p <= '9') F->lut[k++] = (int)strtol(p, &p, 10);
            else p++;
        }
        if (k != F->N) { fprintf(stderr, "id %d: got %d/%d lut entries\n", F->id, k, F->N); exit(1); }
        F->ortho_ok = ortho_derivative(F->lut, F->n, F->ortho);
        if (F->id >= 0 && F->id < (int)(sizeof(g_id2idx)/sizeof(int))) g_id2idx[F->id] = g_nfuncs;
        g_nfuncs++;
    }
    free(line); fclose(f);
}

typedef struct { int n; char sig8[9]; int m; int idx[256]; } Bucket;

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s <luts.tsv> <buckets.tsv>\n", argv[0]); return 2; }
    load_luts(argv[1]);

    /* -------- read buckets, build global pair + task tables -------- */
    FILE *bf = fopen(argv[2], "r");
    if (!bf) { fprintf(stderr, "cannot open %s\n", argv[2]); return 1; }
    Bucket *buckets = NULL; int nb = 0, bcap = 0;
    char *line = NULL; size_t lc = 0; ssize_t ll;
    while ((ll = getline(&line, &lc, bf)) != -1) {
        if (ll <= 1) continue;
        char *save; char *tn = strtok_r(line, "\t", &save);
        char *th = strtok_r(NULL, "\t", &save);
        char *tids = strtok_r(NULL, "\t\n", &save);
        if (!tn || !th || !tids) continue;
        int idlist[256], m = 0;
        for (char *p = tids; *p; ) {
            if (*p >= '0' && *p <= '9') idlist[m++] = (int)strtol(p, &p, 10);
            else p++;
        }
        if (m < 2) continue;
        if (nb == bcap) { bcap = bcap ? bcap*2 : 16; buckets = realloc(buckets, bcap*sizeof(Bucket)); }
        Bucket *B = &buckets[nb];
        B->n = atoi(tn); strncpy(B->sig8, th, 8); B->sig8[8] = 0; B->m = m;
        for (int i = 0; i < m; i++) {
            int fi = g_id2idx[idlist[i]];
            if (fi < 0) { fprintf(stderr, "bucket id %d not in luts\n", idlist[i]); return 1; }
            B->idx[i] = fi;
        }
        for (int i = 0; i < m; i++) for (int j = i+1; j < m; j++) {
            if (g_npairs == g_pcap) { g_pcap = g_pcap ? g_pcap*2 : 64; g_pairs = realloc(g_pairs, g_pcap*sizeof(Pair)); }
            g_pairs[g_npairs++] = (Pair){ B->idx[i], B->idx[j], B->n, nb };
        }
        nb++;
    }
    free(line); fclose(bf);

    g_found = calloc(g_npairs, sizeof(int));

    /* build tasks: (pair, first image) over all pairs. img in 1..2^n-1. */
    long ntasks = 0;
    for (int p = 0; p < g_npairs; p++) ntasks += (1 << g_pairs[p].n) - 1;
    Task *tasks = malloc(ntasks * sizeof(Task));
    long t = 0;
    for (int p = 0; p < g_npairs; p++) {
        int N = 1 << g_pairs[p].n;
        /* skip pairs where either ortho-derivative failed: verdict stays 0 */
        int ok = g_funcs[g_pairs[p].fa].ortho_ok && g_funcs[g_pairs[p].fb].ortho_ok;
        if (!ok) continue;
        for (int img = 1; img < N; img++) tasks[t++] = (Task){ p, img };
    }
    long real_tasks = t;

    struct timespec c0, c1;
    clock_gettime(CLOCK_MONOTONIC, &c0);

    #pragma omp parallel for schedule(dynamic, 1)
    for (long k = 0; k < real_tasks; k++) {
        int p = tasks[k].pair;
        if (g_found[p]) continue;                  /* pair already decided equiv */
        const Func *A = &g_funcs[g_pairs[p].fa];
        const Func *B = &g_funcs[g_pairs[p].fb];
        if (le_subtree(A->ortho, B->ortho, g_pairs[p].n, tasks[k].img, (volatile int*)&g_found[p])) {
            #pragma omp atomic write
            g_found[p] = 1;
        }
    }

    clock_gettime(CLOCK_MONOTONIC, &c1);
    double sec = (c1.tv_sec - c0.tv_sec) + (c1.tv_nsec - c0.tv_nsec) / 1e9;

    /* -------- emit per-pair verdicts + per-bucket partition -------- */
    int total_pairs = 0, total_classes = 0;
    for (int p = 0; p < g_npairs; p++) {
        int a = g_funcs[g_pairs[p].fa].id, b = g_funcs[g_pairs[p].fb].id;
        if (a > b) { int s=a; a=b; b=s; }
        printf("PAIR %d %d %d\n", a, b, g_found[p] ? 1 : 0);
        total_pairs++;
    }
    for (int bi = 0; bi < nb; bi++) {
        Bucket *B = &buckets[bi];
        int parent[256]; for (int i = 0; i < B->m; i++) parent[i] = i;
        /* map func-index pair -> local i,j and union on verdict */
        for (int p = 0; p < g_npairs; p++) {
            if (g_pairs[p].bucket != bi || !g_found[p]) continue;
            int li = -1, lj = -1;
            for (int i = 0; i < B->m; i++) {
                if (B->idx[i] == g_pairs[p].fa) li = i;
                if (B->idx[i] == g_pairs[p].fb) lj = i;
            }
            int ri = uf_find(parent, li), rj = uf_find(parent, lj);
            if (ri != rj) parent[ri] = rj;
        }
        int seen[256]; memset(seen, 0, sizeof(int)*B->m);
        for (int i = 0; i < B->m; i++) {
            int r = uf_find(parent, i);
            if (seen[r]) continue;
            seen[r] = 1;
            printf("CLASS %d %s", B->n, B->sig8);
            for (int j = 0; j < B->m; j++) if (uf_find(parent, j) == r) printf(" %d", g_funcs[B->idx[j]].id);
            printf("\n");
            total_classes++;
        }
    }

    int nth = 1;
#ifdef _OPENMP
    nth = omp_get_max_threads();
#endif
    fprintf(stderr, "ccz_confirm: %d buckets, %d pairs, %d classes | %ld subtree-tasks on %d threads in %.4f s\n",
            nb, total_pairs, total_classes, real_tasks, nth, sec);
    free(tasks); free(buckets); free(g_pairs); free(g_found); free(g_funcs);
    return 0;
}
