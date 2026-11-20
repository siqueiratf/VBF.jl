//! Write a graph snapshot in the format of docs/inspector/closure_graph.jl:
//! <graph>/current.json and <graph>/<version>/{positions,edges,flags}.bin,
//! nodes-<k>.json, manifest.json. Key order follows the files that
//! closure_graph.jl writes, so the JSON is byte-compatible.

use std::fmt::Write as _;
use std::io::Write as _;
use std::path::Path;

pub const SCHEMA: &str = "vbfsearch-class-graph-v1";
pub const CHUNK: usize = 2048;
const KEEP_SNAPSHOTS: usize = 3;

pub enum J {
    Bool(bool),
    Int(i64),
    Float(f64),
    Str(String),
}

pub struct Node {
    pub is_seed: bool,
    pub source: String,
    pub sha: [u8; 32],
    pub incoming: u32,
    pub outgoing: u32,
    pub component: u32,
    pub v5_returns: u32,
    pub switching_returns: u32,
    /// Original class id, written only when it differs from the index + 1.
    pub class_id: u32,
}

pub struct Snapshot {
    pub version: String,
    pub positions: Vec<[f32; 2]>,
    /// Pairs (source, target | bit 30 both methods | bit 31 switching).
    pub edges: Vec<u32>,
    pub flags: Vec<u8>,
    pub nodes: Vec<Node>,
    /// manifest.json fields in closure_graph.jl's order.
    pub manifest: Vec<(&'static str, J)>,
}

/// Version names that the monitor accepts: ^\d{8}T\d{6}-\d+-\d+$
pub fn valid_version(v: &str) -> bool {
    let b = v.as_bytes();
    let digits = |s: &[u8]| !s.is_empty() && s.iter().all(u8::is_ascii_digit);
    if b.len() < 19 || !digits(&b[..8]) || b[8] != b'T' || !digits(&b[9..15]) || b[15] != b'-' {
        return false;
    }
    let rest: Vec<&str> = v[16..].split('-').collect();
    rest.len() == 2 && rest.iter().all(|s| digits(s.as_bytes()))
}

pub fn escape(out: &mut String, s: &str) {
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            '\u{8}' => out.push_str("\\b"),
            '\u{c}' => out.push_str("\\f"),
            c if (c as u32) < 0x20 => write!(out, "\\u{:04x}", c as u32).unwrap(),
            c => out.push(c),
        }
    }
    out.push('"');
}

pub fn object(fields: &[(&str, J)]) -> String {
    let mut s = String::from("{");
    for (i, (k, v)) in fields.iter().enumerate() {
        if i > 0 {
            s.push(',');
        }
        escape(&mut s, k);
        s.push(':');
        match v {
            J::Bool(x) => write!(s, "{x}").unwrap(),
            J::Int(x) => write!(s, "{x}").unwrap(),
            J::Float(x) => write!(s, "{x:?}").unwrap(),
            J::Str(x) => escape(&mut s, x),
        }
    }
    s.push('}');
    s
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().fold(String::with_capacity(64), |mut s, b| {
        write!(s, "{b:02x}").unwrap();
        s
    })
}

fn node_chunk(nodes: &[Node], first: usize, with_class_id: bool) -> String {
    let mut s = String::with_capacity(nodes.len() * 260);
    s.push('[');
    for (j, p) in nodes.iter().enumerate() {
        if j > 0 {
            s.push(',');
        }
        let mut f = vec![
            ("is_seed", J::Bool(p.is_seed)),
            ("source", J::Str(p.source.clone())),
            ("id", J::Int((first + j + 1) as i64)),
            ("component", J::Int(p.component as i64)),
            ("switching_returns", J::Int(p.switching_returns as i64)),
            ("outgoing", J::Int(p.outgoing as i64)),
            ("sha256", J::Str(hex(&p.sha))),
            ("incoming", J::Int(p.incoming as i64)),
            ("v5_returns", J::Int(p.v5_returns as i64)),
        ];
        if with_class_id {
            f.push(("class_id", J::Int(p.class_id as i64)));
        }
        s.push_str(&object(&f));
    }
    s.push(']');
    s
}

fn write_file(path: &Path, bytes: &[u8]) -> Result<(), String> {
    let mut f = std::io::BufWriter::new(std::fs::File::create(path).map_err(|e| format!("{}: {e}", path.display()))?);
    f.write_all(bytes).and_then(|_| f.flush()).map_err(|e| format!("{}: {e}", path.display()))
}

fn atomic(path: &Path, bytes: &[u8]) -> Result<(), String> {
    let tmp = path.with_extension("json.tmp");
    write_file(&tmp, bytes)?;
    std::fs::rename(&tmp, path).map_err(|e| e.to_string())
}

fn le<T: Copy, const W: usize>(values: &[T], f: fn(T) -> [u8; W]) -> Vec<u8> {
    values.iter().flat_map(|&v| f(v)).collect()
}

/// Stage, publish atomically, update current.json, keep the newest 3 snapshots.
/// current.json adds payload_bytes and compute_seconds at closure_graph.jl's positions.
pub fn write(graph: &Path, s: &Snapshot, compute_seconds: f64) -> Result<String, String> {
    if !valid_version(&s.version) {
        return Err(format!("version {} does not match ^\\d{{8}}T\\d{{6}}-\\d+-\\d+$", s.version));
    }
    let n = s.nodes.len();
    if s.positions.len() != n || s.flags.len() != n || s.edges.len() % 2 != 0 {
        return Err("snapshot arrays have different lengths".into());
    }
    std::fs::create_dir_all(graph).map_err(|e| e.to_string())?;
    let final_dir = graph.join(&s.version);
    if final_dir.exists() {
        return Err(format!("{} exists; choose another --version-tag", final_dir.display()));
    }
    let staging = graph.join(format!(".building-{}", s.version));
    if staging.exists() {
        std::fs::remove_dir_all(&staging).map_err(|e| e.to_string())?;
    }
    std::fs::create_dir_all(&staging).map_err(|e| e.to_string())?;
    let flat: Vec<f32> = s.positions.iter().flatten().copied().collect();
    let payload = [
        ("positions.bin", le(&flat, f32::to_le_bytes)),
        ("edges.bin", le(&s.edges, u32::to_le_bytes)),
        ("flags.bin", s.flags.clone()),
    ];
    for (name, bytes) in &payload {
        write_file(&staging.join(name), bytes)?;
    }
    let with_class_id = s.nodes.iter().enumerate().any(|(i, p)| p.class_id as usize != i + 1);
    for (k, chunk) in s.nodes.chunks(CHUNK).enumerate() {
        atomic(&staging.join(format!("nodes-{k}.json")), node_chunk(chunk, k * CHUNK, with_class_id).as_bytes())?;
    }
    atomic(&staging.join("manifest.json"), object(&s.manifest).as_bytes())?;
    std::fs::rename(&staging, &final_dir).map_err(|e| e.to_string())?;

    let payload_bytes: usize = payload.iter().map(|p| p.1.len()).sum();
    let mut current: Vec<(&str, J)> = Vec::new();
    for (k, v) in &s.manifest {
        let copy = match v {
            J::Bool(x) => J::Bool(*x),
            J::Int(x) => J::Int(*x),
            J::Float(x) => J::Float(*x),
            J::Str(x) => J::Str(x.clone()),
        };
        current.push((k, copy));
        match *k {
            "sql_seconds" => current.push(("payload_bytes", J::Int(payload_bytes as i64))),
            "switching_edges" => current.push(("compute_seconds", J::Float(compute_seconds))),
            _ => {}
        }
    }
    let text = object(&current);
    atomic(&graph.join("current.json"), text.as_bytes())?;

    let mut versions: Vec<String> = std::fs::read_dir(graph)
        .map_err(|e| e.to_string())?
        .filter_map(|e| e.ok())
        .filter(|e| e.path().is_dir())
        .filter_map(|e| e.file_name().into_string().ok())
        .filter(|name| valid_version(name))
        .collect();
    versions.sort();
    for old in &versions[..versions.len().saturating_sub(KEEP_SNAPSHOTS)] {
        std::fs::remove_dir_all(graph.join(old)).map_err(|e| e.to_string())?;
    }
    Ok(text)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_regex() {
        assert!(valid_version("20261019T202433-77232-16091896"));
        assert!(!valid_version("20261019T202433-77232"));
        assert!(!valid_version("2026101T202433-1-2"));
        assert!(!valid_version("20261019T202433-1-2-3"));
        assert!(!valid_version("20261019T202433-1-x"));
    }

    #[test]
    fn round_trip() {
        let dir = std::env::temp_dir().join(format!("apn-layout-test-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        let node = |i: u32, seed| Node {
            is_seed: seed,
            source: format!("src\"{i}"),
            sha: [i as u8; 32],
            incoming: i,
            outgoing: 2 * i,
            component: 1,
            v5_returns: 3,
            switching_returns: 0,
            class_id: i + 1,
        };
        let nodes: Vec<Node> = (0..2050).map(|i| node(i, i == 0)).collect();
        let snap = Snapshot {
            version: "20260101T000000-5-2050".into(),
            positions: (0..2050).map(|i| [i as f32 / 2050.0, -0.5]).collect(),
            edges: vec![0, 1 | 0x4000_0000, 0, 1 | 0xC000_0000, 1, 2],
            flags: (0..2050).map(|i| (i == 0) as u8).collect(),
            nodes,
            manifest: vec![
                ("sql_seconds", J::Float(0.0)),
                ("switching_edges", J::Int(1)),
                ("version", J::Str("20260101T000000-5-2050".into())),
                ("nodes", J::Int(2050)),
                ("schema", J::Str(SCHEMA.into())),
            ],
        };
        let text = write(&dir, &snap, 1.5).unwrap();
        let cur: serde_json::Value = serde_json::from_slice(&std::fs::read(dir.join("current.json")).unwrap()).unwrap();
        assert_eq!(text, std::fs::read_to_string(dir.join("current.json")).unwrap());
        assert_eq!(cur["payload_bytes"], 2050 * 8 + 24 + 2050);
        assert_eq!(cur["compute_seconds"], 1.5);
        assert!(text.starts_with("{\"sql_seconds\":0.0,\"payload_bytes\":"));
        let v = dir.join("20260101T000000-5-2050");
        let pos = std::fs::read(v.join("positions.bin")).unwrap();
        let back: Vec<f32> = pos.chunks_exact(4).map(|c| f32::from_le_bytes(c.try_into().unwrap())).collect();
        assert_eq!(back.len(), 4100);
        assert_eq!(back[2 * 1025], 1025.0 / 2050.0);
        assert_eq!(back[2 * 1025 + 1], -0.5);
        let e = std::fs::read(v.join("edges.bin")).unwrap();
        let e: Vec<u32> = e.chunks_exact(4).map(|c| u32::from_le_bytes(c.try_into().unwrap())).collect();
        assert_eq!(e, snap.edges);
        assert_eq!(std::fs::read(v.join("flags.bin")).unwrap(), snap.flags);
        let c1: serde_json::Value = serde_json::from_slice(&std::fs::read(v.join("nodes-1.json")).unwrap()).unwrap();
        assert_eq!(c1.as_array().unwrap().len(), 2);
        assert_eq!(c1[0]["id"], 2049);
        assert_eq!(c1[0]["source"], "src\"2048");
        assert_eq!(c1[0]["is_seed"], false);
        assert!(c1[0].get("class_id").is_none());
        let c0 = std::fs::read_to_string(v.join("nodes-0.json")).unwrap();
        assert!(c0.starts_with("[{\"is_seed\":true,\"source\":\"src\\\"0\",\"id\":1,\"component\":1,"));
        let m: serde_json::Value = serde_json::from_slice(&std::fs::read(v.join("manifest.json")).unwrap()).unwrap();
        assert!(m.get("payload_bytes").is_none());
        std::fs::remove_dir_all(&dir).unwrap();
    }
}
