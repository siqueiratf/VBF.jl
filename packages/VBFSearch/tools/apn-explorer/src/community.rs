//! Feature 5: community detection with Louvain (Blondel et al. 2008) and Leiden
//! (Traag, Waltman and van Eck 2019) on the undirected class graph, modularity with
//! resolution gamma: Q = sum_c [ in_c / 2m - gamma (tot_c / 2m)^2 ].
//!
//! Leiden adds a refinement step to Louvain: inside each community a node joins a
//! refined subcommunity only if both are well connected to the rest of the community,
//! and the aggregate graph is built on the refined partition. So every Leiden
//! community is connected; Louvain communities can be disconnected. Both results are
//! checked: modularity is recomputed on the original graph, and every community is
//! tested for internal connectivity by a breadth-first search.

use crate::graph::Graph;
use std::collections::VecDeque;

pub struct Rng(u64);
impl Rng {
    pub fn new(seed: u64) -> Rng { Rng(seed ^ 0x9E37_79B9_7F4A_7C15) }
    pub fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E3779B97F4A7C15);
        let mut z = self.0; z = (z ^ (z >> 30)).wrapping_mul(0xBF58476D1CE4E5B9); z = (z ^ (z >> 27)).wrapping_mul(0x94D049BB133111EB); z ^ (z >> 31)
    }
    pub fn shuffle<T>(&mut self, v: &mut [T]) { for i in (1..v.len()).rev() { let j = (self.next() % (i as u64 + 1)) as usize; v.swap(i, j); } }
}

/// Sparse accumulator of weights from one node to communities.
struct Acc { w: Vec<f64>, touched: Vec<u32> }
impl Acc {
    fn new(n: usize) -> Acc { Acc { w: vec![0.0; n], touched: Vec::new() } }
    #[inline] fn add(&mut self, c: u32, x: f64) { if self.w[c as usize] == 0.0 { self.touched.push(c); } self.w[c as usize] += x; }
    fn clear(&mut self) { for &c in &self.touched { self.w[c as usize] = 0.0; } self.touched.clear(); }
}

/// Local moving. queue = true: Leiden's fast version (only neighbours of moved nodes are
/// visited again); false: Louvain sweeps until a sweep improves Q by less than 1e-7.
/// Returns true if any node moved.
fn local_moving(g: &Graph, comm: &mut [u32], gamma: f64, rng: &mut Rng, queue: bool) -> bool {
    let n = g.n;
    let mut tot = vec![0f64; n];
    for i in 0..n { tot[comm[i] as usize] += g.k[i]; }
    let mut acc = Acc::new(n);
    let mut order: Vec<u32> = (0..n as u32).collect(); rng.shuffle(&mut order);
    let mut moved_any = false;
    let mut visit = |i: usize, comm: &mut [u32], tot: &mut [f64], acc: &mut Acc| -> Option<u32> {
        let ci = comm[i]; let ki = g.k[i];
        let (nb, ww) = g.adj(i);
        for (&j, &w) in nb.iter().zip(ww) { if j as usize != i { acc.add(comm[j as usize], w as f64); } }
        tot[ci as usize] -= ki;
        let own = acc.w[ci as usize];
        let mut best = ci; let mut best_gain = own - gamma * tot[ci as usize] * ki / g.m2;
        for &c in &acc.touched {
            let gain = acc.w[c as usize] - gamma * tot[c as usize] * ki / g.m2;
            if gain > best_gain + 1e-12 { best_gain = gain; best = c; }
        }
        tot[best as usize] += ki; acc.clear();
        if best != ci { comm[i] = best; Some(best) } else { None }
    };
    if queue {
        let mut q: VecDeque<u32> = order.into_iter().collect();
        let mut inq = vec![true; n];
        while let Some(i) = q.pop_front() {
            inq[i as usize] = false;
            if let Some(c) = visit(i as usize, comm, &mut tot, &mut acc) {
                moved_any = true;
                let (nb, _) = g.adj(i as usize);
                for &j in nb { if !inq[j as usize] && comm[j as usize] != c { inq[j as usize] = true; q.push_back(j); } }
            }
        }
    } else {
        loop {
            let mut moves = 0usize;
            for &i in &order { if visit(i as usize, comm, &mut tot, &mut acc).is_some() { moves += 1; } }
            if moves > 0 { moved_any = true; }
            if moves * 2000 < n.max(1) { break; }  // fewer than 0.05% of the nodes moved
        }
    }
    moved_any
}

/// Renumber communities 0..k-1; returns k.
fn renumber(comm: &mut [u32]) -> usize {
    let mut map = vec![u32::MAX; comm.len().max(1)]; let mut k = 0u32;
    for c in comm.iter_mut() { if map[*c as usize] == u32::MAX { map[*c as usize] = k; k += 1; } *c = map[*c as usize]; }
    k as usize
}

/// Aggregate graph: one node per community of `part` (0..k-1).
fn aggregate(g: &Graph, part: &[u32], k: usize) -> Graph {
    let mut members: Vec<Vec<u32>> = vec![Vec::new(); k];
    for (i, &c) in part.iter().enumerate() { members[c as usize].push(i as u32); }
    let mut acc = Acc::new(k);
    let mut lists = Vec::with_capacity(k);
    for c in 0..k {
        for &i in &members[c] {
            let (nb, ww) = g.adj(i as usize);
            for (&j, &w) in nb.iter().zip(ww) {
                // A self loop of a node is stored once; in the aggregate it stays internal.
                // A self loop is stored once: count it twice, like an internal edge seen from both ends.
                let x = if j == i { 2.0 * w as f64 } else { w as f64 };
                acc.add(part[j as usize], x);
            }
        }
        let mut v: Vec<(u32, f32)> = acc.touched.iter().map(|&d| {
            let x = acc.w[d as usize];
            // Internal weight counted from both ends: halve it for the self loop.
            (d, if d as usize == c { (x / 2.0) as f32 } else { x as f32 })
        }).collect();
        acc.clear();
        v.sort_unstable_by_key(|e| e.0);
        lists.push((v.iter().map(|e| e.0).collect(), v.iter().map(|e| e.1).collect()));
    }
    Graph::from_lists(lists)
}

/// Leiden refinement inside every community of `part`; returns the refined partition.
fn refine(g: &Graph, part: &[u32], gamma: f64, rng: &mut Rng) -> Vec<u32> {
    let n = g.n;
    let mut refined: Vec<u32> = (0..n as u32).collect();
    let mut tot_c = vec![0f64; n]; for i in 0..n { tot_c[part[i] as usize] += g.k[i]; }
    let mut kt = g.k.clone();                 // strength of each refined community
    let mut ext = vec![0f64; n];              // weight from a refined community to the rest of its community
    let mut size = vec![1u32; n];
    for i in 0..n {
        let (nb, ww) = g.adj(i);
        for (&j, &w) in nb.iter().zip(ww) { if j as usize != i && part[j as usize] == part[i] { ext[i] += w as f64; } }
    }
    let mut order: Vec<u32> = (0..n as u32).collect(); rng.shuffle(&mut order);
    let mut acc = Acc::new(n);
    for &v in &order {
        let v = v as usize;
        if size[refined[v] as usize] != 1 { continue; }            // only nodes that are still alone
        let c = part[v] as usize;
        if ext[v] < gamma * g.k[v] * (tot_c[c] - g.k[v]) / g.m2 { continue; }   // v not well connected
        let (nb, ww) = g.adj(v);
        for (&j, &w) in nb.iter().zip(ww) { if j as usize != v && part[j as usize] as usize == c { acc.add(refined[j as usize], w as f64); } }
        let mut best = u32::MAX; let mut best_gain = 0.0;
        for &t in &acc.touched {
            let t_ = t as usize;
            if ext[t_] < gamma * kt[t_] * (tot_c[c] - kt[t_]) / g.m2 { continue; }   // T not well connected
            let gain = acc.w[t_] - gamma * g.k[v] * kt[t_] / g.m2;
            if gain > best_gain { best_gain = gain; best = t; }
        }
        if best != u32::MAX {
            let b = best as usize; let wvt = acc.w[b]; let old = refined[v] as usize;
            ext[b] = ext[b] + ext[v] - 2.0 * wvt; kt[b] += g.k[v]; size[b] += 1;
            size[old] = 0; kt[old] = 0.0; ext[old] = 0.0;
            refined[v] = best;
        }
        acc.clear();
    }
    refined
}

pub struct Result { pub comm: Vec<u32>, pub levels: usize, pub seconds: f64 }

pub fn louvain(g0: &Graph, gamma: f64, seed: u64) -> Result {
    let t = std::time::Instant::now();
    let mut rng = Rng::new(seed);
    let mut member: Vec<u32> = (0..g0.n as u32).collect();   // original node -> current aggregate node
    let mut g = None::<Graph>;
    let mut levels = 0;
    loop {
        let cur = g.as_ref().unwrap_or(g0);
        let mut comm: Vec<u32> = (0..cur.n as u32).collect();
        let moved = local_moving(cur, &mut comm, gamma, &mut rng, false);
        let k = renumber(&mut comm);
        for m in member.iter_mut() { *m = comm[*m as usize]; }
        levels += 1;
        if !moved || k == cur.n { break; }
        g = Some(aggregate(cur, &comm, k));
    }
    Result { comm: member, levels, seconds: t.elapsed().as_secs_f64() }
}

pub fn leiden(g0: &Graph, gamma: f64, seed: u64) -> Result {
    let t = std::time::Instant::now();
    let mut rng = Rng::new(seed);
    let mut member: Vec<u32> = (0..g0.n as u32).collect();   // original node -> current aggregate node
    let mut part: Vec<u32> = (0..g0.n as u32).collect();     // partition of the current aggregate nodes
    let mut g = None::<Graph>;
    let mut levels = 0;
    loop {
        let cur = g.as_ref().unwrap_or(g0);
        let moved = local_moving(cur, &mut part, gamma, &mut rng, true);
        let k = renumber(&mut part);
        levels += 1;
        if k == cur.n { break; }                             // every node alone: done
        let mut refined = refine(cur, &part, gamma, &mut rng);
        let kr = renumber(&mut refined);
        // No move and no merge in the refinement: the aggregate would be the same graph.
        if !moved && kr == cur.n { break; }
        // Next level: aggregate on the refined partition; its nodes start in the
        // community of `part` that holds them.
        let mut next_part = vec![0u32; kr];
        for i in 0..cur.n { next_part[refined[i] as usize] = part[i]; }
        for m in member.iter_mut() { *m = refined[*m as usize]; }
        g = Some(aggregate(cur, &refined, kr));
        part = next_part;
        if levels > 50 { break; }
    }
    let mut comm: Vec<u32> = member.iter().map(|&m| part[m as usize]).collect();
    renumber(&mut comm);
    Result { comm, levels, seconds: t.elapsed().as_secs_f64() }
}

/// Modularity of a partition on the original graph (independent of the algorithms).
pub fn modularity(g: &Graph, comm: &[u32], gamma: f64) -> f64 {
    let k = *comm.iter().max().unwrap_or(&0) as usize + 1;
    let mut inside = vec![0f64; k]; let mut tot = vec![0f64; k];
    for i in 0..g.n {
        tot[comm[i] as usize] += g.k[i];
        let (nb, ww) = g.adj(i);
        for (&j, &w) in nb.iter().zip(ww) { if comm[j as usize] == comm[i] { inside[comm[i] as usize] += if j as usize == i { 2.0 * w as f64 } else { w as f64 }; } }
    }
    (0..k).map(|c| inside[c] / g.m2 - gamma * (tot[c] / g.m2).powi(2)).sum()
}

/// Number of communities that are not connected inside, and the nodes outside the
/// largest component of their community.
pub fn disconnected(g: &Graph, comm: &[u32]) -> (usize, usize) {
    let k = *comm.iter().max().unwrap_or(&0) as usize + 1;
    let mut members: Vec<Vec<u32>> = vec![Vec::new(); k];
    for (i, &c) in comm.iter().enumerate() { members[c as usize].push(i as u32); }
    let mut seen = vec![false; g.n];
    let (mut bad, mut stray) = (0usize, 0usize);
    let mut q = VecDeque::new();
    for c in 0..k {
        let mut comps = vec![];
        for &s in &members[c] {
            if seen[s as usize] { continue; }
            seen[s as usize] = true; q.push_back(s); let mut sz = 0usize;
            while let Some(u) = q.pop_front() {
                sz += 1;
                for &v in g.adj(u as usize).0 { if !seen[v as usize] && comm[v as usize] as usize == c { seen[v as usize] = true; q.push_back(v); } }
            }
            comps.push(sz);
        }
        if comps.len() > 1 { bad += 1; stray += comps.iter().sum::<usize>() - comps.iter().max().unwrap(); }
    }
    (bad, stray)
}

/// Normalized mutual information (arithmetic mean normalization) of two labelings,
/// restricted to the nodes where `b` is defined.
pub fn nmi(a: &[u32], b: &[Option<u32>]) -> f64 {
    use std::collections::HashMap;
    let mut joint: HashMap<(u32, u32), f64> = HashMap::new(); let mut pa: HashMap<u32, f64> = HashMap::new(); let mut pb: HashMap<u32, f64> = HashMap::new();
    let mut n = 0.0;
    for (x, y) in a.iter().zip(b) { if let Some(y) = y { *joint.entry((*x, *y)).or_default() += 1.0; *pa.entry(*x).or_default() += 1.0; *pb.entry(*y).or_default() += 1.0; n += 1.0; } }
    if n == 0.0 { return 0.0; }
    let h = |m: &HashMap<u32, f64>| -m.values().map(|&c| c / n * (c / n).ln()).sum::<f64>();
    let (ha, hb) = (h(&pa), h(&pb));
    let mi: f64 = joint.iter().map(|(&(x, y), &c)| c / n * (c * n / (pa[&x] * pb[&y])).ln()).sum();
    if ha + hb > 0.0 { 2.0 * mi / (ha + hb) } else { 0.0 }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ring_of_cliques(cliques: usize, size: usize) -> (Graph, Vec<u32>) {
        let mut e = vec![];
        for c in 0..cliques {
            let b = (c * size) as u32;
            for i in 0..size as u32 { for j in i + 1..size as u32 { e.push((b + i, b + j)); } }
            e.push((b, (((c + 1) % cliques) * size) as u32 + 1));
        }
        let truth = (0..cliques * size).map(|i| (i / size) as u32).collect();
        (Graph::from_edges(cliques * size, &e), truth)
    }

    fn random_graph(n: usize, m: usize, seed: u64) -> Graph {
        let mut r = Rng::new(seed);
        let e: Vec<(u32, u32)> = (0..m).map(|_| ((r.next() % n as u64) as u32, (r.next() % n as u64) as u32)).filter(|(a, b)| a != b).collect();
        Graph::from_edges(n, &e)
    }

    #[test]
    fn ring_of_cliques_is_recovered() {
        let (g, truth) = ring_of_cliques(30, 10);
        let q_truth = modularity(&g, &truth, 1.0);
        // Known value: sum over cliques of in/2m - (tot/2m)^2.
        let m = g.m2 / 2.0; let inside = 45.0; let tot = 2.0 * 45.0 + 2.0;
        let expected = 30.0 * (inside / m - (tot / (2.0 * m)).powi(2));
        assert!((q_truth - expected).abs() < 1e-9, "{q_truth} vs {expected}");
        for res in [louvain(&g, 1.0, 1), leiden(&g, 1.0, 1)] {
            let k = *res.comm.iter().max().unwrap() as usize + 1;
            assert_eq!(k, 30, "communities");
            assert!(nmi(&res.comm, &truth.iter().map(|&x| Some(x)).collect::<Vec<_>>()) > 0.999);
            assert!((modularity(&g, &res.comm, 1.0) - q_truth).abs() < 1e-9);
        }
    }

    #[test]
    fn aggregation_keeps_weight_and_modularity() {
        let g = random_graph(2000, 9000, 3);
        let mut part: Vec<u32> = (0..g.n as u32).map(|i| i % 37).collect();
        let k = renumber(&mut part);
        let a = aggregate(&g, &part, k);
        assert!((a.m2 - g.m2).abs() < 1e-6, "{} vs {}", a.m2, g.m2);
        let single: Vec<u32> = (0..k as u32).collect();
        assert!((modularity(&a, &single, 1.0) - modularity(&g, &part, 1.0)).abs() < 1e-9);
    }

    #[test]
    fn leiden_communities_are_connected() {
        for seed in 0..8 {
            let g = random_graph(3000, 6000, 100 + seed);
            let r = leiden(&g, 1.0, seed);
            assert_eq!(disconnected(&g, &r.comm).0, 0, "seed {seed}");
            let q = modularity(&g, &r.comm, 1.0); let ql = modularity(&g, &louvain(&g, 1.0, seed).comm, 1.0);
            assert!(q > 0.3 && (q - ql).abs() < 0.05, "Q leiden {q} louvain {ql}");
        }
    }
}
