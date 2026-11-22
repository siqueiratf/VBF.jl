//! Undirected weighted class graph in CSR form, from the distinct directed
//! construction pairs: weight 1 per direction, so a pair found both ways has weight 2.

use rayon::prelude::*;

pub struct Graph {
    pub n: usize,
    pub off: Vec<u64>,
    pub nbr: Vec<u32>,
    pub w: Vec<f32>,
    /// Weighted degree (strength) of every node; self loops count twice.
    pub k: Vec<f64>,
    /// Sum of all strengths = 2m.
    pub m2: f64,
}

impl Graph {
    pub fn from_edges(n: usize, edges: &[(u32, u32)]) -> Graph {
        let mut deg = vec![0u64; n + 1];
        for &(a, b) in edges { if a != b { deg[a as usize] += 1; deg[b as usize] += 1; } }
        let mut off = vec![0u64; n + 1];
        for i in 0..n { off[i + 1] = off[i] + deg[i]; }
        let mut pos = off.clone();
        let mut nbr = vec![0u32; off[n] as usize];
        for &(a, b) in edges {
            if a == b { continue; }
            nbr[pos[a as usize] as usize] = b; pos[a as usize] += 1;
            nbr[pos[b as usize] as usize] = a; pos[b as usize] += 1;
        }
        // Sort each adjacency and merge duplicates (both directions) into weights.
        let lists: Vec<(Vec<u32>, Vec<f32>)> = (0..n).into_par_iter().map(|i| {
            let s = &mut nbr[off[i] as usize..off[i + 1] as usize].to_vec();
            s.sort_unstable();
            let (mut v, mut w) = (Vec::with_capacity(s.len()), Vec::with_capacity(s.len()));
            for &x in s.iter() { if v.last() == Some(&x) { *w.last_mut().unwrap() += 1.0; } else { v.push(x); w.push(1.0f32); } }
            (v, w)
        }).collect();
        Graph::from_lists(lists)
    }

    pub fn from_lists(lists: Vec<(Vec<u32>, Vec<f32>)>) -> Graph {
        let n = lists.len();
        let mut off = vec![0u64; n + 1];
        for (i, l) in lists.iter().enumerate() { off[i + 1] = off[i] + l.0.len() as u64; }
        let mut nbr = Vec::with_capacity(off[n] as usize); let mut w = Vec::with_capacity(off[n] as usize);
        let mut k = vec![0f64; n];
        for (i, (v, ww)) in lists.into_iter().enumerate() {
            for (&x, &y) in v.iter().zip(&ww) { k[i] += if x as usize == i { 2.0 * y as f64 } else { y as f64 }; }
            nbr.extend(v); w.extend(ww);
        }
        let m2 = k.iter().sum();
        Graph { n, off, nbr, w, k, m2 }
    }

    #[inline]
    pub fn adj(&self, i: usize) -> (&[u32], &[f32]) {
        let (a, b) = (self.off[i] as usize, self.off[i + 1] as usize);
        (&self.nbr[a..b], &self.w[a..b])
    }

    pub fn edges(&self) -> usize { self.nbr.len() / 2 }
}
