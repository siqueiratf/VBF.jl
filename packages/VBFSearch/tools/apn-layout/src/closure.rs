//! Snapshot mode: read a closure_graph.jl snapshot directory and the
//! (two, three) features of its classes from reports/features.sqlite.

use crate::input::Result;
use serde::Deserialize;
use std::path::Path;

pub struct ClosureSnapshot {
    /// manifest.json of the snapshot, key order kept.
    pub manifest: serde_json::Map<String, serde_json::Value>,
    pub sha: Vec<[u8; 32]>,
    pub chunks: usize,
}

#[derive(Deserialize)]
struct NodeSha {
    sha256: String,
}

pub fn unhex(s: &str) -> Option<[u8; 32]> {
    let b = s.as_bytes();
    if b.len() != 64 {
        return None;
    }
    let digit = |c: u8| (c as char).to_digit(16).map(|d| d as u8);
    let mut out = [0u8; 32];
    for i in 0..32 {
        out[i] = digit(b[2 * i])? << 4 | digit(b[2 * i + 1])?;
    }
    Some(out)
}

pub fn read(dir: &Path) -> Result<ClosureSnapshot> {
    let text = std::fs::read(dir.join("manifest.json")).map_err(|e| format!("{}/manifest.json: {e}", dir.display()))?;
    let manifest: serde_json::Map<String, serde_json::Value> =
        serde_json::from_slice(&text).map_err(|e| format!("manifest.json: {e}"))?;
    if manifest.get("schema").and_then(|v| v.as_str()) != Some(crate::snapshot::SCHEMA) {
        return Err("manifest.json: not a vbfsearch-class-graph-v1 snapshot".into());
    }
    let n = manifest.get("nodes").and_then(|v| v.as_u64()).ok_or("manifest.json: no nodes")? as usize;
    let chunk = manifest.get("metadata_chunk_size").and_then(|v| v.as_u64()).ok_or("manifest.json: no chunk size")? as usize;
    if chunk == 0 {
        return Err("manifest.json: chunk size 0".into());
    }
    let chunks = n.div_ceil(chunk);
    let mut sha = Vec::with_capacity(n);
    for k in 0..chunks {
        let path = dir.join(format!("nodes-{k}.json"));
        let bytes = std::fs::read(&path).map_err(|e| format!("{}: {e}", path.display()))?;
        let rows: Vec<NodeSha> = serde_json::from_slice(&bytes).map_err(|e| format!("{}: {e}", path.display()))?;
        if rows.len() != chunk.min(n - k * chunk) {
            return Err(format!("{}: {} rows, expected {}", path.display(), rows.len(), chunk.min(n - k * chunk)));
        }
        for r in rows {
            sha.push(unhex(&r.sha256).ok_or(format!("{}: bad sha256 {}", path.display(), r.sha256))?);
        }
    }
    for (name, size) in [("flags.bin", n as u64), ("positions.bin", 8 * n as u64)] {
        let got = std::fs::metadata(dir.join(name)).map_err(|e| format!("{name}: {e}"))?.len();
        if got != size {
            return Err(format!("{name}: {got} bytes, expected {size}"));
        }
    }
    Ok(ClosureSnapshot { manifest, sha, chunks })
}

/// (two, three) per vertex from features(sha TEXT, ..., two, three) keyed by
/// the lowercase hex LUT SHA-256. One ordered scan merged with the sorted
/// vertex list; None when the class is absent or a value is NULL.
pub fn features(path: &Path, sha: &[[u8; 32]]) -> Result<Vec<Option<(i64, i64)>>> {
    use rusqlite::{Connection, OpenFlags};
    let db = Connection::open_with_flags(path, OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX)
        .map_err(|e| format!("{}: {e}", path.display()))?;
    let mut order: Vec<u32> = (0..sha.len() as u32).collect();
    order.sort_by_key(|&v| sha[v as usize]);
    let mut out = vec![None; sha.len()];
    let mut stmt = db
        .prepare("SELECT sha, two, three FROM features ORDER BY sha")
        .map_err(|e| format!("features.sqlite: {e}"))?;
    let mut rows = stmt.query([]).map_err(|e| e.to_string())?;
    let mut i = 0;
    while let Some(row) = rows.next().map_err(|e| e.to_string())? {
        if i == order.len() {
            break;
        }
        let key: String = row.get(0).map_err(|e| e.to_string())?;
        let Some(key) = unhex(&key.to_ascii_lowercase()) else { continue };
        while i < order.len() && sha[order[i] as usize] < key {
            i += 1;
        }
        while i < order.len() && sha[order[i] as usize] == key {
            let two: Option<i64> = row.get(1).map_err(|e| e.to_string())?;
            let three: Option<i64> = row.get(2).map_err(|e| e.to_string())?;
            out[order[i] as usize] = two.zip(three);
            i += 1;
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn features_merge() {
        let dir = std::env::temp_dir().join(format!("apn-layout-features-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("features.sqlite");
        let db = rusqlite::Connection::open(&path).unwrap();
        db.execute_batch("CREATE TABLE features(sha TEXT PRIMARY KEY,two INTEGER,three INTEGER) WITHOUT ROWID").unwrap();
        let s = |b: u8| [b; 32];
        let hex = |x: [u8; 32]| x.iter().map(|b| format!("{b:02x}")).collect::<String>();
        for (b, two, three) in [(1u8, Some(380), Some(29)), (3, Some(384), None), (9, Some(200), Some(5)), (0xab, Some(400), Some(40))] {
            db.execute("INSERT INTO features VALUES(?1,?2,?3)", rusqlite::params![hex(s(b)), two, three]).unwrap();
        }
        drop(db);
        // Vertex order differs from sha order; 2 is absent; 3 has a NULL.
        let got = features(&path, &[s(9), s(2), s(1), s(3), s(0xab)]).unwrap();
        assert_eq!(got, vec![Some((200, 5)), None, Some((380, 29)), None, Some((400, 40))]);
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn reads_a_written_snapshot() {
        use crate::snapshot::{publish, Node, Snapshot, J, SCHEMA};
        let dir = std::env::temp_dir().join(format!("apn-layout-closure-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        let n = 3000u32;
        let nodes = (0..n)
            .map(|i| Node {
                is_seed: i < 2,
                source: String::new(),
                sha: [(i % 251) as u8; 32],
                incoming: 0,
                outgoing: 0,
                component: 1,
                v5_returns: 0,
                switching_returns: 0,
                class_id: i + 1,
            })
            .collect();
        let snap = Snapshot { positions: vec![[0.0; 2]; n as usize], edges: vec![0, 1], flags: vec![0; n as usize], nodes };
        let manifest: Vec<(String, J)> = [
            ("version", J::Str("20260101T000000-1-2".into())),
            ("nodes", J::Int(n as i64)),
            ("metadata_chunk_size", J::Int(2048)),
            ("schema", J::Str(SCHEMA.into())),
        ]
        .into_iter()
        .map(|(k, v)| (k.to_string(), v))
        .collect();
        publish(&dir, "20260101T000000-1-2", &manifest, |d| snap.stage(d), 0.0).unwrap();
        let back = read(&dir.join("20260101T000000-1-2")).unwrap();
        assert_eq!(back.chunks, 2);
        assert_eq!(back.sha.len(), n as usize);
        assert_eq!(back.sha[2999], [(2999 % 251) as u8; 32]);
        let keys: Vec<&String> = back.manifest.keys().collect();
        assert_eq!(keys, ["version", "nodes", "metadata_chunk_size", "schema"]);
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn hex_decoding() {
        assert_eq!(unhex(&"0f".repeat(32)), Some([15u8; 32]));
        assert_eq!(unhex("0f"), None);
        assert_eq!(unhex(&"zz".repeat(32)), None);
    }
}
