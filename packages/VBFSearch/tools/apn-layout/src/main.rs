//! apn-layout: place each APN class by its invariants (see layout.rs) and
//! write a graph snapshot for the closure monitor.
//!
//! Export mode (CSR export of export_graph.py):
//!   apn-layout --export DIR --out RUN [--graph-dir DIR] [--version-tag V] [--fixed-time]
//!   writes RUN/graph/<version> (or --graph-dir DIR/<version>).
//! Snapshot mode (a closure_graph.jl snapshot and reports/features.sqlite):
//!   apn-layout --snapshot GRAPH/VERSION --features FILE --out DRAWING [--version-tag V] [--fixed-time]
//!   writes DRAWING/current.json and DRAWING/<version>. Edges, flags and node
//!   chunks are linked (or copied) from the snapshot; only positions change.
//!
//! --fixed-time takes all timestamps from the input and writes 0.0 for the
//! timings, so two runs give byte-identical files.

mod closure;
mod graph;
mod input;
mod layout;
mod snapshot;

use sha2::{Digest, Sha256};
use snapshot::{Node, Snapshot, J};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::{Instant, SystemTime, UNIX_EPOCH};

const SOURCES: [&[u8]; 6] = [
    include_bytes!("main.rs"),
    include_bytes!("layout.rs"),
    include_bytes!("input.rs"),
    include_bytes!("closure.rs"),
    include_bytes!("graph.rs"),
    include_bytes!("snapshot.rs"),
];
const SEMANTICS: &str = "Observed construction graph of quadratic APN CCZ/EA classes; incomplete coverage.";
const USAGE: &str = "apn-layout --export DIR --out RUN [--graph-dir DIR] [--version-tag V] [--fixed-time]\n\
apn-layout --snapshot GRAPH/VERSION --features FEATURES.sqlite --out DRAWING [--version-tag V] [--fixed-time]";

/// "2026-10-19T20:25:04.634Z" for a UNIX time in milliseconds.
fn utc(ms: u64) -> String {
    let (days, rest) = ((ms / 86_400_000) as i64, ms % 86_400_000);
    // Civil date from days since 1970-01-01 (H. Hinnant's algorithm).
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + (m <= 2) as i64;
    let s = rest / 1000;
    format!("{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}.{:03}Z", s / 3600, s / 60 % 60, s % 60, rest % 1000)
}

/// "20261019T202504" from a "2026-10-19T20:25:04..." timestamp.
fn stamp(utc: &str) -> String {
    let d: String = utc.chars().filter(char::is_ascii_digit).take(14).collect();
    format!("{}T{}", &d[..8], &d[8..])
}

fn now_ms() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_millis() as u64
}

fn builder_sha() -> String {
    let mut hasher = Sha256::new();
    SOURCES.iter().for_each(|s| hasher.update(s));
    hasher.finalize().iter().map(|b| format!("{b:02x}")).collect()
}

fn fail(message: String) -> ! {
    eprintln!("apn-layout: {message}");
    std::process::exit(1)
}

struct Options {
    export: Option<PathBuf>,
    snapshot: Option<PathBuf>,
    features: Option<PathBuf>,
    out: Option<PathBuf>,
    graph_dir: Option<PathBuf>,
    tag: Option<String>,
    fixed: bool,
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut o = Options { export: None, snapshot: None, features: None, out: None, graph_dir: None, tag: None, fixed: false };
    let mut i = 0;
    while i < args.len() {
        let value = || args.get(i + 1).cloned().unwrap_or_else(|| fail(format!("{} needs a value", args[i])));
        match args[i].as_str() {
            "--export" => o.export = Some(PathBuf::from(value())),
            "--snapshot" => o.snapshot = Some(PathBuf::from(value())),
            "--features" => o.features = Some(PathBuf::from(value())),
            "--out" => o.out = Some(PathBuf::from(value())),
            "--graph-dir" => o.graph_dir = Some(PathBuf::from(value())),
            "--version-tag" => o.tag = Some(value()),
            "--fixed-time" => {
                o.fixed = true;
                i += 1;
                continue;
            }
            "-h" | "--help" => {
                println!("{USAGE}");
                return;
            }
            other => fail(format!("unknown option {other}\n{USAGE}")),
        }
        i += 2;
    }
    let canonical = |p: &Path| p.canonicalize().unwrap_or_else(|e| fail(format!("{}: {e}", p.display())));
    match (&o.export, &o.snapshot) {
        (Some(e), None) => {
            let graph = o.graph_dir.clone().or(o.out.as_ref().map(|d| d.join("graph")));
            let graph = graph.unwrap_or_else(|| fail(format!("--out or --graph-dir is required\n{USAGE}")));
            run_export(&canonical(e), &graph, &o)
        }
        (None, Some(s)) => {
            let graph = o.graph_dir.clone().or(o.out.clone());
            let graph = graph.unwrap_or_else(|| fail(format!("--out is required\n{USAGE}")));
            let features = o.features.as_deref().unwrap_or_else(|| fail(format!("--features is required\n{USAGE}")));
            run_snapshot(&canonical(s), &canonical(features), &graph, &o)
        }
        _ => fail(format!("give exactly one of --export and --snapshot\n{USAGE}")),
    }
}

/// Positions: one call per vertex, nothing shared between vertices.
fn place(features: &[Option<(i64, i64)>], sha: &[[u8; 32]]) -> (Vec<[f32; 2]>, usize) {
    let mut clamped = 0usize;
    let positions = features
        .iter()
        .zip(sha)
        .map(|(f, s)| {
            let (p, c) = layout::position(*f, s);
            clamped += c as usize;
            p
        })
        .collect();
    (positions, clamped)
}

fn run_snapshot(source: &Path, features_db: &Path, graph: &Path, o: &Options) {
    let started = Instant::now();
    let snap = closure::read(source).unwrap_or_else(|e| fail(e));
    let features = closure::features(features_db, &snap.sha).unwrap_or_else(|e| fail(e));
    let read_seconds = started.elapsed().as_secs_f64();
    let (positions, clamped) = place(&features, &snap.sha);
    let m = &snap.manifest;
    let text = |k: &str| m.get(k).and_then(|v| v.as_str()).unwrap_or("").to_string();
    let source_version = text("version");
    let suffix = source_version.split_once('-').map(|x| x.1).unwrap_or("0-0").to_string();
    let version = o.tag.clone().unwrap_or_else(|| {
        let when = if o.fixed { stamp(&source_version) } else { stamp(&utc(now_ms())) };
        format!("{when}-{suffix}")
    });
    let built = if o.fixed { text("built_utc") } else { utc(now_ms()) };
    let time = |s: f64| J::Float(if o.fixed { 0.0 } else { s });
    let layout_seconds = started.elapsed().as_secs_f64() - read_seconds;
    let measured = features.iter().filter(|f| f.is_some()).count();
    // Same keys and order as the source manifest; drawing fields replaced, extras appended.
    let mut manifest: Vec<(String, J)> = Vec::new();
    for (k, v) in m {
        let value = match k.as_str() {
            "version" => J::Str(version.clone()),
            "built_utc" => J::Str(built.clone()),
            "builder_sha256" => J::Str(builder_sha()),
            "layout" => J::Str(layout::RULE.into()),
            "layout_seconds" => time(layout_seconds),
            "sql_seconds" => time(read_seconds),
            _ => J::Raw(v.to_string()),
        };
        manifest.push((k.clone(), value));
    }
    manifest.push(("source_version".into(), J::Str(source_version.clone())));
    manifest.push(("source_builder_sha256".into(), J::Str(text("builder_sha256"))));
    manifest.push(("features_measured".into(), J::Int(measured as i64)));
    let chunks = snap.chunks;
    let stage = |dir: &Path| -> Result<u64, String> {
        let mut bytes = snapshot::write_positions(dir, &positions)?;
        for name in ["edges.bin", "flags.bin"] {
            bytes += snapshot::link(&source.join(name), &dir.join(name))?;
        }
        for k in 0..chunks {
            let name = format!("nodes-{k}.json");
            snapshot::link(&source.join(&name), &dir.join(&name))?;
        }
        Ok(bytes)
    };
    let total = started.elapsed().as_secs_f64();
    let out = snapshot::publish(graph, &version, &manifest, stage, if o.fixed { 0.0 } else { total })
        .unwrap_or_else(|e| fail(e));
    println!("{out}");
    report(&features, clamped, started);
}

fn run_export(export: &Path, graph: &Path, o: &Options) {
    let started = Instant::now();
    let x = input::read(export).unwrap_or_else(|e| fail(e));
    let read_seconds = started.elapsed().as_secs_f64();
    let n = x.n;
    let prov = &x.manifest["provenance"]["snapshot_manifest"];
    let num = |v: &serde_json::Value, default: i64| v.as_i64().unwrap_or(default);
    let created = x.manifest["created_utc"].as_str().unwrap_or("1970-01-01T00:00:00Z").to_string();
    let completed = num(&prov["completed_parents"], 0);
    let (positions, clamped) = place(&x.features, &x.sha);

    // Edges in CSR order, which is closure_graph.jl's sorted (parent, child) order.
    let mut edges = Vec::with_capacity(2 * x.targets.len() + 2048);
    let (mut v5, mut switching) = (0i64, 0i64);
    for u in 0..n {
        for k in x.offsets[u] as usize..x.offsets[u + 1] as usize {
            let (t, m) = (x.targets[k], x.methods[k]);
            let both = if m == 3 { 0x4000_0000 } else { 0 };
            if m & 1 != 0 {
                edges.extend([u as u32, t | both]);
                v5 += 1;
            }
            if m & 2 != 0 {
                edges.extend([u as u32, t | both | 0x8000_0000]);
                switching += 1;
            }
        }
    }
    let (component, sizes) = graph::weak_components(n, &x.offsets, &x.targets);
    let strong = graph::largest_strong_component(n, &x.offsets, &x.targets);
    let mut incoming = vec![0u32; n];
    for &t in &x.targets {
        incoming[t as usize] += 1;
    }
    let nodes: Vec<Node> = (0..n)
        .map(|v| Node {
            is_seed: x.is_seed[v],
            source: x.source[v].clone(),
            sha: x.sha[v],
            incoming: incoming[v],
            outgoing: (x.offsets[v + 1] - x.offsets[v]) as u32,
            component: component[v],
            v5_returns: x.v5_returns[v],
            switching_returns: x.switching_returns[v],
            class_id: x.class_id[v],
        })
        .collect();

    let pairs = x.targets.len() as i64;
    let full = num(&prov["nodes"], -1) == n as i64 && num(&prov["directed_pairs"], -1) == pairs;
    let version = o.tag.clone().unwrap_or_else(|| format!("{}-{completed}-{n}", stamp(&created)));
    let built = if o.fixed { created.replace('Z', ".000Z") } else { utc(now_ms()) };
    let layout_seconds = started.elapsed().as_secs_f64() - read_seconds;
    let time = |s: f64| J::Float(if o.fixed { 0.0 } else { s });
    let manifest: Vec<(String, J)> = vec![
        ("sql_seconds", time(read_seconds)),
        ("largest_component", J::Int(sizes[0] as i64)),
        ("builder_sha256", J::Str(builder_sha())),
        ("pending_observations", J::Int(num(&prov["pending_observations"], 0))),
        ("layout_seconds", time(layout_seconds)),
        ("run", J::Str(export.display().to_string())),
        ("switching_edges", J::Int(switching)),
        ("version", J::Str(version.clone())),
        ("components", J::Int(sizes.len() as i64)),
        ("seeds", J::Int(x.is_seed.iter().filter(|&&s| s).count() as i64)),
        ("observations", J::Int(if full { num(&prov["observations"], pairs) } else { pairs })),
        ("nodes", J::Int(n as i64)),
        ("built_utc", J::Str(built)),
        ("metadata_chunk_size", J::Int(snapshot::CHUNK as i64)),
        ("largest_strong_component", J::Int(strong as i64)),
        ("completed_parents", J::Int(completed)),
        ("layout", J::Str(layout::RULE.into())),
        ("v5_edges", J::Int(v5)),
        ("semantics", J::Str(SEMANTICS.into())),
        ("signature_collision_buckets", J::Int(num(&prov["signature_collision_buckets"], 0))),
        ("directed_pairs", J::Int(pairs)),
        ("minimum_refresh_seconds", J::Int(num(&prov["minimum_refresh_seconds"], 600))),
        ("snapshot_utc", J::Str(prov["snapshot_utc"].as_str().unwrap_or(&created).to_string())),
        ("refresh_every_completions", J::Int(num(&prov["refresh_every_completions"], 500))),
        ("schema", J::Str(snapshot::SCHEMA.into())),
    ]
    .into_iter()
    .map(|(k, v)| (k.to_string(), v))
    .collect();
    let flags = x.is_seed.iter().map(|&s| s as u8).collect();
    let snap = Snapshot { positions, edges, flags, nodes };
    let total = started.elapsed().as_secs_f64();
    let text = snapshot::publish(graph, &version, &manifest, |d| snap.stage(d), if o.fixed { 0.0 } else { total })
        .unwrap_or_else(|e| fail(e));
    println!("{text}");
    report(&x.features, clamped, started);
}

/// Layout report on stderr: how crowded the cells are.
fn report(features: &[Option<(i64, i64)>], clamped: usize, started: Instant) {
    let mut cells: HashMap<(i64, i64), usize> = HashMap::new();
    for f in features.iter().flatten() {
        *cells.entry(*f).or_default() += 1;
    }
    let densest = cells.iter().max_by_key(|(k, v)| (**v, std::cmp::Reverse(**k)));
    let unmeasured = features.iter().filter(|f| f.is_none()).count();
    let odd = features.iter().flatten().filter(|f| f.0 % 2 != 0).count();
    let (lo2, hi2) = features.iter().flatten().fold((i64::MAX, i64::MIN), |a, f| (a.0.min(f.0), a.1.max(f.0)));
    let (lo3, hi3) = features.iter().flatten().fold((i64::MAX, i64::MIN), |a, f| (a.0.min(f.1), a.1.max(f.1)));
    eprintln!(
        "apn-layout: {} vertices, {} cells, densest {:?}, two {lo2}..{hi2}, three {lo3}..{hi3}, \
odd two {odd}, unmeasured {unmeasured}, clamped {clamped}, {:.1} s",
        features.len(),
        cells.len(),
        densest,
        started.elapsed().as_secs_f64()
    );
}

#[cfg(test)]
mod tests {
    #[test]
    fn utc_format() {
        assert_eq!(super::utc(0), "1970-01-01T00:00:00.000Z");
        assert_eq!(super::utc(1_760_905_504_634), "2025-10-19T20:25:04.634Z");
        assert_eq!(super::stamp("2026-10-19T20:24:33.5Z"), "20261019T202433");
    }
}
