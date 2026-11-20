//! Position rule: the place of a class depends only on the class itself.
//!
//! x comes from `two` (2-dimensional subspaces in the nonbent component set),
//! y from `three` (3-dimensional nonbent subspaces). These are the axes of the
//! scatter chart on the `/structure` page.
//!
//! Fixed affine map (not fitted to the data):
//!   x = (two   - 320) / 140   two   in [96, 544]  ->  x in [-1.6, 1.6]
//!   y = (three -  80) / 100   three in [-20, 180] ->  y in [-1.0, 1.0]
//! The census of 4,215,166 classes has two in [158, 460] (always even) and
//! three in [0, 140], so the bounds leave a margin on every side.
//!
//! One cell is 2 units of `two` (the values are even) by 1 unit of `three`.
//! Inside a cell, a class gets an offset in an ellipse with semi-axes of 0.8
//! of the half cell. The offset comes from the first 16 bytes of the class's
//! own `lut_sha256` only:
//!   a = LE u64 of bytes 0..8, b = LE u64 of bytes 8..16
//!   u = 2 * (a >> 11) / 2^53 - 1, v = 2 * (b >> 11) / 2^53 - 1  (square [-1, 1))
//!   (dx, dy) = (u * sqrt(1 - v^2 / 2), v * sqrt(1 - u^2 / 2))   (unit disk)
//! Only +, -, *, / and sqrt in f64 are used, all exactly rounded by IEEE 754,
//! then one rounding to f32. No RNG, no reduction, no data-dependent term: the
//! same class gets the same bits in any snapshot, subset or superset.
//!
//! A class without measured features goes to the reserved cell
//! (two = 104, three = -12), which is inside the box and away from the data.
//! A value outside the bounds is clamped to the box edge (counted in the log).

pub const TWO_CENTER: f64 = 320.0;
pub const TWO_SCALE: f64 = 140.0;
pub const THREE_CENTER: f64 = 80.0;
pub const THREE_SCALE: f64 = 100.0;
pub const X_LIMIT: f64 = 1.6;
pub const Y_LIMIT: f64 = 1.0;
/// Half cell in `two` units and in `three` units.
pub const HALF_CELL_TWO: f64 = 1.0;
pub const HALF_CELL_THREE: f64 = 0.5;
/// Fraction of the half cell that the spread uses.
pub const SPREAD: f64 = 0.8;
pub const UNMEASURED: (i64, i64) = (104, -12);

/// Text for the "layout" field of current.json.
pub const RULE: &str = "fixed invariant map: x=(two-320)/140, y=(three-80)/100 \
(two = 2-dim, three = 3-dim nonbent subspaces; bounds two 96..544, three -20..180); \
inside each 2x1 cell an offset in an ellipse of 0.8 half cell from the first 16 bytes \
of the class LUT SHA-256 (elliptical square-to-disk map); unmeasured classes at \
two=104, three=-12; position depends only on the class";

/// Unit-disk offset from the first 16 bytes of a LUT SHA-256.
pub fn disk_offset(sha: &[u8; 32]) -> (f64, f64) {
    let a = u64::from_le_bytes(sha[0..8].try_into().unwrap());
    let b = u64::from_le_bytes(sha[8..16].try_into().unwrap());
    let unit = |w: u64| ((w >> 11) as f64) * (1.0 / 9007199254740992.0) * 2.0 - 1.0;
    let (u, v) = (unit(a), unit(b));
    (u * (1.0 - v * v / 2.0).sqrt(), v * (1.0 - u * u / 2.0).sqrt())
}

/// Cell centre in page coordinates (fixed affine map, no clamping).
pub fn affine(two: f64, three: f64) -> (f64, f64) {
    ((two - TWO_CENTER) / TWO_SCALE, (three - THREE_CENTER) / THREE_SCALE)
}

/// Position of one class. The bool is true when the point was clamped.
pub fn position(features: Option<(i64, i64)>, sha: &[u8; 32]) -> ([f32; 2], bool) {
    let (two, three) = features.unwrap_or(UNMEASURED);
    let (cx, cy) = affine(two as f64, three as f64);
    let (dx, dy) = disk_offset(sha);
    let x = cx + dx * (SPREAD * HALF_CELL_TWO / TWO_SCALE);
    let y = cy + dy * (SPREAD * HALF_CELL_THREE / THREE_SCALE);
    let (kx, ky) = (x.clamp(-X_LIMIT, X_LIMIT), y.clamp(-Y_LIMIT, Y_LIMIT));
    ([kx as f32, ky as f32], kx != x || ky != y)
}

#[cfg(test)]
mod tests {
    use super::*;
    use sha2::{Digest, Sha256};

    fn sha(i: u64) -> [u8; 32] {
        Sha256::digest(i.to_le_bytes()).into()
    }

    #[test]
    fn offset_is_deterministic_and_uses_16_bytes() {
        for i in 0..1000 {
            let s = sha(i);
            let (a, b) = disk_offset(&s);
            assert_eq!(disk_offset(&s), (a, b));
            assert!(a * a + b * b <= 1.0 + 1e-12);
            let mut t = s;
            t[16..].fill(0xff);
            assert_eq!(disk_offset(&t), (a, b), "bytes 16.. must not matter");
        }
        // Pinned value: guards against changes of the rule.
        let p = position(Some((384, 32)), &sha(7)).0;
        assert_eq!(p.map(f32::to_bits), PINNED);
    }
    const PINNED: [u32; 2] = [1055479580, 3203886521];

    #[test]
    fn centre_offset_and_affine_bounds() {
        // a = b = 2^63 gives u = v = 0 exactly.
        let mut s = [0u8; 32];
        s[7] = 0x80;
        s[15] = 0x80;
        assert_eq!(disk_offset(&s), (0.0, 0.0));
        assert_eq!(position(Some((320, 80)), &s), ([0.0, 0.0], false));
        assert_eq!(position(Some((96, -20)), &s), ([-1.6, -1.0], false));
        assert_eq!(position(Some((544, 180)), &s), ([1.6, 1.0], false));
        assert_eq!(position(Some((390, 30)), &s).0, [0.5, -0.5]);
        assert_eq!(position(Some((1000, 30)), &s), ([1.6, -0.5], true));
        assert_eq!(position(None, &s).0, [-1.5428572, -0.92]);
    }

    #[test]
    fn spread_stays_inside_the_cell() {
        let hx = HALF_CELL_TWO / TWO_SCALE;
        let hy = HALF_CELL_THREE / THREE_SCALE;
        for i in 0..5000 {
            let ([x, y], _) = position(Some((384, 32)), &sha(i));
            let (cx, cy) = affine(384.0, 32.0);
            assert!(((x as f64) - cx).abs() < hx && ((y as f64) - cy).abs() < hy);
        }
    }
}
