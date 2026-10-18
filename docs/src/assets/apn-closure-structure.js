'use strict';
// Draws the precomputed structure report (/api/structure) as interactive SVG charts.
const NS = 'http://www.w3.org/2000/svg';
const COLORS = { seeds: 'var(--seed)', known: 'var(--known)', new: 'var(--found)', earlier: 'var(--earlier)' };
const DRAW_ORDER = ['known', 'seeds', 'earlier', 'new'];
const FAMILY = new Set(['known-family', 'APN']);
const SOURCES = {
  beierle2025_n8: 'Beierle et al. 2025', beierleleander2022_n8: 'Beierle–Leander 2022',
  beierleleanderperrin2022_n8: 'Beierle–Leander–Perrin 2022', edelpott2009_n8: 'Edel–Pott 2009',
  langevin_may2025_extra_n8: 'Langevin 2025', simonberg_gf4_n8: 'Simon–Berg GF(4)',
  yuperrin2022_qam_n8: 'Yu–Perrin 2022', yuwangli2014_qam_n8: 'Yu–Wang–Li 2014',
};
const SAMPLES = {
  'reference: APN': 'Named: Gold, BCL, Calderini', 'reference: known-family': 'Named: Gold, Kasami, Taniguchi',
  'reference: APN-rep': 'Named: Edel–Pott representatives', 'reference: CCZ-rep-GF4': 'Named: Simon–Berg GF(4)',
};
const METHODS = { v5: 'V5 only', switching: 'Switching only', 'switching+v5': 'Both' };
const state = { visible: new Set(Object.keys(COLORS)), mode: 'share', log: false };
let data = null; const groups = {}; const tips = new Map(); let tipSeq = 0;

const $ = id => document.getElementById(id);
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const fmtInt = n => Math.round(n).toLocaleString('en-US');
function fmtShare(v) {
  if (v === 0) return '0 %';
  const p = v * 100;
  return (p > 99.9 && p < 100 ? p.toFixed(3) : p >= 10 ? p.toFixed(1) : p >= 1 ? p.toFixed(2) : p >= 0.01 ? p.toFixed(3) : p.toExponential(1)) + ' %';
}
const sum = (rows, f) => rows.reduce((s, r) => s + f(r), 0);
function tally(rows, key) { const m = new Map(); for (const r of rows) m.set(key(r), (m.get(key(r)) || 0) + r.classes); return m; }
const visibleGroups = () => DRAW_ORDER.filter(k => state.visible.has(k)).map(k => groups[k]);
const val = (series, n) => state.mode === 'share' ? n / series.total : n;
const fmtVal = v => state.mode === 'share' ? fmtShare(v) : fmtInt(v);

function el(tag, attrs = {}, parent) {
  const e = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) if (v !== undefined && v !== null) e.setAttribute(k, v);
  if (parent) parent.appendChild(e);
  return e;
}
function text(parent, x, y, str, attrs = {}) { const t = el('text', { x, y, ...attrs }, parent); t.textContent = str; return t; }
function tip(node, html) { const id = ++tipSeq; tips.set(id, html); node.setAttribute('data-tip', id); return node; }

// One delegated tooltip for every chart.
const tooltip = $('tooltip');
function placeTip(e) {
  const pad = 14, w = tooltip.offsetWidth, h = tooltip.offsetHeight;
  let x = e.clientX + pad, y = e.clientY + pad;
  if (x + w > innerWidth - 8) x = e.clientX - w - pad;
  if (y + h > innerHeight - 8) y = e.clientY - h - pad;
  tooltip.style.left = Math.max(4, x) + 'px'; tooltip.style.top = Math.max(4, y) + 'px';
}
document.addEventListener('pointerover', e => {
  const node = e.target.closest && e.target.closest('[data-tip]');
  if (!node) { tooltip.hidden = true; return; }
  const html = tips.get(+node.getAttribute('data-tip'));
  if (!html) return;
  tooltip.innerHTML = typeof html === 'function' ? html() : html; tooltip.hidden = false; placeTip(e);
});
document.addEventListener('pointermove', e => { if (!tooltip.hidden) placeTip(e); });
document.addEventListener('pointerleave', () => { tooltip.hidden = true; });

const sup = n => String(n).replace(/\d/g, d => '⁰¹²³⁴⁵⁶⁷⁸⁹'[d]);
// Charts draw at the panel's own pixel width, so text keeps its size in wide panels.
function chartWidth(id) { return Math.max(460, Math.min(1600, Math.round($(id).querySelector('.chart').clientWidth || 720))); }
function reset(id, H, title, subtitle, W = 720) {
  const panel = $(id); panel.querySelector('h2').textContent = title;
  panel.querySelector('p').textContent = subtitle || '';
  const box = panel.querySelector('.chart'); box.textContent = '';
  const svg = el('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': title });
  box.appendChild(svg); return svg;
}
function niceTicks(max, count = 5) {
  if (!(max > 0)) return [0];
  const raw = max / count, mag = 10 ** Math.floor(Math.log10(raw)), err = raw / mag;
  const step = (err >= 7.5 ? 10 : err >= 3.5 ? 5 : err >= 1.5 ? 2 : 1) * mag, out = [];
  for (let v = 0; v <= max * 1.0001 + step; v += step) { out.push(+v.toPrecision(12)); if (v >= max) break; }
  return out;
}
// Value axis from the plotted values; a log axis drops zeros (they are not drawn).
function valueScale(values, top, base, allowLog = true) {
  const pos = values.filter(v => v > 0);
  if (allowLog && state.log && pos.length) {
    const lo = Math.floor(Math.log10(Math.min(...pos))), hi = Math.max(Math.ceil(Math.log10(Math.max(...pos))), lo + 1);
    const f = v => v > 0 ? base - (Math.log10(v) - lo) / (hi - lo) * (base - top) : null;
    const ticks = []; for (let e = lo; e <= hi; e++) ticks.push(10 ** e);
    return { f, ticks, log: true };
  }
  const ticks = niceTicks(Math.max(...values, 0)), end = ticks.at(-1) || 1;
  return { f: v => base - v / end * (base - top), ticks, log: false };
}
function fmtTick(v, share = state.mode === 'share') {
  if (share) { const p = v * 100; return (p >= 1 || p === 0 ? +p.toFixed(1) : +p.toPrecision(1)) + ' %'; }
  return v >= 1e6 ? +(v / 1e6).toPrecision(3) + 'M' : v >= 1e3 ? +(v / 1e3).toPrecision(3) + 'k' : String(v);
}
function gridY(svg, scale, L, R, share) {
  for (const t of scale.ticks) {
    const y = scale.f(t); if (y === null) continue;
    el('line', { x1: L, x2: R, y1: y, y2: y, class: 'grid' }, svg);
    text(svg, L - 6, y + 4, fmtTick(t, share), { class: 'tick', 'text-anchor': 'end' });
  }
}

// Grouped vertical bars: one band per category, one bar per series.
function groupedBars(id, { title, subtitle, categories, series, count, label, catLabel = String, bands = [], detail, xTitle, H = 300, noun = 'classes' }) {
  const W = chartWidth(id), top = bands.length ? 40 : 18, base = H - 50, L = 62, R = W - 8;
  const svg = reset(id, H, title, subtitle, W);
  const values = []; for (const c of categories) for (const s of series) values.push(val(s, count(s.key, c)));
  const scale = valueScale(values, top, base);
  gridY(svg, scale, L, R);
  const cw = (R - L) / categories.length, gap = 2;
  const bw = Math.max(2, Math.min(24, (cw - 8 - gap * (series.length - 1)) / Math.max(series.length, 1)));
  bands.forEach((b, j) => {
    const i0 = categories.indexOf(b.from), i1 = categories.indexOf(b.to); if (i0 < 0 || i1 < 0) return;
    tip(el('rect', { x: L + i0 * cw, y: top - 10, width: (i1 - i0 + 1) * cw, height: base - top + 10, class: 'band' }, svg), b.tip);
    text(svg, L + i0 * cw + 4, top - 14 - 13 * (j % 2), b.label, { class: 'band-label' });
  });
  categories.forEach((c, i) => {
    const x0 = L + i * cw + (cw - (series.length * bw + (series.length - 1) * gap)) / 2;
    series.forEach((s, k) => {
      const n = count(s.key, c), y = scale.f(val(s, n)); if (!n || y === null) return;
      tip(el('rect', { x: x0 + k * (bw + gap), y, width: bw, height: Math.max(base - y, 0.8), fill: s.color }, svg),
        `<b>${esc(s.name)}</b><br>${esc(label)} ${esc(catLabel(c))}${detail ? detail(c) : ''}<br>${fmtInt(n)} ${noun} · ${fmtShare(n / s.total)} of ${esc(s.unit || 'group')}`);
    });
    if (categories.length <= 16 || i % Math.ceil(categories.length / 16) === 0)
      text(svg, L + i * cw + cw / 2, base + 15, catLabel(c), { class: 'tick', 'text-anchor': 'middle' });
  });
  el('line', { x1: L, x2: R, y1: base, y2: base, class: 'axis' }, svg);
  text(svg, (L + R) / 2, base + 36, xTitle, { class: 'axis-title', 'text-anchor': 'middle' });
}

// Runs of neighbouring categories that hold a family instance, with the names for the tooltip.
function familyBands(categories, valueOf) {
  const fam = data.references.filter(r => FAMILY.has(r.family)), bands = [];
  let run = null;
  categories.forEach(c => {
    const here = fam.filter(r => valueOf(r) === c);
    if (here.length && run) { run.to = c; run.names.push(...here); }
    else if (here.length) { run = { from: c, to: c, names: [...here] }; bands.push(run); }
    else run = null;
  });
  return bands.map(b => ({
    from: b.from, to: b.to, label: `Family instances: ${b.from === b.to ? b.from : `${b.from} to ${b.to}`}`,
    tip: `<b>Named family instances</b><br>${b.names.map(r => `${esc(r.name)}: ${valueOf(r)}`).join('<br>')}`,
  }));
}

function drawStats() {
  const box = $('stats'); box.textContent = '';
  const fam = data.references.filter(r => FAMILY.has(r.family)), famKeys = new Set(fam.map(r => `${r.two}|${r.three}`));
  const newRows = data.signature.filter(r => r.group === 'new' || r.group === 'earlier');
  const newTotal = groups.new.total + groups.earlier.total;
  const famHits = sum(newRows.filter(r => famKeys.has(`${r.two}|${r.three}`)), r => r.classes);
  const degrees = [...new Set(data.degree.map(r => r.degree))];
  const eq = data.family_equivalence || [];
  const autosNew = (data.automorphisms || []).filter(a => a.sample.startsWith('new'));
  const items = [
    [fmtInt(newTotal), 'new classes, none in the published reference'],
    [fmtInt(famHits), 'new classes with the nonbent counts of a family instance'],
    [data.identity_holds ? 'All classes' : 'Fails', 'satisfy bent = 170 + 4·c₄ + 20·c₂'],
    [degrees.length === 1 ? `Degree ${degrees[0]}` : degrees.join(', '), 'ortho-derivative degree of every class'],
    [`${eq.filter(r => !r.ea_equivalent).length} of ${eq.length}`, 'EA tests negative: Gold-signature known outputs against family functions'],
    autosNew.length ? [`${autosNew.filter(a => a.order === 256).length} of ${autosNew.length}`, 'sampled new classes have only the 256 translations'] : ['Pending', 'EA automorphism sample'],
  ];
  for (const [big, small] of items) { const d = document.createElement('div'); d.className = 'stat'; d.innerHTML = `<b>${esc(big)}</b>${esc(small)}`; box.appendChild(d); }
}

function drawBent() {
  const idx = tally(data.bent, r => `${r.group}|${r.bent}`), profile = new Map(data.bent.map(r => [r.bent, r]));
  const cats = [...profile.keys()].sort((a, b) => a - b);
  const above = k => sum(data.bent.filter(r => r.group === k && r.bent > 170), r => r.classes) / groups[k].total;
  const newAbove = sum(data.bent.filter(r => (r.group === 'new' || r.group === 'earlier') && r.bent > 170), r => r.classes) / (groups.new.total + groups.earlier.total);
  groupedBars('p-bent', {
    title: `${fmtShare(newAbove)} of new classes exceed 170 bent components; known outputs ${fmtShare(above('known'))}`,
    subtitle: 'Bent components of the 255 nonzero components; bent = 170 + 4·c₄ + 20·c₂',
    categories: cats, series: visibleGroups(), count: (g, c) => idx.get(`${g}|${c}`) || 0, label: 'bent components:',
    detail: c => { const p = profile.get(c); return `<br>rank 6: ${p.c6} · rank 4: ${p.c4} · rank 2: ${p.c2}`; },
    xTitle: 'Bent components',
  });
}

function drawDU() {
  const idx = tally(data.du, r => `${r.group}|${r.du}`);
  const cats = [...new Set([...data.du.map(r => r.du), ...data.references.filter(r => FAMILY.has(r.family)).map(r => r.du)])].sort((a, b) => a - b);
  const newRows = data.du.filter(r => r.group === 'new' || r.group === 'earlier');
  const mid = sum(newRows.filter(r => r.du >= 10 && r.du <= 14), r => r.classes) / sum(newRows, r => r.classes);
  groupedBars('p-du', {
    title: `${fmtShare(mid)} of new classes have ortho-derivative uniformity 10 to 14`,
    subtitle: 'Differential uniformity of the ortho-derivative; shaded: named family instances',
    categories: cats, series: visibleGroups(), count: (g, c) => idx.get(`${g}|${c}`) || 0, label: 'uniformity', bands: familyBands(cats, r => r.du),
    xTitle: 'Differential uniformity of the ortho-derivative',
  });
}

function drawSignature() {
  const W = chartWidth('p-signature'), H = 470, L = 56, R = W - 8, top = 18, base = H - 46;
  const rows = data.signature, refs = data.references;
  const twos = [...rows.map(r => r.two), ...refs.map(r => r.two)], threes = [...rows.map(r => r.three), ...refs.map(r => r.three)];
  const x0 = Math.min(...twos) - 6, x1 = Math.max(...twos) + 6, y1 = Math.max(...threes) + 3;
  const minNew = Math.min(...rows.filter(r => r.group === 'new' || r.group === 'earlier').map(r => r.three));
  const svg = reset('p-signature', H, `Every new class has ${minNew} or more 3-dim nonbent subspaces; none has the counts of a family instance`,
    'One dot per (2-dim, 3-dim) count pair; dot size grows with the number of classes. ◆ family instance · □ other named reference', W);
  const fx = v => L + (v - x0) / (x1 - x0) * (R - L), fy = v => base - v / y1 * (base - top);
  for (const t of niceTicks(y1, 6)) { if (t > y1) continue; el('line', { x1: L, x2: R, y1: fy(t), y2: fy(t), class: 'grid' }, svg); text(svg, L - 6, fy(t) + 4, t, { class: 'tick', 'text-anchor': 'end' }); }
  for (let t = Math.ceil(x0 / 50) * 50; t <= x1; t += 50) { el('line', { x1: fx(t), x2: fx(t), y1: top, y2: base, class: 'grid' }, svg); text(svg, fx(t), base + 15, t, { class: 'tick', 'text-anchor': 'middle' }); }
  el('line', { x1: L, x2: R, y1: base, y2: base, class: 'axis' }, svg);
  text(svg, (L + R) / 2, base + 36, '2-dimensional subspaces inside the nonbent component set', { class: 'axis-title', 'text-anchor': 'middle' });
  text(svg, 14, (top + base) / 2, '3-dimensional subspaces', { class: 'axis-title', 'text-anchor': 'middle', transform: `rotate(-90 14 ${(top + base) / 2})` });
  const cells = new Map();
  for (const r of rows) { const k = `${r.two}|${r.three}`; if (!cells.has(k)) cells.set(k, {}); cells.get(k)[r.group] = r.classes; }
  const named = new Map();
  for (const r of refs) { const k = `${r.two}|${r.three}`; if (!named.has(k)) named.set(k, []); named.get(k).push(r); }
  const cellTip = (two, three) => () => {
    const c = cells.get(`${two}|${three}`) || {}, lines = [`<b>2-dim ${two} · 3-dim ${three}</b>`];
    for (const k of ['seeds', 'known', 'new', 'earlier']) if (c[k]) lines.push(`${esc(groups[k].name)}: ${fmtInt(c[k])} classes`);
    for (const r of named.get(`${two}|${three}`) || []) lines.push(`${FAMILY.has(r.family) ? '◆' : '□'} ${esc(r.name)} [${esc(r.signature)}], uniformity ${r.du}`);
    return lines.join('<br>');
  };
  const radius = c => 1.4 + 1.9 * Math.log10(c + 1);
  for (const g of visibleGroups()) for (const r of rows) if (r.group === g.key)
    tip(el('circle', { cx: fx(r.two), cy: fy(r.three), r: radius(r.classes), fill: g.color, 'fill-opacity': 0.55 }, svg), cellTip(r.two, r.three));
  for (const [k, list] of named) {
    const [two, three] = k.split('|').map(Number), x = fx(two), y = fy(three), fam = list.some(r => FAMILY.has(r.family));
    const node = fam ? el('path', { d: `M${x},${y - 7}L${x + 7},${y}L${x},${y + 7}L${x - 7},${y}Z`, fill: 'var(--ink)' }, svg)
      : el('rect', { x: x - 4, y: y - 4, width: 8, height: 8, fill: 'none', stroke: 'var(--ink)', 'stroke-width': 1.4 }, svg);
    tip(node, cellTip(two, three));
  }
}

function drawThree() {
  const step = 5, series = visibleGroups();
  const bins = new Map(), maxBin = Math.floor(Math.max(...data.signature.map(r => r.three)) / step) * step;
  for (const r of data.signature) { const k = `${r.group}|${Math.floor(r.three / step) * step}`; bins.set(k, (bins.get(k) || 0) + r.classes); }
  const fam = data.references.filter(r => FAMILY.has(r.family)), byThree = new Map();
  for (const r of fam) { if (!byThree.has(r.three)) byThree.set(r.three, []); byThree.get(r.three).push(r); }
  const famValues = [...byThree.keys()].sort((a, b) => a - b);
  const W = chartWidth('p-three'), H = 300, L = 62, R = W - 8, top = 40, base = H - 50, svg = reset('p-three', H,
    `The new classes sit right of the known outputs; family instances have ${famValues.join(' or ')}`,
    `${state.mode === 'share' ? 'Share of each group' : 'Classes'} by the number of 3-dimensional nonbent subspaces, in bins of 5`, W);
  const values = []; for (const s of series) for (let b = 0; b <= maxBin; b += step) values.push(val(s, bins.get(`${s.key}|${b}`) || 0));
  const scale = valueScale(values, top, base), fx = v => L + v / (maxBin + step) * (R - L);
  gridY(svg, scale, L, R);
  for (let t = 0; t <= maxBin + step; t += 20) text(svg, fx(t), base + 15, t, { class: 'tick', 'text-anchor': 'middle' });
  famValues.forEach((three, j) => {
    const list = byThree.get(three);
    tip(el('line', { x1: fx(three), x2: fx(three), y1: top - 14 + 13 * j, y2: base, class: 'rule' }, svg),
      `<b>Family instances with ${three} 3-dim subspaces</b><br>${list.map(r => esc(r.name)).join('<br>')}`);
    text(svg, fx(three) + 4, top - 17 + 13 * j, `${list.length} family instance${list.length > 1 ? 's' : ''}: ${three}`, { class: 'band-label' });
  });
  const lines = el('g', {}, svg), points = el('g', {}, svg);
  for (const s of series) {
    let d = '', pen = false;
    for (let b = 0; b <= maxBin; b += step) {
      const n = bins.get(`${s.key}|${b}`) || 0, y = scale.f(val(s, n));
      if (y === null) { pen = false; continue; }
      d += `${pen ? 'L' : 'M'}${fx(b + step / 2).toFixed(1)},${y.toFixed(1)}`; pen = true;
      if (n) tip(el('circle', { cx: fx(b + step / 2), cy: y, r: 2.6, fill: s.color }, points),
        `<b>${esc(s.name)}</b><br>${b} to ${b + step - 1} subspaces<br>${fmtInt(n)} classes · ${fmtShare(n / s.total)}`);
    }
    el('path', { d, fill: 'none', stroke: s.color, 'stroke-width': s.key === 'new' ? 2.6 : 2 }, lines);
  }
  el('line', { x1: L, x2: R, y1: base, y2: base, class: 'axis' }, svg);
  text(svg, (L + R) / 2, base + 36, '3-dimensional subspaces inside the nonbent component set', { class: 'axis-title', 'text-anchor': 'middle' });
}

function drawAutos() {
  const a = data.automorphisms;
  if (!a) { reset('p-autos', 10, 'EA automorphism groups', '').parentNode.innerHTML = '<p class="pending">The EA automorphism sample is still in calculation. Reload after autos.jl and the export finish.</p>'; return; }
  const samples = [...new Set(a.map(r => r.sample))];
  const W = chartWidth('p-autos'), rowH = 26, top = 18, L = 236, R = W - 24, H = top + samples.length * rowH + 50, base = top + samples.length * rowH;
  const lg = r => Math.log2(r.order), lo = 7.3, hi = Math.ceil(Math.max(...a.map(lg)));
  const newer = a.filter(r => r.sample.startsWith('new')), trivial = newer.filter(r => r.order === 256).length;
  const svg = reset('p-autos', H, `${trivial} of ${newer.length} sampled new classes have only the 256 translations`,
    'EA automorphism group order, log scale; 2⁸ = the 256 translations x ↦ x + a only. Hollow: search incomplete', W);
  const fx = v => L + (v - lo) / (hi - lo) * (R - L);
  for (let t = 8; t <= hi; t += 2) { el('line', { x1: fx(t), x2: fx(t), y1: top, y2: base, class: 'grid' }, svg); text(svg, fx(t), base + 15, `2${sup(t)}`, { class: 'tick', 'text-anchor': 'middle' }); }
  text(svg, (L + R) / 2, base + 36, 'Order of the EA automorphism group', { class: 'axis-title', 'text-anchor': 'middle' });
  const color = s => s.startsWith('new') ? COLORS.new : s.startsWith('known') ? COLORS.known : 'var(--ink)';
  samples.forEach((s, i) => {
    const list = a.filter(r => r.sample === s), y = top + i * rowH + rowH / 2;
    const counts = new Map(); for (const r of list) counts.set(r.order, (counts.get(r.order) || 0) + 1);
    text(svg, L - 10, y + 4, `${SAMPLES[s] || s} (${list.length})`, { class: 'label', 'text-anchor': 'end' });
    for (const [order, n] of counts) {
      const names = list.filter(r => r.order === order), done = names.every(r => r.complete);
      tip(el('circle', { cx: fx(Math.log2(order)), cy: y, r: Math.min(3 + 2.2 * Math.sqrt(n), 12), fill: done ? color(s) : 'none', stroke: color(s), 'stroke-width': 1.5, 'fill-opacity': 0.75 }, svg),
        `<b>${esc(s)}</b><br>order ${fmtInt(order)} = 256 · ${fmtInt(order / 256)}<br>${n} function${n > 1 ? 's' : ''}${done ? '' : ' (incomplete search)'}<br>${names.slice(0, 12).map(r => esc(r.name)).join(', ')}${names.length > 12 ? ', …' : ''}`);
    }
  });
}

function seedSeries(unit) { return [{ key: 'seeds', name: 'Published seeds', color: COLORS.seeds, total: data.children.seeds, unit }]; }
function drawYield() {
  const counts = new Map(data.yield.map(r => [r.new_children, r.classes])), max = Math.max(...counts.keys());
  const cats = ['0', '1']; for (let lo = 2; lo <= max; lo *= 2) cats.push(`${lo}–${2 * lo - 1}`);
  const inBin = c => { if (c === '0' || c === '1') return counts.get(+c) || 0; const [lo, hi] = c.split('–').map(Number); let n = 0; for (const [k, v] of counts) if (k >= lo && k <= hi) n += v; return n; };
  const sorted = [...counts].sort((a, b) => a[0] - b[0]); let acc = 0, median = 0;
  for (const [k, v] of sorted) { acc += v; if (acc >= data.children.seeds / 2) { median = k; break; } }
  groupedBars('p-yield', {
    title: `The median seed gives ${median} new classes; ${fmtInt(counts.get(0) || 0)} seeds give none`,
    subtitle: `Seeds by the number of new classes among their children; maximum ${max}`,
    categories: cats, series: seedSeries('seeds'), count: (_, c) => inBin(c), label: 'new children:', xTitle: 'New classes produced by one seed', noun: 'seeds',
  });
}

function drawCorpora() {
  const rows = [...data.corpora].sort((a, b) => b.seeds - a.seeds), mean = data.children.new_total / data.children.seeds;
  const W = chartWidth('p-corpora'), rowH = 34, top = 30, L = 210, R = W - 70, H = top + rows.length * rowH + 30;
  const svg = reset('p-corpora', H, `Each large seed source gives about ${mean.toFixed(0)} new classes per seed`,
    'New classes per seed, by the source of the seed; grey: fewer than 100 seeds. A class from two sources counts in each', W);
  const peak = Math.max(mean, ...rows.map(r => r.reached / r.seeds)), fx = v => L + v / peak * (R - L);
  rows.forEach((r, i) => {
    const y = top + i * rowH, per = r.reached / r.seeds;
    text(svg, L - 10, y + 10, SOURCES[r.corpus] || r.corpus, { class: 'label', 'text-anchor': 'end' });
    text(svg, L - 10, y + 23, `${fmtInt(r.seeds)} seeds, ${fmtShare(r.productive / r.seeds)} productive`, { class: 'tick', 'text-anchor': 'end' });
    tip(el('rect', { x: L, y, width: Math.max(fx(per) - L, 1), height: 20, fill: r.seeds >= 100 ? COLORS.new : COLORS.known }, svg),
      `<b>${esc(SOURCES[r.corpus] || r.corpus)}</b><br>${fmtInt(r.reached)} new classes from ${fmtInt(r.seeds)} seeds<br>${per.toFixed(2)} per seed · ${fmtInt(r.productive)} productive seeds`);
    text(svg, fx(per) + 6, y + 15, per.toFixed(1), { class: 'value' });
  });
  el('line', { x1: L, x2: L, y1: top - 4, y2: top + rows.length * rowH - 10, class: 'axis' }, svg);
  tip(el('line', { x1: fx(mean), x2: fx(mean), y1: top - 10, y2: top + rows.length * rowH - 10, class: 'rule' }, svg),
    `<b>All seeds</b><br>${fmtInt(data.children.new_total)} new classes from ${fmtInt(data.children.seeds)} seeds`);
  text(svg, fx(mean), top - 14, `all seeds: ${mean.toFixed(1)}`, { class: 'band-label', 'text-anchor': 'middle' });
}

function drawProducers() {
  const idx = tally(data.producers, r => `${r.group}|${r.seeds}`), cats = [...new Set(data.producers.map(r => r.seeds))].sort((a, b) => a - b);
  const newRows = data.producers.filter(r => r.group === 'new' || r.group === 'earlier');
  const one = sum(newRows.filter(r => r.seeds === 1), r => r.classes) / sum(newRows, r => r.classes);
  groupedBars('p-producers', {
    title: `${fmtShare(one)} of new classes come from exactly one seed`, subtitle: 'Number of published seeds that produce each class',
    categories: cats, series: visibleGroups(), count: (g, c) => idx.get(`${g}|${c}`) || 0, label: 'producing seeds:', xTitle: 'Producing seeds',
  });
}

function drawMethods() {
  const idx = tally(data.methods, r => `${r.group}|${r.method}`), cats = Object.keys(METHODS).filter(m => data.methods.some(r => r.method === m));
  const newRows = data.methods.filter(r => r.group === 'new' || r.group === 'earlier');
  const v5 = sum(newRows.filter(r => r.method.includes('v5')), r => r.classes) / sum(newRows, r => r.classes);
  groupedBars('p-methods', {
    title: `The V5 extension reaches ${fmtShare(v5)} of new classes`, subtitle: 'Construction methods that reach each class from a published seed; switching is rare, so try the log axis',
    categories: cats, series: visibleGroups(), count: (g, c) => idx.get(`${g}|${c}`) || 0, label: 'method:', catLabel: c => METHODS[c], xTitle: 'Construction method',
  });
}

function drawLiterature() {
  const idx = tally(data.literature, r => `${r.group}|${r.source}`), totals = tally(data.literature, r => r.source);
  const cats = [...totals.keys()].sort((a, b) => totals.get(b) - totals.get(a));
  const series = visibleGroups().filter(g => data.literature.some(r => r.group === g.key));
  const known = data.literature.filter(r => r.group === 'known'), top = known.reduce((a, b) => b.classes > a.classes ? b : a, known[0]);
  groupedBars('p-literature', {
    title: `${fmtShare(top.classes / groups.known.total)} of known outputs match ${SOURCES[top.source] || top.source}`,
    subtitle: 'Corpus of the published function that each seed or known output is CCZ-equivalent to (first match)',
    categories: cats, series, count: (g, c) => idx.get(`${g}|${c}`) || 0, label: 'source:', catLabel: c => SOURCES[c] || c, xTitle: 'Literature corpus', H: 280,
  });
}

function draw() {
  tips.clear(); tooltip.hidden = true;
  drawBent(); drawDU(); drawSignature(); drawThree(); drawAutos(); drawYield(); drawCorpora(); drawProducers(); drawMethods(); drawLiterature();
}

let resizeTimer = 0, drawnWidth = 0;
addEventListener('resize', () => {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => { if (data && innerWidth !== drawnWidth) { drawnWidth = innerWidth; draw(); } }, 150);
});

function controls() {
  const box = $('group-toggles');
  for (const g of data.groups) {
    const label = document.createElement('label');
    label.innerHTML = `<input type="checkbox" value="${esc(g.key)}" checked><span class="chip" style="background:${COLORS[g.key]}"></span>${esc(g.name)} <span class="small">${fmtInt(g.classes)}</span>`;
    label.querySelector('input').addEventListener('change', e => { e.target.checked ? state.visible.add(g.key) : state.visible.delete(g.key); draw(); });
    box.appendChild(label);
  }
  for (const input of document.querySelectorAll('input[name=mode]')) input.addEventListener('change', e => { state.mode = e.target.value; draw(); });
  $('log').addEventListener('change', e => { state.log = e.target.checked; draw(); });
}

fetch('/api/structure', { cache: 'no-cache' }).then(async reply => {
  const body = await reply.json();
  if (!reply.ok) throw new Error(body.error || reply.statusText);
  if (body.schema !== 'vbf-closure-structure-v1') throw new Error('unsupported report schema');
  data = body;
  for (const g of data.groups) groups[g.key] = { key: g.key, name: g.name, total: g.classes, color: COLORS[g.key] };
  const total = sum(data.groups, g => g.classes);
  $('summary').textContent = `${fmtInt(total)} classes from ${fmtInt(data.children.seeds)} published seeds · ${data.run} · freeze ${data.freeze}`;
  $('provenance').textContent = `Report generated ${data.generated_utc} from the freeze ${data.freeze} and the reference ${data.reference}.`;
  $('message').hidden = true;
  controls(); drawStats(); drawnWidth = innerWidth; draw();
}).catch(error => { $('message').textContent = `The structure report is unavailable: ${error.message}`; });
