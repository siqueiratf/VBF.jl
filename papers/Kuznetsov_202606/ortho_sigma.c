/* ortho_sigma.c — fast CCZ-invariant for quadratic APN over F2^8 (sboxU-free).
 *
 * Computes the ortho-derivative signature sigma(F) = (differential spectrum of pi_F,
 * absolute Walsh spectrum of pi_F), the same CCZ-invariant Kuznetsov/Canteaut use:
 * by Yoshiara (CCZ=EA for quadratic APN) a sigma mismatch rigorously certifies
 * CCZ-inequivalence. ~ms/function vs sboxU's ~18s code-equivalence call.
 *
 * Input : one look-up table per line (256 ints, any of [..], {..}, space/comma).
 * Output: one line per function "<idx> <sigmahash16hex>" (FNV-1a of the canonical
 *         sorted spectra). Equal hash ⇒ same sigma ⇒ candidate CCZ-equal; different
 *         hash ⇒ provably CCZ-inequivalent.
 *
 * build: gcc -O3 -o ortho_sigma ortho_sigma.c
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#define N 256

/* ortho-derivative pi_F: for a!=0, the unique nonzero u with u . L_a(e_i)=0 for all i,
 * where L_a(x)=F(x^a)^F(x)^F(a)^F(0) is the linear part of the derivative. */
static void ortho(const int *F, int *pi) {
    pi[0] = 0;
    for (int a = 1; a < N; a++) {
        int d0 = F[a] ^ F[0];
        int col[8];
        for (int i = 0; i < 8; i++) {
            int ei = 1 << i;
            col[i] = F[ei ^ a] ^ F[ei] ^ d0;   /* L_a(e_i) */
        }
        int u = 0;
        for (int cand = 1; cand < N; cand++) {
            int ok = 1;
            for (int i = 0; i < 8; i++)
                if (__builtin_parity(cand & col[i])) { ok = 0; break; }
            if (ok) { u = cand; break; }
        }
        pi[a] = u;
    }
}

static int cmp_int(const void *x, const void *y) { return (*(int*)x) - (*(int*)y); }

/* canonical bytes of the multiset of (value:count) pairs of an int histogram */
static int hist_to_pairs(const int *vals, int n, int *out) {
    int *s = malloc(n * sizeof(int));
    memcpy(s, vals, n * sizeof(int));
    qsort(s, n, sizeof(int), cmp_int);
    int m = 0, i = 0;
    while (i < n) {
        int j = i; while (j < n && s[j] == s[i]) j++;
        out[m++] = s[i]; out[m++] = j - i; i = j;
    }
    free(s);
    return m;
}

/* differential spectrum of g: multiset of DDT counts over a!=0 */
static int diff_spectrum(const int *g, int *pairs) {
    int *counts = calloc(255 * N, sizeof(int)); int n = 0;
    for (int a = 1; a < N; a++) {
        int ddt[N]; memset(ddt, 0, sizeof(ddt));
        for (int x = 0; x < N; x++) ddt[g[x ^ a] ^ g[x]]++;
        for (int b = 0; b < N; b++) counts[n++] = ddt[b];
    }
    int m = hist_to_pairs(counts, n, pairs);
    free(counts);
    return m;
}

/* absolute Walsh spectrum of g: multiset of |W| over output masks v!=0, all u */
static int walsh_spectrum(const int *g, int *pairs) {
    int *vals = malloc(255 * N * sizeof(int)); int n = 0;
    for (int v = 1; v < N; v++) {
        int w[N];
        for (int x = 0; x < N; x++) w[x] = __builtin_parity(v & g[x]) ? -1 : 1;
        for (int len = 1; len < N; len <<= 1)            /* fast Walsh-Hadamard */
            for (int i = 0; i < N; i += 2 * len)
                for (int j = 0; j < len; j++) {
                    int a = w[i+j], b = w[i+len+j];
                    w[i+j] = a + b; w[i+len+j] = a - b;
                }
        for (int u = 0; u < N; u++) vals[n++] = w[u] < 0 ? -w[u] : w[u];
    }
    int m = hist_to_pairs(vals, n, pairs);
    free(vals);
    return m;
}

static uint64_t fnv1a(const int *p, int n) {
    uint64_t h = 1469598103934665603ULL;
    const unsigned char *b = (const unsigned char*)p;
    for (size_t i = 0; i < n * sizeof(int); i++) { h ^= b[i]; h *= 1099511628211ULL; }
    return h;
}

/* sigma hash = FNV-1a over [diff-pairs, -1, walsh-pairs] */
static uint64_t sigma_hash(const int *F) {
    int pi[N]; ortho(F, pi);
    int buf[4096]; int n = 0;
    n += diff_spectrum(pi, buf + n);
    buf[n++] = -1;
    n += walsh_spectrum(pi, buf + n);
    return fnv1a(buf, n);
}

int main(void) {
    char *line = NULL; size_t cap = 0; ssize_t len; int idx = 0;
    while ((len = getline(&line, &cap, stdin)) != -1) {
        int F[N], k = 0;
        for (char *p = line; *p && k < N; ) {
            if ((*p >= '0' && *p <= '9')) { F[k++] = (int)strtol(p, &p, 10); }
            else p++;
        }
        if (k != N) continue;
        printf("%d %016llx\n", idx++, (unsigned long long)sigma_hash(F));
    }
    free(line);
    return 0;
}
