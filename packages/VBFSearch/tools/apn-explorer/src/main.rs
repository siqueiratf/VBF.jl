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
mod graph;
mod community;
mod condensed;

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
    if want("communities") {
        let t = Instant::now();
        let g = graph::Graph::from_edges(d.n, &edges);
        eprintln!("graph: {} nodes, {} edges, 2m = {} in {:.2}s, peak {:.0} MiB", g.n, g.edges(), g.m2, t.elapsed().as_secs_f64(), data::peak_rss_mib());
        let gamma = std::env::var("APN_GAMMA").ok().and_then(|v| v.parse().ok()).unwrap_or(1.0);
        let labels = |f: &dyn Fn(usize) -> Option<u32>| -> Vec<Option<u32>> { (0..d.n).map(|i| f(i)).collect() };
        let refs: Vec<(&str, Vec<Option<u32>>)> = vec![
            ("seed lineage", labels(&|i| (d.root[i] > 0).then_some(d.root[i]))),
            ("seed lineage group (24)", labels(&|i| Some(d.family[i] as u32))),
            ("generation", labels(&|i| (d.generation[i] != data::UNKNOWN_GEN).then_some(d.generation[i] as u32))),
            ("status", labels(&|i| (d.status[i] < 3).then_some(d.status[i] as u32))),
            ("c4", labels(&|i| d.measured(i).then_some(d.inv[i][1] as u32))),
            ("two band (10)", labels(&|i| d.measured(i).then_some(d.two[i] as u32 / 10))),
            ("three band (5)", labels(&|i| d.measured(i).then_some(d.three[i] as u32 / 5))),
            ("du", labels(&|i| d.measured(i).then_some(d.inv[i][0] as u32))),
            ("admission decile", labels(&|i| Some((10 * i / d.n) as u32)))];
        let mut summary = serde_json::Map::new();
        let mut leiden_comm = Vec::new();
        for (name, res) in [("louvain", community::louvain(&g, gamma, 7)), ("leiden", community::leiden(&g, gamma, 7))] {
            // Rank communities by size: 0 = largest.
            let k = *res.comm.iter().max().unwrap() as usize + 1;
            let mut size = vec![0u64; k]; for &c in &res.comm { size[c as usize] += 1; }
            let mut order: Vec<usize> = (0..k).collect(); order.sort_by_key(|&c| (std::cmp::Reverse(size[c]), c));
            let mut rank = vec![0u32; k]; for (r, &c) in order.iter().enumerate() { rank[c] = r as u32; }
            let comm: Vec<u32> = res.comm.iter().map(|&c| rank[c as usize]).collect();
            let q = community::modularity(&g, &comm, gamma);
            let (bad, stray) = community::disconnected(&g, &comm);
            let mut sizes: Vec<u64> = order.iter().map(|&c| size[c]).collect();
            let nmis: serde_json::Map<String, serde_json::Value> = refs.iter().map(|(l, v)| (l.to_string(), serde_json::json!(community::nmi(&comm, v)))).collect();
            let singletons = sizes.iter().filter(|&&s| s == 1).count();
            sizes.truncate(50);
            eprintln!("{name}: {k} communities, Q = {q:.4}, {bad} disconnected ({stray} stray nodes), {:.1}s, levels {}", res.seconds, res.levels);
            summary.insert(name.into(), serde_json::json!({"communities": k, "modularity": q, "gamma": gamma, "levels": res.levels, "seconds": res.seconds,
                "disconnected_communities": bad, "nodes_outside_main_component": stray, "singleton_communities": singletons,
                "largest_sizes": sizes, "nmi_with": nmis}));
            let bytes: Vec<u8> = comm.iter().flat_map(|x| x.to_le_bytes()).collect();
            std::fs::create_dir_all(&a.out).unwrap();
            std::fs::write(a.out.join(format!("community_{name}.u32")), bytes).unwrap();
            if name == "leiden" { leiden_comm = comm; }
        }
        // Null model: degree-preserving random graph (configuration model, stubs paired at
        // random, self loops and repeats dropped), partitioned the same way. Modularity of a
        // real community structure must clearly exceed it.
        let conductance_low = |g: &graph::Graph, comm: &[u32]| -> usize {
            let k = *comm.iter().max().unwrap() as usize + 1; let mut vol = vec![0f64; k]; let mut inside = vec![0f64; k];
            for i in 0..g.n { vol[comm[i] as usize] += g.k[i]; let (nb, ww) = g.adj(i);
                for (&j, &w) in nb.iter().zip(ww) { if comm[j as usize] == comm[i] { inside[comm[i] as usize] += w as f64; } } }
            (0..k).filter(|&c| vol[c] > 0.0 && (vol[c] - inside[c]) / vol[c].min(g.m2 - vol[c]).max(1e-9) < 0.1).count()
        };
        if std::env::var("APN_NULL").map_or(true, |v| v != "0") {
            let t3 = Instant::now();
            let mut stubs: Vec<u32> = Vec::with_capacity(2 * g.edges());
            for i in 0..g.n { let (nb, _) = g.adj(i); for &j in nb { if (j as usize) > i { stubs.push(i as u32); stubs.push(j); } } }
            let mut rng = community::Rng::new(99); rng.shuffle(&mut stubs);
            let null_edges: Vec<(u32, u32)> = stubs.chunks_exact(2).filter(|p| p[0] != p[1]).map(|p| (p[0].min(p[1]), p[0].max(p[1]))).collect();
            let mut ne = null_edges; ne.sort_unstable(); ne.dedup();
            let gn = graph::Graph::from_edges(d.n, &ne);
            let r = community::leiden(&gn, gamma, 7);
            let q = community::modularity(&gn, &r.comm, gamma);
            let k = *r.comm.iter().max().unwrap() as usize + 1;
            eprintln!("null model: {k} communities, Q = {q:.4}, {:.1}s", t3.elapsed().as_secs_f64());
            summary.insert("null_configuration_model".into(), serde_json::json!({"communities": k, "modularity": q, "edges": gn.edges(),
                "well_separated_communities": conductance_low(&gn, &r.comm), "seconds": t3.elapsed().as_secs_f64(),
                "note": "same degree sequence, unweighted, random pairing; Leiden with the same settings"}));
        }
        if let Some(serde_json::Value::Object(o)) = summary.get_mut("leiden") { o.insert("well_separated_communities".into(), serde_json::json!(conductance_low(&g, &leiden_comm))); }
        let t2 = Instant::now();
        let cg = condensed::run(&d, &g, &leiden_comm, 300);
        eprintln!("condensed graph in {:.2}s", t2.elapsed().as_secs_f64());
        let v = serde_json::json!({"classes": d.n, "graph": {"nodes": g.n, "edges": g.edges(), "total_weight": g.m2 / 2.0,
            "weights": "1 per construction direction; 2 if a pair was found both ways"}, "algorithms": summary, "condensed_leiden": cg,
            "notes": "NMI with seed lineage, generation or admission decile measures how far communities follow the search (lineages, time); NMI with c4, two, three or du measures how far they follow the invariants (structure)."});
        write_json(&a.out, "communities.json", &v);
        eprintln!("communities in {:.2}s, peak {:.0} MiB", t.elapsed().as_secs_f64(), data::peak_rss_mib());
    }
}
