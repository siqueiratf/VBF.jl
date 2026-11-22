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

  // ---------- view switching ----------
  const RENDER = {heatmap: heatmapView, transitions: transitionsView};
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
    $('filter-map').onclick = () => showView('map');
    $('filter-clear').onclick = () => { X().setFilter(null, ''); hmSel = trSel = null; if (view !== 'map') showView(view); };
    document.addEventListener('apn-show-map', () => showView('map'));
    window.addEventListener('resize', () => { if (view !== 'map') showView(view); });
  }
  init();
})();
