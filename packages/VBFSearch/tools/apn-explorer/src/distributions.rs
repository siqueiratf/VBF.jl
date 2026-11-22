//! Feature 3: degree and rediscovery distributions.
//!
//! in_degree = distinct parents whose construction paths reached the class (exact; the
//! explorer's finders.u8 is capped at 255); out_degree = distinct classes an expanded
//! parent reached; found = all paths that reached the class (rediscoveries); plus new
//! classes reached, maximizing 5-spaces and cosets of the expanded parents.
//! Histograms use log2 bins [2^k, 2^(k+1)), with 0 in its own bin, by status and by
//! generation. Tails get a discrete power-law fit (MLE, xmin chosen by the smallest
//! Kolmogorov-Smirnov distance, after Clauset, Shalizi and Newman 2009).
//!
//! Search-process diagnostics: in-degree grows with the time a class has been known
//! (exposure), so it is reported per admission decile; "already known" is the share
//! of a parent's reached classes that an earlier parent had found, per decile of the
//! expansion order (saturation of the neighbourhood as the search goes on).

use crate::data::Data;
use rayon::prelude::*;
use serde_json::{json, Value};

pub fn in_degree(n: usize, edges: &[(u32, u32)]) -> Vec<u32> {
    let mut d = vec![0u32; n];
    for &(_, c) in edges { d[c as usize] += 1; }
    d
}

fn bin_of(x: f64) -> usize { if x < 1.0 { 0 } else { 1 + x.log2().floor() as usize } }

fn histogram(vals: impl Iterator<Item = f64>) -> Vec<u64> {
    let mut h = vec![0u64; 1];
    for x in vals { let b = bin_of(x); if b >= h.len() { h.resize(b + 1, 0); } h[b] += 1; }
    h
}

fn summary(mut v: Vec<f64>) -> Value {
    if v.is_empty() { return json!(null); }
    v.par_sort_unstable_by(|a, b| a.partial_cmp(b).unwrap());
    let q = |p: f64| v[((v.len() - 1) as f64 * p).round() as usize];
    json!({"count": v.len(), "mean": v.iter().sum::<f64>() / v.len() as f64, "median": q(0.5), "p90": q(0.9), "p99": q(0.99), "max": v[v.len() - 1]})
}

/// Discrete power law: alpha = 1 + n / sum ln(x / (xmin - 1/2)); xmin minimizes the KS distance.
fn powerlaw(mut v: Vec<u64>) -> Value {
    v.retain(|&x| x > 0);
    if v.len() < 100 { return json!(null); }
    v.par_sort_unstable();
    let mut cands: Vec<u64> = v.clone(); cands.dedup();
    cands.retain(|&x| { let tail = v.len() - v.partition_point(|&y| y < x); tail >= 50 });
    cands.truncate(400);
    let fit = |xmin: u64| -> (f64, f64, usize) {
        let start = v.partition_point(|&y| y < xmin); let tail = &v[start..]; let n = tail.len() as f64;
        let s: f64 = tail.iter().map(|&x| (x as f64 / (xmin as f64 - 0.5)).ln()).sum();
        let alpha = 1.0 + n / s;
        // KS between the empirical CDF of the tail and the continuous approximation.
        let mut ks: f64 = 0.0; let mut i = 0usize;
        while i < tail.len() {
            let x = tail[i]; let mut j = i; while j < tail.len() && tail[j] == x { j += 1; }
            let emp = j as f64 / n;
            let model = 1.0 - ((x as f64 + 0.5) / (xmin as f64 - 0.5)).powf(1.0 - alpha);
            ks = ks.max((emp - model).abs()); i = j;
        }
        (alpha, ks, tail.len())
    };
    let best = cands.par_iter().map(|&x| { let (a, ks, t) = fit(x); (x, a, ks, t) })
        .min_by(|a, b| a.2.partial_cmp(&b.2).unwrap()).unwrap();
    json!({"xmin": best.0, "alpha": best.1, "ks": best.2, "tail": best.3, "share_in_tail": best.3 as f64 / v.len() as f64})
}

pub fn run(d: &Data, edges: &[(u32, u32)], pairs_order: &[(u32, u32)]) -> (Value, Vec<u32>) {
    let n = d.n;
    let ind = in_degree(n, edges);
    let mut out = vec![0u32; n];
    for &(p, _) in edges { out[p as usize] += 1; }
    let exp: Vec<usize> = (0..n).filter(|&i| d.expanded[i] > 0).collect();
    type Get<'a> = Box<dyn Fn(usize) -> f64 + Sync + 'a>;
    let metrics: Vec<(&str, Get, bool)> = vec![
        ("in_degree", Box::new(|i| ind[i] as f64), false), ("found", Box::new(|i| d.found[i] as f64), false),
        ("out_degree", Box::new(|i| out[i] as f64), true), ("reached_new", Box::new(|i| d.reached_new[i] as f64), true),
        ("spaces", Box::new(|i| d.spaces[i] as f64), true), ("cosets", Box::new(|i| d.cosets[i] as f64), true)];
    let mut res = serde_json::Map::new();
    for (name, get, parents_only) in &metrics {
        let pool: Vec<usize> = if *parents_only { exp.clone() } else { (0..n).collect() };
        let mut groups = serde_json::Map::new();
        groups.insert("all".into(), json!(histogram(pool.iter().map(|&i| get(i)))));
        for (k, s) in ["catalog", "new", "seed"].iter().enumerate() {
            groups.insert(format!("status:{s}"), json!(histogram(pool.iter().filter(|&&i| d.status[i] as usize == k).map(|&i| get(i)))));
        }
        for g in 0..3u16 {
            groups.insert(format!("generation:{g}"), json!(histogram(pool.iter().filter(|&&i| d.generation[i] == g).map(|&i| get(i)))));
        }
        let vals: Vec<f64> = pool.iter().map(|&i| get(i)).collect();
        let pl = if matches!(*name, "in_degree" | "found" | "out_degree") { powerlaw(vals.iter().map(|&x| x as u64).collect()) } else { json!(null) };
        res.insert((*name).into(), json!({"parents_only": parents_only, "groups": groups, "summary": summary(vals), "powerlaw": pl}));
    }
    // Exposure: mean in-degree per admission decile (classes known longer are found again more often).
    let exposure: Vec<Value> = (0..10).map(|q| {
        let (lo, hi) = (q * n / 10, (q + 1) * n / 10);
        let s: f64 = (lo..hi).map(|i| ind[i] as f64).sum();
        json!({"first_id": lo + 1, "last_id": hi, "mean_in_degree": s / (hi - lo).max(1) as f64,
               "singletons": (lo..hi).filter(|&i| ind[i] == 1).count() as f64 / (hi - lo).max(1) as f64})
    }).collect();
    // Saturation: share of a parent's reached classes already found by an earlier path.
    let mut first_path = vec![u32::MAX; n];
    for &(p, c) in pairs_order { if first_path[c as usize] == u32::MAX { first_path[c as usize] = p; } }
    let parents: Vec<u32> = { let mut v: Vec<u32> = edges.iter().map(|e| e.0).collect(); v.dedup(); v };
    let mut already = vec![(0u64, 0u64); 10];
    let mut k = 0usize;
    while k < edges.len() {
        let p = edges[k].0; let mut j = k;
        let rank = parents.partition_point(|&x| x < p); let dec = (10 * rank / parents.len().max(1)).min(9);
        while j < edges.len() && edges[j].0 == p {
            let c = edges[j].1 as usize;
            already[dec].1 += 1; if first_path[c] != p { already[dec].0 += 1; }
            j += 1;
        }
        k = j;
    }
    let saturation: Vec<Value> = already.iter().enumerate().map(|(q, &(a, t))| json!({"expansion_decile": q, "edges": t, "already_known": a as f64 / t.max(1) as f64})).collect();
    let spearman = {
        let rank = |v: &[f64]| -> Vec<f64> { let mut idx: Vec<usize> = (0..v.len()).collect(); idx.par_sort_unstable_by(|&a, &b| v[a].partial_cmp(&v[b]).unwrap());
            let mut r = vec![0.0; v.len()]; let mut i = 0; while i < idx.len() { let mut j = i; while j < idx.len() && v[idx[j]] == v[idx[i]] { j += 1; }
                let avg = (i + j - 1) as f64 / 2.0; for &x in &idx[i..j] { r[x] = avg; } i = j; } r };
        let a: Vec<f64> = ind.iter().map(|&x| x as f64).collect(); let b: Vec<f64> = (0..n).map(|i| i as f64).collect();
        let (ra, rb) = (rank(&a), rank(&b)); let m = (n as f64 - 1.0) / 2.0;
        let (mut sab, mut saa, mut sbb) = (0.0, 0.0, 0.0);
        for i in 0..n { let (x, y) = (ra[i] - m, rb[i] - m); sab += x * y; saa += x * x; sbb += y * y; }
        sab / (saa * sbb).sqrt()
    };
    drop(metrics);
    (json!({"classes": n, "expanded_parents": exp.len(), "edges": edges.len(), "bins": "log2: bin 0 = value 0, bin k = [2^(k-1), 2^k)",
            "metrics": res, "exposure_by_admission_decile": exposure, "saturation_by_expansion_decile": saturation,
            "spearman_in_degree_vs_admission_order": spearman,
            "notes": "in-degree counts only edges from parents expanded so far; earlier classes had more chances to be found again (see exposure). already_known grows as the neighbourhood of the frontier saturates."}), ind)
}
