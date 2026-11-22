'use strict';
// Analysis views of the class explorer: invariant heatmaps, parent-to-child
// transitions, distributions, generations and communities. All heavy computation
// is done by the Rust tool apn-explorer (packages/VBFSearch/tools/apn-explorer);
// this file only draws its JSON output and turns a click into a linked filter
// (window.apnExplorer.setFilter) that the point map and the statistics respect.
(() => {
  const $ = id => document.getElementById(id);
  const X = () => window.apnExplorer;
  const num = v => Number(v).toLocaleString();
  const cache = {};
  let view = 'map';

  async function analysis(name) {
    if (cache[name]) return cache[name];
    const r = await fetch('/explorer-data/' + X().meta.version + '/analysis/' + name + '.json');
    if (!r.ok) throw new Error(name + '.json is not available: use "Update the data"');
    return (cache[name] = await r.json());
  }

  // ---------- field values, as in the Rust tool (data.rs) ----------
  const FIELD = {
    two: i => X().D.two[i], three: i => X().D.three[i], du: i => X().D.inv[4 * i], c4: i => X().D.inv[4 * i + 1],
    c2: i => X().D.inv[4 * i + 2], four: i => X().D.inv[4 * i + 3], status: i => X().D.status[i], generation: i => X().D.generation[i]
  };
  const measured = i => X().D.two[i] >= 0 && X().D.inv[4 * i] !== 255;
  function value(f, i) {
    if (f === 'status') return X().D.status[i] === 3 ? null : X().D.status[i];
    if (f === 'generation') return X().D.generation[i] === 65535 ? null : X().D.generation[i];
    return measured(i) ? FIELD[f](i) : null;
  }
  function binned(f, i) {
    const v = value(f, i); if (v === null) return null;
    return f === 'two' ? Math.trunc(v / 10) * 10 : f === 'three' ? Math.trunc(v / 5) * 5 : v;
  }
  function maskOf(test) {
    const n = X().n, m = new Uint8Array(n);
    for (let i = 0; i < n; i++) m[i] = test(i) ? 1 : 0;
    return m;
  }

  // ---------- colours ----------
  const RAMP = [[0.18, 0.15, 0.55], [0.13, 0.57, 0.55], [0.99, 0.88, 0.15]];
  const ss = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
  function ramp(t) {
    t = Math.min(1, Math.max(0, t)); const u = ss(0, 0.5, t), w = ss(0.5, 1, t);
    const m = RAMP[0].map((c, k) => c + (RAMP[1][k] - c) * u);
    return 'rgb(' + m.map((c, k) => Math.round(255 * (c + (RAMP[2][k] - c) * w))).join(',') + ')';
  }
  function diverging(t) {  // t in [-1, 1]: blue - neutral - red
    t = Math.max(-1, Math.min(1, t)); const a = Math.abs(t);
    const end = t < 0 ? [49, 104, 196] : [196, 62, 49], mid = [128, 128, 128];
    return 'rgb(' + mid.map((c, k) => Math.round(c + (end[k] - c) * a)).join(',') + ')';
  }

  // ---------- generic cell grid on a canvas ----------
  // cells: [{xi, yi, colour, tip, onClick}], xs/ys: axis labels
  function grid(spec) {
    const c = $('acanvas'), ctx = c.getContext('2d'), dpr = window.devicePixelRatio || 1;
    c.width = Math.round(c.clientWidth * dpr); c.height = Math.round(c.clientHeight * dpr);
    const css = X().css, L = 62 * dpr, B = 46 * dpr, T = 14 * dpr, R = 16 * dpr;
    const W = c.width - L - R, H = c.height - T - B, nx = spec.xs.length, ny = spec.ys.length;
    const cw = W / nx, ch = H / ny;
    ctx.fillStyle = css('--bg'); ctx.fillRect(0, 0, c.width, c.height);
    for (const cell of spec.cells) { ctx.fillStyle = cell.colour; ctx.fillRect(L + cell.xi * cw, T + (ny - 1 - cell.yi) * ch, Math.ceil(cw), Math.ceil(ch)); }
    if (spec.selected) {
      ctx.strokeStyle = css('--ink'); ctx.lineWidth = 2 * dpr;
      ctx.strokeRect(L + spec.selected.xi * cw, T + (ny - 1 - spec.selected.yi) * ch, cw, ch);
    }
    ctx.fillStyle = css('--muted'); ctx.font = (11 * dpr) + 'px system-ui,sans-serif';
    const every = (k, space) => Math.max(1, Math.ceil(k * 13 * dpr / space));
    const sx = every(nx, W * 0.9 / 2.2), sy = every(ny, H);
    ctx.textAlign = 'center';
    spec.xs.forEach((v, i) => { if (i % sx === 0) ctx.fillText(String(v), L + (i + 0.5) * cw, T + H + 14 * dpr); });
    ctx.textAlign = 'right';
    spec.ys.forEach((v, i) => { if (i % sy === 0) ctx.fillText(String(v), L - 5 * dpr, T + (ny - 1 - i + 0.5) * ch + 4 * dpr); });
    ctx.textAlign = 'center'; ctx.fillText(spec.xlabel, L + W / 2, c.height - 8 * dpr);
    ctx.save(); ctx.translate(14 * dpr, T + H / 2); ctx.rotate(-Math.PI / 2); ctx.fillText(spec.ylabel, 0, 0); ctx.restore();
    ctx.textAlign = 'left';
    const at = e => {
      const r = c.getBoundingClientRect(), x = (e.clientX - r.left) * dpr - L, y = (e.clientY - r.top) * dpr - T;
      if (x < 0 || y < 0 || x >= W || y >= H) return null;
      const xi = Math.floor(x / cw), yi = ny - 1 - Math.floor(y / ch);
      return spec.cells.find(k => k.xi === xi && k.yi === yi) || null;
    };
    c.onmousemove = e => { const k = at(e); $('atip').hidden = !k; if (k) { $('atip').innerHTML = k.tip; $('atip').style.left = (e.offsetX + 14) + 'px'; $('atip').style.top = (e.offsetY + 10) + 'px'; } };
    c.onmouseleave = () => { $('atip').hidden = true; };
    c.onclick = e => { const k = at(e); if (k && k.onClick) k.onClick(); };
  }
  function legendBar(lo, hi, label, div) {
    const stops = div ? [-1, -0.5, 0, 0.5, 1].map(diverging) : [0, 0.25, 0.5, 0.75, 1].map(ramp);
    $('alegend').innerHTML = '<span>' + lo + '</span><i style="background:linear-gradient(90deg,' + stops.join(',') + ')"></i><span>' + hi + '</span> <span class="small">' + label + '</span>';
  }

  // ---------- Feature 1: invariant heatmaps ----------
  const METRICS = {
    classes: ['Classes (log)', r => r.classes, true],
    novelty: ['% new (of new + catalog-matching)', r => r.new + r.catalog_matching ? r.new / (r.new + r.catalog_matching) : null, false, 1],
    new: ['New classes (log)', r => r.new, true],
    catalog_only: ['Catalog classes not reached yet (log): unexplored', r => Math.max(0, r.catalog - r.catalog_matching), true],
    catalog: ['Catalog classes (log)', r => r.catalog, true],
    found: ['Mean rediscoveries (log)', r => r.classes ? r.found_sum / r.classes : null, true],
    singletons: ['% found only once', r => r.classes ? r.singletons / r.classes : null, false, 1],
    expanded: ['% expanded as a parent', r => r.classes ? r.expanded / r.classes : null, false],
    rate: ['New per million cosets (expanded parents)', r => r.cosets_sum ? 1e6 * r.reached_new_sum / r.cosets_sum : null, false],
    id: ['Mean admission order (early → late)', r => r.classes ? r.id_mean : null, false],
    gen2: ['% generation 2', r => r.classes ? r.gen2 / r.classes : null, false, 1]
  };
  let hmSel = null;
  async function heatmapView() {
    const h = await analysis('heatmaps'), pair = $('hm-pair').value, metric = $('hm-metric').value, minN = Number($('hm-min').value) || 0;
    const P = h.pairs[pair], ix = Object.fromEntries(h.columns.map((c, k) => [c, k]));
    const rows = P.cells.map(a => Object.fromEntries(h.columns.map((c, k) => [c, a[k]])));
    const xs = [...new Set(rows.map(r => r.x))].sort((a, b) => a - b), ys = [...new Set(rows.map(r => r.y))].sort((a, b) => a - b);
    const xi = new Map(xs.map((v, k) => [v, k])), yi = new Map(ys.map((v, k) => [v, k]));
    const [label, f, log, fixedMax] = METRICS[metric];
    const vals = rows.map(r => (r.classes >= minN || metric === 'catalog' || metric === 'catalog_only') ? f(r) : null);
    const finite = vals.filter(v => v !== null && isFinite(v) && (!log || v > 0));
    const tf = v => log ? Math.log10(v) : v;
    let lo = Math.min(...finite.map(tf)), hi = fixedMax !== undefined ? fixedMax : Math.max(...finite.map(tf));
    if (metric === 'novelty' || metric === 'singletons' || metric === 'gen2') lo = 0;
    const fmt = v => log ? num(Math.round(10 ** v)) : fixedMax === 1 || metric === 'expanded' ? (100 * v).toFixed(0) + '%' : num(Math.round(v));
    legendBar(fmt(lo), fmt(hi), label, false);
    const cells = [];
    rows.forEach((r, k) => {
      const v = vals[k]; if (v === null || !isFinite(v) || (log && v <= 0)) return;
      const tip = '<b>' + P.x + ' = ' + r.x + ', ' + P.y + ' = ' + r.y + '</b><br>' + num(r.classes) + ' classes: ' + num(r.new) + ' new, ' + num(r.catalog_matching) +
        ' catalog-matching, ' + num(r.seeds) + ' seeds<br>catalog ' + num(r.catalog) + ' (' + num(Math.max(0, r.catalog - r.catalog_matching)) + ' not reached)<br>' +
        (r.new + r.catalog_matching ? (100 * r.new / (r.new + r.catalog_matching)).toFixed(1) + '% new · ' : '') +
        (r.classes ? 'mean rediscoveries ' + (r.found_sum / r.classes).toFixed(1) + ' · singletons ' + (100 * r.singletons / r.classes).toFixed(0) + '%' : '') +
        '<br>' + label + ': <b>' + (fixedMax === 1 || metric === 'expanded' || metric === 'gen2' ? (100 * v).toFixed(1) + '%' : num(Math.round(v * 10) / 10)) + '</b>';
      cells.push({xi: xi.get(r.x), yi: yi.get(r.y), colour: ramp((tf(v) - lo) / ((hi - lo) || 1)), tip, onClick: () => {
        hmSel = {pair, x: r.x, y: r.y, xi: xi.get(r.x), yi: yi.get(r.y)};
        X().setFilter(maskOf(i => measured(i) && FIELD[P.x](i) === r.x && FIELD[P.y](i) === r.y), P.x + ' = ' + r.x + ', ' + P.y + ' = ' + r.y);
        cellInfo(r, P); heatmapView();
      }});
    });
    grid({xs, ys, cells, xlabel: P.x, ylabel: P.y, selected: hmSel && hmSel.pair === pair ? hmSel : null});
    $('ainfo-note').textContent = h.notes;
  }
  function cellInfo(r, P) {
    const D = X().D, n = X().n, f = X().filter, top = [];
    if (f) for (let i = 0; i < n; i++) if (f.mask[i]) top.push(i + 1);
    top.sort((a, b) => D.found[b - 1] - D.found[a - 1]);
    const newest = f ? [...top].sort((a, b) => b - a).slice(0, 5) : [];
    const link = id => '<button data-id="' + id + '">#' + num(id) + '</button>';
    $('ainfo').innerHTML = '<b>' + P.x + ' = ' + r.x + ', ' + P.y + ' = ' + r.y + '</b>: ' + num(r.classes) + ' classes, ' + num(r.new) + ' new, ' +
      num(Math.max(0, r.catalog - r.catalog_matching)) + ' catalog classes not reached.<br>Most rediscovered: ' + top.slice(0, 6).map(link).join(' ') +
      '<br>Latest found: ' + newest.map(link).join(' ') + ' <span class="small">(a click selects the class on the map)</span>';
    $('ainfo').querySelectorAll('button[data-id]').forEach(b => { b.onclick = () => { showView('map'); X().select(Number(b.dataset.id)); }; });
  }

  // ---------- Feature 2: parent-to-child transitions ----------
  let trSel = null;
  async function transitionsView() {
    const t = await analysis('transitions'), field = $('tr-field').value, set = $('tr-set').value, mode = $('tr-mode').value;
    const F = t.fields[field], S = F[set], vals = F.values, k = vals.length, M = S.matrix;
    const rows = vals.map((_, i) => M.slice(i * k, (i + 1) * k).reduce((a, b) => a + b, 0));
    const cols = vals.map((_, j) => vals.reduce((a, _, i) => a + M[i * k + j], 0)), N = rows.reduce((a, b) => a + b, 0);
    const cells = [];
    let maxAbs = 0; const lifts = [];
    for (let i = 0; i < k; i++) for (let j = 0; j < k; j++) {
      const c = M[i * k + j], e = rows[i] * cols[j] / (N || 1);
      const lift = c > 0 && e > 0 ? Math.log2(c / e) : null; lifts.push(lift);
      if (lift !== null && rows[i] >= 200 && cols[j] >= 200) maxAbs = Math.max(maxAbs, Math.abs(lift));
    }
    maxAbs = Math.min(maxAbs || 1, 3);
    const pmax = Math.max(...vals.map((_, i) => Math.max(...vals.map((_, j) => rows[i] ? M[i * k + j] / rows[i] : 0))));
    const cmax = Math.log10(Math.max(1, ...M));
    for (let i = 0; i < k; i++) for (let j = 0; j < k; j++) {
      const c = M[i * k + j]; if (!c) continue;
      const lift = lifts[i * k + j], p = rows[i] ? c / rows[i] : 0;
      // Rows or columns with few edges give large random lifts: show them neutral.
      const thin = rows[i] < 200 || cols[j] < 200;
      const colour = mode === 'lift' ? (thin ? 'rgba(128,128,128,0.25)' : diverging((lift || 0) / maxAbs)) : mode === 'cond' ? ramp(p / (pmax || 1)) : ramp(Math.log10(c) / cmax);
      const tip = '<b>parent ' + field + ' ' + vals[i] + ' → child ' + vals[j] + '</b><br>' + num(c) + ' edges · P(child | parent) ' + (100 * p).toFixed(1) +
        '%<br>expected if independent ' + num(Math.round(rows[i] * cols[j] / N)) + ' · lift ' + (lift === null ? '—' : (2 ** lift).toFixed(2) + '×') +
        (thin ? '<br><i>fewer than 200 edges in this row or column: not coloured</i>' : '');
      cells.push({xi: j, yi: i, colour, tip, onClick: () => {
        trSel = {field, set, xi: j, yi: i};
        const D = X().D, pv = vals[i], cv = vals[j];
        X().setFilter(maskOf(x => { const d = D.discoverer[x]; return d > 0 && binned(field, x) === cv && binned(field, d - 1) === pv; }),
          'discoverer ' + field + ' ' + pv + ' → class ' + field + ' ' + cv);
        transitionsView();
      }});
    }
    if (mode === 'lift') legendBar('×' + (2 ** -maxAbs).toFixed(2), '×' + (2 ** maxAbs).toFixed(2), 'lift = observed / expected if independent (log scale)', true);
    else if (mode === 'cond') legendBar('0%', (100 * pmax).toFixed(0) + '%', 'P(child value | parent value), per row', false);
    else legendBar('1', num(Math.round(10 ** cmax)), 'edges (log)', false);
    grid({xs: vals, ys: vals, cells, xlabel: 'child ' + field + (field === 'two' ? ' (bands of 10)' : field === 'three' ? ' (bands of 5)' : ''),
      ylabel: 'parent ' + field, selected: trSel && trSel.field === field && trSel.set === set ? trSel : null});
    const q = S.mi_by_expansion_quarter.map(v => v.toFixed(4)).join(' / ');
    $('ainfo').innerHTML = '<b>' + field + ', ' + (set === 'first' ? 'discoverer → class (depends on the search order)' : 'all parent → class construction pairs (independent of the order)') + '</b><br>' +
      num(S.edges) + ' edges · MI ' + S.mi_bits.toFixed(4) + ' bits · NMI ' + S.nmi.toFixed(4) + ' · Cramér\'s V ' + S.cramers_v.toFixed(3) +
      ' · same value ' + (100 * S.same_value_rate).toFixed(1) + '% (independent: ' + (100 * S.same_value_rate_if_independent).toFixed(1) + '%)<br>' +
      'Null model (parents shuffled): MI ' + S.null_mi_mean.toExponential(2) + ' ± ' + S.null_mi_sd.toExponential(1) + ' → z = ' + S.z.toFixed(0) +
      '. With this many edges any dependence is "significant"; read the effect size (NMI, V). MI per quarter of the expansion order: ' + q +
      ' (a change over time points to the search order, not to structure).' +
      (trSel ? '<br>The filter uses the discoverer of each class (first edges).' : '');
    $('ainfo-note').textContent = '';
  }

  // ---------- simple charts on the analysis canvas ----------
  // series: [{name, colour, points: [[x, y], ...], bars?: bool}], region: [x0, y0, w, h] in canvas pixels
  function chart(ctx, region, series, opt) {
    const css = X().css, dpr = window.devicePixelRatio || 1, [rx, ry, rw, rh] = region;
    const L = 58 * dpr, B = 30 * dpr, T = 20 * dpr, x0 = rx + L, y0 = ry + T, w = rw - L - 10 * dpr, h = rh - T - B;
    const all = series.flatMap(s => s.points).filter(p => isFinite(p[0]) && isFinite(p[1]) && (!opt.logy || p[1] > 0));
    if (!all.length) return null;
    const ty = v => opt.logy ? Math.log10(v) : v;
    const xmin = opt.xmin ?? Math.min(...all.map(p => p[0])), xmax = opt.xmax ?? Math.max(...all.map(p => p[0]));
    const ylo = opt.ymin !== undefined ? ty(opt.ymin) : Math.min(...all.map(p => ty(p[1]))), yhi = opt.ymax !== undefined ? ty(opt.ymax) : Math.max(...all.map(p => ty(p[1])));
    const X_ = v => x0 + (v - xmin) / ((xmax - xmin) || 1) * w, Y_ = v => y0 + h - (ty(v) - ylo) / ((yhi - ylo) || 1) * h;
    ctx.strokeStyle = css('--border'); ctx.lineWidth = dpr; ctx.strokeRect(x0, y0, w, h);
    ctx.fillStyle = css('--muted'); ctx.font = (11 * dpr) + 'px system-ui,sans-serif';
    ctx.fillText(opt.title || '', x0, ry + 13 * dpr);
    ctx.textAlign = 'right';
    for (let k = 0; k <= 4; k++) { const v = ylo + (yhi - ylo) * k / 4; ctx.fillText(opt.logy ? (10 ** v >= 1 ? num(Math.round(10 ** v)) : (10 ** v).toPrecision(2)) : (opt.yfmt || (z => num(+z.toPrecision(3))))(v), x0 - 4 * dpr, y0 + h - k / 4 * h + 4 * dpr); }
    ctx.textAlign = 'center';
    for (let k = 0; k <= 5; k++) { const v = xmin + (xmax - xmin) * k / 5; ctx.fillText((opt.xfmt || (z => num(+z.toPrecision(3))))(v), x0 + k / 5 * w, y0 + h + 14 * dpr); }
    ctx.fillText(opt.xlabel || '', x0 + w / 2, ry + rh - 2 * dpr); ctx.textAlign = 'left';
    const hits = [];
    let lx = x0 + w - 4 * dpr;
    for (const s of series) {
      ctx.strokeStyle = ctx.fillStyle = s.colour; ctx.lineWidth = 2 * dpr; ctx.setLineDash(s.dash ? [5 * dpr, 4 * dpr] : []);
      if (s.bars) {
        const bw = Math.max(2 * dpr, w / Math.max(1, (xmax - xmin + 1)) * 0.8 / (opt.groups || 1));
        s.points.forEach(p => { if (p[1] > 0 || !opt.logy) { const x = X_(p[0]) + (s.offset || 0) * bw - bw * (opt.groups || 1) / 2; const y = Math.min(y0 + h, Math.max(y0, Y_(Math.max(p[1], opt.logy ? 1e-12 : 0))));
          ctx.globalAlpha = 0.85; ctx.fillRect(x, y, bw, y0 + h - y); ctx.globalAlpha = 1; hits.push({x, y, w: bw, h: y0 + h - y, p, s}); } });
      } else {
        ctx.beginPath(); let first = true;
        for (const p of s.points) { if (opt.logy && p[1] <= 0) continue; const x = X_(p[0]), y = Y_(p[1]); first ? ctx.moveTo(x, y) : ctx.lineTo(x, y); first = false; hits.push({x: x - 4 * dpr, y: y - 4 * dpr, w: 8 * dpr, h: 8 * dpr, p, s}); }
        ctx.stroke();
      }
      ctx.setLineDash([]);
      ctx.textAlign = 'right'; ctx.fillText(s.name, lx, y0 + 12 * dpr + 13 * dpr * series.indexOf(s)); ctx.textAlign = 'left';
    }
    return hits;
  }
  function canvasSetup() {
    const c = $('acanvas'), ctx = c.getContext('2d'), dpr = window.devicePixelRatio || 1;
    c.width = Math.round(c.clientWidth * dpr); c.height = Math.round(c.clientHeight * dpr);
    ctx.fillStyle = X().css('--bg'); ctx.fillRect(0, 0, c.width, c.height);
    return {c, ctx, dpr};
  }
  function hover(c, hits, tip, click) {
    const dpr = window.devicePixelRatio || 1;
    const at = e => { const r = c.getBoundingClientRect(), x = (e.clientX - r.left) * dpr, y = (e.clientY - r.top) * dpr;
      return hits.find(k => x >= k.x && x <= k.x + k.w && y >= k.y && y <= k.y + k.h) || null; };
    c.onmousemove = e => { const k = at(e); $('atip').hidden = !k; if (k) { $('atip').innerHTML = tip(k); $('atip').style.left = (e.offsetX + 14) + 'px'; $('atip').style.top = (e.offsetY + 10) + 'px'; } };
    c.onmouseleave = () => { $('atip').hidden = true; };
    c.onclick = e => { const k = at(e); if (k && click) click(k); };
  }
  const GROUP_COLOURS = () => ({all: X().css('--ink'), 'status:catalog': X().css('--found'), 'status:new': X().css('--fresh'), 'status:seed': X().css('--seed'),
    'generation:0': '#e3a72f', 'generation:1': '#3aa8a0', 'generation:2': '#9b6bd6'});
  const binRange = b => b === 0 ? [0, 0] : [2 ** (b - 1), 2 ** b - 1];
  const binText = b => { const [lo, hi] = binRange(b); return lo === hi ? String(lo) : num(lo) + '–' + num(hi); };

  // ---------- Feature 3: degree and rediscovery distributions ----------
  let inDegree = null;
  async function perClass(metric) {
    const D = X().D;
    if (metric === 'in_degree') {
      if (!inDegree) inDegree = new Uint32Array(await (await fetch('/explorer-data/' + X().meta.version + '/analysis/in_degree.u32')).arrayBuffer());
      return i => inDegree[i];
    }
    return {found: i => D.found[i], out_degree: i => D.reached[i], reached_new: i => D.reached_new[i], spaces: i => D.spaces[i], cosets: i => D.cosets[i]}[metric];
  }
  async function distributionsView() {
    const d = await analysis('distributions'), metric = $('ds-metric').value, by = $('ds-by').value, norm = $('ds-norm').value === 'share';
    const M = d.metrics[metric], groups = by === 'all' ? ['all'] : Object.keys(M.groups).filter(g => g.startsWith(by + ':'));
    const colours = GROUP_COLOURS(), {c, ctx, dpr} = canvasSetup();
    const top = [0, 0, c.width, c.height * 0.62], bl = [0, c.height * 0.62, c.width / 2, c.height * 0.38], br = [c.width / 2, c.height * 0.62, c.width / 2, c.height * 0.38];
    const series = groups.map((g, k) => { const h = M.groups[g], tot = h.reduce((a, b) => a + b, 0) || 1;
      return {name: g.replace(':', ' ') + ' (' + num(tot) + ')', colour: colours[g] || '#888', bars: true, offset: k, group: g,
        points: h.map((v, b) => [b, norm ? v / tot : v])}; });
    const pl = M.powerlaw;
    const hits = chart(ctx, top, series, {logy: true, groups: series.length, title: metric.replace('_', ' ') + (M.parents_only ? ' (expanded parents only)' : '') + ' · log2 bins' +
      (pl ? ' · power-law tail from ' + num(pl.xmin) + ': α = ' + pl.alpha.toFixed(2) + ', KS ' + pl.ks.toFixed(3) + ', ' + (100 * pl.share_in_tail).toFixed(1) + '% in the tail' : ''),
      xlabel: 'bin (values ' + binText(0) + ', ' + binText(1) + ', ' + binText(2) + ', ' + binText(3) + ', …)', xfmt: v => binText(Math.round(v)), xmin: -0.5, xmax: Math.max(...series.map(s => s.points.length)) - 0.5,
      ymin: norm ? 1e-6 : 0.5});
    const ex = d.exposure_by_admission_decile, sat = d.saturation_by_expansion_decile;
    chart(ctx, bl, [{name: 'mean in-degree', colour: colours.all, points: ex.map((e, k) => [k + 1, e.mean_in_degree])},
                    {name: '% singletons / 10', colour: colours['status:new'], dash: true, points: ex.map((e, k) => [k + 1, 10 * e.singletons])}],
      {title: 'Exposure: in-degree by admission decile (search effect)', xlabel: 'admission decile (1 = earliest)', ymin: 0});
    chart(ctx, br, [{name: '% already known', colour: colours.all, points: sat.map(e => [e.expansion_decile + 1, 100 * e.already_known])}],
      {title: 'Saturation: reached classes already known, by expansion decile', xlabel: 'expansion decile of the parent', ymin: 0, ymax: 100});
    hover(c, hits || [], k => '<b>' + k.s.name + '</b><br>values ' + binText(k.p[0]) + ': ' + (norm ? (100 * k.p[1]).toFixed(2) + '%' : num(k.p[1]) + ' classes') + '<br><i>click: filter these classes</i>',
      async k => {
        const get = await perClass(metric), [lo, hi] = binRange(k.p[0]), D = X().D, g = k.s.group;
        const inGroup = g === 'all' ? () => true : g.startsWith('status:') ? i => D.status[i] === ['catalog', 'new', 'seed'].indexOf(g.slice(7)) : i => D.generation[i] === Number(g.slice(11));
        X().setFilter(maskOf(i => (!M.parents_only || D.expanded[i]) && inGroup(i) && get(i) >= lo && get(i) <= hi), metric + ' ' + binText(k.p[0]) + (g === 'all' ? '' : ', ' + g.replace(':', ' ')));
      });
    const s = M.summary;
    $('ainfo').innerHTML = '<b>' + metric + '</b>: ' + num(s.count) + ' values · mean ' + (+s.mean.toPrecision(4)) + ' · median ' + num(s.median) + ' · p90 ' + num(s.p90) + ' · p99 ' + num(s.p99) + ' · max ' + num(s.max) +
      '<br>Spearman correlation of in-degree with admission order: ' + d.spearman_in_degree_vs_admission_order.toFixed(3) + ' (negative: earlier classes were found more often, a search effect).';
    $('ainfo-note').textContent = d.notes;
  }

  // ---------- Feature 4: discovery statistics per generation ----------
  async function generationsView() {
    const g = await analysis('generations'), show = $('gn-show').value, {c, ctx, dpr} = canvasSetup(), colours = GROUP_COLOURS();
    const rows = g.rows, labels = g.labels, k = labels.length;
    const gc = gi => colours['generation:' + gi] || '#888';
    const half = [0, 0, c.width, c.height * 0.55];
    let hits;
    if (show === 'curve' || show === 'newcurve') {
      const series = labels.slice(0, -1).map((l, gi) => ({name: 'generation ' + l, colour: gc(gi), generation: gi,
        points: g.admission_curve.map(b => { const tot = b.per_generation.reduce((a, x) => a + x, 0) || 1;
          return [b.first_id, show === 'curve' ? b.per_generation[gi] / tot * 100 : (b.per_generation[gi] ? 100 * b.new_per_generation[gi] / b.per_generation[gi] : NaN)]; })
          .filter(p => isFinite(p[1]) && (show === 'curve' || p[1] > 0))}));
      hits = chart(ctx, half, series, {title: show === 'curve' ? 'Share of each generation in blocks of ' + num(g.block_ids) + ' admissions (%)' : '% new among the classes of each generation, per block',
        xlabel: 'class id (admission order)', ymin: 0, ymax: 100});
    } else {
      const M = g.parent_child_generation_matrix, rowsum = labels.map((_, i) => M.slice(i * k, (i + 1) * k).reduce((a, b) => a + b, 0));
      const series = labels.slice(0, -1).map((l, gi) => ({name: 'parent generation ' + l, colour: gc(gi), bars: true, offset: gi, generation: gi,
        points: labels.slice(0, -1).map((_, cj) => [cj, rowsum[gi] ? 100 * M[gi * k + cj] / rowsum[gi] : 0])}));
      hits = chart(ctx, half, series, {groups: series.length, title: 'Where the construction pairs of each parent generation lead (% of its edges), all pairs', xlabel: 'child generation',
        xmin: -0.5, xmax: labels.length - 1.5, ymin: 0, ymax: 100, xfmt: v => String(Math.round(v))});
    }
    hover(c, hits || [], h => '<b>' + h.s.name + '</b><br>' + num(Math.round(h.p[0])) + ': ' + h.p[1].toFixed(1) + '%<br><i>click: filter this generation</i>',
      h => X().setFilter(maskOf(i => X().D.generation[i] === h.s.generation), 'generation ' + h.s.generation));
    // Table below the chart.
    const pct = v => (100 * v).toFixed(1) + '%';
    let html = '<table class="gn-table"><tr><td>generation</td><td>classes</td><td>% new</td><td>expanded (frontier)</td><td>new per M cosets</td><td>children first per parent</td><td>mean two, three</td><td>c4 > 0</td><td>median in-degree</td><td>singletons</td><td>ids</td><td></td></tr>';
    rows.forEach((r, gi) => {
      const kids = g.children_per_parent.find(x => String(x.parent_generation) === String(gi));
      html += '<tr><td><b>' + r.generation + '</b></td><td>' + num(r.classes) + '</td><td>' + pct(r.new / Math.max(1, r.new + r.catalog_matching)) + '</td><td>' + num(r.expanded) + ' (' + pct(r.expanded_share) +
        ')</td><td>' + (r.new_per_million_cosets ? r.new_per_million_cosets.toFixed(0) : '—') + '</td><td>' + (kids && kids.expanded_parents ? kids.mean_children_first.toFixed(1) : '—') +
        '</td><td>' + r.mean_two.toFixed(1) + ', ' + r.mean_three.toFixed(1) + '</td><td>' + pct(r.c4_positive) + '</td><td>' + r.median_in_degree + '</td><td>' + pct(r.singletons) +
        '</td><td>' + num(r.first_id) + '–' + num(r.last_id) + '</td><td><button data-g="' + r.generation + '">filter</button></td></tr>';
    });
    $('ainfo').innerHTML = html + '</table>';
    $('ainfo').querySelectorAll('button[data-g]').forEach(b => { b.onclick = () => X().setFilter(maskOf(i => String(X().D.generation[i]) === b.dataset.g), 'generation ' + b.dataset.g); });
    $('ainfo-note').textContent = g.notes;
  }

  // ---------- Features 5 and 6: communities and the condensed community graph ----------
  let cmSel = null;
  async function communitiesView() {
    const c0 = await analysis('communities'), cg = c0.condensed_leiden, key = $('cm-colour').value, top = Number($('cm-top').value) || 300;
    const {c, ctx, dpr} = canvasSetup(), css = X().css;
    const nodes = cg.nodes.slice(0, top), idx = new Set(nodes.map((_, i) => i));
    const val = nd => key === 'gen2' ? nd.generations[2] / Math.max(1, nd.size) : nd[key];
    const vs = nodes.map(val), lo = Math.min(...vs), hi = Math.max(...vs);
    const xs = nodes.map(nd => nd.x), ys = nodes.map(nd => nd.y);
    const pad = 40 * dpr, minx = Math.min(...xs), maxx = Math.max(...xs), miny = Math.min(...ys), maxy = Math.max(...ys);
    const sc = Math.min((c.width - 2 * pad) / ((maxx - minx) || 1), (c.height - 2 * pad) / ((maxy - miny) || 1));
    const P = nd => [pad + (nd.x - minx) * sc + (c.width - 2 * pad - (maxx - minx) * sc) / 2, pad + (nd.y - miny) * sc + (c.height - 2 * pad - (maxy - miny) * sc) / 2];
    const maxSize = Math.max(...nodes.map(nd => nd.size)), R = nd => Math.max(2 * dpr, 34 * dpr * Math.sqrt(nd.size / maxSize));
    // Links: only the strongest share (slider), with opacity by log weight.
    const links = cg.links.filter(l => idx.has(l[0]) && idx.has(l[1])).sort((a, b) => b[2] - a[2]);
    const keep = links.slice(0, Math.round(links.length * Number($('cm-links').value) / 100));
    const wmax = Math.log1p(links.length ? links[0][2] : 1);
    for (const [a, b, w] of keep) {
      const [x1, y1] = P(nodes[a]), [x2, y2] = P(nodes[b]);
      ctx.strokeStyle = css('--muted'); ctx.globalAlpha = 0.08 + 0.5 * Math.log1p(w) / wmax; ctx.lineWidth = dpr * (0.5 + 2 * Math.log1p(w) / wmax);
      ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
    }
    ctx.globalAlpha = 1;
    const hits = [];
    nodes.forEach((nd, i) => {
      const [x, y] = P(nd), r = R(nd);
      ctx.fillStyle = ramp((val(nd) - lo) / ((hi - lo) || 1)); ctx.beginPath(); ctx.arc(x, y, r, 0, 2 * Math.PI); ctx.fill();
      if (cmSel === nd.community) { ctx.strokeStyle = css('--ink'); ctx.lineWidth = 2.5 * dpr; ctx.stroke(); }
      hits.push({x: x - r, y: y - r, w: 2 * r, h: 2 * r, nd});
    });
    const fmt = v => ['novelty', 'c4_positive', 'top_seed_share', 'gen2', 'conductance'].includes(key) ? (100 * v).toFixed(0) + '%' : v.toFixed(1);
    legendBar(fmt(lo), fmt(hi), $('cm-colour').selectedOptions[0].text + ' · area = classes · ' + nodes.length + ' of ' + num(cg.communities_total) + ' communities (' + num(cg.shown_classes) + ' classes)', false);
    hover(c, hits, h => { const nd = h.nd; return '<b>community ' + nd.community + '</b>: ' + num(nd.size) + ' classes<br>' + (100 * nd.novelty).toFixed(1) + '% new · ' + num(nd.seeds) + ' seeds · generations ' + nd.generations.map(num).join(' / ') +
      '<br>mean two ' + nd.mean_two.toFixed(1) + ', three ' + nd.mean_three.toFixed(1) + ' · c4 > 0 ' + (100 * nd.c4_positive).toFixed(1) + '%<br>' + num(nd.seed_lineages) + ' seed lineages, the largest has ' + (100 * nd.top_seed_share).toFixed(1) +
      '% · conductance ' + nd.conductance.toFixed(3) + ' · mean rediscoveries ' + nd.mean_found.toFixed(1); },
      async h => {
        await X().loadCommunities(); cmSel = h.nd.community; const C = X().D.community;
        X().setFilter(maskOf(i => C[i] === cmSel), 'community ' + cmSel + ' (Leiden)');
        const D = X().D, ids = []; for (let i = 0; i < X().n; i++) if (C[i] === cmSel) ids.push(i + 1);
        ids.sort((a, b) => D.found[b - 1] - D.found[a - 1]);
        const link = id => '<button data-id="' + id + '">#' + num(id) + '</button>';
        $('ainfo').innerHTML = '<b>Community ' + cmSel + '</b>: ' + num(ids.length) + ' classes. Most rediscovered: ' + ids.slice(0, 8).map(link).join(' ') + ' <span class="small">(a click selects the class on the map)</span>';
        $('ainfo').querySelectorAll('button[data-id]').forEach(b => { b.onclick = () => { showView('map'); X().select(Number(b.dataset.id)); }; });
        communitiesView();
      });
    if (!cmSel) {
      const A = c0.algorithms, row = (l, f) => '<tr><td>' + l + '</td><td>' + f(A.louvain) + '</td><td>' + f(A.leiden) + '</td></tr>';
      const labels = Object.keys(A.leiden.nmi_with);
      $('ainfo').innerHTML = '<table class="gn-table"><tr><td></td><td>Louvain</td><td>Leiden</td></tr>' +
        row('communities', a => num(a.communities)) + row('modularity Q', a => a.modularity.toFixed(4)) + row('disconnected communities', a => num(a.disconnected_communities)) +
        row('time', a => a.seconds.toFixed(1) + ' s') + row('well-separated (conductance < 0.1)', a => a.well_separated_communities === undefined ? '—' : num(a.well_separated_communities)) +
        labels.map(l => row('NMI with ' + l, a => a.nmi_with[l].toFixed(3))).join('') + '</table>' +
        (A.null_configuration_model ? 'Null model (random graph with the same degrees, Leiden): ' + num(A.null_configuration_model.communities) + ' communities, Q = ' +
          A.null_configuration_model.modularity.toFixed(4) + ', ' + num(A.null_configuration_model.well_separated_communities) + ' well separated. ' : '') +
        'Graph: ' + num(c0.graph.nodes) + ' classes, ' + num(c0.graph.edges) + ' undirected edges.';
    }
    $('ainfo-note').textContent = c0.notes;
  }

  // ---------- view switching ----------
  const RENDER = {heatmap: heatmapView, transitions: transitionsView, distributions: distributionsView, generations: generationsView, communities: communitiesView};
  function showView(v) {
    view = v;
    document.querySelectorAll('#view-tabs button').forEach(b => b.classList.toggle('active', b.dataset.view === v));
    $('analysis-view').hidden = v === 'map';
    document.querySelectorAll('.aview-controls').forEach(e => { e.hidden = e.dataset.view !== v; });
    if (v === 'map') { X().redraw(); return; }
    $('atip').hidden = true;
    RENDER[v]().catch(e => { $('ainfo').textContent = String(e.message || e); });
  }
  function init() {
    if (!X() || !X().D || !X().D.two) { setTimeout(init, 300); return; }
    document.querySelectorAll('#view-tabs button').forEach(b => { b.onclick = () => showView(b.dataset.view); });
    for (const id of ['hm-pair', 'hm-metric', 'hm-min']) $(id).oninput = () => heatmapView();
    for (const id of ['tr-field', 'tr-set', 'tr-mode']) $(id).oninput = () => transitionsView();
    for (const id of ['ds-metric', 'ds-by', 'ds-norm']) $(id).oninput = () => distributionsView();
    $('gn-show').oninput = () => generationsView();
    for (const id of ['cm-colour', 'cm-links', 'cm-top']) $(id).oninput = () => communitiesView();
    $('filter-map').onclick = () => showView('map');
    $('filter-clear').onclick = () => { X().setFilter(null, ''); hmSel = trSel = cmSel = null; if (view !== 'map') showView(view); };
    document.addEventListener('apn-show-map', () => showView('map'));
    window.addEventListener('resize', () => { if (view !== 'map') showView(view); });
  }
  init();
})();
