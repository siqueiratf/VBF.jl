//! Catalog status per class, occupied (two, three) cells and 95% covariance
//! ellipses of the raw (two, three) values. All sums run in vertex order in
//! f64, so the output is deterministic.

use crate::closure::unhex;
use crate::input::Result;
use crate::layout;
use crate::snapshot::{object, J};
use std::collections::BTreeMap;
use std::fmt::Write as _;
use std::path::Path;

pub const UNKNOWN: u8 = 0;
pub const CATALOG: u8 = 1;
pub const NEW: u8 = 2;
/// Chi-square quantile, 2 degrees of freedom, 95%: -2 ln(0.05).
pub const CHI2_95: f64 = 5.991464547107979;

/// Map classes.absent to a status: 1 is new (signature absent from the pinned
/// catalog), 0 is catalog-matching (not proven equal), no row is unknown.
pub fn status_of(absent: Option<i64>) -> u8 {
    match absent {
        Some(0) => CATALOG,
        Some(_) => NEW,
        None => UNKNOWN,
    }
}

/// Status per vertex from classes(sha, absent), keyed by the LUT SHA-256.
pub fn classes(path: &Path, sha: &[[u8; 32]]) -> Result<Vec<u8>> {
    use rusqlite::{Connection, OpenFlags};
    let db = Connection::open_with_flags(path, OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX)
        .map_err(|e| format!("{}: {e}", path.display()))?;
    let mut order: Vec<u32> = (0..sha.len() as u32).collect();
    order.sort_by_key(|&v| sha[v as usize]);
    let mut absent: Vec<Option<i64>> = vec![None; sha.len()];
    let mut stmt = db.prepare("SELECT sha, absent FROM classes").map_err(|e| format!("classes.sqlite: {e}"))?;
    let mut rows = stmt.query([]).map_err(|e| e.to_string())?;
    while let Some(row) = rows.next().map_err(|e| e.to_string())? {
        let key: String = row.get(0).map_err(|e| e.to_string())?;
        let Some(key) = unhex(&key.to_ascii_lowercase()) else { continue };
        if let Ok(i) = order.binary_search_by(|&v| sha[v as usize].cmp(&key)) {
            let value: i64 = row.get(1).map_err(|e| e.to_string())?;
            let slot = &mut absent[order[i] as usize];
            // Two rows for one class: "new" wins only if every row says so.
            *slot = Some(slot.map_or(value, |old| old.min(value)));
        }
    }
    Ok(absent.into_iter().map(status_of).collect())
}

#[derive(Default, Clone, Copy, Debug, PartialEq)]
pub struct Cell {
    pub n: u64,
    pub new: u64,
    pub catalog: u64,
    pub unknown: u64,
    pub seed: u64,
}

pub fn cells(features: &[Option<(i64, i64)>], status: &[u8], seed: &[bool]) -> BTreeMap<(i64, i64), Cell> {
    let mut out: BTreeMap<(i64, i64), Cell> = BTreeMap::new();
    for (v, f) in features.iter().enumerate() {
        let Some(key) = f else { continue };
        let c = out.entry(*key).or_default();
        c.n += 1;
        match status[v] {
            NEW => c.new += 1,
            CATALOG => c.catalog += 1,
            _ => c.unknown += 1,
        }
        c.seed += seed[v] as u64;
    }
    out
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Ellipse {
    pub n: u64,
    pub mean: [f64; 2],
    /// Sample covariance [[s_xx, s_xy], [s_xy, s_yy]] (divisor n - 1).
    pub cov: [f64; 3],
}

/// Two passes in vertex order: mean, then centred sums.
pub fn moments(points: impl Iterator<Item = (f64, f64)> + Clone) -> Option<Ellipse> {
    let (mut n, mut sx, mut sy) = (0u64, 0.0, 0.0);
    for (x, y) in points.clone() {
        n += 1;
        sx += x;
        sy += y;
    }
    if n < 2 {
        return None;
    }
    let (mx, my) = (sx / n as f64, sy / n as f64);
    let (mut xx, mut xy, mut yy) = (0.0, 0.0, 0.0);
    for (x, y) in points {
        let (dx, dy) = (x - mx, y - my);
        xx += dx * dx;
        xy += dx * dy;
        yy += dy * dy;
    }
    let d = (n - 1) as f64;
    Some(Ellipse { n, mean: [mx, my], cov: [xx / d, xy / d, yy / d] })
}

/// Semi-axes (major, minor) and angle of the major axis (radians from +x)
/// of the region (p - m)' S^-1 (p - m) <= q.
pub fn axes(cov: [f64; 3], q: f64) -> (f64, f64, f64) {
    let [a, b, c] = cov;
    let mid = (a + c) / 2.0;
    let r = (((a - c) / 2.0).powi(2) + b * b).sqrt();
    let (l1, l2) = (mid + r, (mid - r).max(0.0));
    let angle = 0.5 * (2.0 * b).atan2(a - c);
    ((q * l1).sqrt(), (q * l2).sqrt(), angle)
}

/// Covariance in page coordinates: the affine map scales x by 1/140, y by 1/100.
pub fn page_cov(cov: [f64; 3]) -> [f64; 3] {
    let (sx, sy) = (1.0 / layout::TWO_SCALE, 1.0 / layout::THREE_SCALE);
    [cov[0] * sx * sx, cov[1] * sx * sy, cov[2] * sy * sy]
}

/// Share of 720 boundary points of the 95% region of `inner` that lie in the
/// region of `outer` (Mahalanobis distance^2 <= q). 1.0 means inside.
pub fn inside(inner: &Ellipse, outer: &Ellipse, q: f64) -> f64 {
    let (a, b, angle) = axes(inner.cov, q);
    let [p, r, s] = outer.cov;
    let det = p * s - r * r;
    if det <= 0.0 {
        return 0.0;
    }
    let hits = (0..720).filter(|&k| {
        let t = k as f64 * std::f64::consts::PI / 360.0;
        let (u, v) = (a * t.cos(), b * t.sin());
        let x = inner.mean[0] + u * angle.cos() - v * angle.sin() - outer.mean[0];
        let y = inner.mean[1] + u * angle.sin() + v * angle.cos() - outer.mean[1];
        (s * x * x - 2.0 * r * x * y + p * y * y) / det <= q
    });
    hits.count() as f64 / 720.0
}

fn f(x: f64) -> J {
    J::Float(x)
}

/// cells.json: one record per occupied cell, sorted by (two, three).
pub fn cells_json(cells: &BTreeMap<(i64, i64), Cell>) -> String {
    let mut s = String::from("[");
    for (i, ((two, three), c)) in cells.iter().enumerate() {
        if i > 0 {
            s.push(',');
        }
        let (x, y) = layout::affine(*two as f64, *three as f64);
        s.push_str(&object(&[
            ("two", J::Int(*two)),
            ("three", J::Int(*three)),
            ("x", f(x)),
            ("y", f(y)),
            ("n", J::Int(c.n as i64)),
            ("n_new", J::Int(c.new as i64)),
            ("n_catalog", J::Int(c.catalog as i64)),
            ("n_unknown", J::Int(c.unknown as i64)),
            ("n_seed", J::Int(c.seed as i64)),
            ("all_new", J::Bool(c.new == c.n)),
        ]));
    }
    s.push(']');
    s
}

fn array(values: &[f64]) -> J {
    let mut s = String::from("[");
    for (i, v) in values.iter().enumerate() {
        if i > 0 {
            s.push(',');
        }
        write!(s, "{v:?}").unwrap();
    }
    s.push(']');
    J::Raw(s)
}

fn ellipse_json(name: &str, e: &Ellipse) -> String {
    let (a, b, angle) = axes(e.cov, CHI2_95);
    let pc = page_cov(e.cov);
    let (pa, pb, pangle) = axes(pc, CHI2_95);
    let (cx, cy) = layout::affine(e.mean[0], e.mean[1]);
    object(&[
        ("group", J::Str(name.into())),
        ("n", J::Int(e.n as i64)),
        ("mean", array(&e.mean)),
        ("cov", J::Raw(format!("[[{:?},{:?}],[{:?},{:?}]]", e.cov[0], e.cov[1], e.cov[1], e.cov[2]))),
        ("semi_axes", array(&[a, b])),
        ("angle_deg", f(angle.to_degrees())),
        ("page_centre", array(&[cx, cy])),
        ("page_semi_axes", array(&[pa, pb])),
        ("page_angle_deg", f(pangle.to_degrees())),
    ])
}

/// status counts, cell counts, the three ellipses and their containment.
pub fn ellipses_json(features: &[Option<(i64, i64)>], status: &[u8], seed: &[bool], cells: &BTreeMap<(i64, i64), Cell>) -> String {
    let group = |keep: &dyn Fn(usize) -> bool| {
        let pts = features
            .iter()
            .enumerate()
            .filter(|(v, f)| f.is_some() && keep(*v))
            .map(|(_, f)| f.map(|(a, b)| (a as f64, b as f64)).unwrap());
        moments(pts.collect::<Vec<_>>().into_iter())
    };
    let groups = [
        ("new", group(&|v| status[v] == NEW)),
        ("catalog", group(&|v| status[v] == CATALOG)),
        ("seeds", group(&|v| seed[v])),
    ];
    let count = |s: u8| status.iter().filter(|&&x| x == s).count() as i64;
    let all_new = cells.values().filter(|c| c.new == c.n).count() as i64;
    let no_new = cells.values().filter(|c| c.new == 0).count() as i64;
    let counts = object(&[
        ("new", J::Int(count(NEW))),
        ("catalog", J::Int(count(CATALOG))),
        ("unknown", J::Int(count(UNKNOWN))),
        ("seeds", J::Int(seed.iter().filter(|&&s| s).count() as i64)),
        ("unmeasured", J::Int(features.iter().filter(|f| f.is_none()).count() as i64)),
        ("cells", J::Int(cells.len() as i64)),
        ("cells_all_new", J::Int(all_new)),
        ("cells_no_new", J::Int(no_new)),
        ("cells_mixed", J::Int(cells.len() as i64 - all_new - no_new)),
    ]);
    let list: Vec<String> = groups.iter().filter_map(|(name, e)| e.as_ref().map(|e| ellipse_json(name, e))).collect();
    let mut contain: Vec<(String, J)> = Vec::new();
    for (i, (a, ea)) in groups.iter().enumerate() {
        for (j, (b, eb)) in groups.iter().enumerate() {
            if let (true, Some(x), Some(y)) = (i != j, ea, eb) {
                let share = inside(x, y, CHI2_95);
                let o = object(&[("inside", J::Bool(share == 1.0)), ("boundary_share_inside", f(share))]);
                contain.push((format!("{a}_inside_{b}"), J::Raw(o)));
            }
        }
    }
    object(&[
        ("chi2_95", f(CHI2_95)),
        ("data", J::Str("raw (two, three) of the classes with features; sample covariance (n - 1)".into())),
        ("note", J::Str("Descriptive statistics of the explored region; not a statistical test.".into())),
        ("counts", J::Raw(counts)),
        ("groups", J::Raw(format!("[{}]", list.join(",")))),
        ("containment", J::Raw(object(&contain))),
    ])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn status_mapping() {
        assert_eq!(status_of(Some(1)), NEW);
        assert_eq!(status_of(Some(0)), CATALOG);
        assert_eq!(status_of(None), UNKNOWN);
        let dir = std::env::temp_dir().join(format!("apn-layout-classes-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("classes.sqlite");
        let db = rusqlite::Connection::open(&path).unwrap();
        db.execute_batch("CREATE TABLE classes(id INTEGER PRIMARY KEY,sha TEXT,absent INTEGER)").unwrap();
        let hex = |b: u8| format!("{b:02x}").repeat(32);
        for (id, b, absent) in [(1, 5u8, 1), (2, 7, 0), (3, 9, 1)] {
            db.execute("INSERT INTO classes VALUES(?1,?2,?3)", rusqlite::params![id, hex(b), absent]).unwrap();
        }
        drop(db);
        let got = classes(&path, &[[7; 32], [8; 32], [5; 32], [9; 32]]).unwrap();
        assert_eq!(got, vec![CATALOG, UNKNOWN, NEW, NEW]);
        std::fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn ellipse_math() {
        // Points (+-a, 0) and (0, +-b) repeated: cov = diag(a^2/2, b^2/2) * n/(n-1).
        let pts: Vec<(f64, f64)> = [(3.0, 0.0), (-3.0, 0.0), (0.0, 1.0), (0.0, -1.0)].repeat(250);
        let e = moments(pts.into_iter().map(|(x, y)| (x + 10.0, y + 20.0))).unwrap();
        let k = 1000.0 / 999.0;
        assert_eq!(e.mean, [10.0, 20.0]);
        assert!((e.cov[0] - 4.5 * k).abs() < 1e-12 && e.cov[1].abs() < 1e-12 && (e.cov[2] - 0.5 * k).abs() < 1e-12);
        // A rotated covariance: eigenvalues 4 and 1, major axis at 30 degrees.
        let t = 30f64.to_radians();
        let (c, s) = (t.cos(), t.sin());
        let cov = [4.0 * c * c + s * s, 3.0 * c * s, 4.0 * s * s + c * c];
        let (a, b, angle) = axes(cov, CHI2_95);
        assert!((a - (4.0 * CHI2_95).sqrt()).abs() < 1e-12 && (b - CHI2_95.sqrt()).abs() < 1e-12);
        assert!((angle.to_degrees() - 30.0).abs() < 1e-9);
        // Page covariance scales by the affine map.
        let p = page_cov([140.0 * 140.0, 0.0, 100.0 * 100.0]);
        assert!((p[0] - 1.0).abs() < 1e-12 && (p[2] - 1.0).abs() < 1e-12);
        // Containment: a small circle inside a large one, not the reverse.
        let small = Ellipse { n: 10, mean: [0.0, 0.0], cov: [1.0, 0.0, 1.0] };
        let large = Ellipse { n: 10, mean: [0.5, 0.0], cov: [9.0, 0.0, 9.0] };
        assert_eq!(inside(&small, &large, CHI2_95), 1.0);
        assert_eq!(inside(&large, &small, CHI2_95), 0.0);
    }

    #[test]
    fn cell_counts() {
        let f = [Some((2, 3)), Some((2, 3)), Some((4, 1)), None];
        let c = cells(&f, &[NEW, CATALOG, NEW, NEW], &[false, true, false, false]);
        assert_eq!(c[&(2, 3)], Cell { n: 2, new: 1, catalog: 1, unknown: 0, seed: 1 });
        assert_eq!(c[&(4, 1)].new, 1);
        assert!(cells_json(&c).contains("\"two\":4,\"three\":1,\"x\":-2.257142857142857"));
    }
}
