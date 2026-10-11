# Hyperplane changes of quadratic APN functions

**Path**: `census/quadratic_apn8/theory/HYPERPLANE.md`

**Scope**: Two APN extensions $F = G \oplus_L$ and $F' = G \oplus_{L+D}$ of the same
$(n-1,n)$-function $G$ agree on a hyperplane $H$ and differ on the other coset by a
linear map. This document studies this situation. It connects the extension count
$e(G)$ of `UNIQUENESS.md` with the "hyperplane equivalence" of Taniguchi, Polujan, Pott
and Arshad (TPPA 2025). It gives a combinatorial description of the extensions, compares
the input direction with the output (switching) direction, and defines the
hyperplane-neighbour graph on CCZ classes.

**Status labels**: PROVED (complete proof here or in a cited section), SKETCH (argument
with a named gap), OPEN, OBSERVED (computation only; the scripts and data are given).

**Shared definitions** (see `METHOD.md` Sections 1–4 and `UNIQUENESS.md` Sections 1–4):
$V = H \oplus \mathbb F_2 e_0$, $W = \mathbb F_2^m$ (mostly $m = n$), $B_G$, $I_\alpha =
B_G(\alpha, H)$, $\mathcal V(G)$, $e(G) = |\mathcal V(G)|$, $G \oplus_L$, $\Lambda$,
$\Phi$, $\ker\Phi$, $W_\alpha = I_\alpha^\perp$, $T_\alpha = W_\alpha \setminus \{0\}$,
$\pi_F$, $\mathrm{Rad}_b = \mathrm{Rad}(G_b)$, $\ell_b = b \cdot L$, the orbit formula
(`UNIQUENESS.md` Proposition 6.1) and Conjecture C1 ($\ker\Phi = \Lambda$).

**Scripts** (`theory/hyperplane_theory/`; `make -C theory/hyperplane_theory all threads=2`,
or the single targets `admissible`, `estimates`, `gold`, `graph6`, `graph7`, `aut7`,
`isolated8`):

- `admissible.jl`: admissible selections versus realizable restrictions (Section 2).
- `neighbours.jl`: Gold reach, the exact neighbour graphs for $n = 6, 7$, isolated vertices
  at $n = 8$, $|\mathrm{Aut}|$ for $n = 7$ (Sections 3 and 5).
- Results are in `hyperplane_theory/results/`.

| Statement | Status |
|---|---|
| 1.2 APN $H$-changes of a quadratic $F$ with linear $D$ $\leftrightarrow$ $\mathcal V(F\rvert_H)$; their number is $e(F\rvert_H)$ | PROVED |
| 1.3 TPPA Example 3.3 counts are $e(x^3\rvert_H)$; $n = 6$ value is 35,648, not "about 40,000" | PROVED + OBSERVED |
| 1.4 For quadratic $F$, TPPA Theorem 4.1 changes are the rank-1 $H$-changes | PROVED |
| §1.4 TPPA Theorem 3.5 in this language; all 13 classes at $n = 6$ are pairwise neighbours | OBSERVED |
| 2.3 realizable $\Rightarrow$ admissible; $e/\lvert\ker\Phi\rvert \le$ #admissible | PROVED |
| 2.4 linear criterion: realizable $\iff \lambda_\pi \perp \ker\varepsilon$; admissible $\iff \lambda_\pi \perp K_{\text{loc}}$ | PROVED |
| 2.5 equality iff no admissible selection is killed by $\ker\varepsilon / K_{\text{loc}}$; holds when $\ker\varepsilon = K_{\text{loc}}$ | PROVED |
| 2.6 equality fails for $n = 4, 6, 7, 8$ (holds for $n = 5$) | PROVED (by computation and Schrijver's bound) |
| 3.1 $e > 2^{n-1} \iff$ second $P(G)$-orbit or non-extending symmetry of $G$ | PROVED |
| 3.2 dichotomy criterion for the difference $D$ | PROVED |
| 3.3 radical/rank invariants of $G$ do not separate $e > 2^{n-1}$ | OBSERVED |
| 3.4 why structured functions have more multiple extensions | OPEN (partial data) |
| 4.1 input change $\Delta\varphi \in (\ell \wedge V^*) \otimes W$; switching $\Delta\varphi \in \Lambda^2V^* \otimes \langle a\rangle$; intersection = TPPA Thm 4.1 | PROVED |
| 4.2 switching: liftings form one affine subspace; input: union of $\ker\Phi$-cosets; no exact duality for $m \ge n$ | PROVED |
| 5.1 neighbour relation = EA class of an APN $H$-change | PROVED |
| 5.2 degree bound; degree 0 when $e(F\rvert_H) = 2^{n-1}$ for all $H$ | PROVED |
| 5.3 graph at $n = 6$ complete; at $n = 8$ disconnected (isolated vertices) | PROVED (computation) |
| 5.3 graph at $n = 7$ connected, degrees 2–296 | OBSERVED ($\sigma$ labels) |
| 5.4 census estimator of the mass-weighted mean of $e/2^{n-1} - 1$ | PROVED |
| 5.5 expected yield of a hyperplane-neighbour search at $n = 8$ | SKETCH; confirmed by the scan (Section 6) |
| 6.1 $e(F\rvert_H)$ is constant on the $\mathrm{Aut}(F)$-orbits of hyperplanes | PROVED |
| 6.2 generic functions: one rate of $e > 128$ per hyperplane, about $5.7 \cdot 10^{-4}$, close to independent over hyperplanes | OBSERVED |
| 6.3 the rate grows with the number of rank-4 components and with $B_6$ | OBSERVED |
| 6.4 the second class of a generic function is new with probability $0.313 \pm 0.012$, equal to $1 - \hat c$ of the census | OBSERVED |

---

## 1. Relation to Taniguchi, Polujan, Pott, Arshad (2025)

Source: H. Taniguchi, A. Polujan, A. Pott, R. Arshad, *Changing almost perfect nonlinear
functions on affine subspaces of small codimensions*, arXiv:2501.03922 (LaTeX in
`papers/2025/Taniguchi_202501/input/`; reproduction in `papers/2025/Taniguchi_202501/`).
TPPA work on $\mathbb F_{2^n}$ with $T_0 = \{x : \mathrm{Tr}(x) = 0\}$ and a fixed $e_0$
with $\mathrm{Tr}(e_0) = 1$. We write $H = T_0$ and $V = H \oplus \langle e_0\rangle$.

### 1.1 The statements (codimension 1)

- **TPPA Theorem 2.10** (any $f, g : \mathbb F_2^{n-1} \to \mathbb F_2^m$). The function
  $F$ with $F(x) = f(x)$, $F(x + e_0) = g(x)$ ($x \in H$) is APN if and only if $f$ and $g$
  are APN and $f(x+a) + f(x) + g(y+a) + g(y) \ne 0$ for all $x, y \in H$, $a \in H
  \setminus 0$.
- **TPPA Proposition 2.11** (quadratic $f$, $g = f + L + c$, $L$ linear). $F$ is APN if and
  only if $x \mapsto L(x) + B_f(x, A)$ is injective on $H$ for every $A \in H$.
  This is Theorem 4.1 of Beierle et al. (2025) and Theorem 3.1 of `METHOD.md`: injectivity
  for all $A$ says $L(x) \ne B_f(x, A)$ for $x \ne 0$, that is, $L(x) \notin I_x$.
- **TPPA Corollary 3.1** (from [12], any $F$, any $L$): an APN criterion for
  $F(x) + \mathrm{Tr}(x) L(x)$ in terms of the images of $D_aF$ and $D_a(F+L)$.
- **TPPA Theorem 3.2** (quadratic APN $F$, linear $L$; the `.tex` says
  "$\mathbb F_{2^2}$-linear", an OCR error for $\mathbb F_2$-linear, see the reproduction
  README). $G(x) = F(x) + \mathrm{Tr}(x)L(x)$ is APN if and only if
  $L_a : T_0 \ni x \mapsto L(x) + B_F(x, a + e_0)$ is injective for every $a \in T_0$.
- **TPPA Example 3.3**: for $F = x^3$, the number of linear $L$ with $L(e_0) = 0$ that
  satisfy Theorem 3.2 is 448 ($n = 4$), 4608 ($n = 5$), "about 40 000" ($n = 6$).
- **TPPA Definition 3.4** ($H$-equivalence): $G = F$ on $H$ and $G = F + L$ off $H$ with
  $L$ affine.
- **TPPA Theorem 3.5**: up to EA-equivalence, every quadratic APN function on
  $\mathbb F_{2^6}$ is $x^3 + \mathrm{Tr}(x)L(x)$ with $L$ linear.
- **TPPA Theorem 3.7**: $x^3 + \mathrm{Tr}(x)L(x)$ is APN if and only if an exponential-sum
  identity (3.1) holds.
- **TPPA Theorem 4.1** (codimension 2, any APN $F$): with the four cosets $U_i$ of an
  $(n-2)$-space $U$ and constants $a_i$, $G = F + a_i$ on $U_i$ is APN if and only if
  $F(x_1)+F(x_2)+F(x_3)+F(x_4) \ne a_1 + a_2 + a_3 + a_4$ for every 2-flat that meets each
  $U_i$ once. Example 4.2 applies this to $x^3$ on $\mathbb F_{2^8}$.

Theorems 2.10 and 4.1 and Corollary 3.1 hold for every $F$. Proposition 2.11 and
Theorem 3.2 need a quadratic $F$ and a linear $L$; Theorem 3.7 is specific to $x^3$.

### 1.2 Translation

**Proposition 1.2 (PROVED).** Let $F$ be a quadratic APN $(n,n)$-function, $H = \ker\ell$ a
hyperplane, $e_0 \notin H$, $G = F|_H$ and $L_F = B_F(\cdot, e_0)|_H$. For a linear map
$D : V \to W$, put $F_D = F + \ell \cdot D$ (that is, $F_D = F$ on $H$ and $F + D$ off $H$).

1. $F_D$ is quadratic, and $F_D$ is EA-equivalent to $G \oplus_{L_F + D|_H}$. In
   particular $F = F_0 \simeq G \oplus_{L_F}$.
2. $F_D$ is APN if and only if $L_F + D|_H \in \mathcal V(G)$, if and only if
   $D(\alpha) \notin B_F(\alpha, V \setminus H)$ for every $\alpha \in H \setminus 0$.
3. Thus the number of linear $D$ with $D(e_0) = 0$ such that $F_D$ is APN is exactly
   $e(F|_H)$. (Without the normalisation, multiply by $2^n$ for $D(e_0)$; a constant
   added off $H$ multiplies by another $2^n$. Both are affine changes.)
4. $F_D$ is EA-equivalent to $F$ via the shear of `METHOD.md` Lemma 4.2 when
   $D|_H \in \Lambda$. If C1 holds, the APN $H$-changes modulo these trivial ones are
   counted by $e(F|_H)/2^{n-1}$, the number of restrictions $\pi|_H$.

*Proof.* (1) $\ell(x)D(x)$ is a product of two linear forms, so it is quadratic. Write
$x = y + s e_0$ ($y \in H$). Lemma 1.3(2) of `METHOD.md` gives
$F(y + s e_0) = F(y) + s\,(B_F(y, e_0) + F(e_0) + F(0))$, and $\ell(x)D(x) =
s\,(D(y) + D(e_0))$. So $F_D(y + s e_0) = G(y) + s\,(L_F + D|_H)(y) + s\,c$ with a
constant $c$. The last term is linear in $(y,s)$. (2) Theorem 3.1 of `METHOD.md`. The
second form: $B_F(\alpha, y + e_0) = B_G(\alpha, y) + L_F(\alpha)$, so
$B_F(\alpha, V \setminus H) = L_F(\alpha) + I_\alpha$, and
$L_F(\alpha) + D(\alpha) \notin I_\alpha \iff D(\alpha) \notin L_F(\alpha) + I_\alpha$.
(3) $D \mapsto L_F + D|_H$ is a bijection from $\{D : D(e_0) = 0\}$ onto
$\mathrm{Hom}(H, W)$. (4) `METHOD.md` Lemma 4.2 and `UNIQUENESS.md` Proposition 3.2. $\square$

Item 2 is TPPA Theorem 3.2: the injectivity of
$L_a = L + B_F(\cdot, a + e_0)$ on $T_0$ for all $a \in T_0$ is the statement
$L(\alpha) \ne B_F(\alpha, v)$ for all $v \notin H$.

**Corollary 1.3 (PROVED + OBSERVED).** TPPA Example 3.3 counts $e(x^3|_{T_0})$. Our
counter gives $e = 448, 4608, 35\,648$ for $n = 4, 5, 6$, so the exact $n = 6$ value is
$35\,648 = 32 \cdot 1114$ (the repository reproduction found the same number by brute
force over $2^{30}$ maps). For $n = 7$ and $n = 8$ the counts are $e = 128 = 2 \cdot 64$
and $e = 512 = 4 \cdot 128$ (`UNIQUENESS.md` Section 7; `neighbours.jl: gold_reach`).

**Prediction for $n = 8$.** TPPA give no count for $n = 8$. In this language, the number of
APN codimension-1 changes of $F$ on $H$ (linear $D$, $D(e_0) = 0$) is $e(F|_H)$, and
`UNIQUENESS.md` Section 7 measures it: 128 in 4,966 of 5,000 sampled pairs, 256 in 24,
512 in 10. For $x^3$ every hyperplane gives 512. For a typical member of
`beierle2025_n8`, all 128 changes are the trivial shears ($D|_H \in \Lambda$), so
$H$-equivalence gives nothing new for about 99.97 % of the pairs.

### 1.3 Codimension 2 is a special case

**Proposition 1.4 (PROVED).** Let $F$ be quadratic. Let $U = \ker\ell_1 \cap \ker\ell_2$,
and let $G = F + c(\ell_1(x), \ell_2(x))$ with an arbitrary map
$c : \mathbb F_2^2 \to W$ (this is TPPA (4.1)). Then

$$G = F + a\,\ell_1\ell_2 + (\text{affine}), \qquad a = \sum_{t \in \mathbb F_2^2} c(t) = a_1 + a_2 + a_3 + a_4 .$$

Thus $G$ is an $H$-change of $F$ on $H = \ker \ell_1$ with the rank-1 map
$D = a\,\ell_2$ (and also on $\ker\ell_2$ and $\ker(\ell_1+\ell_2)$). Conversely, every
$H$-change with $\mathrm{rank}(D|_H) \le 1$ has this form.

*Proof.* Every function of $(\ell_1, \ell_2)$ is
$c(0,0) + (c(0,0)+c(1,0))\ell_1 + (c(0,0)+c(0,1))\ell_2 + (\sum_t c(t))\ell_1\ell_2$
(Möbius inversion on $\mathbb F_2^2$). Conversely $D|_H = a\lambda$ with
$\lambda \in H^*$; extend $\lambda$ to $\ell_2$ on $V$; then $\ell_1 D = a \ell_1\ell_2$
up to an affine term. $\square$

So for quadratic $F$, TPPA Theorem 4.1 gives exactly the APN $H$-changes with
$\mathrm{rank}(D) = 1$. Their Example 4.2,
$x^3 + \alpha^{85}\mathrm{Tr}_1^8(x)\mathrm{Tr}_2^8(x)$, is of this type:
$\mathrm{Tr}_2^8(x) = \ell_A + \beta\ell_B$ with $\mathrm{Tr}_1^8 = \ell_B$, so the change is
$\alpha^{85}\ell_A\ell_B$ plus a linear term. Hence it is a hyperplane neighbour of
$x^3$ (Section 5). `neighbours.jl: example42_check` confirms it: the $\sigma$ of the
catalog entry `n8_Taniguchi2025_ex4_2` (`74c0486e…`) is one of the three $\sigma$ among the
extensions of $x^3|_H$ (`UNIQUENESS.md` Section 7.3). The catalog records that this class is
the class of Budaghyan–Carlet–Leander (2009) eq. (6); so Example 4.2 is a known neighbour
of $x^3$, not a new class.

### 1.4 TPPA Theorem 3.5 in this language (OBSERVED)

TPPA Theorem 3.5 says that the canonical extensions of $G = x^3|_{T_0}$ ($n = 6$) meet all
13 EA classes. `neighbours.jl: gold_reach(6)` confirms it: the 1,114 canonical extensions
have 13 distinct $\sigma$, and these are the $\sigma$ of the 13 catalog classes. The
exact neighbour graph at $n = 6$ (all 13 classes, all 63 hyperplanes,
`graph_small(6)`) is the **complete graph** $K_{13}$: every class is a hyperplane
neighbour of every other class. TPPA's Remark 3.6.1 (H-equivalence reaches all classes
from one class, switching does not) is thus true in the strongest form at $n = 6$.

| $n$ | $e(x^3\rvert_H)/2^{n-1}$ | classes among the extensions of $x^3\rvert_H$ |
|---|---|---|
| 4 | 56 | 1 |
| 5 | 288 | 1 |
| 6 | 1114 | 13 (all) |
| 7 | 2 | 2 $\sigma$ values ($x^3$ and one other class) |
| 8 | 4 | 3 |

---

## 2. A combinatorial description of the APN extensions

Fix a quadratic APN $(n-1, n)$-function $G$ on $H$. For $\alpha \in H \setminus 0$,
$T_\alpha = \{b \ne 0 : \alpha \in \mathrm{Rad}_b\}$ has exactly 3 elements, and
$T_\alpha \cup \{0\} = W_\alpha$ is a plane (`UNIQUENESS.md` Section 1).

**Definition 2.1.** A **selection** is a map $\pi : H \setminus 0 \to W$ with
$\pi(\alpha) \in T_\alpha$. For $b \ne 0$ put $R_b = \pi^{-1}(b) \cup \{0\}$. The selection is
**admissible** if every $R_b$ is a linear subspace of $\mathrm{Rad}_b$ with
$\dim R_b \ge \dim\mathrm{Rad}_b - 1$ (so $R_b = \mathrm{Rad}_b$ or a hyperplane of it).
It is **realizable** if $\pi = \pi_F|_{H \setminus 0}$ for an APN extension
$F = G \oplus_L$.

**Remark 2.2.** $\pi^{-1}(b) \subseteq \mathrm{Rad}_b$ holds for every selection, because
$b \in T_\alpha \iff \alpha \in \mathrm{Rad}_b$. The dimension condition is the
restriction rule: $\mathrm{Rad}(F_b) \cap H$ is $\mathrm{Rad}_b$ (case A) or a hyperplane
of $\mathrm{Rad}_b$ (case B) by `UNIQUENESS.md` Proposition 4.1(2) and Lemma 5.1. For
$\dim\mathrm{Rad}_b = 0$ the only choice is $R_b = 0$; for $\dim\mathrm{Rad}_b = 1$,
$R_b \in \{0, \mathrm{Rad}_b\}$; for $\dim\mathrm{Rad}_b \ge 2$, $R_b \ne 0$.

**Proposition 2.3 (PROVED).** Every realizable selection is admissible. Distinct
$\ker\Phi$-cosets in $\mathcal V(G)$ give distinct selections. Hence

$$\frac{e(G)}{|\ker\Phi|} = \#\{\text{realizable selections}\} \le \#\{\text{admissible selections}\}.$$

*Proof.* `UNIQUENESS.md` Lemma 3.3 gives $R_b = \mathrm{Rad}(F_b) \cap H$, and Proposition
4.1(2) there gives its shape. Proposition 3.2 there gives the bijection between
$\ker\Phi$-cosets in $\mathcal V(G)$ and restrictions $\pi_F|_H$. $\square$

### 2.1 The linear criterion

Let $P = \{(\alpha, b) : \alpha \in H\setminus 0,\ b \in T_\alpha\}$, so
$|P| = 3(2^{n-1}-1)$. Let

$$\varepsilon : \mathbb F_2^P \to H \otimes W, \qquad e_{(\alpha,b)} \mapsto \alpha \otimes b .$$

For a selection $\pi$ let $\lambda_\pi \in \mathbb F_2^P$, $\lambda_\pi(\alpha, b) = 1$ iff
$\pi(\alpha) \ne b$. Let $K_{\text{loc}} \subseteq \mathbb F_2^P$ be spanned by

- the **row relations** $\sum_{b \in T_\alpha} e_{(\alpha,b)}$, one for each $\alpha$, and
- the **line relations** $e_{(\alpha_1,b)} + e_{(\alpha_2,b)} + e_{(\alpha_1+\alpha_2,b)}$ for
  $\alpha_1 \ne \alpha_2$ in $\mathrm{Rad}_b \setminus 0$.

Both kinds lie in $\ker\varepsilon$ ($\sum_{b \in T_\alpha} b = 0$ because $T_\alpha \cup 0$
is a plane), so $K_{\text{loc}} \le \ker\varepsilon$.

**Theorem 2.4 (PROVED).** Let $\lambda \in \mathbb F_2^P$ have exactly one zero in every row
$\{(\alpha, b) : b \in T_\alpha\}$; these are exactly the vectors $\lambda_\pi$.

1. $\pi$ is admissible if and only if $\lambda_\pi \perp K_{\text{loc}}$.
2. $\pi$ is realizable if and only if $\lambda_\pi \perp \ker\varepsilon$, that is,
   $\lambda_\pi \in \mathrm{Im}(\varepsilon^{T})$, which means: there is a linear
   $L : H \to W$ with $b \cdot L(\alpha) = \lambda_\pi(\alpha, b)$ for all $(\alpha,b) \in P$.

*Proof.* (1) A row of $\lambda_\pi$ is $(0,1,1)$ up to order, so it is orthogonal to the row
relation. For fixed $b$, the function $f_b(\alpha) = \lambda_\pi(\alpha, b)$ on
$\mathrm{Rad}_b$ ($f_b(0) := 0$) is orthogonal to all line relations iff
$f_b(\alpha_1) + f_b(\alpha_2) = f_b(\alpha_1 + \alpha_2)$, iff $f_b$ is a linear
functional, iff its zero set $R_b$ is $\mathrm{Rad}_b$ or a hyperplane of it.
(2) $\varepsilon^T(L)(\alpha, b) = b \cdot L(\alpha)$ under
$(H \otimes W)^* = \mathrm{Hom}(H, W)$, and $\mathrm{Im}(\varepsilon^T) =
(\ker\varepsilon)^\perp$. If $F = G \oplus_L$ is APN, then by Lemma 3.1 of
`UNIQUENESS.md`, $\pi_F(\alpha)$ is the unique $b \in T_\alpha$ with $b \cdot L(\alpha) = 0$,
so $\varepsilon^T(L) = \lambda_{\pi_F}$. Conversely, if $\varepsilon^T(L) = \lambda_\pi$,
then for each $\alpha$ the functional $b \mapsto b\cdot L(\alpha)$ on $W_\alpha$ is nonzero
(two of the three values are 1), so $L(\alpha) \notin I_\alpha = W_\alpha^\perp$; thus
$L \in \mathcal V(G)$ and $\pi_{G \oplus_L} = \pi$. $\square$

**Corollary 2.5 (PROVED).** The admissible selections are the realizable ones plus those
whose $\lambda_\pi$ is orthogonal to $K_{\text{loc}}$ but not to $\ker\varepsilon$.
Equality holds when $\ker\varepsilon = K_{\text{loc}}$. If C1 holds, then
$\dim\ker\varepsilon = |P| - (n-1)^2$ (`UNIQUENESS.md` Proposition 4.1(3)).

### 2.2 Equality fails (PROVED by computation and by a matching bound)

**Lemma 2.6 (PROVED).** Let $G$ have the radical type "$2^{n-1}$ components with
$\mathrm{Rad}_b = 0$ and $2^{n-1}-1$ components with $\dim \mathrm{Rad}_b = 2$" (this is
the type of every restriction $x \mapsto F|_H$ at $n = 5$ and $n = 7$ in the experiment).
Then the admissible selections are the perfect matchings of the bipartite graph between
the $N = 2^{n-1} - 1$ points of $H \setminus 0$ and the $N$ components $b$ with
$\dim\mathrm{Rad}_b = 2$ ($\alpha \sim b$ iff $\alpha \in \mathrm{Rad}_b$). This graph is
3-regular. By Schrijver's theorem (A. Schrijver, *Counting 1-factors in regular bipartite
graphs*, J. Combin. Theory Ser. B 72 (1998) 122–135), there are at least
$(4/3)^{N}$ admissible selections.

*Proof.* Each $b$ with $\dim\mathrm{Rad}_b = 2$ needs $R_b \ne 0$, so it covers 3 points
($R_b = \mathrm{Rad}_b$) or 1 point (a line). The $N$ components cover the $N$ points
exactly once, so every component covers exactly one point. Each point lies in exactly 3
radicals, all of dimension 2. Schrijver: a $k$-regular bipartite graph with $2N$
vertices has at least $((k-1)^{k-1}/k^{k-2})^N$ perfect matchings. $\square$

At $n = 7$: $N = 63$, so at least $(4/3)^{63} \approx 7.4 \cdot 10^7$ admissible
selections, while $e/2^6 \le 13$ for every one of the 61,976 pairs. At $n = 5$
($N = 15$) both numbers are 288.

**Computation** (`admissible.jl: admissible_report`, `admissible_estimates`; file
`hyperplane_theory/results/admissible.tsv`). $|P|$, $\dim\ker\varepsilon$ and
$\dim K_{\text{loc}}$ are exact.

| $n$ | pairs | realizable $e/\lvert\ker\Phi\rvert$ | admissible | $(\lvert P\rvert, \dim\ker\varepsilon, \dim K_{\text{loc}})$ | equality |
|---|---|---|---|---|---|
| 4 | 15 (all) | 56 | 113 (exact) | (21, 12, 11) | no |
| 5 | 62 (all) | 288 | 288 (exact) | (45, 29, 29) | **yes** |
| 6 | 819 (all) | 992–1984 | 2,031,617 – 251,942,400 (exact) | (93, 68, 50–57) | no |
| 7 | 488 (one $H$ per class) | 1–12 | $\ge 7.4 \cdot 10^7$ (Lemma 2.6) | (189, 153, 122–125) | no |
| 8 | 134 (all 34 with $e > 128$, 100 with $e = 128$) | 1–4 | $\ge$ realizable + 1 in 96 pairs (enumeration to $2\cdot 10^5$ nodes); Knuth estimate $10^{30.7}$–$10^{33.3}$ | (381, 332, 209–216) | no |

Thus the combinatorial conditions (fibres are subspaces of the right dimension) are far
from sufficient for $n \ge 6$. The missing conditions are the $\dim\ker\varepsilon -
\dim K_{\text{loc}}$ "non-local" linear relations among the pure tensors
$\alpha \otimes b$ (for example 121–123 of them at $n = 8$). At $n = 5$ there are none,
and the combinatorial description is exact. Also $\dim\ker\varepsilon = |P| - (n-1)^2$ in
every case, as C1 predicts.

---

## 3. When is $e(G) > 2^{n-1}$?

**Proposition 3.1 (PROVED).** Let $F$ be one APN extension of $G$. Then $e(G) > 2^{n-1}$ if
and only if (i) $\mathcal V(G)$ has a $P(G)$-orbit other than the orbit of $F$, or (ii)
$|\mathrm{Stab}(\varphi_G)| > |\mathrm{Stab}_H(F)|$, that is, some symmetry of $G$ does not
extend to a symmetry of $F$ that fixes $H$. Case (i) holds whenever $G$ has two
CCZ-inequivalent extensions.

*Proof.* The orbit formula (`UNIQUENESS.md` Proposition 6.1) writes $e/2^{n-1}$ as a sum of
positive integers $|\mathrm{Stab}(\varphi_G)|/|\mathrm{Stab}_H(F_O)|$, one per orbit.
The sum is 1 iff there is one orbit and its term is 1. $\square$

**Proposition 3.2 (dichotomy, PROVED).** Let $F = G \oplus_L$ be APN and $D \in
\mathrm{Hom}(H, W)$. Then $G \oplus_{L+D}$ is APN if and only if, for every
$\alpha \in H\setminus 0$,

$$\pi_F(\alpha) \cdot D(\alpha) = 0 \ \Longrightarrow\ D(\alpha) \in I_\alpha .$$

The set $A_D = \{\alpha : D(\alpha) \notin I_\alpha\}$ (where the restriction of $\pi$
changes) is then exactly $\{\alpha : \pi_F(\alpha)\cdot D(\alpha) = 1\}$.

*Proof.* $L(\alpha) + D(\alpha) \notin I_\alpha \iff D(\alpha) \notin L(\alpha) + I_\alpha$.
$I^F_\alpha = I_\alpha \cup (L(\alpha) + I_\alpha) = \pi_F(\alpha)^\perp$. So the forbidden
set is $\pi_F(\alpha)^\perp \setminus I_\alpha$. If $D(\alpha) \notin I_\alpha$ and
$D(\alpha)$ is allowed, then $\pi_F(\alpha)\cdot D(\alpha) = 1$; if $D(\alpha) \in I_\alpha$,
then $\pi_F(\alpha)\cdot D(\alpha) = 0$. $\square$

So a second extension needs a linear $D \notin \ker\Phi$ whose "support"
$\{\alpha : D(\alpha) \notin I_\alpha\}$ coincides with the set where $D(\alpha)$ has
odd product with $\pi_F(\alpha)$. This is a strong condition: outside $A_D$, $D(\alpha)$ must
lie in the $(n-2)$-dimensional space $I_\alpha$, a fraction $1/4$ of $\pi_F(\alpha)^\perp$.

**Observation 3.3 (OBSERVED): simple invariants of $G$ do not separate.**

- Rank (radical) type of $G$ at $n = 8$: $e > 128$ occurs for both types
  $(234,21,0,0)$ (33 of 4,959 pairs) and $(238,16,1,0)$ (1 of 41)
  (`UNIQUENESS.md` Section 7.2). The rank type of $G$ does not determine the rank type
  of the extensions (`UNIQUENESS.md` Corollary 5.3).
- $\dim K_{\text{loc}}$ (which measures dependencies among the local relations): in the
  134 pairs at $n = 8$, $e > 128$ occurs for $\dim K_{\text{loc}} = 210, 211, 216$, and
  $e = 128$ for 209, 210, 211, 215. At $n = 7$ and $n = 6$ the values of $e/2^{n-1}$ spread
  over all values of $\dim K_{\text{loc}}$. No separation.
- Symmetry: the `beierle2025_n8` member 3,049,449 has $|\mathrm{Aut}| = 2^8$, and its
  restriction to $u = 249$ has $\mathrm{Stab}(\varphi_G) = 1$ and $e = 256$
  (`UNIQUENESS.md` Section 7.3). So case (i) of Proposition 3.1 occurs without any
  symmetry; a nontrivial automorphism group is not necessary.

**3.4 Structured functions (OPEN, with data).** The observed rates of pairs with
$e > 128$ at $n = 8$: Gold $x^3$ 5/5 ($e = 512$), $x^9$ 5/5 (256), Edel–Pott 13/110,
Beierle–Leander 2022 8/480, `beierle2025_n8` 1/3,185 (`UNIQUENESS.md` Section 7.2), and 2
of $20 \cdot 255$ further pairs of random `beierle2025_n8` members in Section 5.3 below. We cannot prove why structured
families have more multiple extensions. What we can say:

1. (PROVED) If $\mathrm{Aut}(F)$ is transitive on hyperplanes (Gold), the value
   $e(F|_H)$ is the same for all $H$; so the rate is 0 or 1 per class. The Gold rate
   1 is a single event, not 255 independent events.
2. (PROVED) If $e(F|_H) > 2^{n-1}$ is caused by case (ii) of Proposition 3.1 alone, then
   all extensions are EA-equivalent to $F$. In all 34 observed pairs at $n = 8$ the
   extensions have at least two distinct $\sigma$, so case (i) occurs every time; symmetry
   alone never explains the observed cases.
3. (OBSERVED, $n = 7$) `neighbours.jl: aut_small(7)` gives $|\mathrm{Aut}|$ for all 488
   classes (`results/aut_n7.tsv`). Compared with the exact graph:

   | $\lvert\mathrm{Aut}\rvert$ | classes | degree | mean $e/64$ over the 127 hyperplanes | share of hyperplanes with $e = 64$ |
   |---|---|---|---|---|
   | 128 (trivial) | 473 | 216–296 | 3.88 (3.39–4.46) | 0.064 |
   | 896 | 12 | 40–68 | 3.89 (3.11–5.20) | 0.060 |
   | 113,792 (Gold) | 3 | 2 | 2.67 (2–3) | 0 |

   At $n = 7$ a large automorphism group does **not** raise the number of extensions per
   hyperplane (the means are equal), and it lowers the degree, because the hyperplanes fall
   into fewer $\mathrm{Aut}$-orbits (about $127/7$ for $|\mathrm{Stab}| = 7$). So at
   $n = 7$ the data contradict "symmetry causes multiple extensions". At $n = 8$ the
   structured families have higher per-hyperplane rates, but we have no $|\mathrm{Aut}|$
   data for the 34 pairs (one computation takes about 7 minutes).
4. (SKETCH) A plausible mechanism: the known structured families (Gold, Edel–Pott,
   Beierle–Leander, QAM) are built from few parameters, often over subfields, and their
   hyperplane restrictions share these restrictions; the neighbouring classes of a
   structured class are often structured too (for $x^3$ at $n = 8$ the neighbours are in the
   catalog `functions` table). The gap: no invariant of $G$ that forces a second solution
   of the system in Proposition 3.2 is known.

---

## 4. Input direction versus output direction

Identify $\mathrm{Hom}(\Lambda^2 V, W) = \Lambda^2 V^* \otimes W$ (`METHOD.md` Section 1).
For $\ell \in V^*\setminus 0$ and $a \in W \setminus 0$:

- an **input change** on $H = \ker\ell$ adds $\Delta\varphi \in (\ell \wedge V^*) \otimes W$:
  $\Delta = \ell \cdot D$ has bilinear form $\ell(x)D(y) + \ell(y)D(x)$. Every component of
  $\Delta$ has rank $\le 2$, and all of them contain the same linear form $\ell$;
- an **output switching** in direction $a$ (Edel–Pott; paper Remarks 3.17–3.18) adds
  $\Delta\varphi \in \Lambda^2 V^* \otimes \langle a\rangle$: $F' = F + a f$ with a quadratic
  Boolean $f$.

**Proposition 4.1 (PROVED).** $(\ell \wedge V^*) \otimes W \ \cap\ \Lambda^2V^* \otimes
\langle a \rangle = (\ell \wedge V^*) \otimes \langle a\rangle$. A change lies in both
families iff it is $a\,\ell\lambda$ (up to affine terms), that is, a rank-1 input change,
that is, TPPA Theorem 4.1 for quadratic $F$ (Proposition 1.4).

*Proof.* A tensor in $(\ell\wedge V^*)\otimes W$ with all values in $\langle a \rangle$ is
$(\ell \wedge \mu) \otimes a$. $\square$

**Proposition 4.2 (PROVED): the two extension problems have different type.**

1. *Output.* Let $\psi = \pi_a \circ \varphi$ be the $(n, m-1)$-function obtained by
   projecting along $a$, $Z = D_n \cap \ker\psi$ (the flats on which $\psi$ vanishes) and
   fix a lift $\tilde\psi$. The APN functions $\tilde\psi + a f$ are those with $f(v) = 1$ for
   all $v \in Z$. They form **one coset** $f_0 + Z^0$ of the annihilator of $\mathrm{span}(Z)$,
   or the empty set. The trivial moves $f \mapsto f + \beta\circ\psi$
   ($\beta \in (W/\langle a\rangle)^*$, an output linear map) form a subgroup of $Z^0$ of
   order $2^{m-1}$. So the number of APN liftings is $0$ or a power of 2, and it is
   $2^{m-1}$ (unique up to trivial moves) iff $\dim\mathrm{span}(Z) = \binom n2 - (m-1)$.
   For $m = n$ this is the full-rank condition of the paper's Remark 3.17
   ($\binom{n-1}2$ free unknowns).
2. *Input.* $\mathcal V(G)$ is a union of $\ker\Phi$-cosets, one for each nonzero point of
   $\mathrm{Im}\Phi$ in $\prod_\alpha (Q_\alpha \setminus 0)$; the trivial moves $\Lambda$
   have order $2^{n-1}$. The count is not a power of 2 in general ($e/32 = 1114$, $1473$ at
   $n = 6$).
3. The reason is the dimension of the quotient in which the value must be nonzero: 1 for
   the output switching ($\varphi(v) \in \langle a\rangle$ for $v \in Z$; "nonzero" is the
   affine condition $f(v) = 1$), and $\dim Q_\alpha = m - n + 2 \ge 2$ for the input
   extension ("nonzero in $\mathbb F_2^2$" is not affine). The input problem would be affine
   only for $m = n - 1$; but quadratic APN $(n, n-1)$-functions do not exist for $n \ge 3$
   (APN with $m = n-1$ means differential uniformity $2^{n-m}$, that is, vectorial bent,
   which needs $m \le n/2$).

So there is **no exact duality** for $m \ge n$; there is an analogy with the dictionary
$\Lambda \leftrightarrow \{\beta\circ\psi\}$ (both of order $2^{n-1}$ for $m = n$),
$\ker\Phi \leftrightarrow Z^0$, "$e = 2^{n-1}$" $\leftrightarrow$ "full rank". The output
uniqueness is decided by one rank computation; the input uniqueness needs a search
(FL3) or the linear criterion of Theorem 2.4 together with a nonvanishing condition.

---

## 5. The hyperplane-neighbour graph

**Definition 5.0.** Quadratic APN $(n,n)$-classes $[F]$, $[F']$ are **hyperplane
neighbours** ($F \sim F'$) if $F|_H$ and $F'|_{H'}$ are EA-equivalent for some hyperplanes
$H, H'$ (restrictions in any basis; EA-equivalence of $(n-1,n)$-functions).

**Proposition 5.1 (PROVED).** $F \sim F'$ iff $F'$ is EA-equivalent to an APN $H$-change
$F + \ell D$ of $F$ ($D$ linear). The relation is reflexive, symmetric, and well defined on
CCZ classes.

*Proof.* If $F|_H \simeq F'|_{H'}$ via $(A, N)$ on the pure quadratic parts, extend $A$ to
$M \in \mathrm{GL}(V)$ with $M(H) = H'$; then $F'' = N^{-1}\circ F' \circ M$ has the same
pure quadratic part as $F$ on $\Lambda^2 H$, so $F'' = G \oplus_{L''}$ up to affine terms,
and Proposition 1.2 gives the $H$-change. The converse is the definition. Restrictions of
EA-equivalent functions to corresponding hyperplanes are EA-equivalent, and CCZ = EA for
quadratic APN functions (Yoshiara). $\square$

**Proposition 5.2 (PROVED).** Let $\mathcal H$ be a set of representatives of the
$\mathrm{Stab}(F)$-orbits on hyperplanes. Then

$$\deg[F] \le \sum_{H \in \mathcal H} \Big(\#\{P(F|_H)\text{-orbits}\} - 1\Big)
\le \sum_{H \in \mathcal H} \Big(\frac{e(F|_H)}{2^{n-1}} - 1\Big).$$

In particular $[F]$ is an isolated vertex iff, for every $H$, all APN extensions of $F|_H$
are EA-equivalent to $F$; this holds if $e(F|_H) = 2^{n-1}$ for all $H$.

*Proof.* A neighbour $F'$ is EA-equivalent to an extension of $F|_H$ for some $H$
(Proposition 5.1), and EA-equivalent extensions of $F|_H$ in one $P(G)$-orbit are
counted once; the orbit of $F$ itself is excluded. Each orbit contributes at least
$2^{n-1}$ to $e$ (`UNIQUENESS.md` Proposition 6.1). $\square$

**Computations 5.3.**

- $n = 6$ (PROVED by computation, exact, $\sigma$ separates the 13 classes): complete graph
  $K_{13}$ (`results/graph_n6.tsv`).
- $n = 7$ (OBSERVED, exact up to the $\sigma$ labels): all 488 classes, all 127 hyperplanes (61,976 pairs),
  every canonical extension labelled by $\sigma$ (`results/graph_n7.tsv`). $\sigma$
  separates the 488 classes except Gold $x^3$ and $x^9$ (classes 32 and 34 have the same
  $\sigma$), so the neighbour lists of these two are uncertain by one entry; this also
  causes the two non-symmetric lists that the script reports. No extension has a $\sigma$
  outside the 488 classes (as the classification requires). The graph is **connected**.
  Degrees: the three Gold classes (32, 33, 34) have degree 2; 13 classes have degree 40–68;
  the other 472 classes have degree 216–296 (median of all classes 253).
- $n = 8$ (PROVED by computation): for 20 random members of `beierle2025_n8` and member
  3,049,449, `isolated8` computes $e(F|_H)$ for all 255 hyperplanes
  (`results/isolated_n8.tsv`). 18 of the 20 random members have $e = 128$ on every
  hyperplane, so they are **isolated vertices** (Proposition 5.2), for example member
  1,282,703. Members 3,005,563 ($u = 36$) and 1,900,292 ($u = 148$) and 3,049,449
  ($u = 249$) have exactly one hyperplane with $e = 256$ and none with more. Since there
  are other classes, the graph at $n = 8$ is **disconnected**. The second classes (`check_uniqueness.jl: inspect_pair`): for
  3,049,449 the $\sigma$ `57a71f4c…` is absent from the index (the new class in
  `new_classes_extra.tsv`); for 3,005,563 ($\sigma$ `1e70c0c2…`) and 1,900,292
  ($\sigma$ `d7d91a8f…`) the second class is in `beierle2025_n8`.
- $x^3$ at $n = 8$: $\mathrm{Aut}(x^3)$ is transitive on hyperplanes, so
  $2 \le \deg[x^3] \le 3$ (3 distinct $\sigma$ among 4 canonical extensions of one
  restriction).

So the graph changes character between $n = 6$ (complete) and $n = 8$ (mostly isolated
vertices). This is the same transition as in the extension counts (`UNIQUENESS.md`,
Open problem 2).

### 5.4 What the census estimator says

**Proposition 5.4 (PROVED).** Let $\tau$ be a uniformly random APN coefficient tuple on
$n$ variables and $G_\tau$ its restriction to $\mathrm{span}(e_1, \dots, e_{n-1})$. Then the
class of $\tau$ has probability proportional to $1/|\mathrm{Stab}|$, and given the class,
the hyperplane of $F$ that corresponds to $\mathrm{span}(e_1,\dots,e_{n-1})$ is uniform among
the $2^n - 1$ hyperplanes. For every function $h$ of $G$ (constant on the leaves below $G$),
the census gives the unbiased ratio estimate

$$\frac{\sum_t W'_t\, h(G_t)}{\sum_t W'_t} \ \longrightarrow\
\frac{\sum_{[F]} \frac{1}{|\mathrm{Stab}(F)|} \cdot \frac{1}{2^n - 1}\sum_{H} h(F|_H)}{\sum_{[F]} \frac{1}{|\mathrm{Stab}(F)|}} .$$

With $h = e(G)/2^{n-1} - 1$ this is the mass-weighted mean, over classes and hyperplanes,
of the number of extra extension orbits; it bounds the mean degree per hyperplane.

*Proof.* Orbit–stabilizer: each class has $|\mathcal G|/|\mathrm{Stab}|$ tuples.
Within an orbit, $\varphi = (M,N)\cdot\varphi_F$ with $(M,N)$ uniform in $\mathcal G$ (each
tuple is hit $|\mathrm{Stab}|$ times), and $\varphi|_{\Lambda^2 \mathrm{span}(e_1..e_{n-1})}$
is $F$ restricted to $M^{-1}(\mathrm{span}(e_1..e_{n-1}))$ up to equivalence; $M$ uniform makes
this hyperplane uniform. `METHOD.md` Proposition 5.1 with $h$ (which is constant on
$\Lambda$-orbits) gives the estimate. $\square$

The census recorded $e(G)$ for every hit: all 1,661 hits have $e = 128$, so the estimate
of the mean of $e/128 - 1$ is 0. The weights are heavy-tailed, so we use the restriction
experiments for a rate: for `beierle2025_n8` (about 68 % of the mass) the pairs with
$e > 128$ are 1 of 3,185 (`UNIQUENESS.md`) and 2 of 5,100 (the 20 random members of
Section 5.3; member 3,049,449 is left out there because it was chosen for its event),
together $3/8\,285 \approx 3.6 \cdot 10^{-4}$ per hyperplane (95 % interval about
$0.7$–$10.6 \cdot 10^{-4}$), each with $e = 256$ (one extra class).

**5.5 Expected yield (SKETCH).** A search that restricts every known class to all 255
hyperplanes and enumerates the extensions would find about
$3.8 \cdot 10^6 \cdot 255 \cdot 3.6 \cdot 10^{-4} \approx 3.5 \cdot 10^5$ (class, hyperplane)
pairs with a second class. If these neighbours were mass-weighted random classes, a
fraction $1 - \hat c \approx 0.32$ (`METHOD.md` Section 5.2) would be new, that is about
$1.1 \cdot 10^5$ new classes (fewer after duplicates). The cost is about $0.04$ s per
pair (FL3), $3.9 \cdot 10^7$ CPU-seconds, about 450 CPU-days, or about 10 new classes per
CPU-hour. The census sampler found 553 new $\sigma$ in about 96 CPU-hours (about 6 per
CPU-hour). The gaps: the per-hyperplane rate has a large relative error (4 events), and
neighbours of known classes need not be mass-weighted random classes (structured
classes have more neighbours, Section 3.4). A direct sample: of the three second classes found among
`beierle2025_n8` members (Section 5.3), one is new and two are in `beierle2025_n8`.

---

## 6. The hyperplane scan at $n = 8$

The scan in `hyperplane_scan/` (README there) calculates $e(F|_H)$ for **all 255
hyperplanes** of 11,684 functions (first pass): the 67 quadratic APN rows of the catalog,
the small corpora, 2,000–2,256 members of each pre-2025 bulk corpus, our 553 + 1 + 773 new
classes, and 2,000 random `beierle2025_n8` members. This is 2,979,420 pairs $(F, H)$.
For each pair with $k = e/2^{7} > 1$ it builds one extension for each coset and classifies
its $\sigma$. Below, $n_{>1}(F)$ is the number of hyperplanes $H$ with $k > 1$.

**Proposition 6.1 (PROVED).** Let $(A, B) \in \mathrm{Stab}(F)$, that is $F \circ A = B
\circ F$ up to affine terms. Then $e(F|_{A(H)}) = e(F|_H)$ for every hyperplane $H$. Thus
$n_{>1}(F)$ is a sum of sizes of $\mathrm{Aut}(F)$-orbits on hyperplanes.

*Proof.* First, $e$ is an EA invariant of $(n-1, m)$-functions: if $G' = B \circ G \circ A'$
up to affine terms, with $A' \in GL(n-1)$ and $B \in GL(m)$, then $L \mapsto B \circ L \circ
A'$ is a bijection from the valid $L$ of $G$ (Theorem 4.1 of the paper) to the valid $L$
of $G'$, because it maps $I^G_\alpha$ to $I^{G'}_{A'^{-1}\alpha}$. In particular $e(F|_H)$
does not depend on the basis of $H$. Second, the restriction of $F \circ A = B \circ F$ to
$H$ gives $F|_{A(H)} \circ A|_H = B \circ F|_H$ up to affine terms. Thus the two
restrictions are EA-equivalent and have the same $e$. $\square$

*Data.* In `beierleleander2022_n8`, $n_{>1}(F)$ is a multiple of 3 for 1,230 of the 1,242
functions with $n_{>1} > 0$ (values 3: 729, 6: 329, 9: 132, 12: 29, 15: 9, 18: 2). This
agrees with Proposition 6.1 if these functions have an automorphism of order 3 with no fixed
hyperplane among the counted ones. Table 5.2 of the paper lists 12,647 known classes with
$|\mathrm{Aut}| = 2^8 \cdot 3$. We did not calculate $\mathrm{Aut}$ per function (the VBF
routine is too slow at $n = 8$), so the link is OBSERVED, not PROVED.

**Observation 6.2 (generic rate).** For the generic sources (`beierleleanderperrin2022_n8`,
the two QAM corpora, the 553, the 773 and the `beierle2025_n8` sample: 9,582 functions,
2,443,410 pairs), 1,399 pairs have $k > 1$. The rate is $5.73 \cdot 10^{-4}$ per
hyperplane, and it is the same within $\pm 15\,\%$ for each of these sources. Almost all
these pairs have $k = 2$. If the 255 hyperplanes were independent, the expected
$n_{>1}$ would be $255 \cdot 5.73 \cdot 10^{-4} = 0.146$, and
$P(n_{>1} > 0) = 1 - e^{-0.146} = 13.6\,\%$. The observed fraction is $1{,}229 / 9{,}582 =
12.8\,\%$. Thus the events on different hyperplanes of a generic function are close to
independent. The earlier estimate of Section 5.4 ($3.6 \cdot 10^{-4}$, 3 events) is
consistent with this value.

**Observation 6.3 (structure).** The rate grows with structure:

| Component ranks $(r_8, r_6, r_4, r_2)$ | Functions | $n_{>1} > 0$ | Pair rate |
|---|---:|---:|---:|
| (170, 85, 0, 0) | 10,308 | 19.5 % | 0.31 % |
| (174, 80, 1, 0) | 1,263 | 34.8 % | 0.61 % |
| (178, 75, 2, 0) | 83 | 65.1 % | 1.59 % |
| (182, 70, 3, 0) | 25 | 88.0 % | 2.26 % |
| (186, 65, 4, 0) | 5 | 100 % | 3.29 % |

By $B_6$ (bminK order): $B_6 = 52$ and $54$ have pair rates of 0.06–0.08 %; $B_6 = 56$
0.39 %; $B_6 = 58$ and $60$ about 1.1 %; $B_6 = 50$ (the Gold-like and Edel–Pott classes)
14.2 %. These numbers mix the families: the (170, 85, 0, 0) row contains the structured
Beierle–Leander 2022 functions. Within one generic family, the Spearman correlation of
$n_{>1}$ with $r_4$, $B_6$ or $K_6$ is below 0.05. Thus the simple invariants explain the
difference between families, but not the variation inside a family (Observation 3.3).
Why rank-4 components and large $B_6$ give more multiple extensions is OPEN.

**Observation 6.4 (a third coverage estimate).** For a generic parent $F$ and a pair with
$k > 1$, one coset gives the class of $F$ and the other coset gives a second class. Over the
generic sources, the second class is in the index for 960 cosets and absent from every
list (NEW) for 437 cosets: the new fraction is $0.313 \pm 0.012$. The census
(`METHOD.md`, Section 5) gives $1 - \hat c = 0.323 \pm 0.013$. Thus the neighbours of
generic functions behave like random classes with respect to the known list. Under this
assumption, $\hat c = 0.687 \pm 0.012$ and $N \approx 3{,}808{,}491 / 0.687 \approx 5.54
\cdot 10^6 \pm 0.10 \cdot 10^6$, between the two census estimates. This is not a proof:
the neighbours are not a mass-weighted sample, and several cosets can come from one
parent.

**Yield (OBSERVED).** The first pass used 47.0 thread-hours and found 463 distinct verified
new classes (differential uniformity 2, $\sigma$ recalculated, absent from the index and
from the lists of 553, 1, 773 and 546). This is 9.8 new classes per thread-hour, as
Section 5.5 predicted (about 10). The B6 = 52 search finds about 1,400 per thread-hour. Thus
the hyperplane relation is a good tool to study the structure, but a weak tool for mass
discovery.

## References

- H. Taniguchi, A. Polujan, A. Pott, R. Arshad. Changing almost perfect nonlinear functions
  on affine subspaces of small codimensions. arXiv:2501.03922, 2025.
- C. Beierle, P. Langevin, G. Leander, A. Polujan, S. Rasoolzadeh. Millions of inequivalent
  quadratic APN functions in eight variables. arXiv:2508.04644v2, 2026 (Theorem 4.1,
  Lemma 4.5, Remarks 3.17–3.18).
- Y. Edel, A. Pott. A new almost perfect nonlinear function which is not quadratic.
  Adv. Math. Commun. 3 (2009) 59–81 (switching).
- A. Schrijver. Counting 1-factors in regular bipartite graphs. J. Combin. Theory Ser. B 72
  (1998) 122–135.
- S. Yoshiara. Equivalences of quadratic APN functions. J. Algebraic Combin. 35 (2012)
  461–475.
