//! Explorer arrays (tools/analysis/explorer_data.py): one value per class,
//! index i = class id - 1, admission order. `limit` keeps the first N classes,
//! for benchmarks on subsets; pairs with an endpoint beyond N are dropped.

use std::fs;
use std::path::{Path, PathBuf};

pub const UNKNOWN_GEN: u16 = 65535;

pub struct Data {
    pub n: usize,
    pub two: Vec<i16>,
    pub three: Vec<i16>,
    /// du, c4, c2, four (255 = not measured)
    pub inv: Vec<[u8; 4]>,
    /// 0 catalog-matching, 1 new, 2 published seed, 3 unknown
    pub status: Vec<u8>,
    pub method: Vec<u8>,
    pub generation: Vec<u16>,
    pub family: Vec<u8>,
    pub discoverer: Vec<u32>,
    pub root: Vec<u32>,
    pub time: Vec<f32>,
    pub found: Vec<u16>,
    pub finders: Vec<u8>,
    pub expanded: Vec<u8>,
    pub spaces: Vec<u16>,
    pub cosets: Vec<f32>,
    pub reached: Vec<u16>,
    pub reached_new: Vec<u16>,
    pub dir: PathBuf,
}

fn read(dir: &Path, name: &str) -> Vec<u8> {
    fs::read(dir.join(name)).unwrap_or_else(|e| panic!("{}: {e}", dir.join(name).display()))
}

macro_rules! le {
    ($bytes:expr, $t:ty, $n:expr) => {{
        let b = $bytes;
        let w = std::mem::size_of::<$t>();
        b.chunks_exact(w).take($n).map(|c| <$t>::from_le_bytes(c.try_into().unwrap())).collect::<Vec<$t>>()
    }};
}

impl Data {
    pub fn load(dir: &Path, limit: Option<usize>) -> Data {
        let meta: serde_json::Value = serde_json::from_slice(&read(dir, "meta.json")).expect("meta.json");
        let full = meta["count"].as_u64().expect("count") as usize;
        let n = limit.map_or(full, |l| l.min(full));
        let inv_bytes = read(dir, "inv.u8");
        let inv = inv_bytes.chunks_exact(4).take(n).map(|c| [c[0], c[1], c[2], c[3]]).collect();
        let mut d = Data {
            n,
            two: le!(read(dir, "two.i16"), i16, n),
            three: le!(read(dir, "three.i16"), i16, n),
            inv,
            status: read(dir, "status.u8")[..n].to_vec(),
            method: read(dir, "method.u8")[..n].to_vec(),
            generation: le!(read(dir, "generation.u16"), u16, n),
            family: read(dir, "family.u8")[..n].to_vec(),
            discoverer: le!(read(dir, "discoverer.u32"), u32, n),
            root: le!(read(dir, "root.u32"), u32, n),
            time: le!(read(dir, "time.f32"), f32, n),
            found: le!(read(dir, "found.u16"), u16, n),
            finders: read(dir, "finders.u8")[..n].to_vec(),
            expanded: read(dir, "expanded.u8")[..n].to_vec(),
            spaces: le!(read(dir, "spaces.u16"), u16, n),
            cosets: le!(read(dir, "cosets.f32"), f32, n),
            reached: le!(read(dir, "reached.u16"), u16, n),
            reached_new: le!(read(dir, "reached_new.u16"), u16, n),
            dir: dir.to_path_buf(),
        };
        // A discoverer beyond the subset is unknown inside the subset.
        for v in d.discoverer.iter_mut() {
            if *v as usize > n {
                *v = 0;
            }
        }
        d
    }

    pub fn measured(&self, i: usize) -> bool {
        self.two[i] >= 0 && self.inv[i][0] != 255
    }

    /// Invariant value by field name; None if not measured.
    pub fn field(&self, f: Field, i: usize) -> Option<i32> {
        match f {
            Field::Status => Some(self.status[i] as i32),
            Field::Generation => (self.generation[i] != UNKNOWN_GEN).then_some(self.generation[i] as i32),
            _ if !self.measured(i) => None,
            Field::Two => Some(self.two[i] as i32),
            Field::Three => Some(self.three[i] as i32),
            Field::Du => Some(self.inv[i][0] as i32),
            Field::C4 => Some(self.inv[i][1] as i32),
            Field::C2 => Some(self.inv[i][2] as i32),
            Field::Four => Some(self.inv[i][3] as i32),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Field { Two, Three, Du, C4, C2, Four, Status, Generation }

impl Field {
    pub fn name(self) -> &'static str {
        match self {
            Field::Two => "two", Field::Three => "three", Field::Du => "du", Field::C4 => "c4",
            Field::C2 => "c2", Field::Four => "four", Field::Status => "status", Field::Generation => "generation",
        }
    }
}

/// (parent, class) pairs of every construction path, little-endian u32, path order;
/// returns 0-based indices with both ends inside 1..=n.
pub fn load_pairs(path: &Path, n: usize) -> Vec<(u32, u32)> {
    let b = fs::read(path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
    b.chunks_exact(8)
        .map(|c| (u32::from_le_bytes(c[0..4].try_into().unwrap()), u32::from_le_bytes(c[4..8].try_into().unwrap())))
        .filter(|&(p, c)| p >= 1 && c >= 1 && (p as usize) <= n && (c as usize) <= n)
        .map(|(p, c)| (p - 1, c - 1))
        .collect()
}

/// Peak resident memory of this process in MiB (Linux).
pub fn peak_rss_mib() -> f64 {
    fs::read_to_string("/proc/self/status").ok()
        .and_then(|s| s.lines().find(|l| l.starts_with("VmHWM:")).and_then(|l| l.split_whitespace().nth(1)?.parse::<f64>().ok()))
        .map_or(0.0, |kb| kb / 1024.0)
}
