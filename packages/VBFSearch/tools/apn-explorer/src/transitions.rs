//! Feature 2: parent-to-child invariant transitions.
//!
//! Two edge sets: "first" (the discoverer of each class: the parent of its first
//! construction path) and "all" (every distinct parent -> class pair of a construction
//! path). The first set depends on the search order (which parent happened to reach a
//! class first); the second does not, so a pattern present in "all" is a property of
//! the constructions, not of the order.
//!
//! Per invariant: the count matrix parent value x child value, the mutual information
//! MI (bits), NMI = MI / sqrt(H(parent) H(child)), Cramer's V, the diagonal rate
//! (child keeps the parent's value) against its independence rate, and a permutation
//! null: parent values shuffled over the edges (both marginals kept), so z =
//! (MI - mean_null) / sd_null measures dependence beyond chance. MI per quarter of the
//! parents' expansion order shows whether the dependence changes as the search goes on.

use crate::data::{Data, Field};
use rayon::prelude::*;
use serde_json::{json, Value};
use std::collections::BTreeMap;

pub const FIELDS: [Field; 7] = [Field::Two, Field::Three, Field::Du, Field::C4, Field::Four, Field::Status, Field::Generation];

/// Binned value: two in bands of 10, three in bands of 5, the others exact.
pub fn binned(d: &Data, f: Field, i: usize) -> Option<i32> {
    let v = d.field(f, i)?;
    Some(match f { Field::Two => v / 10 * 10, Field::Three => v / 5 * 5, Field::Status if v == 3 => return None, _ => v })
}

fn splitmix(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9E3779B97F4A7C15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D049BB133111EB);
    z ^ (z >> 31)
}

fn mutual_information(pv: &[u16], cv: &[u16], k: usize) -> (f64, Vec<u64>) {
    let mut m = vec![0u64; k * k];
    for (&a, &b) in pv.iter().zip(cv) { m[a as usize * k + b as usize] += 1; }
    (mi_of(&m, k).0, m)
}

/// (MI bits, H(row), H(col)) of a k x k count matrix.
fn mi_of(m: &[u64], k: usize) -> (f64, f64, f64) {
    let n: f64 = m.iter().sum::<u64>() as f64;
    if n == 0.0 { return (0.0, 0.0, 0.0); }
    let rows: Vec<f64> = (0..k).map(|i| m[i * k..(i + 1) * k].iter().sum::<u64>() as f64).collect();
    let cols: Vec<f64> = (0..k).map(|j| (0..k).map(|i| m[i * k + j]).sum::<u64>() as f64).collect();
    let mut mi = 0.0;
    for i in 0..k { for j in 0..k {
        let x = m[i * k + j] as f64;
        if x > 0.0 { mi += x / n * (x * n / (rows[i] * cols[j])).log2(); }
    } }
    let h = |v: &[f64]| -v.iter().filter(|&&x| x > 0.0).map(|&x| x / n * (x / n).log2()).sum::<f64>();
    (mi, h(&rows), h(&cols))
}

fn stats(pv: &[u16], cv: &[u16], k: usize, perms: usize, seed: u64) -> Value {
    let (mi, m) = mutual_information(pv, cv, k);
    let (_, hr, hc) = mi_of(&m, k);
    let n = pv.len() as f64;
    let rows: Vec<f64> = (0..k).map(|i| m[i * k..(i + 1) * k].iter().sum::<u64>() as f64).collect();
    let cols: Vec<f64> = (0..k).map(|j| (0..k).map(|i| m[i * k + j]).sum::<u64>() as f64).collect();
    let mut chi = 0.0;
    for i in 0..k { for j in 0..k {
        let e = rows[i] * cols[j] / n.max(1.0);
        if e > 0.0 { chi += (m[i * k + j] as f64 - e).powi(2) / e; }
    } }
    let kr = rows.iter().filter(|&&x| x > 0.0).count(); let kc = cols.iter().filter(|&&x| x > 0.0).count();
    let cramers_v = if kr > 1 && kc > 1 && n > 0.0 { (chi / (n * ((kr.min(kc) - 1) as f64))).sqrt() } else { 0.0 };
    let diag = (0..k).map(|i| m[i * k + i]).sum::<u64>() as f64 / n.max(1.0);
    let base = (0..k).map(|i| rows[i] * cols[i]).sum::<f64>() / (n * n).max(1.0);
    let nulls: Vec<f64> = (0..perms).into_par_iter().map(|p| {
        let mut s = seed ^ (p as u64 + 1).wrapping_mul(0x2545F4914F6CDD1D);
        let mut q = pv.to_vec();
        for i in (1..q.len()).rev() { let j = (splitmix(&mut s) % (i as u64 + 1)) as usize; q.swap(i, j); }
        mutual_information(&q, cv, k).0
    }).collect();
    let mean = nulls.iter().sum::<f64>() / perms.max(1) as f64;
    let sd = (nulls.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / (perms.max(2) - 1) as f64).sqrt();
    json!({"edges": pv.len(), "matrix": m, "mi_bits": mi, "nmi": if hr > 0.0 && hc > 0.0 { mi / (hr * hc).sqrt() } else { 0.0 },
           "cramers_v": cramers_v, "same_value_rate": diag, "same_value_rate_if_independent": base,
           "null_mi_mean": mean, "null_mi_sd": sd, "z": if sd > 0.0 { (mi - mean) / sd } else { 0.0 }, "permutations": perms})
}

/// Distinct (parent, class) edges, sorted, from the construction-path pairs.
pub fn distinct_edges(pairs: &[(u32, u32)]) -> Vec<(u32, u32)> {
    let mut e: Vec<u64> = pairs.par_iter().filter(|&&(p, c)| p != c).map(|&(p, c)| (p as u64) << 32 | c as u64).collect();
    e.par_sort_unstable(); e.dedup();
    e.into_iter().map(|x| ((x >> 32) as u32, x as u32)).collect()
}

pub fn run(d: &Data, edges_all: &[(u32, u32)], perms: usize) -> Value {
    let first: Vec<(u32, u32)> = (0..d.n).filter(|&i| d.discoverer[i] > 0).map(|i| (d.discoverer[i] - 1, i as u32)).collect();
    // Expansion order of the parents: rank of the parent id among parents with out-edges.
    let mut parents: Vec<u32> = edges_all.iter().map(|e| e.0).collect(); parents.dedup();
    let quarter = |p: u32| -> usize { let r = parents.partition_point(|&x| x < p); (4 * r / parents.len().max(1)).min(3) };
    let mut out = serde_json::Map::new();
    for f in FIELDS {
        let mut values: BTreeMap<i32, u16> = BTreeMap::new();
        for i in 0..d.n { if let Some(v) = binned(d, f, i) { values.entry(v).or_insert(0); } }
        for (k, v) in values.iter_mut().enumerate() { *v.1 = k as u16; }
        let k = values.len();
        let code = |i: usize| binned(d, f, i).map(|v| values[&v]);
        let collect = |edges: &[(u32, u32)]| -> (Vec<u16>, Vec<u16>, Vec<u8>) {
            let mut pv = Vec::with_capacity(edges.len()); let mut cv = Vec::with_capacity(edges.len()); let mut q = Vec::with_capacity(edges.len());
            for &(p, c) in edges {
                if let (Some(a), Some(b)) = (code(p as usize), code(c as usize)) { pv.push(a); cv.push(b); q.push(quarter(p) as u8); }
            }
            (pv, cv, q)
        };
        let mut entry = serde_json::Map::new();
        entry.insert("values".into(), json!(values.keys().collect::<Vec<_>>()));
        for (name, edges) in [("first", &first[..]), ("all", edges_all)] {
            let (pv, cv, q) = collect(edges);
            let mut s = stats(&pv, &cv, k, perms, 0xA5A5_0000 ^ k as u64);
            let by_q: Vec<f64> = (0..4).map(|qq| {
                let (a, b): (Vec<u16>, Vec<u16>) = pv.iter().zip(&cv).zip(&q).filter(|(_, &x)| x as usize == qq).map(|((&a, &b), _)| (a, b)).unzip();
                mutual_information(&a, &b, k).0
            }).collect();
            s["mi_by_expansion_quarter"] = json!(by_q);
            entry.insert(name.into(), s);
        }
        out.insert(f.name().into(), Value::Object(entry));
    }
    json!({"classes": d.n, "first_edges": first.len(), "all_edges": edges_all.len(), "fields": out,
           "binning": {"two": "bands of 10", "three": "bands of 5", "others": "exact values"},
           "notes": "first = discoverer -> class (depends on the search order); all = every distinct parent -> class construction pair (independent of the order). z compares MI with parent values shuffled over the edges."})
}
