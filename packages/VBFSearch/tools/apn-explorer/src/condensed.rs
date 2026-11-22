//! Feature 6: condensed community graph. One node per community (the largest ones),
//! with its size, status and generation mix, invariant means, seed-lineage purity and
//! conductance; edges carry the construction weight between communities. The layout
//! is a force-directed Fruchterman-Reingold placement with log weights, deterministic
//! (start on a spiral by size, fixed number of iterations).

use crate::data::Data;
use crate::graph::Graph;
use rayon::prelude::*;
use serde_json::{json, Value};
use std::collections::HashMap;

pub fn run(d: &Data, g: &Graph, comm: &[u32], top: usize) -> Value {
    let k = *comm.iter().max().unwrap_or(&0) as usize + 1;
    let mut size = vec![0u64; k];
    for &c in comm { size[c as usize] += 1; }
    let mut order: Vec<usize> = (0..k).collect(); order.sort_by_key(|&c| std::cmp::Reverse(size[c]));
    let keep: Vec<usize> = order.iter().copied().take(top).collect();
    let mut slot = vec![u32::MAX; k]; for (s, &c) in keep.iter().enumerate() { slot[c] = s as u32; }
    let t = keep.len();
    // Per community statistics over its classes.
    #[derive(Default, Clone)] struct S { st: [u64; 4], g: [u64; 3], two: f64, three: f64, meas: u64, c4: u64, exp: u64, found: f64, vol: f64, inside: f64 }
    let mut s = vec![S::default(); t];
    let mut roots: Vec<HashMap<u32, u64>> = vec![HashMap::new(); t];
    for i in 0..d.n {
        let sl = slot[comm[i] as usize]; if sl == u32::MAX { continue; } let x = &mut s[sl as usize];
        x.st[d.status[i] as usize] += 1; if (d.generation[i] as usize) < 3 { x.g[d.generation[i] as usize] += 1; }
        if d.measured(i) { x.two += d.two[i] as f64; x.three += d.three[i] as f64; x.meas += 1; x.c4 += (d.inv[i][1] > 0) as u64; }
        x.exp += (d.expanded[i] > 0) as u64; x.found += d.found[i] as f64; x.vol += g.k[i];
        *roots[sl as usize].entry(d.root[i]).or_default() += 1;
    }
    // Weights between the kept communities.
    let mut between: HashMap<(u32, u32), f64> = HashMap::new();
    for i in 0..g.n {
        let a = slot[comm[i] as usize]; if a == u32::MAX { continue; }
        let (nb, ww) = g.adj(i);
        for (&j, &w) in nb.iter().zip(ww) {
            let b = slot[comm[j as usize] as usize]; if b == u32::MAX { continue; }
            if a == b { s[a as usize].inside += w as f64; } else if a < b { *between.entry((a, b)).or_default() += w as f64; }
        }
    }
    let edges: Vec<(u32, u32, f64)> = between.into_iter().map(|((a, b), w)| (a, b, w)).collect();
    // Fruchterman-Reingold layout.
    let mut pos: Vec<[f64; 2]> = (0..t).map(|i| { let r = (i as f64 + 1.0).sqrt(); let a = i as f64 * 2.39996; [r * a.cos(), r * a.sin()] }).collect();
    let area = t as f64; let kk = (area / t.max(1) as f64).sqrt();
    let wmax = edges.iter().map(|e| e.2).fold(1.0, f64::max).ln_1p();
    let mut temp = (t as f64).sqrt();
    for _ in 0..600 {
        let mut disp: Vec<[f64; 2]> = (0..t).into_par_iter().map(|i| {
            let mut dsp = [0.0; 2];
            for j in 0..t { if i == j { continue; }
                let dx = pos[i][0] - pos[j][0]; let dy = pos[i][1] - pos[j][1]; let dist = (dx * dx + dy * dy).sqrt().max(0.01);
                let f = kk * kk / dist; dsp[0] += dx / dist * f; dsp[1] += dy / dist * f; }
            dsp
        }).collect();
        for &(a, b, w) in &edges {
            let (a, b) = (a as usize, b as usize);
            let dx = pos[a][0] - pos[b][0]; let dy = pos[a][1] - pos[b][1]; let dist = (dx * dx + dy * dy).sqrt().max(0.01);
            let f = dist * dist / kk * (w.ln_1p() / wmax);
            disp[a][0] -= dx / dist * f; disp[a][1] -= dy / dist * f; disp[b][0] += dx / dist * f; disp[b][1] += dy / dist * f;
        }
        for i in 0..t {
            let l = (disp[i][0].powi(2) + disp[i][1].powi(2)).sqrt().max(1e-9);
            pos[i][0] += disp[i][0] / l * l.min(temp); pos[i][1] += disp[i][1] / l * l.min(temp);
        }
        temp *= 0.992;
    }
    let nodes: Vec<Value> = keep.iter().enumerate().map(|(sl, &c)| {
        let x = &s[sl]; let n = size[c] as f64;
        let top_root = roots[sl].iter().max_by_key(|e| e.1).map(|(&r, &cnt)| (r, cnt)).unwrap_or((0, 0));
        let cut = x.vol - x.inside;
        json!({"community": c, "size": size[c], "x": pos[sl][0], "y": pos[sl][1],
               "catalog_matching": x.st[0], "new": x.st[1], "seeds": x.st[2], "unknown": x.st[3], "generations": x.g,
               "novelty": if x.st[0] + x.st[1] > 0 { x.st[1] as f64 / (x.st[0] + x.st[1]) as f64 } else { 0.0 },
               "mean_two": if x.meas > 0 { x.two / x.meas as f64 } else { 0.0 }, "mean_three": if x.meas > 0 { x.three / x.meas as f64 } else { 0.0 },
               "c4_positive": if x.meas > 0 { x.c4 as f64 / x.meas as f64 } else { 0.0 }, "expanded": x.exp, "mean_found": x.found / n,
               "seed_lineages": roots[sl].len(), "top_seed": top_root.0, "top_seed_share": top_root.1 as f64 / n,
               "conductance": if x.vol > 0.0 { cut / x.vol.min(g.m2 - x.vol).max(1e-9) } else { 0.0 }})
    }).collect();
    let links: Vec<Value> = edges.iter().map(|&(a, b, w)| json!([a, b, w])).collect();
    json!({"communities_total": k, "shown": t, "shown_classes": keep.iter().map(|&c| size[c]).sum::<u64>(), "nodes": nodes, "links": links,
           "layout": "Fruchterman-Reingold, 600 iterations, log weights, spiral start by size (deterministic)"})
}
