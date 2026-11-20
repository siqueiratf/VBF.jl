//! Graph statistics that closure_graph.jl stores: weak components and the
//! largest strong component. Both are sequential and deterministic.

/// Weak component of each vertex, numbered from 1 like closure_graph.jl:
/// sorted by size (largest first), then by the smallest vertex.
/// Returns (component per vertex, sizes in that order).
pub fn weak_components(n: usize, offsets: &[u64], targets: &[u32]) -> (Vec<u32>, Vec<usize>) {
    let mut parent: Vec<u32> = (0..n as u32).collect();
    fn find(p: &mut [u32], mut x: u32) -> u32 {
        while p[x as usize] != x {
            p[x as usize] = p[p[x as usize] as usize];
            x = p[x as usize];
        }
        x
    }
    for u in 0..n {
        for &v in &targets[offsets[u] as usize..offsets[u + 1] as usize] {
            let (a, b) = (find(&mut parent, u as u32), find(&mut parent, v));
            if a != b {
                // The smaller root wins, so a root is the smallest vertex of its set.
                let (lo, hi) = if a < b { (a, b) } else { (b, a) };
                parent[hi as usize] = lo;
            }
        }
    }
    let mut size = vec![0usize; n];
    let root: Vec<u32> = (0..n as u32).map(|v| find(&mut parent, v)).collect();
    for &r in &root {
        size[r as usize] += 1;
    }
    let mut roots: Vec<u32> = (0..n as u32).filter(|&v| root[v as usize] == v).collect();
    roots.sort_by_key(|&r| (std::cmp::Reverse(size[r as usize]), r));
    let mut index = vec![0u32; n];
    for (i, &r) in roots.iter().enumerate() {
        index[r as usize] = i as u32 + 1;
    }
    let sizes = roots.iter().map(|&r| size[r as usize]).collect();
    (root.iter().map(|&r| index[r as usize]).collect(), sizes)
}

/// Size of the largest strongly connected component (iterative Tarjan).
pub fn largest_strong_component(n: usize, offsets: &[u64], targets: &[u32]) -> usize {
    const NONE: u32 = u32::MAX;
    let mut index = vec![NONE; n];
    let mut low = vec![0u32; n];
    let mut on_stack = vec![false; n];
    let mut stack: Vec<u32> = Vec::new();
    let mut call: Vec<(u32, u64)> = Vec::new();
    let (mut next, mut best) = (0u32, 0usize);
    for start in 0..n as u32 {
        if index[start as usize] != NONE {
            continue;
        }
        call.push((start, offsets[start as usize]));
        index[start as usize] = next;
        low[start as usize] = next;
        next += 1;
        stack.push(start);
        on_stack[start as usize] = true;
        while let Some(&(v, edge)) = call.last() {
            let vi = v as usize;
            if edge < offsets[vi + 1] {
                let w = targets[edge as usize];
                call.last_mut().unwrap().1 += 1;
                let wi = w as usize;
                if index[wi] == NONE {
                    index[wi] = next;
                    low[wi] = next;
                    next += 1;
                    stack.push(w);
                    on_stack[wi] = true;
                    call.push((w, offsets[wi]));
                } else if on_stack[wi] {
                    low[vi] = low[vi].min(index[wi]);
                }
            } else {
                call.pop();
                if let Some(&(u, _)) = call.last() {
                    low[u as usize] = low[u as usize].min(low[vi]);
                }
                if low[vi] == index[vi] {
                    let mut count = 0;
                    loop {
                        let w = stack.pop().unwrap();
                        on_stack[w as usize] = false;
                        count += 1;
                        if w == v {
                            break;
                        }
                    }
                    best = best.max(count);
                }
            }
        }
    }
    best
}

#[cfg(test)]
mod tests {
    use super::*;

    fn csr(n: usize, edges: &[(u32, u32)]) -> (Vec<u64>, Vec<u32>) {
        let mut offsets = vec![0u64; n + 1];
        let mut sorted = edges.to_vec();
        sorted.sort();
        for &(u, _) in &sorted {
            offsets[u as usize + 1] += 1;
        }
        for i in 0..n {
            offsets[i + 1] += offsets[i];
        }
        (offsets, sorted.iter().map(|e| e.1).collect())
    }

    #[test]
    fn components_and_scc() {
        // {0,1,2} cycle, {3,4} chain, {5} alone, {6,7} 2-cycle.
        let (o, t) = csr(8, &[(0, 1), (1, 2), (2, 0), (3, 4), (6, 7), (7, 6)]);
        let (c, sizes) = weak_components(8, &o, &t);
        assert_eq!(c, vec![1, 1, 1, 2, 2, 4, 3, 3]);
        assert_eq!(sizes, vec![3, 2, 2, 1]);
        assert_eq!(largest_strong_component(8, &o, &t), 3);
    }
}
