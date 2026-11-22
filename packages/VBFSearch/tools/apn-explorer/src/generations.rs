//! Feature 4: discovery statistics per generation (distance from a published seed
//! along first construction paths). The search is breadth-first, so generation g+1
//! grows only from expanded parents of generation g; the expanded share per
//! generation is the progress of the frontier, and the parent-generation x
//! child-generation matrix over all construction pairs shows how often a parent finds
//! classes of earlier generations (rediscoveries across generations).

use crate::data::{Data, UNKNOWN_GEN};
use serde_json::{json, Value};

pub fn run(d: &Data, edges: &[(u32, u32)], ind: &[u32]) -> Value {
    let n = d.n;
    let gmax = (0..n).filter(|&i| d.generation[i] != UNKNOWN_GEN).map(|i| d.generation[i] as usize).max().unwrap_or(0);
    let k = gmax + 2; // last index = unknown
    let gi = |i: usize| if d.generation[i] == UNKNOWN_GEN { k - 1 } else { d.generation[i] as usize };
    let mut rows = vec![];
    for g in 0..k {
        let idx: Vec<usize> = (0..n).filter(|&i| gi(i) == g).collect();
        if idx.is_empty() { continue; }
        let c = idx.len() as f64;
        let cnt = |f: &dyn Fn(usize) -> bool| idx.iter().filter(|&&i| f(i)).count();
        let meas: Vec<usize> = idx.iter().copied().filter(|&i| d.measured(i)).collect();
        let mean = |f: &dyn Fn(usize) -> f64| if meas.is_empty() { 0.0 } else { meas.iter().map(|&i| f(i)).sum::<f64>() / meas.len() as f64 };
        let exp: Vec<usize> = idx.iter().copied().filter(|&i| d.expanded[i] > 0).collect();
        let rnew: f64 = exp.iter().map(|&i| d.reached_new[i] as f64).sum(); let cos: f64 = exp.iter().map(|&i| d.cosets[i] as f64).sum();
        let mut ids: Vec<usize> = idx.iter().map(|&i| i + 1).collect(); ids.sort_unstable();
        let mut indeg: Vec<u32> = idx.iter().map(|&i| ind[i]).collect(); indeg.sort_unstable();
        rows.push(json!({"generation": if g == k - 1 { json!("unknown") } else { json!(g) }, "classes": idx.len(),
            "new": cnt(&|i| d.status[i] == 1), "catalog_matching": cnt(&|i| d.status[i] == 0), "seeds": cnt(&|i| d.status[i] == 2),
            "v5_first": cnt(&|i| d.method[i] == 1), "switching_first": cnt(&|i| d.method[i] == 2),
            "expanded": exp.len(), "expanded_share": exp.len() as f64 / c, "new_per_million_cosets": if cos > 0.0 { 1e6 * rnew / cos } else { 0.0 },
            "mean_two": mean(&|i| d.two[i] as f64), "mean_three": mean(&|i| d.three[i] as f64), "mean_du": mean(&|i| d.inv[i][0] as f64),
            "c4_positive": meas.iter().filter(|&&i| d.inv[i][1] > 0).count() as f64 / meas.len().max(1) as f64,
            "four_positive": meas.iter().filter(|&&i| d.inv[i][3] > 0).count() as f64 / meas.len().max(1) as f64,
            "first_id": ids[0], "median_id": ids[ids.len() / 2], "last_id": ids[ids.len() - 1],
            "median_in_degree": indeg[indeg.len() / 2], "singletons": indeg.iter().filter(|&&x| x == 1).count() as f64 / c}));
    }
    // Children found first per expanded parent, by parent generation.
    let mut kids = vec![0u64; n];
    for i in 0..n { if d.discoverer[i] > 0 { kids[d.discoverer[i] as usize - 1] += 1; } }
    let kids_by_gen: Vec<Value> = (0..k).map(|g| {
        let p: Vec<usize> = (0..n).filter(|&i| gi(i) == g && d.expanded[i] > 0).collect();
        json!({"parent_generation": g, "expanded_parents": p.len(), "mean_children_first": if p.is_empty() { 0.0 } else { p.iter().map(|&i| kids[i] as f64).sum::<f64>() / p.len() as f64 }})
    }).collect();
    // Parent generation x child generation over all construction pairs.
    let mut m = vec![0u64; k * k];
    for &(p, c) in edges { m[gi(p as usize) * k + gi(c as usize)] += 1; }
    // Admission curve: classes per generation in blocks of ids.
    let block = (n / 100).max(1);
    let curve: Vec<Value> = (0..n).step_by(block).map(|lo| {
        let hi = (lo + block).min(n); let mut c = vec![0u64; k]; let mut nw = vec![0u64; k];
        for i in lo..hi { c[gi(i)] += 1; if d.status[i] == 1 { nw[gi(i)] += 1; } }
        json!({"first_id": lo + 1, "per_generation": c, "new_per_generation": nw})
    }).collect();
    json!({"classes": n, "generations": k - 1, "labels": (0..k).map(|g| if g == k - 1 { "unknown".to_string() } else { g.to_string() }).collect::<Vec<_>>(),
           "rows": rows, "children_per_parent": kids_by_gen, "parent_child_generation_matrix": m, "admission_curve": curve, "block_ids": block,
           "notes": "Breadth-first search: expanded_share is the frontier progress of each generation; off-diagonal entries g -> g' < g+1 are constructions that reach classes of earlier generations."})
}
