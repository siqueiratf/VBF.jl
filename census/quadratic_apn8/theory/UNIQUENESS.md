# The values of the last-step count $e(G)$

**Path**: `census/quadratic_apn8/theory/UNIQUENESS.md`

**Question**: In the $(8,8)$ census, all 1,661 sampled $(7,8)$-functions $G$ with an APN
extension had $e(G) = 128 = 2^7 = |\Lambda|$. Is $e(G) \in \{0, 2^{n-1}\}$ a theorem at
$n = 8$?

**Answer**: No. The strong statement is **false**. Hyperplane restrictions of known
quadratic APN $(8,8)$-functions give $e = 256$ and $e = 512$ (Section 7). One
counterexample comes from a member of `beierle2025_n8`; its second extension has a
$\sigma$-signature that is absent from the VBFCatalog index. The property is still
"almost true" at $n = 8$: 4,966 of 5,000 random restriction pairs give $e = 128$, and for
members of `beierle2025_n8` the rate of $e > 128$ is 1 in 3,185 pairs.

**Status labels**: PROVED (complete proof here), SKETCH (argument with a gap that we name),
OPEN (no proof), FALSE (counterexample), OBSERVED (computation only).

| Statement | Status |
|---|---|
| 2.1 Valid set is a union of $\ker\Phi$-cosets; $e = \lvert\ker\Phi\rvert \cdot \lvert\Phi(\mathcal V)\rvert$; $\Lambda \le \ker\Phi$ | PROVED |
| 3.2 For $m = n$: $\Phi(L) \leftrightarrow \pi_F\rvert_H$; $e/\lvert\ker\Phi\rvert$ = number of restrictions $\pi_F\rvert_H$ | PROVED |
| 3.3 $\pi_F^{-1}(b) \cup \{0\} = \mathrm{Rad}(F_b)$ | PROVED |
| 4.1 Component form of $\Phi$; $\ker\Phi = \Lambda$ iff $\ker\mu$ is spanned by pure tensors | PROVED |
| 5.1–5.3 Restriction rank rule; rank bookkeeping at $n = 8$; ranks do not force uniqueness | PROVED |
| 6.1 Orbit formula $e = \sum_O 2^{n-1}\lvert\mathrm{Stab}(G)\rvert / \lvert\mathrm{Stab}_H(F_O)\rvert$ | PROVED |
| C1 $\ker\Phi = \Lambda$ for every quadratic APN $(n-1,n)$-function | OPEN (OBSERVED for all 67,872 tested $G$, $4 \le n \le 8$) |
| C0 $e(G) \in \{0, 128\}$ for every quadratic APN $(7,8)$-function | FALSE |
| C2 Under the census measure, $P(e(G) > 2^{7}) \ll 1$ at $n = 8$ | OBSERVED |

---

## 1. Setting

Let $n \ge 4$, $H = \mathbb F_2^{n-1}$, $W = \mathbb F_2^m$ and let $G$ be a pure quadratic APN
$(n-1, m)$-function with bilinear form $B_G$. We use the notation of `METHOD.md`:

- $I_\alpha = B_G(\alpha, H)$, of dimension $n-2$ for $\alpha \ne 0$.
- $\mathcal V(G) = \{ L \in \mathrm{Hom}(H, W) : L(\alpha) \notin I_\alpha\ \forall \alpha \ne 0\}$,
  $e(G) = |\mathcal V(G)|$. By Theorem 3.1 of `METHOD.md`, $L \in \mathcal V(G)$ if and only
  if $F_L(x,s) = G(x) + sL(x)$ is APN on $V = H \oplus \mathbb F_2$.
- $\Lambda = \{ \lambda_\beta = B_G(\cdot, \beta) : \beta \in H \}$, $|\Lambda| = 2^{n-1}$.
- $Q_\alpha = W / I_\alpha$ and $P_\alpha : W \to Q_\alpha$ the projection.
  $\dim Q_\alpha = m - n + 2$.
- $W_\alpha = I_\alpha^\perp \subset W$ (dot product), $\dim W_\alpha = m - n + 2$. Note
  $b \in W_\alpha \iff b \cdot B_G(\alpha, y) = 0\ \forall y \iff \alpha \in \mathrm{Rad}(G_b)$.
- $\mathrm{Rad}(f)$ is the radical of the bilinear form of a quadratic Boolean function $f$,
  and $\mathrm{rank}(f) = \dim(\text{domain}) - \dim \mathrm{Rad}(f)$ (always even).

---

## 2. The coset structure (PROVED)

Define the linear map

$$\Phi : \mathrm{Hom}(H, W) \to \bigoplus_{\alpha \in H \setminus 0} Q_\alpha, \qquad
\Phi(L) = \big(P_\alpha L(\alpha)\big)_{\alpha}.$$

Let $\mathcal S$ be the set of tuples whose every block is nonzero.

**Proposition 2.1.**

1. $\mathcal V(G) = \Phi^{-1}(\mathcal S)$. So $\mathcal V(G)$ is a union of cosets of
   $\ker \Phi$, and $e(G) = |\ker\Phi| \cdot |\Phi(\mathrm{Hom}(H,W)) \cap \mathcal S|$.
2. $\Lambda \le \ker\Phi$. Thus $|\ker\Phi| \ge 2^{n-1}$ and $2^{n-1} \mid |\ker\Phi|$, so
   $2^{n-1}$ divides $e(G)$.
3. $\ker\Phi = \{ L : L(\alpha) \in I_\alpha\ \forall \alpha \}$.

*Proof.* (1) $L(\alpha) \notin I_\alpha \iff P_\alpha L(\alpha) \ne 0$. If
$\Phi(L) = \Phi(L')$ then $L$ and $L'$ are both valid or both invalid. The valid set is
the preimage of $\mathcal S \cap \mathrm{Im}\,\Phi$, and each fibre of $\Phi$ is a coset of
$\ker\Phi$. (2) $\lambda_\beta(\alpha) = B_G(\alpha,\beta) \in I_\alpha$. $\Lambda$ is a
subgroup of the elementary abelian group $\ker\Phi$, so its order divides $|\ker\Phi|$.
$|\Lambda| = 2^{n-1}$ by Proposition 4.3 of `METHOD.md`. (3) is the definition. $\square$

---

## 3. Ortho-derivative interpretation, $m = n$ (PROVED)

For $m = n$: $\dim I_\alpha = n-2$, so $\dim Q_\alpha = \dim W_\alpha = 2$. For a quadratic
APN $(n,n)$-function $F$, the **ortho-derivative** $\pi_F(v)$, $v \ne 0$, is the unique
nonzero $w$ with $w \perp I^F_v$ ($I^F_v$ has dimension $n-1$); $\pi_F(0) = 0$. This is
the definition in Section 2 of the paper.

**Lemma 3.1.** Let $L \in \mathcal V(G)$ and $F = F_L$. For $\alpha \in H \setminus 0$:
$I^F_{(\alpha,0)} = I_\alpha + \langle L(\alpha) \rangle$, and $\pi_F(\alpha,0)$ is the unique
nonzero $w \in W_\alpha$ with $w \cdot L(\alpha) = 0$.

*Proof.* By formula (3.1) of `METHOD.md`, $B_F((\alpha,0),(y,t)) = B_G(\alpha, y) + tL(\alpha)$.
So $I^F_{(\alpha,0)} = I_\alpha + \langle L(\alpha)\rangle$, and $w \perp I^F_{(\alpha,0)}$
if and only if $w \in W_\alpha$ and $w \cdot L(\alpha) = 0$. The functional
$w \mapsto w \cdot L(\alpha)$ on the 2-dimensional space $W_\alpha$ is nonzero, because
$L(\alpha) \notin I_\alpha = W_\alpha^\perp$. Its kernel is a line, which has exactly one
nonzero vector. $\square$

**Proposition 3.2.** Let $L, L' \in \mathcal V(G)$. Then
$\pi_{F_L}|_{H} = \pi_{F_{L'}}|_{H}$ if and only if $\Phi(L) = \Phi(L')$, that is, if and
only if $L' - L \in \ker\Phi$. Consequently

$$\frac{e(G)}{|\ker\Phi|} = \#\{\pi_{F}|_H : F \text{ an APN extension of } G \text{ of the form } F_L\}.$$

*Proof.* The dot product gives a perfect pairing $W_\alpha \times Q_\alpha \to \mathbb F_2$,
$(w, y + I_\alpha) \mapsto w \cdot y$. In a 2-dimensional space over $\mathbb F_2$, a nonzero
$q \in Q_\alpha$ is orthogonal to exactly one nonzero $w_q \in W_\alpha$, and the map
$q \mapsto w_q$ is a bijection between the three nonzero vectors of $Q_\alpha$ and the three
nonzero vectors of $W_\alpha$ (each nonzero $w$ is orthogonal to exactly one nonzero $q$).
By Lemma 3.1, $\pi_{F_L}(\alpha) = w_{P_\alpha L(\alpha)}$. Thus the restriction
$\pi_{F_L}|_{H\setminus 0}$ and the tuple $\Phi(L)$ determine each other. Proposition 2.1(1)
gives the count. $\square$

So the question "is $e(G) = 2^{n-1}$?" splits into two questions: is
$\ker\Phi = \Lambda$ (Conjecture C1), and is the restriction $\pi_F|_H$ unique?

**Lemma 3.3.** For a quadratic APN $(n,n)$-function $F$ and $b \ne 0$:
$\pi_F^{-1}(b) \cup \{0\} = \mathrm{Rad}(F_b)$. In particular the fibres of $\pi_F$ determine
the rank distribution of $F$: $\mathrm{rank}(F_b) = n - \log_2(|\pi_F^{-1}(b)| + 1)$.

*Proof.* $v \in \mathrm{Rad}(F_b) \iff b \cdot B_F(v, y) = 0\ \forall y \iff b \perp I^F_v$.
For $v \ne 0$, $(I^F_v)^\perp = \{0, \pi_F(v)\}$. $\square$

---

## 4. Component form of $\Phi$ (PROVED)

For $b \in W$ let $\ell_b = b \cdot L \in H^*$. The component of $F_L$ at $b$ is
$(F_L)_b(x, s) = G_b(x) + s\,\ell_b(x)$.

**Proposition 4.1.**

1. $\Phi(L)$ and the family $\big(\ell_b|_{\mathrm{Rad}(G_b)}\big)_{b \ne 0}$ determine each
   other. In particular $\ker\Phi = \{ L : \ell_b|_{\mathrm{Rad}(G_b)} = 0 \ \forall b\}$.
2. (Radical of an extension.) If $\ell_b|_{\mathrm{Rad}(G_b)} \ne 0$ ("case B") then
   $\mathrm{Rad}((F_L)_b) = \mathrm{Rad}(G_b) \cap \ker \ell_b \subset H$, a hyperplane of
   $\mathrm{Rad}(G_b)$, and $\mathrm{rank}((F_L)_b) = \mathrm{rank}(G_b) + 2$. If
   $\ell_b|_{\mathrm{Rad}(G_b)} = 0$ ("case A") then $\mathrm{Rad}((F_L)_b)$ has dimension
   $\dim\mathrm{Rad}(G_b) + 1$, is not contained in $H$, and
   $\mathrm{rank}((F_L)_b) = \mathrm{rank}(G_b)$.
3. (Tensor form.) Let $\mu : H \otimes W \to H^*$, $\alpha \otimes b \mapsto b \cdot B_G(\alpha, \cdot)$,
   and $S = \sum_{b} \mathrm{Rad}(G_b) \otimes b \subseteq H \otimes W$. Under the pairing
   $\langle L, \alpha \otimes b\rangle = b \cdot L(\alpha)$:
   $\ker\Phi = S^\perp$ and $\Lambda = (\ker\mu)^\perp$. A pure tensor $\alpha \otimes b$
   ($\alpha, b \ne 0$) lies in $\ker\mu$ if and only if $\alpha \in \mathrm{Rad}(G_b)$. Thus
   $\ker\Phi = \Lambda$ if and only if $\ker\mu$ (of dimension $(n-1)(m-1)$) is spanned by
   the pure tensors that it contains.

*Proof.* (1) For $\alpha \ne 0$, the block $P_\alpha L(\alpha) \in Q_\alpha \cong W_\alpha^*$ is
the functional $w \mapsto w \cdot L(\alpha) = \ell_w(\alpha)$ on $W_\alpha$. And
$w \in W_\alpha \iff \alpha \in \mathrm{Rad}(G_w)$. So the tuple $\Phi(L)$ is the list of
values $\ell_b(\alpha)$ over the pairs with $\alpha \in \mathrm{Rad}(G_b)$; this list is the
family of restrictions.
(2) The bilinear form of $(F_L)_b$ is $((x,s),(y,t)) \mapsto B_{G_b}(x,y) + s\ell_b(y) + t\ell_b(x)$.
A vector $(x,0)$ is in its radical iff $x \in \mathrm{Rad}(G_b)$ and $\ell_b(x) = 0$. A
vector $(x,1)$ is in its radical iff $B_{G_b}(x, \cdot) = \ell_b$ on $H$ and $\ell_b(x) = 0$.
The first condition has a solution iff $\ell_b \in \mathrm{Im}(B_{G_b}) = \mathrm{Rad}(G_b)^0$
(the annihilator), that is, iff $\ell_b|_{\mathrm{Rad}(G_b)} = 0$; then the solutions form a
coset of $\mathrm{Rad}(G_b)$, and $\ell_b(x) = B_{G_b}(x,x) = 0$ holds automatically. Count
dimensions.
(3) $\langle L, \alpha \otimes b \rangle = \ell_b(\alpha)$, so (1) gives $\ker\Phi = S^\perp$.
$\langle \lambda_\beta, t\rangle = \mu(t)(\beta)$, so $\Lambda^\perp = \ker\mu$ and
$\Lambda = (\ker\mu)^\perp$. $\mu$ is onto because $\beta \mapsto \lambda_\beta$ is injective,
so $\dim\ker\mu = (n-1)m - (n-1)$. $S \subseteq \ker\mu$ is spanned by the pure tensors of
$\ker\mu$. $\square$

With Lemma 3.3: in case B, $\pi_{F_L}$ takes the value $b$ on the hyperplane
$\mathrm{Rad}(G_b) \cap \ker\ell_b$ of $\mathrm{Rad}(G_b)$; in case A, on all of
$\mathrm{Rad}(G_b)$ (and on points outside $H$). The sets $\pi_{F_L}^{-1}(b) \cap H$ partition
$H \setminus 0$.

---

## 5. Ranks (PROVED)

**Lemma 5.1 (restriction to a hyperplane).** Let $f$ be an alternating form of rank $r$ on
$V$ (dimension $n$) with radical $R$, and let $H = \ker u$ be a hyperplane. If
$R \not\subseteq H$, then $\mathrm{Rad}(f|_H) = R \cap H$ and $\mathrm{rank}(f|_H) = r$. If
$R \subseteq H$, then $\mathrm{Rad}(f|_H) = R \oplus \langle x_0 \rangle$ with
$f(x_0, \cdot) = u$, and $\mathrm{rank}(f|_H) = r - 2$.

*Proof.* $x \in H$ is in $\mathrm{Rad}(f|_H)$ iff $f(x,\cdot) \in \{0, u\}$. The set of $x$
with $f(x,\cdot) = u$ is nonempty iff $u \in \mathrm{Im}(x \mapsto f(x,\cdot)) = R^0$, that
is, iff $R \subseteq H$; then it is a coset $x_0 + R$, and $u(x_0) = f(x_0,x_0) = 0$, so
$x_0 \in H$. $\square$

This is Proposition 4.1(2) read backwards: $F_b$ is in case A iff
$\mathrm{Rad}(F_b) \not\subseteq H$.

**Proposition 5.2 (bookkeeping at $n = 8$).** Let $F$ be a quadratic APN $(8,8)$-function
with the rank distribution $(N_8, N_6, N_4, N_2) = (170+4j, 85-5j, j, 0)$ (the family of
Theorem 5.2 of the paper, $j = 17 - i$). Let $H$ be a hyperplane, and let $s_6$, $s_4$ be the
numbers of rank-6 and rank-4 components with $\mathrm{Rad}(F_b) \subseteq H$. Then

$$s_6 + 4 s_4 = 21 - j,$$

and the restriction $G = F|_H$ has the rank distribution
$(g_6, g_4, g_2, g_0) = (255 - j - s_6,\ s_6 + j - s_4,\ s_4,\ 0)$, that is,

$$g_2 = s_4, \qquad g_4 = 21 - 5 g_2, \qquad g_6 = 234 + 4 g_2 .$$

*Proof.* By Lemma 3.3, the sets $\mathrm{Rad}(F_b) \setminus 0$ partition $V \setminus 0$, and
they meet $H$ in $|\mathrm{Rad}(F_b) \cap H| - 1$ points. A rank-6 radical (dimension 2)
meets $H$ in 3 points if it lies in $H$, else in 1 point; a rank-4 radical (dimension 4)
in 15 or 7 points; bent components have radical 0. Counting the 127 points of
$H \setminus 0$: $127 = (85 - 5j) + 2 s_6 + 7j + 8 s_4$, which gives the first identity.
Lemma 5.1 gives the ranks of the restrictions: rank 8 $\to$ 6; rank 6 $\to$ 4 (if in $H$)
or 6; rank 4 $\to$ 2 (if in $H$) or 4. Substitute $s_6 = 21 - j - 4s_4$. $\square$

**Corollary 5.3 (ranks do not force uniqueness).** The rank distribution of $G$ does not
depend on $j$. Thus a $G$ of type $(234, 21, 0, 0)$ can, as far as ranks go, extend to
functions of every type $j = 0, \dots, 16$ (and $j \le 21$ from the identity). In the
experiment, restrictions of types $j = 0, 1, 2, 3$ all give $G$ of type
$(234, 21, 0, 0)$, and types $j = 1, 2, 3$ also give $(238, 16, 1, 0)$ (Section 7.2).
So no argument that uses only the rank distributions of $F$ and $G$ can prove uniqueness of
the extension. The analogous count for the type $(190, 64, 0, 1)$ gives
$2 s_6 + 32 s_2 = 32$.

---

## 6. The orbit formula (PROVED)

Let $\mathcal G = \mathrm{GL}(V) \times \mathrm{GL}(W)$ act on $\mathrm{Hom}(\Lambda^2 V, W)$
as in `METHOD.md` Section 2. Let $P_H = \{ M \in \mathrm{GL}(V) : M(H) = H\}$. Over
$\mathbb F_2$ every $M \in P_H$ has the form $M(x,s) = (Ax + s\beta, s)$ with
$A \in \mathrm{GL}(H)$, $\beta \in H$. Let

$$P(G) = \{ (M, N) \in P_H \times \mathrm{GL}(W) : (A, N) \in \mathrm{Stab}(\varphi_G) \}, \qquad
|P(G)| = 2^{n-1}\,|\mathrm{Stab}(\varphi_G)| .$$

Identify $L \in \mathcal V(G)$ with $\varphi_{F_L}$; these are the APN maps $\varphi$ on
$\Lambda^2 V$ with $\varphi|_{\Lambda^2 H} = \varphi_G$ ($\varphi(e_i \wedge e_n) = L(e_i)$).

**Proposition 6.1.** $P(G)$ acts on $\mathcal V(G)$. The elements with $A = I$, $N = I$ act as
$\Lambda$ ($L \mapsto L + \lambda_\beta$). The stabilizer of $L$ is
$\mathrm{Stab}_H(F_L) := \mathrm{Stab}(\varphi_{F_L}) \cap (P_H \times \mathrm{GL}(W))$.
Hence, summing over the $P(G)$-orbits $O \subseteq \mathcal V(G)$ with representatives $F_O$,

$$e(G) = \sum_{O} \frac{2^{n-1}\,|\mathrm{Stab}(\varphi_G)|}{|\mathrm{Stab}_H(F_O)|},$$

and every term $|\mathrm{Stab}(\varphi_G)| / |\mathrm{Stab}_H(F_O)|$ is a positive integer.

*Proof.* For $(M,N) \in P(G)$, $(M,N)\cdot\varphi$ is APN, and its restriction to
$\Lambda^2 H$ is $(A,N) \cdot \varphi_G = \varphi_G$, because $M^{-1}|_H = A^{-1}$. For
$A = I$, $N = I$: $M^{-1} = M$ and
$\varphi(e_i \wedge (e_n + \beta)) = L(e_i) + B_G(e_i, \beta)$, which is
$L + \lambda_\beta$. An element of $\mathrm{Stab}(\varphi_{F_L})$ with $M \in P_H$ restricts
to an element of $\mathrm{Stab}(\varphi_G)$, so the stabilizer in $P(G)$ is
$\mathrm{Stab}_H(F_L)$. Orbit–stabilizer gives the sum. $\Lambda \le P(G)$, so every
$P(G)$-orbit is a union of $\Lambda$-orbits, each of size $2^{n-1}$ (free action). Thus
$|O|/2^{n-1}$ is a positive integer. $\square$

**Corollary 6.2.**

1. $e(G)/2^{n-1} \ge \#\{P(G)\text{-orbits}\} \ge \#\{\text{EA classes of APN extensions of } G\}$.
2. If $\mathrm{Stab}(\varphi_G) = 1$, then every $\mathrm{Stab}_H(F_O)$ is trivial and
   $e(G)/2^{n-1}$ is the number of $P(G)$-orbits.
3. If $F$ is an extension with $|\mathrm{Aut}(F)| = 2^n$ (trivial stabilizer) and
   $e(G) = 2 \cdot 2^{n-1}$, and some extension $F'$ has a different $\sigma$, then
   $\mathrm{Stab}(\varphi_G) = 1$ and $\{F, F'\}$ represent the two orbits.

*Proof.* (1) Each term is at least 1; EA-equivalent extensions may lie in different
orbits. (2) $\mathrm{Stab}_H(F_O)$ embeds into $\mathrm{Stab}(\varphi_G)$: an element that
restricts to the identity on $\Lambda^2 H$ with $N = I$ has $A = I$, so it is in $\Lambda$,
which acts freely. (3) The two $\sigma$ values give two orbits; the sum of two positive
integers is 2, so both terms are 1, and the term of $F$ is
$|\mathrm{Stab}(\varphi_G)|/1$. $\square$

**Example 6.3 ($n = 4$).** All APN $(3,4)$-functions form one orbit ($T(3,4) = 2\,520$ is
the number of injective linear maps $\Lambda^2\mathbb F_2^3 \to \mathbb F_2^4$, and
$\mathrm{GL}(4)$ is transitive on them), so
$|\mathrm{Stab}(\varphi_G)| = 168 \cdot 20160 / 2520 = 1344$. The only extension class is
$x^3$ on $\mathbb F_{16}$ with $|\mathrm{Stab}| = 360$. The maps $x \mapsto ax$,
$y \mapsto a^3 y$ ($a \in \mathbb F_{16}^*$) are in the stabilizer and move the hyperplane
$\ker \mathrm{Tr}(cx)$ to $\ker \mathrm{Tr}(ca^{-1}x)$, so the stabilizer is transitive on
the 15 hyperplanes and $|\mathrm{Stab}_H| = 360/15 = 24$. One orbit gives $e = 8 \cdot 1344/24 = 448$. This is the value
that the census and the experiment both find.

---

## 7. Experiments (OBSERVED)

### 7.1 Method

Script: `check_uniqueness.jl`; target: `make check_uniqueness n=<n> samples=<N> threads=<T>`
(`make check_uniqueness_all` runs $n = 6, 7, 8$). For a quadratic APN $(n,n)$-function $F$
and a nonzero $u \in \mathbb F_2^n$, the script takes the basis
$a_j = e_j + u_j e_p$ ($j \ne p$, $p$ the lowest set bit of $u$) of $H = \ker u$ and the
coefficients

$$c_{ij} = F(a_i + a_j) + F(a_i) + F(a_j) + F(0)$$

of $G = F|_H$ in this basis (Lemma 1.3(2) of `METHOD.md`; affine terms of $F$ drop out).
It computes $e(G)$ with `FL3.count_completions(C, n-1, n)` (the census counter),
$\dim\ker\Phi$ by Gaussian elimination over the equations
$w \cdot L(\alpha) = 0$, $w \in W_\alpha$, and the rank distributions of $F$ and $G$. For
$n \le 7$ (all pairs) and for every pair with $e > 2^{n-1}$, it lists the canonical
solutions, computes the restrictions $\pi|_H$ and checks Proposition 3.2. For $n = 8$ and
$e > 128$, it computes the $\sigma$-signature of every canonical extension. $F$ is an
extension of $G$, so $e(G) \ge 2^{n-1}$ always (the script checks it).

Functions: $n = 4, 5, 6, 7$: all VBFCatalog CCZ class representatives (1, 2, 13, 488
classes) and **all** hyperplanes. $n = 8$: Gold $x^3$ and $x^9$, all members of
`edelpott2009_n8` (22), `taniguchi2019_n8` (2), `wengtangong2013_n8` (10), 96 random
members of `beierleleander2022_n8`, 77 each of `beierleleanderperrin2022_n8`,
`yuperrin2022_qam_n8`, `yuwangli2014_qam_n8`, and 637 random members of `beierle2025_n8`
(1,000 functions), 5 random hyperplanes each (seed 1). Run time: $n = 8$ 108 s, $n = 7$
217 s, on 2 threads.

### 7.2 Results

| $n$ | pairs | $\dim\ker\Phi$ | $e/2^{n-1}$ (number of pairs) | Prop. 3.2 check |
|---|---|---|---|---|
| 4 | 15 | 3 (all) | 56 (15) | 15/15 |
| 5 | 62 | 4 (all) | 288 (62) | 62/62 |
| 6 | 819 | 5 (all) | 992 (1), 1114 (411), 1473 (405), 1984 (2) | 819/819 |
| 7 | 61,976 | 6 (all) | 1 (3925), 2 (10533), 3 (14671), 4 (12908), 5 (9268), 6 (5562), 7 (2884), 8 (1234), 9 (609), 10 (241), 11 (66), 12 (62), 13 (13) | 61,976/61,976 |
| 8 | 5,000 | 7 (all) | **1 (4966), 2 (24), 4 (10)** | 34/34 (pairs with $e > 128$) |

The values for $n \le 7$ agree with the census samples of $(n-1,n) \to (n,n)$:
$448$, $4608$, $\{31744, 35648, 47136, 63488\}$, and $64k$ with $k = 1, \dots, 13$. Thus at
$n \le 7$ non-uniqueness is the rule, as expected.

$n = 8$, by source (pairs; pairs with $e > 128$; maximum $e$):

| source | pairs | $e > 128$ | max $e$ |
|---|---|---|---|
| `beierle2025_n8` | 3,185 | 1 | 256 |
| `beierleleander2022_n8` | 480 | 8 | 256 |
| `beierleleanderperrin2022_n8` | 385 | 1 | 256 |
| `yuperrin2022_qam_n8` | 385 | 1 | 256 |
| `yuwangli2014_qam_n8` | 385 | 0 | 128 |
| `edelpott2009_n8` | 110 | 13 | 512 |
| `wengtangong2013_n8` | 50 | 0 | 128 |
| `taniguchi2019_n8` | 10 | 0 | 128 |
| Gold $x^3$ | 5 | 5 | 512 |
| Gold $x^9$ | 5 | 5 | 256 |

$n = 8$, rank types: $F$ of types $j = 0$ (4,450 pairs), $1$ (505), $2$ (35), $3$ (10);
$G$ of types $(234,21,0,0)$ (4,959) and $(238,16,1,0)$ (41). The pairs with $e > 128$ occur
for $F$ of types $j = 0, 1, 2$ and both $G$ types.

For every one of the 34 pairs with $e > 128$, the canonical extensions are **not** all
CCZ-equivalent: 24 pairs have 2 canonical extensions with 2 distinct $\sigma$, and 10 pairs
($x^3$ and `edelpott2009_n8` #1) have 4 canonical extensions with 3 distinct $\sigma$. In
each case one $\sigma$ equals $\sigma(F)$. Since $\sigma$ is a CCZ invariant, these
extensions are pairwise inequivalent where $\sigma$ differs.

### 7.3 The counterexamples

**Gold $x^3$** (every hyperplane, since $\mathrm{Aut}$ is transitive on hyperplanes):
$u = 46$, $G$ = `124e0b4aeb1a0b01f5a09fc26dd2e8a1c44cb46351` (coefficients $c_{ij}$,
$i<j\le 7$, row order), $e = 512$, 4 restrictions $\pi|_H$, extensions with 3 distinct
$\sigma$, all in the VBFCatalog `functions` table. By Proposition 6.1 the Gold term is
$|\mathrm{Stab}(\varphi_G)|/8$ ($|\mathrm{Stab}_H(x^3)| = 2040/255 = 8$).

**A member of `beierle2025_n8`**: member 3,049,449, $u = 249$,
$G$ = `60586b23865a0415cf7832b7700de33212e22ccc9a`, $e = 256$, $\dim\ker\Phi = 7$, two
restrictions $\pi|_H$:

| extension | $L(e_1), \dots, L(e_7)$ | coefficients (8 variables) | $\sigma$ | index |
|---|---|---|---|---|
| 1 | 01 0e f0 d8 96 61 42 | `60586b23865a010415cf78320eb7700de3f03212e2d82ccc969a6142` | `57a71f4c…` | **absent** |
| 2 | 01 a9 a2 51 a6 be c7 | `60586b23865a010415cf7832a9b7700de3a23212e2512ccca69abec7` | $= \sigma(F)$ | `beierle2025_n8` |

Both extensions have differential uniformity 2 (checked with VBF).
`VBF.automorphisms_from_ortho_derivative` gives $|\mathrm{Aut}(F)| = 256$ (417 s) and
$|\mathrm{Aut}(F_1)| = 256$ (450 s), so both stabilizers are trivial
(`METHOD.md`, Proposition 2.4). By Corollary 6.2(3), $\mathrm{Stab}(\varphi_G) = 1$ and
$\mathcal V(G)$ consists of exactly two $P(G)$-orbits of size 128, one for each class. So
this $G$ has no symmetry at all and still has two CCZ-inequivalent APN extensions: the
non-uniqueness at $n = 8$ does not come only from symmetric functions.

Extension 1 has a $\sigma$ that is absent from the VBFCatalog index and is not among the
553 new $\sigma$ of the census (`results/new_sigma.tsv`). If the index is complete, it is
a quadratic APN class outside the known lists (status as for the 553: pending
verification).

Reproduce: `julia --project=<root> -e 'include("check_uniqueness.jl"); inspect_pair("beierle2025_n8", 3049449, 249)'`.

---

## 8. Conjectures and open problems

**C0 (FALSE).** "Every quadratic APN $(7,8)$-function $G$ has $e(G) \in \{0, 128\}$."
Section 7.3 gives counterexamples with $e = 256$ and $e = 512$, with CCZ-inequivalent
extensions. The census observation (1,661 of 1,661 hits with $e = 128$) is a statement
about typical $G$, not about all $G$.

**C1 (OPEN).** For every quadratic APN $(n-1, n)$-function $G$, $\ker\Phi = \Lambda$.
Equivalently (Proposition 4.1(3)): the kernel of the contraction
$\mu : H \otimes W \to H^*$, $\alpha \otimes b \mapsto b \cdot B_G(\alpha,\cdot)$, is spanned by
the pure tensors $\alpha \otimes b$ with $\alpha \in \mathrm{Rad}(G_b)$.
Evidence: true for all 67,872 restrictions tested ($n = 4, \dots, 8$). If C1 holds, then
by Proposition 3.2, $e(G) = 2^{n-1} \cdot \#\{\pi_F|_H\}$ exactly, and the census
observation says that the restriction $\pi_F|_H$ is typically unique at $n = 8$.
A proof would need a property of APN $G$ beyond dimension counting: the pure tensors in
$\ker\mu$ number $3(2^{n-1}-1)$ (each $\alpha \ne 0$ lies in exactly three radicals
$\mathrm{Rad}(G_b)$), which is more than $\dim\ker\mu = (n-1)^2$ for every $n \ge 4$, but
their span is not controlled by the count.

**C2 (OBSERVED).** At $n = 8$, $e(G) = 2^7$ for "most" $G$. Precisely: let $G$ be the
restriction of a uniformly random APN tuple to $\mathrm{span}(e_1,\dots,e_7)$ (this is a
random class with probability proportional to $1/|\mathrm{Stab}|$ and a uniformly random
hyperplane). By Proposition 5.1 of `METHOD.md` (with $h = \mathbf 1[e(G) > 128]$, which is
constant on $\Lambda$-orbits), the census estimates $P(e(G) > 128)$ by the $W$-weighted
share of hits with $e > 128$; this share is 0 in the 1,661 hits. The restriction
experiment gives the rate 1/3,185 (95 % upper bound about $1.5 \cdot 10^{-3}$) for
members of `beierle2025_n8`, which carry most of the known mass. The structured families
(Gold, Edel–Pott, Beierle–Leander 2022) have higher rates.

**Open problem 1.** Characterize the $G$ with $e(G) > 2^{n-1}$ at $n = 8$. The Gold cases
have large $\mathrm{Stab}(\varphi_G)$ (Corollary 6.2 does not apply). The
`beierle2025_n8` case has two inequivalent extensions and $\mathrm{Stab}(\varphi_G) = 1$
(Section 7.3; this uses the VBF value $|\mathrm{Aut}| = 256$ of both extensions), so
symmetry is not the only source of $e(G) > 2^{n-1}$.

**Open problem 2.** Explain the drop of the mean of $e/2^{n-1}$ (restriction measure):
56, 288, 1,294, 3.87, 1.01 for $n = 4, \dots, 8$. A naive independence model
(each of the $2^{n-1}-1$ blocks of a random element of the $(n-1)^2$-dimensional image
$\Phi(\mathrm{Hom})$ is nonzero with probability 3/4) predicts
$2^{(n-1)^2}(3/4)^{2^{n-1}-1} \approx 68, 876, 4494, 925, 0.08$. The model is wrong at
$n = 7$ by a factor of about 240, so it is not evidence for C2; we list it only to warn
against its use.

**Effect on the census.** None. The census uses the exact value $e(G)$ in every weight;
it does not assume $e(G) = 128$. The selection of one canonical completion uniformly
(Proposition 5.1 of `METHOD.md`) is correct for every value of $e(G)$.
