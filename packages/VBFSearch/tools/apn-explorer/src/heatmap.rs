//! Feature 1: invariant heatmaps. For each pair of invariants, one cell per pair of
//! exact values, with counts by status and generation, rediscoveries, singletons,
//! expanded parents and their yield, admission order, and the catalog count of the
//! cell (search-independent reference). A cell's novelty rate is new / (new + catalog-
//! matching); catalog_only = catalog - catalog-matching estimates catalog classes the
//! search has not reached yet (signatures fix the invariants, so a class and its
//! catalog signature fall in the same cell).

use crate::data::{Data, Field};
use rayon::prelude::*;
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::path::Path;

pub const PAIRS: [(Field, Field); 8] = [
    (Field::Two, Field::Three), (Field::Two, Field::Du), (Field::Three, Field::Du), (Field::Two, Field::C4),
    (Field::Three, Field::C4), (Field::Du, Field::C4), (Field::Two, Field::Four), (Field::Three, Field::Four),
];

pub const COLUMNS: [&str; 18] = ["x", "y", "classes", "catalog_matching", "new", "seeds", "unknown", "gen0", "gen1", "gen2",
    "found_sum", "singletons", "expanded", "reached_new_sum", "cosets_sum", "id_mean", "id_min", "catalog"];

#[derive(Default, Clone)]
struct Cell { n: u64, st: [u64; 4], g: [u64; 3], found: u64, single: u64, exp: u64, rnew: u64, cosets: f64, id_sum: f64, id_min: u64, catalog: u64 }

/// Catalog invariants (two, three, du, c4, c2, four) of the published catalog.
pub fn load_catalog(path: &Path) -> Vec<[i32; 6]> {
    let db = rusqlite::Connection::open_with_flags(path, rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY).expect("catalog");
    let mut st = db.prepare("SELECT two, three, du, c4, c2, four FROM catalog_features WHERE (error IS NULL OR error='') AND two IS NOT NULL").unwrap();
    st.query_map([], |r| Ok([r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?, r.get(5)?])).unwrap().map(|r| r.unwrap()).collect()
}

fn cat_field(c: &[i32; 6], f: Field) -> i32 {
    match f { Field::Two => c[0], Field::Three => c[1], Field::Du => c[2], Field::C4 => c[3], Field::C2 => c[4], Field::Four => c[5], _ => -1 }
}

pub fn run(d: &Data, catalog: Option<&[[i32; 6]]>) -> Value {
    let maps: Vec<(String, Value)> = PAIRS.par_iter().map(|&(fx, fy)| {
        let mut cells: BTreeMap<(i32, i32), Cell> = BTreeMap::new();
        for i in 0..d.n {
            let (Some(x), Some(y)) = (d.field(fx, i), d.field(fy, i)) else { continue };
            let c = cells.entry((x, y)).or_insert_with(|| Cell { id_min: u64::MAX, ..Default::default() });
            c.n += 1; c.st[d.status[i] as usize] += 1;
            if (d.generation[i] as usize) < 3 { c.g[d.generation[i] as usize] += 1; }
            c.found += d.found[i] as u64; c.single += (d.found[i] == 1) as u64;
            if d.expanded[i] > 0 { c.exp += 1; c.rnew += d.reached_new[i] as u64; c.cosets += d.cosets[i] as f64; }
            c.id_sum += (i + 1) as f64; c.id_min = c.id_min.min((i + 1) as u64);
        }
        if let Some(cat) = catalog {
            for r in cat {
                let (x, y) = (cat_field(r, fx), cat_field(r, fy));
                cells.entry((x, y)).or_insert_with(|| Cell { id_min: 0, ..Default::default() }).catalog += 1;
            }
        }
        let rows: Vec<Value> = cells.iter().map(|(&(x, y), c)| json!([x, y, c.n, c.st[0], c.st[1], c.st[2], c.st[3], c.g[0], c.g[1], c.g[2],
            c.found, c.single, c.exp, c.rnew, (c.cosets as u64), if c.n > 0 { (c.id_sum / c.n as f64).round() as u64 } else { 0 },
            if c.n > 0 { c.id_min } else { 0 }, c.catalog])).collect();
        (format!("{}|{}", fx.name(), fy.name()), json!({"x": fx.name(), "y": fy.name(), "cells": rows}))
    }).collect();
    let mut pairs = serde_json::Map::new();
    for (k, v) in maps { pairs.insert(k, v); }
    json!({"columns": COLUMNS, "classes": d.n, "catalog_rows": catalog.map_or(0, |c| c.len()), "pairs": pairs,
           "notes": "novelty = new / (new + catalog_matching); catalog_only = catalog - catalog_matching (reference minus reached); rediscoveries and singletons depend on how far the search has expanded around the cell (search coverage), not only on structure."})
}
