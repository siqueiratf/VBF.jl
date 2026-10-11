# The mathematics of the census of quadratic APN functions on $\mathbb F_2^8$

**Path**: `census/quadratic_apn8/theory/METHOD.md`

**Scope**: This document gives the full mathematical line of the census in
`census/quadratic_apn8/`. It states every definition, every result and every proof that the
estimators use. Section 7 copies the validation table and the current results from the
README. The companion file `UNIQUENESS.md` studies the values of the exact last-step
count $e(G)$.

**Sources**: C. Beierle, P. Langevin, G. Leander, A. Polujan, S. Rasoolzadeh, *Millions of
inequivalent quadratic APN functions in eight variables*, arXiv:2508.04644v2 (2026). We
write "the paper" and use the numbering of v2: Theorem 4.1 (extension by one input
variable), Lemma 4.5 (EA-equivalent extensions), Lemma 3.14 and Remark 3.15 (Edel's
criterion), Theorem 5.2 (rank distributions), Table 5.2 (automorphism groups). In v1
(`papers/2025/Beierle_202508/input/`) Theorem 4.1 is Theorem 4.9 and Lemma 3.14 is
Lemma 4.7.

---

## 0. Notation

- $V = \mathbb F_2^n$ and $W = \mathbb F_2^m$. The vectors $e_1, \dots, e_n$ are the standard
  basis of $V$. The dot product on $W$ is $b \cdot y$.
- An $(n,m)$-function is a map $F : V \to W$. Its **component** at $b \in W$ is
  $F_b(x) = b \cdot F(x)$.
- $F$ is **APN** (differential uniformity 2) when for every $a \ne 0$ and every $c \in W$
  the equation $F(x+a) + F(x) = c$ has at most 2 solutions. For $m \ne n$ we use the same
  word, as the paper does in Theorem 4.1.
- $\mathrm{GL}(n) = \mathrm{GL}(n,2)$. Its order is
  $|\mathrm{GL}(n)| = \prod_{i=0}^{n-1} (2^n - 2^i)$.
- $\Lambda^2 V$ is the second exterior power. It has the basis $e_i \wedge e_j$,
  $i < j$, so $\dim \Lambda^2 V = \binom n2$. Over $\mathbb F_2$, $x \wedge x = 0$ and
  $x \wedge y = y \wedge x$.
- $D_n = \{ x \wedge y : x, y \in V \text{ linearly independent} \} \subset \Lambda^2 V$ is
  the set of nonzero **decomposable** vectors.

---

## 1. Reduction to linear maps on $\Lambda^2 V$

### 1.1 Pure quadratic functions

**Definition 1.1.** A **pure quadratic** $(n,m)$-function is a function

$$F(x) = \sum_{1 \le i < j \le n} x_i x_j \, c_{ij}, \qquad c_{ij} \in W .$$

The tuple $c = (c_{ij})_{i<j} \in W^{\binom n2}$ is its **coefficient tuple**. The map
$c \mapsto F$ is a bijection between $W^{\binom n2}$ and the pure quadratic functions,
because the algebraic normal form is unique.

**Definition 1.2.** For any function $F$ of degree at most 2, the **bilinear form** of $F$
is

$$B_F(x,y) = F(x+y) + F(x) + F(y) + F(0).$$

**Lemma 1.3.** Let $\deg F \le 2$.

1. $B_F$ is bilinear, symmetric and alternating ($B_F(x,x) = 0$).
2. For every $c \in V$, $F(x+y+c) + F(x+c) + F(y+c) + F(c) = B_F(x,y)$.
3. $B_F = 0$ if and only if $F$ is affine.
4. If $F$ is pure quadratic with coefficients $c_{ij}$, then $B_F(e_i, e_j) = c_{ij}$ for
   $i < j$. Thus $B_F(x,y) = \sum_{i<j} (x_i y_j + x_j y_i)\, c_{ij}$.

*Proof.* The second derivative $D_x D_y F(z) = F(z+x+y) + F(z+x) + F(z+y) + F(z)$ of a
function of degree at most 2 does not depend on $z$. This gives item 2 and, with $z = 0$,
the definition. The map $(x,y) \mapsto D_xD_yF$ is bilinear for $\deg F \le 2$ (direct check
on the monomials $x_i x_j$, $x_i$ and $1$; a monomial $x_i x_j$ gives
$x_i y_j + x_j y_i$, and affine monomials give 0). This also gives items 3 and 4.
$B_F(x,x) = F(0) + F(x) + F(x) + F(0) = 0$. $\square$

**Definition 1.4.** For a pure quadratic $F$ with coefficients $c_{ij}$, let
$\varphi_F : \Lambda^2 V \to W$ be the linear map with $\varphi_F(e_i \wedge e_j) = c_{ij}$.

**Lemma 1.5.** $\varphi_F(x \wedge y) = B_F(x,y)$ for all $x, y \in V$. The map
$c \mapsto \varphi_F$ is a bijection from $W^{\binom n2}$ to $\mathrm{Hom}(\Lambda^2 V, W)$.

*Proof.* $x \wedge y = \sum_{i<j} (x_i y_j + x_j y_i)\, e_i \wedge e_j$. Apply
$\varphi_F$ and compare with Lemma 1.3(4). A linear map on $\Lambda^2 V$ is free on the
basis $e_i \wedge e_j$. $\square$

### 1.2 The APN criterion

**Proposition 1.6.** Let $\deg F \le 2$. Then $F$ is APN if and only if
$B_F(x,y) \ne 0$ for all linearly independent $x, y$. For a pure quadratic $F$, this is
the condition

$$\varphi_F(v) \ne 0 \quad \text{for all } v \in D_n .$$

*Proof.* Fix $a \ne 0$. By Definition 1.2,
$F(x+a) + F(x) = B_F(x,a) + F(a) + F(0)$. The map $x \mapsto B_F(x,a)$ is linear with
kernel $K_a \ni a$. The equation $F(x+a)+F(x) = c$ has either 0 or $|K_a|$ solutions.
Thus $F$ is APN if and only if $K_a = \{0, a\}$ for every $a \ne 0$, that is, if and
only if $B_F(x,a) \ne 0$ for every $x \notin \{0, a\}$. Lemma 1.5 gives the second
form. $\square$

**Definition 1.7.** For $\alpha \in V$, let $I_\alpha = \{ B_F(\alpha, y) : y \in V \}$ be
the image of the derivative direction $\alpha$. By Proposition 1.6, $F$ is APN if and only
if $\dim I_\alpha = n-1$ for every $\alpha \ne 0$.

**Remark 1.8 (Edel's criterion, Lemma 3.14 and Remark 3.15 of the paper).** Identify
$\Lambda^2 V$ with the space of quadratic forms $\sum a_{ij} x_i x_j$ through
$e_i \wedge e_j \leftrightarrow x_i x_j$; this is the scalar product of Remark 3.15. The
components $b \cdot F$ are the linear functionals $b \cdot \varphi_F$ on $\Lambda^2 V$, so
$\mathrm{Comp}(F)^\perp = \ker \varphi_F$. The vector $x \wedge y$ corresponds to the form
with the alternating matrix $x y^{T} + y x^{T}$. The nonzero matrices of this type are
exactly the alternating matrices of rank 2. Thus Proposition 1.6 says: $F$ is APN if and
only if $\mathrm{Comp}(F)^\perp$ contains no form of rank 2. This is Edel's criterion
(Edel 2011, Lemma 8).

### 1.3 The decomposable set

**Lemma 1.9.** The map $U = \langle x, y \rangle \mapsto x \wedge y$ is well defined and
injective on the set of 2-dimensional subspaces of $V$. Its image is $D_n$. Thus

$$|D_n| = \binom n2_{\!2} = \frac{(2^n-1)(2^{n-1}-1)}{3}.$$

*Proof.* Another basis of $U$ is $(x', y') = (x,y)\,P$ with $P \in \mathrm{GL}(2,2)$, and
$x' \wedge y' = \det(P)\, x \wedge y = x \wedge y$. The subspace is recovered as
$U = \{ v \in V : v \wedge x \wedge y = 0 \text{ in } \Lambda^3 V \}$, so the map is
injective. The count is the Gaussian binomial coefficient. $\square$

For $n = 8$, $|D_8| = 255 \cdot 127 / 3 = 10\,795$, inside the space $\Lambda^2 V$ of
dimension 28. The vectors $e_i \wedge e_j$ are in $D_n$, so $D_n$ spans $\Lambda^2 V$.

### 1.4 The count $T(n,m)$ as a characteristic polynomial

**Definition 1.10.** $T(n,m)$ is the number of coefficient tuples $c \in W^{\binom n2}$ whose
pure quadratic function is APN. By Lemma 1.5 and Proposition 1.6,

$$T(n,m) = \#\{ \varphi \in \mathrm{Hom}(\Lambda^2 V, W) : \varphi(v) \ne 0 \ \forall v \in D_n \}.$$

**Definition 1.11.** Let $E$ be a finite set of nonzero vectors in $\mathbb F_q^r$ and let
$\mathrm{rk}(X) = \dim \mathrm{span}(X)$ for $X \subseteq E$. The **vector matroid** $M(E)$
has the rank function $\mathrm{rk}$. Its **characteristic polynomial** is

$$\chi_{M(E)}(\lambda) = \sum_{X \subseteq E} (-1)^{|X|}\, \lambda^{\mathrm{rk}(E) - \mathrm{rk}(X)} .$$

**Theorem 1.12 (critical theorem; Crapo and Rota 1970, Chapter 16).** Let
$E \subset \mathbb F_q^r \setminus \{0\}$ span $\mathbb F_q^r$. For every integer
$k \ge 0$, the number of linear maps $f : \mathbb F_q^r \to \mathbb F_q^k$ with
$f(v) \ne 0$ for all $v \in E$ is $\chi_{M(E)}(q^k)$.

*Proof.* For $X \subseteq E$, the maps that vanish on $X$ are the maps that vanish on
$\mathrm{span}(X)$. They form a space of dimension $k\,(r - \mathrm{rk}(X))$, so there are
$q^{k(r - \mathrm{rk} X)} = (q^k)^{\mathrm{rk}(E) - \mathrm{rk}(X)}$ of them. Inclusion and
exclusion over the set of vectors in $E$ on which $f$ vanishes gives
$\sum_{X \subseteq E} (-1)^{|X|} (q^k)^{\mathrm{rk}(E) - \mathrm{rk}(X)}
= \chi_{M(E)}(q^k)$. $\square$

**Corollary 1.13.** $T(n,m) = \chi_{M(D_n)}(2^m)$, where $M(D_n)$ is the binary matroid of
the Grassmannian $G(2,n)$ in its Plücker embedding (the matroid of the point set $D_n$ of
$\mathrm{PG}(\Lambda^2 V)$). In particular $T(n,m)$ is a polynomial in $2^m$ of degree
$\binom n2$, and $T(n,m) = 0$ when $\chi_{M(D_n)}$ vanishes at $2^m$ (for example when
$m < n-1$, see Remark 1.16).

*Proof.* Apply Theorem 1.12 with $q = 2$, $r = \binom n2$, $E = D_n$, $k = m$. $D_n$
spans $\Lambda^2 V$ (Section 1.3). $\square$

An equivalent form sorts the maps by their kernel. A map $\varphi$ with kernel $K$ is an
injective linear map $\Lambda^2 V / K \to W$. Thus

$$T(n,m) = \sum_{\substack{K \le \Lambda^2 V\\ K \cap D_n = \emptyset}}
\ \prod_{i=0}^{\binom n2 - \dim K - 1} (2^m - 2^i). \tag{1.1}$$

**Example 1.14 ($n = 3$).** $\dim \Lambda^2 \mathbb F_2^3 = 3$, and every nonzero vector of
$\Lambda^2 \mathbb F_2^3$ is decomposable: $|D_3| = 7 \cdot 3/3 = 7$. Thus only $K = 0$
occurs in (1.1), and

$$T(3,m) = (2^m-1)(2^m-2)(2^m-4).$$

This gives $T(3,3) = 168$, $T(3,4) = 2\,520$ and $T(3,5) = 26\,040$. The depth-first count
`QK.exact_count` returns the same values (`make test`).

**Example 1.15 ($n = 4$).** $D_4$ is the set of 35 points of the Klein quadric
$Q^+(5,2) \subset \mathrm{PG}(5,2)$. Write
$v = \sum_{i<j} v_{ij}\, e_i \wedge e_j$ and view $v$ as the alternating $4 \times 4$ matrix
$(v_{ij})$. A nonzero $v$ is decomposable if and only if this matrix has rank 2, that is,
if and only if its Pfaffian $\mathrm{Pf}(v) = v_{12}v_{34} + v_{13}v_{24} + v_{14}v_{23}$
is 0 ($\det = \mathrm{Pf}^2$). $\mathrm{Pf}$ is a hyperbolic quadratic form on
$\mathbb F_2^6$ whose polar form is the wedge pairing $\Lambda^2 \times \Lambda^2 \to \Lambda^4$.
A subspace $K$ with $K \cap D_4 = \emptyset$ is a totally anisotropic subspace of
this hyperbolic form, so $\dim K \le 2$. Let $a_k$ be the number of such subspaces of
dimension $k$. Then $a_0 = 1$, $a_1 = 63 - 35 = 28$, and a direct count gives
$a_2 = 56$ (see Section 7.3). By (1.1),

$$T(4,m) = \prod_{i=0}^{5}(2^m-2^i) + 28 \prod_{i=0}^{4}(2^m-2^i)
+ 56 \prod_{i=0}^{3}(2^m-2^i).$$

For $m = 4$ only the last term is nonzero: $T(4,4) = 56 \cdot 15 \cdot 14 \cdot 12 \cdot 8
= 1\,128\,960$. This equals the depth-first count.

**Remark 1.16.** For an APN function, $\dim I_\alpha = n-1 \le m$. Thus $T(n,m) = 0$ for
$m < n-1$. For $m = n-1$ the count is positive only when quadratic APN
$(n, n-1)$-functions exist.

---

## 2. Equivalence, stabilizers and the mass formula

### 2.1 EA classes are orbits

Two $(n,m)$-functions are **EA-equivalent** when $F' = A \circ F \circ B + C$ with affine
permutations $A$ of $W$ and $B$ of $V$ and an affine map $C : V \to W$.

The group $\mathcal G = \mathrm{GL}(n) \times \mathrm{GL}(m)$ acts on
$\mathrm{Hom}(\Lambda^2 V, W)$ by

$$(M, N) \cdot \varphi = N \circ \varphi \circ \Lambda^2(M^{-1}), \qquad
\Lambda^2(M)(x \wedge y) = Mx \wedge My .$$

This action corresponds to $F \mapsto N \circ F \circ M^{-1}$ on pure quadratic functions.
It maps APN functions to APN functions, because $\Lambda^2(M)$ maps $D_n$ onto $D_n$.

For a function $F$ of degree at most 2, let $Q(F)$ be the pure quadratic function with the
same bilinear form; $F + Q(F)$ is affine by Lemma 1.3(3).

**Proposition 2.1.** Let $F, F'$ have degree at most 2.

1. $F$ is EA-equivalent to $Q(F)$.
2. $F$ and $F'$ are EA-equivalent if and only if $\varphi_{Q(F)}$ and $\varphi_{Q(F')}$ are
   in the same $\mathcal G$-orbit.

Thus the EA classes of quadratic APN $(n,m)$-functions are in bijection with the
$\mathcal G$-orbits on the set of APN maps $\varphi$.

*Proof.* (1) $F = Q(F) + C$ with $C$ affine. (2) Let $B(x) = Mx + c$, $A(y) = Ny + d$ and
let $C$ be affine. By Lemma 1.3(2),

$$B_{A \circ F \circ B + C}(x,y) = N\big(F(Mx+My+c) + F(Mx+c) + F(My+c) + F(c)\big)
= N B_F(Mx, My).$$

Thus $\varphi_{Q(F')} = N \circ \varphi_{Q(F)} \circ \Lambda^2(M)$, which is the action of
$(M^{-1}, N)$. Conversely, if $\varphi_{Q(F')} = (M,N)\cdot \varphi_{Q(F)}$ then
$Q(F') = N \circ Q(F) \circ M^{-1}$, and item 1 gives the EA-equivalence of $F$ and
$F'$. $\square$

**Theorem 2.2 (Yoshiara 2012).** Two quadratic APN $(n,n)$-functions are CCZ-equivalent if
and only if they are EA-equivalent.

Thus, for $m = n$, the CCZ classes of quadratic APN functions are the $\mathcal G$-orbits
on APN maps $\varphi$. The census counts these orbits. (A CCZ class can contain
non-quadratic functions. Theorem 2.2 says that its quadratic members form one EA class.)

### 2.2 The mass formula

Let $\mathcal A$ be the set of APN maps $\varphi$, so $|\mathcal A| = T(n,m)$. For an orbit
$K$ let $\mathrm{Stab}(K)$ be the stabilizer in $\mathcal G$ of one of its members (all
are conjugate).

**Proposition 2.3 (mass formula).**

$$\mathcal M(n,m) := \frac{T(n,m)}{|\mathrm{GL}(n)|\,|\mathrm{GL}(m)|}
= \sum_{\text{orbits } K} \frac{1}{|\mathrm{Stab}(K)|}, \qquad
N(n,m) := \#\{\text{orbits}\} = \mathcal M(n,m) + \sum_K \Big(1 - \frac{1}{|\mathrm{Stab}(K)|}\Big).$$

*Proof.* The orbit–stabilizer theorem gives
$|K| = |\mathcal G| / |\mathrm{Stab}(K)|$. Sum over the orbits, which partition
$\mathcal A$, and divide by $|\mathcal G|$. The second identity is
$\sum_K 1 = \sum_K 1/|\mathrm{Stab}| + \sum_K (1 - 1/|\mathrm{Stab}|)$. $\square$

Each term $1 - 1/|\mathrm{Stab}(K)|$ is in $[0, 1)$. It is zero exactly for the classes
with a trivial stabilizer. Thus $N \ge \mathcal M$, and $N - \mathcal M$ is small when
almost all classes have a trivial stabilizer.

### 2.3 Stabilizers and automorphism groups

Let $F$ be a quadratic $(n,m)$-function. Its **EA-automorphism group**
$\mathrm{Aut}_{EA}(F)$ is the group of affine permutations of $V \times W$ of the form

$$\sigma(x, y) = (Mx + c,\ Ny + Rx + d), \qquad M \in \mathrm{GL}(n),\ N \in \mathrm{GL}(m),\
R \in \mathrm{Hom}(V, W),$$

that map the graph $\Gamma_F = \{(x, F(x))\}$ onto itself. The condition is
$F(Mx + c) = N F(x) + Rx + d$ for all $x$.

**Proposition 2.4.** $|\mathrm{Aut}_{EA}(F)| = 2^n\, |\mathrm{Stab}_{\mathcal G}(\varphi_{Q(F)})|$.

*Proof.* We may replace $F$ by $Q(F)$: an affine summand changes the conditions only by
an affine function, which moves into $R$ and $d$. The map
$\rho : \sigma \mapsto (M, N)$ is a group homomorphism (the composition of two maps of the
form above has the product of the linear parts as its $(M,N)$). By Lemma 1.3(2), the
condition forces $B_F(Mx, My) = N B_F(x,y)$, that is,
$N^{-1} \circ \varphi_F \circ \Lambda^2(M) = \varphi_F$. This says
$(M^{-1}, N^{-1}) \in \mathrm{Stab}(\varphi_F)$, which is equivalent to
$(M, N) \in \mathrm{Stab}(\varphi_F)$. So the image of $\rho$ is in the stabilizer.
Conversely, for $(M,N)$ with $B_F(Mx,My) = NB_F(x,y)$ and any $c \in V$, the function
$x \mapsto F(Mx+c) + NF(x)$ has bilinear form 0, so it is affine, equal to $Rx + d$ for a
unique pair $(R, d)$. Thus $\rho$ is onto. The kernel consists of the maps
$(x,y) \mapsto (x + c, y + Rx + d)$ with $F(x+c) = F(x) + Rx + d$. For every $c$ there is
exactly one such pair, $R = B_F(\cdot, c)$ and $d = F(c) + F(0)$. Thus
$|\ker \rho| = 2^n$. $\square$

The kernel of $\rho$ is the elementary abelian group of order $2^n$ that the paper
mentions in Section 5.1.

**Checks.** $n = 4$: $|\mathrm{Aut}| = 5760 = 16 \cdot 360$, and
$\mathcal M(4,4) = T(4,4)/|\mathrm{GL}(4)|^2 = 1\,128\,960 / 20160^2 = 1/360$.
$n = 5$: two classes with $|\mathrm{Aut}| = 4960 = 32 \cdot 155$, so
$\mathcal M(5,5) = 2/155$, which the pipeline test confirms (`make test`). For $n = 6, 7$
the masses from $|\mathrm{Aut}|$ agree with independent Knuth estimates (Section 7).

**Remark 2.5 (which automorphism group).** The census computes $|\mathrm{Aut}(F)|$ with
`VBF.automorphisms_from_ortho_derivative`. Table 5.2 of the paper lists the order of the
CCZ-automorphism group $\mathrm{Aut}_{CCZ}(F)$ (all affine permutations of $V \times W$
that fix $\Gamma_F$), computed in Magma. Always
$\mathrm{Aut}_{EA}(F) \le \mathrm{Aut}_{CCZ}(F)$. The census uses
$|\mathrm{Stab}| = |\mathrm{Aut}|/2^n$. We do not prove here that the two groups are equal
for quadratic APN functions. The effect of a difference is bounded:

- For $|\mathrm{Aut}_{CCZ}(F)| = 2^n$ the inclusion forces equality, because
  $|\mathrm{Aut}_{EA}| \ge 2^n$. This covers 3,795,716 of the 3,808,491 known classes
  (Table 5.2).
- For the other 12,775 known classes, a strict inclusion would make the value of
  $\mathcal M_{\text{known}}$ in Section 5.3 too small. The true contribution of a class is
  at most 1, so the error $\delta$ is at most
  $\sum (1 - 2^8/|\mathrm{Aut}|) = 12\,775 - 4\,258.1 = 8\,516.9$ (0.22 % of
  $\mathcal M_{\text{known}}$). In $\widehat N_{\text{cov}}$ (Section 5.2) the error
  enters as $\delta\,(1/\hat c - 1) \le 4\,100$, far below the standard error
  $1.1 \cdot 10^5$.

The exact masses for $n \le 7$ agree with independent estimates (Section 7), so at these
dimensions no difference is visible.

---

## 3. Knuth's estimator on the input-extension tree

### 3.1 Extension by one input variable

Let $H = \mathbb F_2^{k}$ and let $G$ be a quadratic $(k, m)$-function. For a linear map
$L : H \to W$ let $F = G \oplus_L$ be the $(k+1, m)$-function

$$F(x, s) = G(x) + s\, L(x), \qquad x \in H,\ s \in \mathbb F_2 .$$

We write $I_\alpha = I^G_\alpha = \{ B_G(\alpha, y) : y \in H \}$.

**Theorem 3.1 (Theorem 4.1 of the paper; Taniguchi, Polujan, Pott, Arshad 2025,
Prop. 2.11).** $F$ is APN if and only if $G$ is APN and $L(\alpha) \notin I_\alpha$ for every
$\alpha \in H \setminus \{0\}$.

The paper writes the condition as $L(\alpha) \ne G(x+\alpha) + G(x) + G(\alpha) + G(0)$ for
all $x$; the right side is $B_G(x, \alpha)$, so the set of right sides is $I_\alpha$.

*Proof.* A direct computation gives

$$B_F\big((x,s),(y,t)\big) = B_G(x,y) + s\,L(y) + t\,L(x). \tag{3.1}$$

By Proposition 1.6, $F$ is APN if and only if $B_F(u,v) \ne 0$ for all independent
$u, v \in H \oplus \mathbb F_2$. The value $B_F(u,v) = \varphi_F(u \wedge v)$ depends only
on the plane $\langle u,v \rangle$ (Lemma 1.9). Every plane meets the hyperplane
$H \times \{0\}$ in a nonzero vector, because $2 + k - (k+1) = 1$. Thus $F$ is APN if and
only if $B_F((\alpha,0), (y,t)) \ne 0$ for every $\alpha \in H\setminus\{0\}$ and every
$(y,t) \notin \{(0,0), (\alpha,0)\}$. By (3.1) this value is $B_G(\alpha, y) + t L(\alpha)$.
For $t = 0$ the condition is "$G$ is APN". For $t = 1$ the condition is
$L(\alpha) \ne B_G(\alpha, y)$ for all $y \in H$, that is, $L(\alpha) \notin I_\alpha$.
$\square$

### 3.2 The extension tree

Fix $(n, m)$. A coefficient tuple is built column by column. Column $j$
($j = 2, \dots, n$) holds $c_{1j}, \dots, c_{j-1,j}$. With
$G_j(x_1, \dots, x_j) = \sum_{i < i' \le j} x_i x_{i'} c_{ii'}$ we have

$$G_j(x, x_j) = G_{j-1}(x) + x_j L_j(x), \qquad L_j(e_i) = c_{ij} .$$

The **levels** are the pairs $(j, i)$, $2 \le j \le n$, $1 \le i < j$, in the order
$(2,1), (3,1), (3,2), (4,1), \dots, (n, n-1)$. There are $\binom n2$ levels. Level
$(j,i)$ fixes $c_{ij} = L_j(e_i)$.

**Definition 3.2 (validity).** The condition $V(j,i)$ on a partial tuple is:
$G_{j-1}$ is APN and, for every $a \in \mathrm{span}(e_1, \dots, e_{i-1})$,

$$L_j(a) + L_j(e_i) \notin I^{G_{j-1}}_{a + e_i}.$$

$V(j,i)$ depends only on the columns $2, \dots, j-1$ and on $c_{1j}, \dots, c_{ij}$.

**Definition 3.3 (tree).** The **nodes** at depth $t$ are the partial tuples of the first
$t$ levels that satisfy $V$ at every level up to $t$. The root is the empty tuple
($G_1 = 0$ on one variable is APN: $\dim I_{e_1} = 0 = 1 - 1$). The children of a node at
depth $t$ are its valid extensions at level $t+1$. A **leaf** is a node at depth
$\binom n2$. A **dead end** is a node at smaller depth with no children.

In the code, level $(j,i)$ is `nv = j-1`, `k = i`. The forbidden set of level $(j,i)$ is
$\bigcup_{a} \big(L_j(a) + I_{a+e_i}\big)$ (`QK.free_values!`), and $d$ is the number of
values outside it.

**Lemma 3.4.** The leaves are exactly the APN coefficient tuples. Thus the tree has
$T(n,m)$ leaves.

*Proof.* Every $\alpha \in \mathrm{span}(e_1, \dots, e_{j-1}) \setminus \{0\}$ has a unique
largest index $i$ with $\alpha_i = 1$, so $\alpha = a + e_i$ with
$a \in \mathrm{span}(e_1,\dots,e_{i-1})$ and $L_j(\alpha) = L_j(a) + L_j(e_i)$. Thus the
conditions $V(j,1), \dots, V(j,j-1)$ together say: $G_{j-1}$ is APN and
$L_j(\alpha) \notin I_\alpha$ for all $\alpha \ne 0$. By Theorem 3.1 this says that $G_j$
is APN. Induction on $j$ (with $G_1$ APN) shows: a full tuple satisfies all conditions if
and only if $G_n$ is APN. The validity of a level depends only on the earlier levels and
on the level itself, so the set of valid partial tuples is closed under prefixes. Thus
every APN tuple is a leaf, and every leaf is APN. $\square$

### 3.3 The estimator

**Theorem 3.5 (Knuth 1975).** Start at the root. At a node $v$ with $d(v) \ge 1$ children,
move to a child chosen uniformly at random. Stop at a leaf or at a dead end. Let
$W = \prod_v d(v)$ over the nodes $v$ on the path except the last one if the path ends at
a leaf, and $W = 0$ if the path ends at a dead end. Then $E[W] = \#\text{leaves} = T(n,m)$.

*Proof.* A leaf $\ell$ with the path $v_0, v_1, \dots, v_{\binom n2} = \ell$ is reached
with probability $\prod_{t} 1/d(v_t)$, and then $W = \prod_t d(v_t)$. The product of the
two numbers is 1. A path that ends at a dead end contributes $W = 0$. Thus
$E[W] = \sum_\ell 1 = T(n,m)$. $\square$

**Corollary 3.6.** For $N$ independent probes, $\widehat T = \frac1N \sum_{t=1}^N W_t$ is
an unbiased estimator of $T(n,m)$, and
$\widehat{\mathcal M} = \widehat T / (|\mathrm{GL}(n)||\mathrm{GL}(m)|)$ is an unbiased
estimator of the mass. The standard error is $s_W / \sqrt N$, with $s_W$ the sample
standard deviation of the $W_t$, all probes included.

**Why the zero rows must stay.** A sample file has one row per probe. A row with
`logw = -Inf` is a path that ended at a dead end before $n-1$ variables. A row with
`e = 0` is a path that reached a node $G$ on $n-1$ variables with no APN completion. Both
have $W = 0$. Corollary 3.6 divides by the number $N$ of probes. If we drop the zero rows
and divide by the number $N_{\text{hit}}$ of hits, we compute

$$\frac{1}{N_{\text{hit}}} \sum_{\text{hits}} W_t \ \longrightarrow\
E[W \mid W > 0] = \frac{T(n,m)}{P(W > 0)} .$$

For $(8,8)$ the hit rate is $P(W>0) \approx 4.14 \cdot 10^{-4}$, so the result is too
large by a factor of about 2,400. The zero rows are not failures of the method. They are
the part of the probability space where the tree has no leaves.

---

## 4. The exact last step

### 4.1 The count $e(G)$

The sampler runs the random walk only to depth $\binom{n-1}2$, that is, to a node $G$ on
$n-1$ variables. Then it counts the leaves below $G$ exactly. By Lemma 3.4 and
Theorem 3.1, these leaves are in bijection with

$$\mathcal V(G) = \{ L \in \mathrm{Hom}(H, W) : L(\alpha) \notin I_\alpha \ \forall \alpha \in H\setminus\{0\} \},
\qquad e(G) = |\mathcal V(G)|,$$

where $H = \mathbb F_2^{n-1}$.

**Proposition 4.1.** Let $W' = \prod_{\text{levels before } G} d(v) \cdot e(G)$ (and
$W' = 0$ at a dead end). Then $E[W'] = T(n,m)$.

*Proof.* As in Theorem 3.5, a node $G$ at depth $\binom{n-1}2$ is reached with
probability $1/\prod d(v)$, so $E[W'] = \sum_G e(G) = \sum_G \#\{\text{leaves below } G\}
= T(n,m)$. $\square$

$W'$ has a smaller variance than $W$, because it replaces the last $n-1$ random factors by
their exact conditional expectation (Rao–Blackwell).

### 4.2 The free action of $\Lambda$

Let $G$ be a quadratic APN $(k,m)$-function, $k = n-1 \ge 2$, on $H = \mathbb F_2^k$. Let

$$\Lambda = \{ \lambda_\beta : x \mapsto B_G(x, \beta) \ :\ \beta \in H \} \subset \mathrm{Hom}(H, W).$$

**Lemma 4.2 (Lemma 4.5 of the paper).** For $\beta \in H$, the extensions $G \oplus_L$ and
$G \oplus_{L + \lambda_\beta}$ are EA-equivalent.

*Proof.* Let $P(x,s) = (x + s\beta, s)$, a linear permutation of $H \times \mathbb F_2$.
Then
$(G \oplus_L)(P(x,s)) = G(x + s\beta) + sL(x) + sL(\beta)$. By Definition 1.2 with
$s \in \{0,1\}$, $G(x + s\beta) = G(x) + s\,(B_G(x,\beta) + G(\beta) + G(0))$. Thus
$(G \oplus_L) \circ P = G \oplus_{L + \lambda_\beta} + s\,(G(\beta) + G(0) + L(\beta))$,
and the last term is linear in $(x,s)$. $\square$

**Proposition 4.3.** $\Lambda$ is a group of order $2^k$ under addition, and it acts freely
on $\mathcal V(G)$ by $L \mapsto L + \lambda_\beta$. Thus $2^k$ divides $e(G)$.

*Proof.* $\beta \mapsto \lambda_\beta$ is linear. If $\lambda_\beta = 0$ with $\beta \ne 0$
then $I_\beta = 0$, but $\dim I_\beta = k-1 \ge 1$ for an APN $G$. So the map is injective
and $|\Lambda| = 2^k$. For $L \in \mathcal V(G)$ and $\alpha \ne 0$,
$\lambda_\beta(\alpha) = B_G(\alpha, \beta) \in I_\alpha$. Thus
$(L + \lambda_\beta)(\alpha) \in L(\alpha) + I_\alpha$, which is a coset of $I_\alpha$
different from $I_\alpha$. So $L + \lambda_\beta \in \mathcal V(G)$. The action is a
translation by a nonzero element when $\beta \ne 0$, so it has no fixed points. $\square$

### 4.3 Canonical representatives

**Proposition 4.4.** Let $b_{21} = B_G(e_2, e_1)$. Fix one representative $r_C$ in every
coset $C \ne I_{e_1}$ of $I_{e_1}$ in $W$. Call $L \in \mathcal V(G)$ **canonical** when

1. $L(e_1) = r_C$ for its coset $C = L(e_1) + I_{e_1}$, and
2. $L(e_2) < L(e_2) + b_{21}$ as integers.

Then every $\Lambda$-orbit in $\mathcal V(G)$ contains exactly one canonical element, and
$e(G) = 2^{k} \cdot \#\{\text{canonical } L\}$.

*Proof.* Let $L \in \mathcal V(G)$ and $C = L(e_1) + I_{e_1}$; $C \ne I_{e_1}$ because
$L(e_1) \notin I_{e_1}$. The map $\beta \mapsto \lambda_\beta(e_1) = B_G(e_1, \beta)$ is
linear from $H$ onto $I_{e_1}$ with kernel $\{0, e_1\}$ (APN). Thus
$(L + \lambda_\beta)(e_1) = r_C$ holds exactly for $\beta$ in one coset
$\beta_0 + \{0, e_1\}$. The two candidates differ in $e_2$ by
$\lambda_{e_1}(e_2) = B_G(e_2, e_1) = b_{21}$, which is nonzero ($G$ APN, $e_1, e_2$
independent). So exactly one of the two values $L'(e_2)$, $L'(e_2) + b_{21}$ is the
smaller one, and exactly one $\beta$ gives a canonical element. Free action
(Proposition 4.3) gives the count. $\square$

The production counter `FL3.count_completions` implements this. Level 1 enumerates one
value per nonzero coset of $I_{e_1}$ (the first value in the coset that is not forbidden).
Level 2 fixes the basis vector $e_2$ and keeps a value $b$ only if $b < b \oplus b_{21}$.
This halves the count exactly: the set of valid $L(e_2)$, given $L(e_1)$, is closed under
$b \mapsto b + b_{21}$, because $b_{21} \in I_{e_2}$ and $b_{21} \in I_{e_1 + e_2}$. The
remaining basis vectors $e_3, \dots, e_k$ are chosen in fail-first order with forward
checking; the order does not change the number of leaves. The counter returns
$2^k \cdot (\text{canonical count})$, and with `want_solution = true` the list of
canonical $L$.

**Values of $e(G)$.** At $n = 8$ all 1,661 hits of the census have $e(G) = 2^7$, but
$e(G) > 2^{n-1}$ occurs for some $G$ (for example hyperplane restrictions of Gold $x^3$
give $e = 512$). The census never assumes $e(G) = 2^{n-1}$. See `UNIQUENESS.md`.

---

## 5. Sampled functions and the coverage estimator

### 5.1 The distribution of a sampled function

When $e(G) > 0$ the sampler selects one canonical $L$ uniformly and writes the APN
function $\tau = G \oplus_L$. Let $h$ be a function on APN tuples that is constant on
$\Lambda$-orbits (for example the indicator of an EA class, by Lemma 4.2).

**Proposition 5.1.** $E[W' \, h(\tau)] = \sum_{\text{APN tuples } c} h(c)$, with
$h(\tau) := 0$ when $W' = 0$.

*Proof.* Fix a node $G$ at depth $\binom{n-1}{2}$; it is reached with probability
$p_G = 1/\prod d(v)$, and then $W' = e(G)/p_G$. Let $c_G = e(G)/2^k$ be the number of
canonical $L$. Then

$$E[W' h(\tau)] = \sum_G p_G \cdot \frac{e(G)}{p_G} \cdot \frac{1}{c_G}
\sum_{L \text{ canonical}} h(G \oplus_L)
= \sum_G \sum_{L \text{ canonical}} 2^k\, h(G \oplus_L)
= \sum_G \sum_{L \in \mathcal V(G)} h(G \oplus_L),$$

because each canonical $L$ represents $2^k$ elements of $\mathcal V(G)$ with the same
value of $h$. The double sum runs over all leaves. $\square$

With $h = \mathbf 1_K$ for a class $K$: $E[W' \mathbf 1_K(\tau)] = |K| =
|\mathcal G|/|\mathrm{Stab}(K)|$. Divided by $|\mathcal G|$, this is the mass of $K$.

### 5.2 Coverage

Let $\mathcal S$ be the set of $\sigma$-values in the index of known classes (VBFCatalog,
`ccz_sigma_index`). $\sigma$ is a CCZ invariant, so $\mathrm{known}(\tau) =
\mathbf 1[\sigma(\tau) \in \mathcal S]$ is a class function. By Proposition 5.1,

$$\frac{E[W'\,\mathrm{known}(\tau)]}{E[W']} = \frac{\mathcal M'_{\text{known}}}{\mathcal M},
\qquad \mathcal M'_{\text{known}} = \sum_{K:\ \sigma(K) \in \mathcal S} \frac{1}{|\mathrm{Stab}(K)|}.$$

The **coverage** estimator is the ratio estimator

$$\hat c = \frac{\sum_t W'_t\, \mathrm{known}_t}{\sum_t W'_t},$$

with the delta-method standard error
$\mathrm{se}(\hat c) = \sqrt{\sum_t (x_t - \hat c\, W'_t)^2 / (N(N-1))} \,/\, \overline{W'}$,
$x_t = W'_t \mathrm{known}_t$. All $N$ probes are in both sums; the zero rows add 0 to
the sums but they count in $N$.

If no unknown class has the same $\sigma$ as a known class, then
$\mathcal M'_{\text{known}} = \mathcal M_{\text{known}}$, and

$$\widehat{\mathcal M}_{\text{cov}} = \frac{\mathcal M_{\text{known}}}{\hat c}, \qquad
\widehat N_{\text{cov}} = \widehat{\mathcal M}_{\text{cov}} + (N_{\text{known}} - \mathcal M_{\text{known}}),
\qquad \widehat N_{\text{mass}} = \widehat{\mathcal M} + (N_{\text{known}} - \mathcal M_{\text{known}}).$$

$\sigma$-collisions between unknown and known classes make $\hat c$ too large and
$\widehat{\mathcal M}_{\text{cov}}$ too small.

**Relation between the two estimators.** Both estimate the same total mass $\mathcal M$.
$\widehat{\mathcal M}$ uses only the weights; its relative standard error is 2.9 % at
4,012,000 probes, because the weights are heavy-tailed. $\widehat{\mathcal M}_{\text{cov}}$
uses the exact value $\mathcal M_{\text{known}}$ and estimates only the ratio $\hat c$;
the common fluctuations of numerator and denominator cancel, so its relative standard
error is smaller (2.0 %). The two estimates use the same probes, so they are not
independent.

**Why both N estimates are lower-side.** By Proposition 2.3,
$N = \mathcal M + \sum_K (1 - 1/|\mathrm{Stab}(K)|)$. The correction
$N_{\text{known}} - \mathcal M_{\text{known}}$ covers the known classes. The unknown
classes with a nontrivial stabilizer add a nonnegative amount that the estimators omit.
Among the known classes of the paper, only one of the 3,775,599 new classes has a
nontrivial stabilizer, so this amount is expected to be small.

### 5.3 The known mass from Table 5.2

By Proposition 2.4, $1/|\mathrm{Stab}(K)| = 2^8 / |\mathrm{Aut}(K)|$. Table 5.2 of the
paper gives the following orders ($\mathrm{Aut}$ as in Remark 2.5).

| $\lvert\mathrm{Aut}\rvert$ | $\lvert\mathrm{Stab}\rvert$ | classes (a) known 32,892 | classes (b) new 3,775,599 | mass $\sum 1/\lvert\mathrm{Stab}\rvert$ |
|---|---|---|---|---|
| $2^8$ | 1 | 20,118 | 3,775,598 | 3,795,716 |
| $2^9$ | 2 | 69 | | 34.5 |
| $2^8 \cdot 3$ | 3 | 12,647 | 1 | 4,216 |
| $2^{10}$ | 4 | 8 | | 2 |
| $2^8 \cdot 5$ | 5 | 3 | | 0.6 |
| $2^9 \cdot 3$ | 6 | 11 | | 1.8333 |
| $2^8 \cdot 7$ | 7 | 9 | | 1.2857 |
| $2^{11}$ | 8 | 3 | | 0.375 |
| $2^8 \cdot 3^2$ | 9 | 3 | | 0.3333 |
| $2^{10} \cdot 3$ | 12 | 9 | | 0.75 |
| $2^8 \cdot 3 \cdot 5$ | 15 | 5 | | 0.3333 |
| $2^{11} \cdot 3$ | 24 | 2 | | 0.0833 |
| $2^{10} \cdot 3 \cdot 5$ | 60 | 1 | | 0.0167 |
| $2^{10} \cdot 3^2 \cdot 5$ | 180 | 2 | | 0.0111 |
| $2^{11} \cdot 3 \cdot 5 \cdot 17$ | 2040 | 2 | | 0.0010 |
| **total** | | **32,892** | **3,775,599** | **3,799,974.1228** |

Thus $N_{\text{known}} = 3\,808\,491$, $\mathcal M_{\text{known}} = 162\,790\,891\,421 / 42\,840 = 3\,799\,974.1228\ldots$, and
$N_{\text{known}} - \mathcal M_{\text{known}} = 8\,516.877\ldots$. The census uses the
rounded values `KNOWN_MASS = 3_799_974.1228` and `DELTA_KNOWN = KNOWN_CLASSES -
KNOWN_MASS` (`helpers.jl`). The two classes with $|\mathrm{Aut}| = 2^{11}\cdot 3\cdot 5\cdot 17$
are the Gold functions $x^3$ and $x^9$ ($|\mathrm{Stab}| = |\Gamma\mathrm L(1, 2^8)| = 2040$).

---

## 6. Summary of the chain

1. Pure quadratic APN tuples $\leftrightarrow$ maps $\varphi$ that do not vanish on $D_n$
   (Proposition 1.6); their number is $T(n,m) = \chi_{M(D_n)}(2^m)$ (Corollary 1.13).
2. CCZ classes of quadratic APN $(n,n)$-functions $\leftrightarrow$ $\mathcal G$-orbits
   (Proposition 2.1, Theorem 2.2); $T/|\mathcal G| = \sum 1/|\mathrm{Stab}|$
   (Proposition 2.3); $|\mathrm{Stab}| = |\mathrm{Aut}_{EA}|/2^n$ (Proposition 2.4).
3. The tuples are the leaves of the extension tree (Lemma 3.4); the Knuth weight is
   unbiased (Theorem 3.5); the zero rows count in the denominator.
4. The last level is counted exactly; $\Lambda$ acts freely and $e = 2^{n-1} \cdot
   (\text{canonical count})$ (Propositions 4.1, 4.3, 4.4).
5. A weighted sampled function estimates mass shares of class sets (Proposition 5.1);
   with the known mass from Table 5.2 this gives $\widehat N_{\text{cov}}$.

---

## 7. Validation and results

This section copies the tables of `../README.md` (state of 2026-10-08).

### 7.1 Validation

| Check | Method | Estimate | Exact | Where |
|---|---|---|---|---|
| T(3,3), T(3,4), T(3,5) | DFS, closed form | 168, 2,520, 26,040 | same | `make test` |
| T(4,4) | DFS | 1,128,960 (mass 1/360) | same | `make test` |
| T(n,m), n ≤ 4 | plain Knuth, Knuth + exact last step | within 5 SE | | `make test` |
| FL, FL2, FL3 | vs slow counter QK2, 34 random cases | equal | | `make test` |
| (5,5) mass | pipeline, 2,000 samples | within 5 SE and 5 % | 2/155 = 0.012903 | `make test` |
| (6,6) mass | plain Knuth, 200,000 probes, seed 7 | 7.71986 ± 0.0415 (z = +2.10) | 7.632804 | `make validate` |
| (7,7) mass | pipeline, 200,000 samples, seed 7, 12 threads | 472.304 ± 1.31 (z = −1.85) | 474.7177 | `make validate` |
| (7,7) mass | pipeline, legacy `s77.tsv` (200,000 samples, seed 7, 4 threads) | 475.002 ± 1.31 (z = +0.22) | 474.7177 | `make validate data77=…/s77.tsv` |

Other seeds: (6,6), 200,000 probes, seeds 8–11: z = +1.06, −0.62, +0.45, −0.06. (7,7),
50,000 samples, 12 threads, seeds 7–11: z = −3.90, +0.70, −1.62, +0.82, −0.11.

Exact masses from the catalog class representatives ($\sum 2^n/|\mathrm{Aut}|$):

| n | Classes | $\sum 2^n/\lvert\mathrm{Aut}\rvert$ | $\lvert\mathrm{Aut}\rvert$ histogram |
|---|---|---|---|
| 4 | 1 | 1/360 | 5760 × 1 |
| 5 | 2 | 2/155 | 4960 × 2 |
| 6 | 13 | 7 + 2/5 + 1/7 + 1/14 + 1/63 + 1/378 = 7.632804 | 64 × 7, 320 × 2, 448, 896, 4032, 24192 |
| 7 | 488 | 473 + 12/7 + 3/889 = 474.7177 | 128 × 473, 896 × 12, 113792 × 3 |

### 7.2 Results for $(8,8)$

Data: legacy `s1.tsv` (12,000 samples, seed 1) and chunks `c101`–`c140` (100,000 samples
each, seeds 101–140), all with 12 threads.

| Quantity | Value |
|---|---|
| Samples | 4,012,000 |
| APN hits ($e > 0$) | 1,661 (hit rate $4.14 \cdot 10^{-4}$) |
| Mass $\mathcal M = \sum 1/\lvert\mathrm{Stab}\rvert$ | $5.464 \cdot 10^6 \pm 1.58 \cdot 10^5$ (2.9 %) |
| Hits with known σ | 1,108 of 1,661 |
| Weighted coverage $\hat c$ | 0.6770 ± 0.0133 |
| Mass from coverage | $5.613 \cdot 10^6 \pm 1.1 \cdot 10^5$ |
| **$\widehat N_{\text{cov}}$** | **$5.621 \cdot 10^6 \pm 1.1 \cdot 10^5$** |
| $\widehat N_{\text{mass}}$ | $5.473 \cdot 10^6 \pm 1.58 \cdot 10^5$ |
| Distinct new σ | 553, no repeats (pending verification) |

### 7.3 Small computations for this document

- **Known mass.** Exact rational arithmetic over Table 5.2 gives
  $\mathcal M_{\text{known}} = 162\,790\,891\,421/42\,840 = 3\,799\,974.122806$ and
  $N_{\text{known}} - \mathcal M_{\text{known}} = 8\,516.877$. The 12,775 classes with
  $|\mathrm{Aut}| > 2^8$ contribute $4\,258.12$ to $\mathcal M_{\text{known}}$
  (Remark 2.5).
- **Klein quadric ($n = 4$).** With the coordinates
  $v = (v_{12}, v_{13}, v_{14}, v_{23}, v_{24}, v_{34})$, $v \ne 0$ is decomposable if and
  only if $v_{12}v_{34} + v_{13}v_{24} + v_{14}v_{23} = 0$. There are 35 such vectors, and
  56 lines of $\mathrm{PG}(5,2)$ have no decomposable point. Formula (1.1) then gives
  $T(4,3) = 0$, $T(4,4) = 1\,128\,960$, $T(4,5) = 314\,979\,840$ and
  $T(4,6) = 38\,532\,533\,760$.

These numbers come from short Julia computations (exact rationals; brute force over the
63 points and their lines). They are not part of the Makefile.

---

## References

- C. Beierle, P. Langevin, G. Leander, A. Polujan, S. Rasoolzadeh. Millions of
  inequivalent quadratic APN functions in eight variables. arXiv:2508.04644v2, 2026.
- H. Crapo, G.-C. Rota. *On the Foundations of Combinatorial Theory: Combinatorial
  Geometries*. MIT Press, 1970 (Chapter 16, the critical problem).
- J. P. S. Kung. Critical problems. In *Matroid Theory*, Contemp. Math. 197, AMS, 1996,
  pp. 1–127.
- Y. Edel. Quadratic APN functions as subspaces of alternating bilinear forms. Contact
  Forum Coding Theory and Cryptography III, 2011, pp. 11–24.
- D. E. Knuth. Estimating the efficiency of backtrack programs. *Math. Comp.* 29 (1975),
  121–136.
- S. Yoshiara. Equivalences of quadratic APN functions. *J. Algebraic Combin.* 35 (2012),
  461–475.
- H. Taniguchi, A. Polujan, A. Pott, R. Arshad. Changing almost perfect nonlinear
  functions on affine subspaces of small codimensions. arXiv:2501.03922, 2025.
