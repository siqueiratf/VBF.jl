//! apn-explorer: analyses of the class explorer data (see the module docs).
//!
//!   apn-explorer <command> --data DIR/<version> [--pairs pairs.u32] [--catalog catalog_features.sqlite]
//!                [--out DIR] [--limit N] [--threads T]
//!
//! commands: heatmaps, transitions, distributions, generations, communities, all, bench
//! Output: JSON files in --out (default DIR/analysis) and per-class community arrays.

mod data;
mod heatmap;
mod transitions;
mod distributions;
mod generations;

use data::Data;
use std::path::PathBuf;
use std::time::Instant;

pub struct Args { pub cmd: String, pub data: PathBuf, pub pairs: Option<PathBuf>, pub catalog: Option<PathBuf>, pub out: PathBuf, pub limit: Option<usize> }

fn args() -> Args {
    let mut it = std::env::args().skip(1);
    let cmd = it.next().unwrap_or_else(|| { eprintln!("usage: apn-explorer <command> --data DIR [--pairs F] [--catalog F] [--out DIR] [--limit N] [--threads T]"); std::process::exit(2) });
    let (mut data, mut pairs, mut catalog, mut out, mut limit, mut threads) = (None, None, None, None, None, None);
    while let Some(a) = it.next() {
        let v = it.next().unwrap_or_else(|| panic!("{a} needs a value"));
        match a.as_str() {
            "--data" => data = Some(PathBuf::from(v)), "--pairs" => pairs = Some(PathBuf::from(v)),
            "--catalog" => catalog = Some(PathBuf::from(v)), "--out" => out = Some(PathBuf::from(v)),
            "--limit" => limit = Some(v.parse().expect("limit")), "--threads" => threads = Some(v.parse::<usize>().expect("threads")),
            _ => panic!("unknown option {a}"),
        }
    }
    if let Some(t) = threads { rayon::ThreadPoolBuilder::new().num_threads(t).build_global().unwrap(); }
    let data = data.expect("--data");
    let out = out.unwrap_or_else(|| data.join("analysis"));
    Args { cmd, data, pairs, catalog, out, limit }
}

pub fn write_json(out: &PathBuf, name: &str, v: &serde_json::Value) {
    std::fs::create_dir_all(out).unwrap();
    let tmp = out.join(format!(".{name}.tmp"));
    std::fs::write(&tmp, serde_json::to_vec(v).unwrap()).unwrap();
    std::fs::rename(&tmp, out.join(name)).unwrap();
}

fn main() {
    let a = args();
    let t = Instant::now();
    let d = Data::load(&a.data, a.limit);
    eprintln!("loaded {} classes in {:.2}s", d.n, t.elapsed().as_secs_f64());
    let want = |c: &str| a.cmd == c || a.cmd == "all";
    if want("heatmaps") {
        let t = Instant::now();
        let cat = a.catalog.as_ref().map(|p| heatmap::load_catalog(p));
        let v = heatmap::run(&d, cat.as_deref());
        write_json(&a.out, "heatmaps.json", &v);
        eprintln!("heatmaps in {:.2}s, peak {:.0} MiB", t.elapsed().as_secs_f64(), data::peak_rss_mib());
    }
    let need_edges = want("transitions") || want("communities") || want("distributions") || want("generations");
    let mut path_pairs: Vec<(u32, u32)> = Vec::new();
    let edges = if need_edges {
        let t = Instant::now();
        let p = a.pairs.as_ref().expect("--pairs is needed");
        path_pairs = data::load_pairs(p, d.n);
        let e = transitions::distinct_edges(&path_pairs);
        eprintln!("{} distinct edges in {:.2}s, peak {:.0} MiB", e.len(), t.elapsed().as_secs_f64(), data::peak_rss_mib());
        e
    } else { Vec::new() };
    if want("transitions") {
        let t = Instant::now();
        let v = transitions::run(&d, &edges, 12);
        write_json(&a.out, "transitions.json", &v);
        eprintln!("transitions in {:.2}s, peak {:.0} MiB", t.elapsed().as_secs_f64(), data::peak_rss_mib());
    }
    let mut indegree: Vec<u32> = Vec::new();
    if want("distributions") || want("generations") {
        let t = Instant::now();
        let (v, ind) = distributions::run(&d, &edges, &path_pairs);
        if want("distributions") {
            write_json(&a.out, "distributions.json", &v);
            let bytes: Vec<u8> = ind.iter().flat_map(|x| x.to_le_bytes()).collect();
            std::fs::write(a.out.join("in_degree.u32"), bytes).unwrap();
        }
        indegree = ind;
        eprintln!("distributions in {:.2}s, peak {:.0} MiB", t.elapsed().as_secs_f64(), data::peak_rss_mib());
    }
    if want("generations") {
        let t = Instant::now();
        let v = generations::run(&d, &edges, &indegree);
        write_json(&a.out, "generations.json", &v);
        eprintln!("generations in {:.2}s, peak {:.0} MiB", t.elapsed().as_secs_f64(), data::peak_rss_mib());
    }
}
