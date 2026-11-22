#!/usr/bin/env python3
"""Render a timelapse of the class map: the classes appear in admission order.

    timelapse.py --classes classes.sqlite --features features.sqlite --out FILE
                 [--admitted admitted.json] [--per-frame 10000] [--frame-seconds 0.2]
                 [--hold 2] [--width 1920] [--height 1200] [--format mp4|gif]
                 [--point 1] [--first ID] [--last ID] [--theme light|dark]
                 [--no-labels] [--progress FILE]

Frame k shows every class with first <= id <= first + k*per_frame - 1 (parent ids
are in admission order). Positions follow apn-layout/src/layout.rs exactly:
x = (two - 320)/140, y = (three - 80)/100, plus an offset inside the cell from
the first 16 bytes of the class LUT SHA-256, so the video matches the /drawing
page. Colours are the page colours: published seeds, catalog-matching classes
(signature in the pinned catalog) and new classes (signature absent). A class
without measured features is not drawn yet and is counted in the label.
--admitted (optional) maps parent ids to admission times for the frame label.
"""
import argparse, bisect, json, sqlite3, subprocess, sys, time
from fractions import Fraction
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

THEMES = {  # the CSS tokens of apn-closure-drawing.html
    "light": dict(bg="#f4f5f2", ink="#242c2b", muted="#59665f", border="#d7dfd9",
                  seed="#a45c00", found="#247698", fresh="#b0297a"),
    "dark": dict(bg="#111917", ink="#e5ebe6", muted="#b7c6bd", border="#3b4b41",
                 seed="#ffc36a", found="#69b9cc", fresh="#f07ac0"),
}
# View of the data region (the census has two in [158, 460], three in [0, 140]).
TWO_RANGE, THREE_RANGE = (150.0, 470.0), (-6.0, 148.0)


def rgb(hex_colour):
    return tuple(int(hex_colour[i:i + 2], 16) for i in (1, 3, 5))


def positions(shas, two, three):
    """Page coordinates as in layout.rs::position (f64 steps, then f32)."""
    raw = np.frombuffer(bytes.fromhex("".join(s[:32] for s in shas)), dtype="<u8").reshape(-1, 2)
    unit = lambda w: (w >> np.uint64(11)).astype(np.float64) * (1.0 / 9007199254740992.0) * 2.0 - 1.0
    u, v = unit(raw[:, 0]), unit(raw[:, 1])
    dx, dy = u * np.sqrt(1.0 - v * v / 2.0), v * np.sqrt(1.0 - u * u / 2.0)
    x = (two - 320.0) / 140.0 + dx * (0.8 * 1.0 / 140.0)
    y = (three - 80.0) / 100.0 + dy * (0.8 * 0.5 / 100.0)
    return np.clip(x, -1.6, 1.6).astype(np.float32), np.clip(y, -1.0, 1.0).astype(np.float32)


def load(classes, features, first, last):
    db = sqlite3.connect(f"file:{classes}?mode=ro", uri=True)
    db.execute("ATTACH ? AS f", (f"file:{features}?mode=ro",))
    rows = db.execute(
        "SELECT c.id, c.sha, c.absent, c.origin='root', f.two, f.three FROM classes c "
        "LEFT JOIN f.features f ON f.sha=c.sha WHERE c.id BETWEEN ? AND ? ORDER BY c.id",
        (first, last)).fetchall()
    db.close()
    if not rows:
        sys.exit("timelapse: no classes in the requested id range")
    ids = np.array([r[0] for r in rows], dtype=np.int64)
    status = np.array([2 if r[3] else (1 if r[2] else 0) for r in rows], dtype=np.uint8)  # 0 catalog, 1 new, 2 seed
    measured = np.array([r[4] is not None and r[5] is not None for r in rows])
    two = np.array([r[4] if r[4] is not None else 0 for r in rows], dtype=np.float64)
    three = np.array([r[5] if r[5] is not None else 0 for r in rows], dtype=np.float64)
    x, y = positions([r[1] for r in rows], two, three)
    return ids, status, measured, x, y


class Canvas:
    def __init__(self, width, height, theme, point, labels):
        self.w, self.h, self.t, self.point, self.labels = width, height, theme, point, labels
        size = max(12, height // 60)
        try:
            self.font = ImageFont.load_default(size=size)
            self.small = ImageFont.load_default(size=int(size * 0.8))
        except TypeError:
            self.font = self.small = ImageFont.load_default()
        top, bottom = (int(height * 0.09), int(height * 0.07)) if labels else (10, 10)
        left, right = (int(width * 0.06), int(width * 0.02)) if labels else (10, 10)
        page_x = [(v - 320.0) / 140.0 for v in TWO_RANGE]
        page_y = [(v - 80.0) / 100.0 for v in THREE_RANGE]
        scale = min((width - left - right) / (page_x[1] - page_x[0]), (height - top - bottom) / (page_y[1] - page_y[0]))
        self.scale = scale
        self.x0 = left + ((width - left - right) - scale * (page_x[1] - page_x[0])) / 2 - scale * page_x[0]
        self.y0 = top + ((height - top - bottom) - scale * (page_y[1] - page_y[0])) / 2 + scale * page_y[1]
        base = Image.new("RGB", (width, height), rgb(theme["bg"]))
        if labels:
            self.axes(ImageDraw.Draw(base))
        self.pixels = np.array(base)
        self.colours = np.array([rgb(theme["found"]), rgb(theme["fresh"]), rgb(theme["seed"])], dtype=np.uint8)

    def to_pixel(self, x, y):
        return (self.x0 + self.scale * x).astype(np.int64), (self.y0 - self.scale * y).astype(np.int64)

    def axes(self, draw):
        t = self.t
        (xa, ya), (xb, yb) = [tuple(int(v[0]) for v in self.to_pixel(np.array([(a - 320) / 140]), np.array([(b - 80) / 100])))
                              for a, b in ((TWO_RANGE[0], THREE_RANGE[0]), (TWO_RANGE[1], THREE_RANGE[1]))]
        draw.rectangle([xa, yb, xb, ya], outline=rgb(t["border"]))
        for two in range(160, 470, 40):
            px = int(self.to_pixel(np.array([(two - 320) / 140]), np.array([0.0]))[0][0])
            draw.line([px, ya, px, ya + 5], fill=rgb(t["muted"]))
            draw.text((px, ya + 8), str(two), fill=rgb(t["muted"]), font=self.small, anchor="mt")
        for three in range(0, 150, 20):
            py = int(self.to_pixel(np.array([0.0]), np.array([(three - 80) / 100]))[1][0])
            draw.line([xa - 5, py, xa, py], fill=rgb(t["muted"]))
            draw.text((xa - 8, py), str(three), fill=rgb(t["muted"]), font=self.small, anchor="rm")
        draw.text(((xa + xb) // 2, self.h - 4), "two: 2-dimensional subspaces in the nonbent component set",
                  fill=rgb(t["muted"]), font=self.small, anchor="mb")
        draw.text((4, (ya + yb) // 2), "three", fill=rgb(t["muted"]), font=self.small, anchor="lm")

    def add(self, x, y, status):
        px, py = self.to_pixel(x, y)
        for ox in range(self.point):
            for oy in range(self.point):
                qx, qy = px + ox, py + oy
                ok = (qx >= 0) & (qx < self.w) & (qy >= 0) & (qy < self.h)
                self.pixels[qy[ok], qx[ok]] = self.colours[status[ok]]

    def frame(self, lines):
        if not self.labels:
            return self.pixels.tobytes()
        image = Image.fromarray(self.pixels)
        draw = ImageDraw.Draw(image)
        t, y = self.t, 6
        draw.text((10, y), lines[0], fill=rgb(t["ink"]), font=self.font)
        y += int(self.font.size * 1.3) if hasattr(self.font, "size") else 16
        x = 10
        for text, key in lines[1]:
            if key:
                draw.ellipse([x, y + 3, x + 9, y + 12], fill=rgb(t[key]))
                x += 14
            draw.text((x, y), text, fill=rgb(t["muted"]), font=self.small)
            x += int(draw.textlength(text, font=self.small)) + 18
        return image.tobytes()


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--classes", required=True); p.add_argument("--features", required=True)
    p.add_argument("--out", required=True); p.add_argument("--admitted")
    p.add_argument("--per-frame", type=int, default=10000); p.add_argument("--frame-seconds", type=float, default=0.2)
    p.add_argument("--hold", type=float, default=2.0, help="seconds to keep the last frame")
    p.add_argument("--width", type=int, default=1920); p.add_argument("--height", type=int, default=1200)
    p.add_argument("--format", choices=("mp4", "gif"), default="mp4")
    p.add_argument("--point", type=int, default=1); p.add_argument("--theme", choices=tuple(THEMES), default="light")
    p.add_argument("--first", type=int, default=1); p.add_argument("--last", type=int, default=2**62)
    p.add_argument("--no-labels", action="store_true"); p.add_argument("--progress")
    a = p.parse_args()
    if not (100 <= a.per_frame <= 10_000_000 and 0.02 <= a.frame_seconds <= 10 and 0 <= a.hold <= 60
            and 160 <= a.width <= 3840 and 120 <= a.height <= 2160 and 1 <= a.point <= 6 and a.first >= 1):
        sys.exit("timelapse: a parameter is outside its range")
    width, height = a.width // 2 * 2, a.height // 2 * 2  # H.264 needs even sizes

    def progress(**state):
        if a.progress:
            tmp = Path(a.progress).with_suffix(".tmp"); tmp.write_text(json.dumps(state)); tmp.replace(a.progress)

    started = time.time()
    progress(phase="reading classes and features", frame=0, frames=0)
    ids, status, measured, x, y = load(a.classes, a.features, a.first, a.last)
    admitted = None
    if a.admitted and Path(a.admitted).is_file():
        data = json.loads(Path(a.admitted).read_text())
        admitted = (data["ids"], data["utc"])
    frames = -(-len(ids) // a.per_frame)
    canvas = Canvas(width, height, THEMES[a.theme], a.point, not a.no_labels)
    rate = Fraction(1 / a.frame_seconds).limit_denominator(1000)
    out = Path(a.out); tmp_out = out.with_name(".part-" + out.name)
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
               "-s", f"{width}x{height}", "-r", f"{rate.numerator}/{rate.denominator}", "-i", "-"]
    if a.format == "mp4":
        command += ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-movflags", "+faststart", "-f", "mp4"]
    else:
        command += ["-vf", "split[a][b];[a]palettegen=max_colors=32:stats_mode=full[p];[b][p]paletteuse=dither=none",
                    "-loop", "0", "-f", "gif"]
    encoder = subprocess.Popen(command + [str(tmp_out)], stdin=subprocess.PIPE)
    counts = np.zeros(3, dtype=np.int64); unmeasured = 0
    for k in range(frames):
        lo, hi = k * a.per_frame, min(len(ids), (k + 1) * a.per_frame)
        m = measured[lo:hi]
        canvas.add(x[lo:hi][m], y[lo:hi][m], status[lo:hi][m])
        counts += np.bincount(status[lo:hi], minlength=3); unmeasured += int((~m).sum())
        last_id = int(ids[hi - 1])
        when = ""
        if admitted:
            i = bisect.bisect_right(admitted[0], last_id) - 1
            when = "  ·  " + admitted[1][max(i, 0)][:16].replace("T", " ") + " UTC"
        title = f"{hi:,} classes (ids {int(ids[0]):,}–{last_id:,}){when}"
        legend = [(f"published seeds {counts[2]:,}", "seed"), (f"catalog-matching {counts[0]:,}", "found"),
                  (f"new {counts[1]:,}", "fresh")]
        if unmeasured:
            legend.append((f"not yet measured {unmeasured:,}", None))
        image = canvas.frame((title, legend))
        repeats = 1 + (round(a.hold / a.frame_seconds) if k == frames - 1 else 0)
        for _ in range(repeats):
            encoder.stdin.write(image)
        if k % 5 == 0 or k == frames - 1:
            progress(phase="rendering", frame=k + 1, frames=frames, seconds=round(time.time() - started, 1))
    encoder.stdin.close()
    if encoder.wait() != 0:
        tmp_out.unlink(missing_ok=True); sys.exit("timelapse: ffmpeg failed")
    tmp_out.replace(out)
    summary = dict(phase="done", frame=frames, frames=frames, classes=int(len(ids)), file=out.name,
                   bytes=out.stat().st_size, video_seconds=round(frames * a.frame_seconds + a.hold, 2),
                   seconds=round(time.time() - started, 1))
    progress(**summary)
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
