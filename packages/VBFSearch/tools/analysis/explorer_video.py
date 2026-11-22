#!/usr/bin/env python3
"""Render a view of the class explorer as an MP4, frame by frame (no screen capture).

    explorer_video.py --explorer DIR/<version> --params 'x=0&y=1&colour=0&...' --out FILE.mp4
                      [--progress FILE.json]

PARAMS is the view state of /explorer (its link): x, y, colour, point, alpha,
show, expanded, trail, drift, dtrail, dcell, dmin, dscale, step, sec, from,
to, hold, bg, size, grid. The video always uses the Fit view of the axes.
Axis values, jitter, filters and colours follow apn-closure-explorer.js, so
a frame looks like the page. Classes are drawn in admission order; with a
trail, classes older than the trail are dimmed.
"""
import argparse, json, subprocess, sys, time
from fractions import Fraction
from pathlib import Path
from urllib.parse import parse_qs

import numpy as np
from PIL import Image, ImageDraw, ImageFont

THEMES = {
    "light": dict(bg="#f4f5f2", ink="#242c2b", muted="#59665f", border="#d7dfd9", seed="#a45c00", found="#247698", fresh="#b0297a", unknown="#8a8f8c"),
    "dark": dict(bg="#111917", ink="#e5ebe6", muted="#b7c6bd", border="#3b4b41", seed="#ffc36a", found="#69b9cc", fresh="#f07ac0", unknown="#9a9e9c"),
}
THEMES["black"] = dict(THEMES["dark"], bg="#000000", border="#2c3631")
THEMES["auto"] = THEMES["light"]
AXES = {0: "two: 2-dim subspaces (nonbent set)", 1: "three: 3-dim nonbent subspaces", 2: "admission order (class id)",
        3: "admission time (hours since the start)", 4: "generation (distance from a seed)",
        5: "rediscoveries, log2(1 + paths)", 6: "distinct finders, log2(1 + parents)",
        7: "maximizing 5-spaces as a parent, log2(1 + n)", 8: "new classes reached as a parent",
        9: "du: differential uniformity of the ortho-derivative", 10: "c4: components of rank 4",
        11: "four: entry 4 of the nonbent signature", 12: "c2: components of rank 2"}
COLOUR_NAMES = {1: "Generation", 3: "Admission time", 5: "Rediscoveries", 6: "Recency (trail)",
                7: "New classes reached (as a parent)", 8: "New per million cosets (as a parent)", 9: "du (ortho-derivative)"}


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64) / 255


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)


def ramp(t):
    t = np.clip(t, 0, 1)[:, None]
    c0, c1, c2 = np.array([0.18, 0.15, 0.55]), np.array([0.13, 0.57, 0.55]), np.array([0.99, 0.88, 0.15])
    m = c0 + (c1 - c0) * smooth(0, 0.5, t)
    return m + (c2 - m) * smooth(0.5, 1, t)


def hue(h):
    k = np.abs(np.mod(h[:, None] + np.array([0, 2 / 3, 1 / 3]), 1) * 6 - 3)
    return 0.15 + 0.7 * np.clip(k - 1, 0, 1)


def ticks(a, b, count):
    step = 10 ** np.floor(np.log10((b - a) / count))
    m = next(k for k in (1, 2, 5, 10) if (b - a) / (step * k) <= count) * step
    v = np.ceil(a / m) * m; out = []
    while v <= b:
        out.append(float(f"{v:.12g}")); v += m
    return out


def font(size, bold=False):
    for f in (("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/TTF/DejaVuSans.ttf"),
              "/usr/share/fonts/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            continue
    return ImageFont.load_default(size=size)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--explorer", required=True); p.add_argument("--params", required=True)
    p.add_argument("--out", required=True); p.add_argument("--progress")
    a = p.parse_args(); t0 = time.time()
    q = {k: v[0] for k, v in parse_qs(a.params).items()}
    num = lambda k, d: float(q[k]) if k in q and q[k] != "" else d
    E = Path(a.explorer); meta = json.loads((E / "meta.json").read_text())
    L = lambda name, t: np.fromfile(E / name, t)

    def progress(**s):
        if a.progress:
            tmp = Path(a.progress).with_suffix(".tmp"); tmp.write_text(json.dumps(s)); tmp.replace(a.progress)

    progress(phase="loading the arrays", frame=0, frames=0)
    n = meta["count"]
    two, three = L("two.i16", "<i2").astype(np.float32), L("three.i16", "<i2").astype(np.float32)
    jit = L("jitter.i8", "i1").reshape(-1, 2).astype(np.float32) / 127
    st, meth, gen, fam = L("status.u8", "u1"), L("method.u8", "u1"), L("generation.u16", "<u2").astype(np.float32), L("family.u8", "u1")
    tim, found, finders = L("time.f32", "<f4"), L("found.u16", "<u2").astype(np.float32), L("finders.u8", "u1").astype(np.float32)
    disc = L("discoverer.u32", "<u4").astype(np.int64)
    opt = lambda name, t: L(name, t) if (E / name).exists() else None
    exp_, spaces, cosets, rnew = opt("expanded.u8", "u1"), opt("spaces.u16", "<u2"), opt("cosets.f32", "<f4"), opt("reached_new.u16", "<u2")
    inv = opt("inv.u8", "u1"); inv = inv.reshape(-1, 4).astype(np.float32) if inv is not None else np.full((n, 4), 255, np.float32)
    exp_ = exp_ if exp_ is not None else np.zeros(n, np.uint8)
    spaces = (spaces if spaces is not None else np.zeros(n)).astype(np.float32)
    cosets = (cosets if cosets is not None else np.zeros(n)).astype(np.float32)
    rnew = (rnew if rnew is not None else np.zeros(n)).astype(np.float32)
    ids = np.arange(1, n + 1, dtype=np.float32)

    xc, yc, colour = int(num("x", 0)), int(num("y", 1)), int(num("colour", 0))

    def axis(c):
        return {0: two + jit[:, 0] * 0.8, 1: three + jit[:, 1] * 0.4, 2: ids, 3: tim / 3600, 4: gen + jit[:, 1] * 0.4,
                5: np.log2(1 + found) + jit[:, 1] * 0.08, 6: np.log2(1 + finders) + jit[:, 1] * 0.08,
                7: np.log2(1 + spaces) + jit[:, 1] * 0.08, 8: rnew + jit[:, 1] * 0.4, 9: inv[:, 0] + jit[:, 1] * 0.8,
                10: inv[:, 1] + jit[:, 1] * 0.35, 11: inv[:, 3] + jit[:, 1] * 0.35}.get(c, inv[:, 2] + jit[:, 1] * 0.35)

    def rng(c):
        pad = lambda lo, hi, f: (lo - (hi - lo) * f or lo - 1, hi + (hi - lo) * f or hi + 1)
        return {0: pad(*meta["two_range"], 0.03), 1: pad(*meta["three_range"], 0.04), 2: pad(0, n, 0.01),
                3: pad(0, meta["time_span_seconds"] / 3600, 0.01), 4: pad(0, meta["generation_max"], 0.03),
                5: pad(0, np.log2(1 + meta["found_max"]), 0.03), 7: pad(0, np.log2(1 + meta.get("spaces_max", 1)), 0.03),
                8: pad(0, min(meta.get("reached_new_max", 1), 400), 0.03), 9: pad(*meta.get("du_range", [8, 62]), 0.04),
                10: pad(0, 4, 0.08), 11: pad(0, 2, 0.1), 12: pad(0, 1, 0.15)}.get(c, pad(0, 8, 0.03))

    X, Y = axis(xc), axis(yc)
    (x0, x1), (y0, y1) = rng(xc), rng(yc)
    theme = THEMES.get(q.get("bg", "light"), THEMES["light"])
    bg = rgb(theme["bg"])
    pal = np.stack([rgb(theme["found"]), rgb(theme["fresh"]), rgb(theme["seed"]), rgb(theme["unknown"])])
    mpal = np.stack([rgb(theme["seed"]), rgb(theme["found"]), rgb(theme["fresh"])])
    rate_max = max(1.0, meta.get("new_per_mcoset_p99", 1.0))
    trail = int(num("trail", 0)) if "trail" in q else 0

    # Filters as in the vertex shader.
    mask = int(num("show", 15)); keep = ((mask >> st) & 1) == 1
    if q.get("expanded") == "1":
        keep &= exp_ > 0
    if xc <= 1 or yc <= 1 or xc >= 9 or yc >= 9 or colour >= 9:
        keep &= two >= 0
    if xc == 4 or yc == 4:
        keep &= gen < 65000

    def colours(sel):
        if colour == 0: return pal[st[sel]]
        if colour == 1: return ramp(gen[sel] / max(1, meta["generation_max"]))
        if colour == 2: return mpal[np.minimum(meth[sel], 2)]
        if colour == 3: return ramp(tim[sel] / max(1, meta["time_span_seconds"]))
        if colour == 4: return hue(fam[sel] / 24 + 0.03)
        if colour == 5: return ramp(np.log2(1 + found[sel]) / np.log2(1 + max(1, meta["found_max"])))
        if colour == 7:
            c = ramp(np.log2(1 + rnew[sel]) / np.log2(1 + max(1, meta.get("reached_new_max", 1))))
            c[exp_[sel] == 0] = pal[3] * 0.6; return c
        if colour == 8:
            c = ramp(1e6 * rnew[sel] / np.maximum(cosets[sel], 1) / rate_max); c[exp_[sel] == 0] = pal[3] * 0.6; return c
        if colour == 9: return ramp((inv[sel, 0] - 8) / 20)
        if colour == 10:
            c4 = inv[sel, 1]; out = np.tile(pal[0], (len(sel), 1))
            out[c4 >= 0.5] = pal[2]; out[c4 >= 1.5] = pal[1]; out[c4 >= 2.5] = np.array([0.1, 0.1, 0.1]); return out
        return pal[st[sel]]

    size = q.get("size", "1920x1200")
    W, H = (int(v) for v in (size.split("x") if "x" in size else "1920x1200".split("x")))
    W, H = max(320, min(3840, W)) // 2 * 2, max(240, min(2160, H)) // 2 * 2
    k = max(1.0, H / 560)                       # text scale, as in the page export
    pt = max(1, int(round(num("point", 1) * max(1.0, H / 1000))))
    alpha = num("alpha", 70) / 100
    px = ((X - x0) / (x1 - x0) * W).astype(np.int64)
    py = ((1 - (Y - y0) / (y1 - y0)) * H).astype(np.int64)
    inside = keep & (px >= 0) & (px < W) & (py >= 0) & (py < H)

    first, last = int(num("from", 0)), int(min(n, num("to", n)))
    per, sec, hold = max(1, int(num("step", 10000))), min(10.0, max(0.02, num("sec", 0.2))), min(60.0, max(0.0, num("hold", 2)))
    frames = max(1, -(-(last - first) // per))

    # Static parts: background, grid, ticks, axis description, legend.
    base = Image.new("RGB", (W, H), tuple(int(v * 255) for v in bg)); d = ImageDraw.Draw(base)
    f_small, f_legend = font(int(11 * k)), font(int(15 * k))
    to_x = lambda v: (v - x0) / (x1 - x0) * W; to_y = lambda v: (1 - (v - y0) / (y1 - y0)) * H
    xt, yt = ticks(x0, x1, 8), ticks(y0, y1, 6)
    muted = tuple(int(v * 255) for v in rgb(theme["muted"]))
    if q.get("grid") == "1":
        g = tuple(int(v * 255) for v in (bg * 0.72 + rgb(theme["muted"]) * 0.28))
        for v in xt: d.line([(to_x(v), 0), (to_x(v), H)], fill=g, width=max(1, int(k ** 0.5)))
        for v in yt: d.line([(0, to_y(v)), (W, to_y(v))], fill=g, width=max(1, int(k ** 0.5)))
    for v in xt:
        d.line([(to_x(v), H - 6 * k), (to_x(v), H)], fill=muted, width=max(1, int(k)))
        d.text((to_x(v) + 3 * k, H - 8 * k), f"{v + 0.0:,.6g}", fill=muted, font=f_small, anchor="ls")
    for v in yt:
        d.line([(0, to_y(v)), (6 * k, to_y(v))], fill=muted, width=max(1, int(k)))
        d.text((8 * k, to_y(v) - 3 * k), f"{v + 0.0:,.6g}", fill=muted, font=f_small, anchor="ls")
    d.text((8 * k, 14 * k), f"x: {AXES[xc]}   ·   y: {AXES[yc]}", fill=muted, font=f_small, anchor="ls")
    ink = tuple(int(v * 255) for v in rgb(theme["ink"])); lx, ly = 8 * k, 40 * k
    items = {0: [("seed", "published seeds"), ("found", "catalog-matching"), ("fresh", "new")],
             2: [("seed", "seed"), ("found", "found first by v5"), ("fresh", "found first by switching")],
             10: [("found", "c4 = 0"), ("seed", "c4 = 1"), ("fresh", "c4 = 2")]}.get(colour)
    if items:
        for key, text in items:
            c = tuple(int(v * 255) for v in rgb(theme[key]))
            d.ellipse([lx, ly - 11 * k, lx + 12 * k, ly + 1 * k], fill=c)
            d.text((lx + 17 * k, ly), text, fill=ink, font=f_legend, anchor="ls")
            lx += 17 * k + d.textlength(text, font=f_legend) + 18 * k
    elif colour == 4:
        d.text((lx, ly), "colour = group of the seed lineage (24 colours)", fill=ink, font=f_legend, anchor="ls")
    else:
        grad = (ramp(np.linspace(0, 1, int(200 * k))) * 255).astype(np.uint8)
        base.paste(Image.fromarray(np.repeat(grad[None], int(12 * k), 0)), (int(lx), int(ly - 11 * k)))
        d.text((lx + 212 * k, ly), COLOUR_NAMES.get(colour, ""), fill=ink, font=f_legend, anchor="ls")
    static = np.array(base, dtype=np.float32) / 255
    text_mask = np.array(base, dtype=np.int16)

    canvas = static.copy()          # points older than the trail (or all points) accumulate here
    old_upto = first                # canvas holds classes first .. old_upto-1

    def paint(img, lo, hi, dim):
        sel = np.arange(lo, hi)[inside[lo:hi]]
        if not len(sel): return
        c = colours(sel); a_ = alpha * (0.12 if dim else 1.0)
        c = bg * (1 - a_) + c * a_ if a_ < 1 else c
        for ox in range(pt):
            for oy in range(pt):
                qx, qy = np.minimum(px[sel] + ox, W - 1), np.minimum(py[sel] + oy, H - 1)
                img[qy, qx] = c

    drift = q.get("drift") == "1" and xc == 0 and yc == 1
    dcell, dmin, dscale = int(num("dcell", 10)), int(num("dmin", 30)), num("dscale", 1)

    def arrows(img_u8, cut):
        lo = max(0, cut - trail) if (q.get("dtrail") == "1" and trail) else 0
        i = np.arange(lo, cut); dd = disc[lo:cut]; ok = dd > 0
        i, j = i[ok], dd[ok] - 1
        ok = (two[i] >= 0) & (two[j] >= 0); i, j = i[ok], j[ok]
        if not len(i): return
        key = (two[j] // dcell).astype(np.int64) * 100000 + (three[j] // (dcell / 2)).astype(np.int64)
        u, inv_k, cnt = np.unique(key, return_inverse=True, return_counts=True)
        sx = np.bincount(inv_k, two[j]); sy = np.bincount(inv_k, three[j])
        dx = np.bincount(inv_k, two[i] - two[j]); dy = np.bincount(inv_k, three[i] - three[j])
        im = Image.fromarray(img_u8); dr = ImageDraw.Draw(im); mx = cnt.max()
        for c_, x_, y_, dx_, dy_ in zip(cnt, sx, sy, dx, dy):
            if c_ < dmin: continue
            ax, ay = to_x(x_ / c_), to_y(y_ / c_); bx, by = to_x(x_ / c_ + dscale * dx_ / c_), to_y(y_ / c_ + dscale * dy_ / c_)
            w = max(1, int((0.8 + 2.5 * (c_ / mx) ** 0.5) * k ** 0.5))
            dr.line([(ax, ay), (bx, by)], fill=ink, width=w)
            ang = np.arctan2(by - ay, bx - ax); h_ = 5 * k
            dr.polygon([(bx, by), (bx - h_ * np.cos(ang - 0.45), by - h_ * np.sin(ang - 0.45)),
                        (bx - h_ * np.cos(ang + 0.45), by - h_ * np.sin(ang + 0.45))], fill=ink)
        img_u8[:] = np.array(im)

    rate = Fraction(1 / sec).limit_denominator(1000)
    out = Path(a.out); part = out.with_name(".part-" + out.name)
    enc = subprocess.Popen(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                            "-s", f"{W}x{H}", "-r", f"{rate.numerator}/{rate.denominator}", "-i", "-",
                            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16", "-preset", "medium",
                            "-movflags", "+faststart", "-f", "mp4", str(part)], stdin=subprocess.PIPE)
    labels_on_top = np.any(text_mask != np.array(base.getpixel((W // 2, H // 2)), dtype=np.int16), axis=2)
    for f in range(frames):
        cut = min(last, first + (f + 1) * per)
        if trail:
            boundary = max(first, cut - trail)
            if boundary > old_upto:
                paint(canvas, old_upto, boundary, True); old_upto = boundary
            frame = canvas.copy(); recent_lo = max(first, cut - trail)
            if colour == 6:  # recency colours inside the trail
                sel = np.arange(recent_lo, cut)[inside[recent_lo:cut]]
                c = ramp(1 - (cut - sel) / max(trail, 1)); c = bg * (1 - alpha) + c * alpha
                for ox in range(pt):
                    for oy in range(pt):
                        frame[np.minimum(py[sel] + oy, H - 1), np.minimum(px[sel] + ox, W - 1)] = c
            else:
                paint(frame, recent_lo, cut, False)
        else:
            paint(canvas, old_upto, cut, False); old_upto = cut; frame = canvas
        img = (np.clip(frame, 0, 1) * 255).astype(np.uint8)
        img[labels_on_top] = text_mask[labels_on_top]       # text and grid stay readable above the points
        if drift:
            arrows(img, cut)
        data = img.tobytes()
        for _ in range(1 + (round(hold / sec) if f == frames - 1 else 0)):
            enc.stdin.write(data)
        if f % 5 == 0 or f == frames - 1:
            progress(phase="rendering", frame=f + 1, frames=frames, seconds=round(time.time() - t0, 1))
    enc.stdin.close()
    if enc.wait() != 0:
        part.unlink(missing_ok=True); sys.exit("explorer_video: ffmpeg failed")
    part.replace(out)
    summary = dict(phase="done", frame=frames, frames=frames, file=out.name, bytes=out.stat().st_size, width=W, height=H,
                   video_seconds=round(frames * sec + round(hold / sec) * sec, 2), seconds=round(time.time() - t0, 1))
    progress(**summary); print(json.dumps(summary))


if __name__ == "__main__":
    main()
