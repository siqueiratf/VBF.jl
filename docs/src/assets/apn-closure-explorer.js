'use strict';
// Class explorer: admitted classes in admission order with a time slider,
// free axes and colours, a parent -> child drift field and in-browser video
// MP4 export. Data: /explorer-data/<version>/*.{i16,i8,u8,u16,u32,f32} from
// tools/analysis/explorer_data.py (index = class id - 1).
(() => {
  const $ = id => document.getElementById(id);
  const number = v => Number(v).toLocaleString();
  const css = name => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  const hexRGB = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16) / 255);
  const AXES = [  // code, label, unit
    [0, 'two: 2-dim subspaces (nonbent set)'], [1, 'three: 3-dim nonbent subspaces'], [2, 'admission order (class id)'],
    [3, 'admission time (hours since the start)'], [4, 'generation (distance from a seed)'],
    [5, 'rediscoveries, log2(1 + paths)'], [6, 'distinct finders, log2(1 + parents)'],
    [7, 'maximizing 5-spaces as a parent, log2(1 + n)'], [8, 'new classes reached as a parent'],
    [9, 'du: differential uniformity of the ortho-derivative'], [10, 'c4: components of rank 4'],
    [11, 'four: entry 4 of the nonbent signature'], [12, 'c2: components of rank 2']];
  let meta, D = {}, n = 0, gl, program, vao, loc = {}, view = null, cut = 1, playing = false, timer = null;
  let selected = 0, children = [], driftCache = null;

  // ---------- data ----------
  async function load() {
    const current = await (await fetch('/explorer-data/current.json', {cache: 'no-store'})).json();
    meta = await (await fetch('/explorer-data/' + current.version + '/meta.json')).json();
    n = meta.count;
    const types = {i16: Int16Array, i8: Int8Array, u8: Uint8Array, u16: Uint16Array, u32: Uint32Array, f32: Float32Array};
    let done = 0;
    const names = Object.keys(meta.fields);
    await Promise.all(names.map(async name => {
      const buffer = await (await fetch('/explorer-data/' + meta.version + '/' + name)).arrayBuffer();
      D[name.split('.')[0]] = new types[name.split('.')[1]](buffer);
      $('message').textContent = 'Loading the data… ' + (++done) + ' of ' + names.length + ' arrays';
    }));
    $('summary').textContent = number(n) + ' classes · ' + number(meta.seeds) + ' seeds · ' + number(meta.new) + ' new · ' +
      number(meta.catalog) + ' catalog-matching · generations up to ' + meta.generation_max + ' · data ' + meta.version.slice(0, 15);
    $('provenance').textContent = 'Data version ' + meta.version + '; time origin ' + meta.time_origin_utc + '.';
  }

  // ---------- WebGL ----------
  const VS = `#version 300 es
  in float a_two, a_three, a_status, a_method, a_gen, a_family, a_time, a_found, a_finders; in vec2 a_jit;
  in float a_exp, a_spaces, a_cosets, a_rnew; in vec4 a_inv;
  uniform int u_x, u_y, u_colour, u_show, u_onlyExp; uniform vec4 u_view; uniform float u_cut, u_window, u_point, u_alpha;
  uniform float u_genMax, u_timeMax, u_foundMax, u_spacesMax, u_rnewMax, u_rateMax; uniform vec3 u_pal[4]; uniform vec3 u_meth[3]; uniform int u_sel;
  out vec4 v_colour;
  float axis(int c) {
    if (c == 0) return a_two + a_jit.x * 0.8;
    if (c == 1) return a_three + a_jit.y * 0.4;
    if (c == 2) return float(gl_VertexID + 1);
    if (c == 3) return a_time / 3600.0;
    if (c == 4) return a_gen + a_jit.y * 0.4;
    if (c == 5) return log2(1.0 + a_found) + a_jit.y * 0.08;
    if (c == 6) return log2(1.0 + a_finders) + a_jit.y * 0.08;
    if (c == 7) return log2(1.0 + a_spaces) + a_jit.y * 0.08;
    if (c == 8) return a_rnew + a_jit.y * 0.4;
    if (c == 9) return a_inv.x + a_jit.y * 0.8;
    if (c == 10) return a_inv.y + a_jit.y * 0.35;
    if (c == 11) return a_inv.w + a_jit.y * 0.35;
    return a_inv.z + a_jit.y * 0.35;
  }
  vec3 ramp(float t) {  // perceptual-ish blue -> green -> yellow
    t = clamp(t, 0.0, 1.0);
    return mix(mix(vec3(0.18,0.15,0.55), vec3(0.13,0.57,0.55), smoothstep(0.0,0.5,t)), vec3(0.99,0.88,0.15), smoothstep(0.5,1.0,t));
  }
  vec3 hue(float h) { vec3 k = abs(fract(h + vec3(0.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0); return 0.15 + 0.7 * clamp(k - 1.0, 0.0, 1.0); }
  void main() {
    int st = int(a_status + 0.5);
    bool needsInv = u_x <= 1 || u_y <= 1 || u_x >= 9 || u_y >= 9 || u_colour >= 9;
    if (((u_show >> st) & 1) == 0 || (u_onlyExp == 1 && a_exp < 0.5) || (needsInv && a_two < 0.0) || (u_x == 4 || u_y == 4) && a_gen > 65000.0) { gl_Position = vec4(2.0, 2.0, 0.0, 1.0); gl_PointSize = 0.0; v_colour = vec4(0.0); return; }
    vec2 p = vec2(axis(u_x), axis(u_y));
    gl_Position = vec4((p.x - u_view.x) / (u_view.y - u_view.x) * 2.0 - 1.0, (p.y - u_view.z) / (u_view.w - u_view.z) * 2.0 - 1.0, 0.0, 1.0);
    gl_PointSize = u_point;
    float age = u_cut - float(gl_VertexID);
    vec3 c;
    if (u_colour == 0) c = u_pal[st];
    else if (u_colour == 1) c = ramp(a_gen / u_genMax);
    else if (u_colour == 2) c = u_meth[int(a_method + 0.5)];
    else if (u_colour == 3) c = ramp(a_time / u_timeMax);
    else if (u_colour == 4) c = hue(a_family / 24.0 + 0.03);
    else if (u_colour == 5) c = ramp(log2(1.0 + a_found) / log2(1.0 + u_foundMax));
    else if (u_colour == 7) c = a_exp > 0.5 ? ramp(log2(1.0 + a_rnew) / log2(1.0 + u_rnewMax)) : u_pal[3] * 0.6;
    else if (u_colour == 8) c = a_exp > 0.5 ? ramp(1e6 * a_rnew / max(a_cosets, 1.0) / u_rateMax) : u_pal[3] * 0.6;
    else if (u_colour == 9) c = ramp((a_inv.x - 8.0) / 20.0);
    else if (u_colour == 10) c = a_inv.y < 0.5 ? u_pal[0] : a_inv.y < 1.5 ? u_pal[2] : a_inv.y < 2.5 ? u_pal[1] : vec3(0.1);
    else c = ramp(1.0 - clamp(age / max(u_window, 1.0), 0.0, 1.0));
    float a = u_alpha;
    if (u_window > 0.0) a *= age <= u_window ? 1.0 : 0.12;
    if (u_sel > 0 && gl_VertexID + 1 == u_sel) { gl_PointSize = max(u_point * 3.0, 7.0); a = 1.0; }
    v_colour = vec4(c, a);
  }`;
  const FS = `#version 300 es
  precision mediump float; in vec4 v_colour; out vec4 o;
  void main() { if (v_colour.a <= 0.0) discard; o = vec4(v_colour.rgb * v_colour.a, v_colour.a); }`;

  function setupGL() {
    gl = $('gl').getContext('webgl2', {antialias: false, preserveDrawingBuffer: true, premultipliedAlpha: true});
    if (!gl) throw new Error('This page needs WebGL2.');
    const shader = (type, src) => { const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s)); return s; };
    program = gl.createProgram();
    gl.attachShader(program, shader(gl.VERTEX_SHADER, VS)); gl.attachShader(program, shader(gl.FRAGMENT_SHADER, FS));
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program));
    vao = gl.createVertexArray(); gl.bindVertexArray(vao);
    const attr = (name, data, type, size, normalized) => {
      const l = gl.getAttribLocation(program, name); if (l < 0) return;
      const b = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, b); gl.bufferData(gl.ARRAY_BUFFER, data, gl.STATIC_DRAW);
      gl.enableVertexAttribArray(l); gl.vertexAttribPointer(l, size, type, normalized, 0, 0);
    };
    attr('a_two', D.two, gl.SHORT, 1, false); attr('a_three', D.three, gl.SHORT, 1, false);
    attr('a_jit', D.jitter, gl.BYTE, 2, true); attr('a_status', D.status, gl.UNSIGNED_BYTE, 1, false);
    attr('a_method', D.method, gl.UNSIGNED_BYTE, 1, false); attr('a_gen', D.generation, gl.UNSIGNED_SHORT, 1, false);
    attr('a_family', D.family, gl.UNSIGNED_BYTE, 1, false); attr('a_time', D.time, gl.FLOAT, 1, false);
    attr('a_found', D.found, gl.UNSIGNED_SHORT, 1, false); attr('a_finders', D.finders, gl.UNSIGNED_BYTE, 1, false);
    if (D.expanded) {
      attr('a_exp', D.expanded, gl.UNSIGNED_BYTE, 1, false); attr('a_spaces', D.spaces, gl.UNSIGNED_SHORT, 1, false);
      attr('a_cosets', D.cosets, gl.FLOAT, 1, false); attr('a_rnew', D.reached_new, gl.UNSIGNED_SHORT, 1, false);
    }
    if (D.inv) attr('a_inv', D.inv, gl.UNSIGNED_BYTE, 4, false);
    for (const u of ['u_x', 'u_y', 'u_colour', 'u_show', 'u_view', 'u_cut', 'u_window', 'u_point', 'u_alpha', 'u_genMax',
      'u_timeMax', 'u_foundMax', 'u_pal', 'u_meth', 'u_sel', 'u_onlyExp', 'u_spacesMax', 'u_rnewMax', 'u_rateMax']) loc[u] = gl.getUniformLocation(program, u);
  }

  // ---------- view ----------
  const axisCode = id => Number($(id).value);
  function range(code) {
    const pad = (a, b, f) => { const d = (b - a) * f || 1; return [a - d, b + d]; };
    if (code === 0) return pad(meta.two_range[0], meta.two_range[1], 0.03);
    if (code === 1) return pad(meta.three_range[0], meta.three_range[1], 0.04);
    if (code === 2) return pad(0, n, 0.01);
    if (code === 3) return pad(0, meta.time_span_seconds / 3600, 0.01);
    if (code === 4) return pad(0, meta.generation_max, 0.03);
    if (code === 5) return pad(0, Math.log2(1 + meta.found_max), 0.03);
    if (code === 7) return pad(0, Math.log2(1 + (meta.spaces_max || 1)), 0.03);
    if (code === 8) return pad(0, Math.min(meta.reached_new_max || 1, 400), 0.03);
    if (code === 9) return pad((meta.du_range || [8, 62])[0], (meta.du_range || [8, 62])[1], 0.04);
    if (code === 10) return pad(0, 4, 0.08);
    if (code === 11) return pad(0, 2, 0.1);
    if (code === 12) return pad(0, 1, 0.15);
    return pad(0, 8, 0.03);
  }
  function fitView() { const x = range(axisCode('x-axis')), y = range(axisCode('y-axis')); return [x[0], x[1], y[0], y[1]]; }
  function fit() { view = fitView(); draw(); }
  let textScale = 1;  // larger text in exported videos
  function size() {
    const dpr = window.devicePixelRatio || 1;
    for (const c of [$('gl'), $('overlay')]) {
      const w = Math.round(c.clientWidth * dpr), h = Math.round(c.clientHeight * dpr);
      if (c.width !== w || c.height !== h) { c.width = w; c.height = h; }
    }
  }
  const toScreen = (x, y) => [($('gl').width) * (x - view[0]) / (view[1] - view[0]), ($('gl').height) * (1 - (y - view[2]) / (view[3] - view[2]))];
  const toData = (sx, sy) => [view[0] + sx / $('gl').width * (view[1] - view[0]), view[2] + (1 - sy / $('gl').height) * (view[3] - view[2])];
  function showMask() { let m = 0; document.querySelectorAll('.show').forEach(c => { if (c.checked) m |= 1 << Number(c.value); }); return m; }
  const trail = () => $('trail-on').checked ? Math.max(1, Number($('trail').value) || 1) : 0;

  let pending = false;
  function draw() { if (!pending) { pending = true; requestAnimationFrame(() => { pending = false; render(); }); } }
  function render() {
    size();
    const dpr = window.devicePixelRatio || 1;
    gl.viewport(0, 0, $('gl').width, $('gl').height);
    const bg = hexRGB(css('--bg')); gl.clearColor(bg[0], bg[1], bg[2], 1); gl.clear(gl.COLOR_BUFFER_BIT);
    gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
    gl.useProgram(program); gl.bindVertexArray(vao);
    gl.uniform1i(loc.u_x, axisCode('x-axis')); gl.uniform1i(loc.u_y, axisCode('y-axis'));
    gl.uniform1i(loc.u_colour, Number($('colour').value)); gl.uniform1i(loc.u_show, showMask());
    gl.uniform4f(loc.u_view, view[0], view[1], view[2], view[3]);
    gl.uniform1f(loc.u_cut, cut); gl.uniform1f(loc.u_window, trail());
    gl.uniform1f(loc.u_point, Number($('point').value) * dpr); gl.uniform1f(loc.u_alpha, Number($('alpha').value) / 100);
    gl.uniform1f(loc.u_genMax, Math.max(1, meta.generation_max)); gl.uniform1f(loc.u_timeMax, Math.max(1, meta.time_span_seconds));
    gl.uniform1f(loc.u_foundMax, Math.max(1, meta.found_max)); gl.uniform1i(loc.u_sel, selected);
    gl.uniform1i(loc.u_onlyExp, $('only-expanded').checked ? 1 : 0); gl.uniform1f(loc.u_spacesMax, Math.max(1, meta.spaces_max || 1));
    gl.uniform1f(loc.u_rnewMax, Math.max(1, meta.reached_new_max || 1)); gl.uniform1f(loc.u_rateMax, Math.max(1, meta.new_per_mcoset_p99 || 1));
    gl.uniform3fv(loc.u_pal, [...hexRGB(css('--found')), ...hexRGB(css('--fresh')), ...hexRGB(css('--seed')), ...hexRGB(css('--unknown'))]);
    gl.uniform3fv(loc.u_meth, [...hexRGB(css('--seed')), ...hexRGB(css('--found')), ...hexRGB(css('--fresh'))]);
    gl.drawArrays(gl.POINTS, 0, Math.max(0, Math.min(cut, n)));
    overlay();
    label();
  }

  // ---------- overlay: axes, drift arrows, lineage ----------
  function ticks(a, b, count) {
    const step = Math.pow(10, Math.floor(Math.log10((b - a) / count))); const m = [1, 2, 5, 10].find(k => (b - a) / (step * k) <= count) * step;
    const out = []; for (let v = Math.ceil(a / m) * m; v <= b; v += m) out.push(+v.toPrecision(12)); return out;
  }
  function overlay() {
    const c = $('overlay'), ctx = c.getContext('2d'), dpr = window.devicePixelRatio || 1, k = dpr * textScale;
    ctx.clearRect(0, 0, c.width, c.height);
    const xt = ticks(view[0], view[1], 8), yt = ticks(view[2], view[3], 6);
    if ($('grid').checked) {  // reference lines at the axis ticks
      ctx.save(); ctx.strokeStyle = css('--muted'); ctx.globalAlpha = 0.28; ctx.lineWidth = Math.max(1, dpr * Math.sqrt(textScale));
      ctx.beginPath();
      for (const v of xt) { const [x] = toScreen(v, 0); ctx.moveTo(Math.round(x) + 0.5, 0); ctx.lineTo(Math.round(x) + 0.5, c.height); }
      for (const v of yt) { const [, y] = toScreen(0, v); ctx.moveTo(0, Math.round(y) + 0.5); ctx.lineTo(c.width, Math.round(y) + 0.5); }
      ctx.stroke(); ctx.restore();
    }
    ctx.font = (11 * k) + 'px system-ui,sans-serif'; ctx.fillStyle = css('--muted'); ctx.strokeStyle = css('--border');
    for (const v of xt) { const [x] = toScreen(v, 0); ctx.fillRect(x, c.height - 6 * k, Math.max(1, textScale), 6 * k); ctx.fillText(number(v), x + 3 * k, c.height - 8 * k); }
    for (const v of yt) { const [, y] = toScreen(0, v); ctx.fillRect(0, y, 6 * k, Math.max(1, textScale)); ctx.fillText(number(v), 8 * k, y - 3 * k); }
    ctx.fillText('x: ' + AXES[axisCode('x-axis')][1] + '   ·   y: ' + AXES[axisCode('y-axis')][1], 8 * k, 14 * k);
    if ($('drift').checked) arrows(ctx, dpr);
    if (selected) lineage(ctx, dpr);
  }
  function position(id) {
    const i = id - 1, x = axisCode('x-axis'), y = axisCode('y-axis');
    const v = c => c === 0 ? D.two[i] + D.jitter[2 * i] / 127 * 0.8 : c === 1 ? D.three[i] + D.jitter[2 * i + 1] / 127 * 0.4 :
      c === 2 ? id : c === 3 ? D.time[i] / 3600 : c === 4 ? D.generation[i] : c === 5 ? Math.log2(1 + D.found[i]) :
      c === 6 ? Math.log2(1 + D.finders[i]) : c === 7 ? Math.log2(1 + (D.spaces ? D.spaces[i] : 0)) :
      c === 8 ? (D.reached_new ? D.reached_new[i] : 0) : c === 9 ? D.inv[4 * i] : c === 10 ? D.inv[4 * i + 1] : c === 11 ? D.inv[4 * i + 3] : D.inv[4 * i + 2];
    if ((x <= 1 || y <= 1 || x >= 9 || y >= 9) && D.two[i] < 0) return null;
    return toScreen(v(x), v(y));
  }
  function lineage(ctx, dpr) {
    ctx.lineWidth = 1.5 * dpr; ctx.strokeStyle = css('--ink'); ctx.beginPath();
    let id = selected, first = true, guard = 0;
    while (id > 0 && guard++ < 10000) {
      const p = position(id); if (!p) break;
      first ? ctx.moveTo(p[0], p[1]) : ctx.lineTo(p[0], p[1]); first = false;
      id = D.discoverer[id - 1];
    }
    ctx.stroke();
    ctx.fillStyle = css('--fresh');
    for (const k of children) { if (k > cut) continue; const p = position(k); if (p) ctx.fillRect(p[0] - 2 * dpr, p[1] - 2 * dpr, 4 * dpr, 4 * dpr); }
  }
  function driftField() {
    const cw = Number($('drift-cell').value), ch = cw / 2, only = $('drift-trail').checked ? trail() : 0;
    const key = [cut, cw, only].join();
    if (driftCache && driftCache.key === key) return driftCache;
    const cells = new Map(), start = only ? Math.max(0, cut - only) : 0;
    let total = 0, sumDx = 0, sumDy = 0, down = 0, right = 0;
    for (let i = start; i < cut; i++) {
      const d = D.discoverer[i]; if (!d) continue;
      const j = d - 1; if (D.two[i] < 0 || D.two[j] < 0) continue;
      const k = Math.floor(D.two[j] / cw) * 100000 + Math.floor(D.three[j] / ch);
      let c = cells.get(k); if (!c) { c = {x: 0, y: 0, dx: 0, dy: 0, n: 0}; cells.set(k, c); }
      const dx = D.two[i] - D.two[j], dy = D.three[i] - D.three[j];
      c.x += D.two[j]; c.y += D.three[j]; c.dx += dx; c.dy += dy; c.n++;
      total++; sumDx += dx; sumDy += dy; if (dy < 0) down++; if (dx > 0) right++;
    }
    driftCache = {key, cells, total, meanDx: sumDx / (total || 1), meanDy: sumDy / (total || 1), down: down / (total || 1), right: right / (total || 1)};
    return driftCache;
  }
  function arrows(ctx, dpr) {
    if (axisCode('x-axis') !== 0 || axisCode('y-axis') !== 1) { ctx.fillText('The drift field needs X = two and Y = three.', 8 * dpr, 30 * dpr); return; }
    const f = driftField(), min = Number($('drift-min').value) || 1, scale = Number($('drift-scale').value);
    let maxN = 1; for (const c of f.cells.values()) maxN = Math.max(maxN, c.n);
    ctx.strokeStyle = css('--ink'); ctx.fillStyle = css('--ink');
    for (const c of f.cells.values()) {
      if (c.n < min) continue;
      const x = c.x / c.n, y = c.y / c.n, [ax, ay] = toScreen(x, y), [bx, by] = toScreen(x + scale * c.dx / c.n, y + scale * c.dy / c.n);
      ctx.globalAlpha = 0.35 + 0.65 * Math.sqrt(c.n / maxN); ctx.lineWidth = (0.8 + 2.5 * Math.sqrt(c.n / maxN)) * dpr;
      ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(bx, by); ctx.stroke();
      const t = Math.atan2(by - ay, bx - ax), h = 5 * dpr;
      ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(bx - h * Math.cos(t - 0.45), by - h * Math.sin(t - 0.45)); ctx.lineTo(bx - h * Math.cos(t + 0.45), by - h * Math.sin(t + 0.45)); ctx.fill();
    }
    ctx.globalAlpha = 1;
    $('drift-summary').innerHTML = '<tr><td>parent → child pairs</td><td>' + number(f.total) + '</td></tr>' +
      '<tr><td>mean Δtwo</td><td>' + f.meanDx.toFixed(2) + '</td></tr><tr><td>mean Δthree</td><td>' + f.meanDy.toFixed(2) + '</td></tr>' +
      '<tr><td>children lower in three</td><td>' + (100 * f.down).toFixed(1) + '%</td></tr><tr><td>children right in two</td><td>' + (100 * f.right).toFixed(1) + '%</td></tr>';
  }

  // ---------- labels and statistics ----------
  function when(i) { return new Date(Date.parse(meta.time_origin_utc) + 1000 * D.time[Math.max(0, i - 1)]).toISOString().slice(0, 16).replace('T', ' ') + ' UTC'; }
  function label() {
    $('cut-label').textContent = number(cut) + ' of ' + number(n) + ' classes · ' + (cut ? when(cut) : '');
  }
  let statsTimer = null;
  function stats() {
    clearTimeout(statsTimer);
    statsTimer = setTimeout(() => {
      const w = trail(), start = w ? Math.max(0, cut - w) : 0;
      const s = [0, 0, 0, 0], m = [0, 0, 0]; let gsum = 0, gk = 0, f1 = 0, ex = 0, rn = 0, co = 0;
      for (let i = start; i < cut; i++) {
        s[D.status[i]]++; m[D.method[i]]++; if (D.generation[i] < 65535) { gsum += D.generation[i]; gk++; } if (D.found[i] === 1) f1++;
        if (D.expanded && D.expanded[i]) { ex++; rn += D.reached_new[i]; co += D.cosets[i]; }
      }
      const tot = cut - start || 1, pct = v => (100 * v / tot).toFixed(1) + '%';
      $('stats').innerHTML = '<tr><td>' + (w ? 'Trail (last ' + number(cut - start) + ')' : 'All shown') + '</td><td>' + number(cut - start) + '</td></tr>' +
        '<tr><td>new</td><td>' + pct(s[1]) + '</td></tr><tr><td>catalog-matching</td><td>' + pct(s[0]) + '</td></tr>' +
        '<tr><td>found by v5 / switching</td><td>' + pct(m[1]) + ' / ' + pct(m[2]) + '</td></tr>' +
        '<tr><td>mean generation</td><td>' + (gsum / (gk || 1)).toFixed(2) + '</td></tr>' +
        '<tr><td>found only once (singletons)</td><td>' + pct(f1) + '</td></tr>' +
        (D.expanded ? '<tr><td>expanded parents</td><td>' + number(ex) + '</td></tr><tr><td>their new classes per million cosets</td><td>' + (co ? (1e6 * rn / co).toFixed(0) : '—') + '</td></tr>' : '');
    }, 120);
  }
  function legend() {
    const mode = Number($('colour').value), L = $('legend'), G = $('gradient'), GL = $('gradient-labels');
    const dot = (colour, text) => '<span><i style="background:' + colour + '"></i>' + text + '</span>';
    G.hidden = true; GL.textContent = '';
    if (mode === 0) L.innerHTML = dot(css('--seed'), 'seeds') + dot(css('--found'), 'catalog-matching') + dot(css('--fresh'), 'new') + dot(css('--unknown'), 'unknown');
    else if (mode === 2) L.innerHTML = dot(css('--seed'), 'seed') + dot(css('--found'), 'v5') + dot(css('--fresh'), 'switching');
    else if (mode === 4) L.innerHTML = '<span class="small">24 colours, one per group of seed lineages</span>';
    else if (mode === 10) L.innerHTML = dot(css('--found'), 'c4 = 0') + dot(css('--seed'), 'c4 = 1') + dot(css('--fresh'), 'c4 = 2') + dot('#1a1a1a', 'c4 ≥ 3');
    else if (mode === 9) { L.innerHTML = ''; G.hidden = false; G.style.background = 'linear-gradient(90deg,#2e268c,#21928c,#fde026)'; GL.textContent = 'du 8 … 28 and more'; }
    else if (mode === 7 || mode === 8) {
      L.innerHTML = dot(css('--unknown'), 'not an expanded parent'); G.hidden = false; G.style.background = 'linear-gradient(90deg,#2e268c,#21928c,#fde026)';
      GL.textContent = mode === 7 ? '0 … ' + number(meta.reached_new_max) + ' new classes reached (log)' : '0 … ' + Math.round(meta.new_per_mcoset_p99) + ' new per million cosets (99th percentile)';
    }
    else {
      L.innerHTML = ''; G.hidden = false; G.style.background = 'linear-gradient(90deg,#2e268c,#21928c,#fde026)';
      GL.textContent = mode === 1 ? '0 … ' + meta.generation_max + ' generations' : mode === 3 ? 'start … ' + (meta.time_span_seconds / 3600).toFixed(0) + ' h' :
        mode === 5 ? '1 … ' + number(meta.found_max) + ' paths (log)' : 'older … newest in the trail';
    }
  }

  // ---------- selection ----------
  function select(id) {
    if (!(id >= 1 && id <= n)) return;
    selected = id; children = [];
    for (let i = id; i < n; i++) if (D.discoverer[i] === id) children.push(i + 1);
    const i = id - 1, st = ['catalog-matching', 'new', 'published seed', 'unknown'][D.status[i]], me = ['seed or none', 'v5', 'switching'][D.method[i]];
    const link = v => v ? '<button data-id="' + v + '">#' + v + '</button>' : '—';
    let chain = [], a = D.discoverer[i], guard = 0; while (a && guard++ < 6) { chain.push(a); a = D.discoverer[a - 1]; }
    $('info-title').textContent = 'Class #' + number(id);
    $('info').innerHTML = '<table class="small">' +
      '<tr><td>status</td><td>' + st + '</td></tr><tr><td>two, three, four</td><td>' + (D.two[i] >= 0 ? D.two[i] + ', ' + D.three[i] + (D.inv ? ', ' + D.inv[4 * i + 3] : '') : 'not measured') + '</td></tr>' +
      (D.inv && D.two[i] >= 0 ? '<tr><td>du, c4, c2</td><td>' + D.inv[4 * i] + ', ' + D.inv[4 * i + 1] + ', ' + D.inv[4 * i + 2] + '</td></tr>' : '') +
      '<tr><td>admitted</td><td>' + when(id) + '</td></tr><tr><td>generation</td><td>' + (D.generation[i] < 65535 ? D.generation[i] : 'unknown') + '</td></tr>' +
      '<tr><td>found first by</td><td>' + link(D.discoverer[i]) + ' (' + me + ')</td></tr><tr><td>seed of the lineage</td><td>' + link(D.root[i]) + '</td></tr>' +
      '<tr><td>ancestors</td><td>' + (chain.length ? chain.map(link).join(' ') : '—') + '</td></tr>' +
      '<tr><td>rediscoveries</td><td>' + number(D.found[i]) + ' paths, ' + D.finders[i] + ' parents</td></tr>' +
      '<tr><td>children found first</td><td>' + number(children.length) + '</td></tr>' +
      (D.expanded ? '<tr><td>as a parent</td><td>' + (D.expanded[i] ? 'expanded' : 'not expanded yet') + ', ' + number(D.spaces[i]) + ' 5-spaces, ' +
        number(Math.round(D.cosets[i])) + ' cosets, ' + number(D.reached[i]) + ' classes reached, ' + number(D.reached_new[i]) + ' new' +
        (D.expanded[i] && D.cosets[i] > 0 ? ' (' + (1e6 * D.reached_new[i] / D.cosets[i]).toFixed(0) + ' per million cosets)' : '') + '</td></tr>' : '') + '</table>' +
      '<div class="row"><input id="find-id" type="number" min="1" value="' + id + '"><button id="find">Select</button><button id="clear">Clear</button></div>';
    $('info').querySelectorAll('button[data-id]').forEach(b => { b.onclick = () => select(Number(b.dataset.id)); });
    $('find').onclick = () => select(Number($('find-id').value)); $('clear').onclick = () => { selected = 0; children = []; $('info-title').textContent = 'Selected class'; draw(); };
    draw();
  }
  function pick(sx, sy) {
    const dpr = window.devicePixelRatio || 1, mask = showMask(); let best = 0, bestD = (8 * dpr) ** 2;
    for (let id = 1; id <= cut; id++) {
      if (!((mask >> D.status[id - 1]) & 1)) continue;
      const p = position(id); if (!p) continue;
      const d = (p[0] - sx) ** 2 + (p[1] - sy) ** 2; if (d < bestD) { bestD = d; best = id; }
    }
    if (best) select(best);
  }

  // ---------- time ----------
  function setCut(v) { cut = Math.max(0, Math.min(n, Math.round(v))); $('cut').value = cut; driftCache = null; draw(); stats(); }
  function bounds() { const a = Math.max(0, Number($('from').value) || 0), b = Math.min(n, Number($('to').value) || n); return [a, Math.max(a + 1, b)]; }
  function step(sign) { setCut(cut + sign * Math.max(1, Number($('per-step').value) || 1)); }
  function play(start) {
    if (playing) { stopPlay(); return; }
    const [a, b] = bounds(); if (start || cut >= b) setCut(a);
    playing = true; $('play').textContent = '⏸';
    const tick = () => {
      if (!playing) return;
      if (cut >= b) { stopPlay(); return; }
      setCut(Math.min(b, cut + Math.max(1, Number($('per-step').value) || 1)));
      timer = setTimeout(tick, 1000 * Math.max(0.02, Number($('seconds').value) || 0.2));
    };
    timer = setTimeout(tick, 1000 * Math.max(0.02, Number($('seconds').value) || 0.2));
  }
  function stopPlay() { playing = false; clearTimeout(timer); $('play').textContent = '▶'; }

  // ---------- video settings and server-side MP4 ----------
  const settings = () => ({per: Math.max(1, Number($('per-step').value) || 1), sec: Math.min(10, Math.max(0.02, Number($('seconds').value) || 0.2)),
    hold: Math.min(60, Math.max(0, Number($('hold').value) || 0))});
  function frameCount() { const [a0, b0] = bounds(); return Math.max(1, Math.ceil((b0 - a0) / settings().per)); }
  function showLength() { const s = settings(); $('video-length').value = (frameCount() * s.sec + s.hold).toFixed(1); }
  function lengthChanged() {
    const s = settings(), len = Number($('video-length').value);
    if (!(len > 0)) return;
    const sec = Math.min(10, Math.max(0.02, (len - s.hold) / frameCount()));
    $('seconds').value = +sec.toFixed(3); $('seconds-range').value = Math.min(1, sec);
  }
  // The video is made on the server (explorer_video.py through the vlab dashboard):
  // every frame is computed at the chosen size in the Fit view, independent of the screen.
  let videoBusy = false;
  async function exportMP4() {
    if (videoBusy) {
      await fetch('/control/explorer/video', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({cancel: true})});
      $('export-state').textContent = 'Cancelling…'; return;
    }
    const r = await fetch('/control/explorer/video', {method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({params: currentState().toString()})});
    if (r.status === 404) { $('export-state').textContent = 'The video export needs the vlab dashboard (it renders on the server).'; return; }
    if (r.status >= 400) { $('export-state').textContent = ((await r.json().catch(() => ({}))).error) || 'HTTP ' + r.status; return; }
    videoBusy = true; $('export-video').textContent = '■ Cancel'; $('export-video').classList.add('recording');
    const started = performance.now();
    const poll = async () => {
      let s;
      try { s = await (await fetch('/control/explorer/video', {cache: 'no-store'})).json(); } catch (e) { setTimeout(poll, 1500); return; }
      if (s.busy) {
        $('export-state').textContent = s.frames ? 'Rendering frame ' + number(s.frame) + ' of ' + number(s.frames) + ' (' + Math.round(100 * s.frame / s.frames) + '%)…' : 'Preparing (' + (s.phase || '') + ')…';
        setTimeout(poll, 700); return;
      }
      videoBusy = false; $('export-video').textContent = '⬇ Download MP4'; $('export-video').classList.remove('recording');
      if (s.phase !== 'done' || !s.file) { $('export-state').textContent = s.last_error === 'cancelled' ? 'Cancelled.' : 'Video failed: ' + (s.last_error || s.phase); return; }
      const a = document.createElement('a'); a.href = '/control/explorer/video/file?name=' + encodeURIComponent(s.file); a.download = s.file; a.click();
      $('export-state').textContent = 'Saved ' + s.file + ': ' + (s.bytes / 1e6).toFixed(1) + ' MB, ' + s.video_seconds + ' s, ' + s.width + ' × ' + s.height +
        ', made in ' + ((performance.now() - started) / 1000).toFixed(0) + ' s. ';
      const again = document.createElement('a'); again.href = a.href; again.download = s.file; again.textContent = 'Download again';
      $('export-state').append(again);
    };
    poll();
  }

  // ---------- view state (link, templates) ----------
  // Keys: x y colour point alpha show expanded trail drift dtrail dcell dmin dscale step sec from to cut id view play
  const FIELDS = {x: 'x-axis', y: 'y-axis', colour: 'colour', point: 'point', alpha: 'alpha', dcell: 'drift-cell',
    dmin: 'drift-min', dscale: 'drift-scale', step: 'per-step', sec: 'seconds', from: 'from', to: 'to', hold: 'hold', bg: 'theme', size: 'rec-size'};
  const CHECKS = {expanded: 'only-expanded', drift: 'drift', dtrail: 'drift-trail', grid: 'grid'};
  function currentState() {
    const h = new URLSearchParams();
    for (const [k, id] of Object.entries(FIELDS)) if ($(id).value !== '') h.set(k, $(id).value);
    for (const [k, id] of Object.entries(CHECKS)) if ($(id).checked) h.set(k, '1');
    if ($('trail-on').checked) h.set('trail', $('trail').value);
    if (showMask() !== 15) h.set('show', String(showMask()));
    h.set('cut', String(cut));
    if (selected) h.set('id', String(selected));
    h.set('view', view.map(v => +v.toPrecision(6)).join(','));
    return h;
  }
  function applyState(h) {
    stopPlay();
    for (const [k, id] of Object.entries(FIELDS)) if (h.has(k)) $(id).value = h.get(k);
    for (const [k, id] of Object.entries(CHECKS)) $(id).checked = h.get(k) === '1';
    $('trail-on').checked = h.has('trail'); if (h.has('trail')) $('trail').value = h.get('trail');
    const mask = h.has('show') ? Number(h.get('show')) : 15;
    document.querySelectorAll('.show').forEach(c => { c.checked = ((mask >> Number(c.value)) & 1) === 1; });
    if (!h.has('to')) $('to').value = n;
    legend(); driftCache = null;
    if (h.has('view')) { const v = h.get('view').split(',').map(Number); if (v.length === 4 && v.every(Number.isFinite)) view = v; else fit(); } else fit();
    cut = h.has('cut') ? Math.max(0, Math.min(n, Number(h.get('cut')))) : n; $('cut').value = cut;
    if (h.has('id')) select(Number(h.get('id'))); else { selected = 0; children = []; }
    draw(); stats();
    if (h.has('bg')) $('theme').onchange();
    $('per-step-range').value = $('per-step').value; $('seconds-range').value = Math.min(1, Number($('seconds').value) || 0.2); showLength();
    if (h.get('play') === '1') play(true);
  }

  // ---------- templates ----------
  async function templates() {
    const list = $('tpl-list'); list.replaceChildren();
    const add = (t, user) => {
      const div = document.createElement('div'); div.className = 'tpl';
      const b = document.createElement('button'); b.textContent = 'Apply'; b.onclick = () => { applyState(new URLSearchParams(t.params)); location.hash = t.params; };
      const title = document.createElement('strong'); title.textContent = ' ' + t.title + (user ? ' (yours)' : '');
      const p = document.createElement('p'); p.className = 'small'; p.textContent = t.notes || '';
      div.append(b, title, p);
      if (user) {
        const d = document.createElement('button'); d.textContent = 'Delete'; d.className = 'tpl-del';
        d.onclick = async () => { await fetch('/control/explorer/templates', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({delete: t.id})}); templates(); };
        div.append(d);
      }
      list.append(div);
    };
    try { for (const t of await (await fetch('/explorer-templates.json', {cache: 'no-store'})).json()) add(t, false); } catch (e) { /* none */ }
    try {
      const r = await fetch('/control/explorer/templates', {cache: 'no-store'});
      if (r.ok) { for (const t of await r.json()) add(t, true); $('tpl-save-row').hidden = false; $('tpl-save').hidden = false; }
    } catch (e) { /* read-only monitor: no saving */ }
  }
  async function saveTemplate() {
    const title = $('tpl-title').value.trim(); if (!title) { $('tpl-state').textContent = 'Give the template a title.'; return; }
    const r = await fetch('/control/explorer/templates', {method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({title, notes: $('tpl-notes').value.trim(), params: currentState().toString()})});
    $('tpl-state').textContent = r.ok ? 'Saved.' : ((await r.json().catch(() => ({}))).error || 'HTTP ' + r.status);
    if (r.ok) { $('tpl-title').value = ''; $('tpl-notes').value = ''; templates(); }
  }

  // ---------- experiments (order_experiments.py report) ----------
  async function experiments() {
    try {
      const r = await fetch('/explorer-data/experiments/report.json', {cache: 'no-store'}); if (!r.ok) return;
      const rep = await r.json(), e2 = rep.E2_replay, e1 = rep.E1_yield;
      let html = '<tr><td>order</td><td>10% cosets</td><td>25%</td><td>50%</td><td>10% parents</td></tr>';
      for (const [name, v] of Object.entries(e2)) {
        const c = v.new_found_after_x_percent_of_cosets || {}, p = v.new_found_after_x_percent_of_parents;
        html += '<tr><td>' + name + '</td><td>' + number(c['10%'] || 0) + '</td><td>' + number(c['25%'] || 0) + '</td><td>' + number(c['50%'] || 0) + '</td><td>' + number(p['10%']) + '</td></tr>';
      }
      $('exp-table').innerHTML = html;
      $('exp-e1').textContent = number(e1.parents) + ' expanded parents; mean ' + e1.mean_reached.toFixed(0) + ' classes reached, ' + e1.mean_reached_new.toFixed(1) +
        ' new. Rank correlation of new classes reached with 5-spaces: ' + e1.spearman_with_reached_new['5-spaces'].toFixed(2) +
        '; of new classes per coset with any feature: at most ' + Math.max(...Object.values(e1.spearman_with_new_per_coset).map(Math.abs)).toFixed(2) + '.';
      $('experiments').hidden = false;
      const c = await (await fetch('/explorer-data/experiments/catalog_compare.json', {cache: 'no-store'})).json();
      let rows = '<tr><td>c4</td><td>two</td><td>catalog</td><td>search</td><td>new</td><td>estimate</td><td>known</td></tr>';
      for (const e of c.coarse_strata) if (e.catalog + e.search >= 2000)
        rows += '<tr><td>' + e.c4 + '</td><td>' + e.two + '</td><td>' + number(e.catalog) + '</td><td>' + number(e.search) + '</td><td>' + number(e.new) +
          '</td><td>' + number(e.chapman_estimate) + '</td><td>' + (100 * e.known_share_of_estimate).toFixed(1) + '%</td></tr>';
      $('cat-table').innerHTML = rows;
      $('cat-total').textContent = 'Known signatures ' + number(c.known_total) + '; estimate over the strata ' + number(c.coarse_estimate_total) +
        ' (fine strata ' + number(c.fine_estimate_total) + ', unstratified ' + number(c.unstratified_estimate) + ').';
    } catch (e) { /* no report yet */ }
  }

  // ---------- data update (vlab dashboard proxy) ----------
  async function rebuildStatus() {
    try {
      const r = await fetch('/control/explorer', {cache: 'no-store'}); if (r.status === 404) { $('rebuild').hidden = true; return; }
      const s = await r.json();
      $('rebuild').disabled = s.busy;
      $('rebuild-state').textContent = s.busy ? 'Working: ' + s.phase : s.last_error ? 'Last error: ' + s.last_error : s.finished_utc ? 'Last update ' + new Date(s.finished_utc).toLocaleString() + (s.version && meta && s.version !== meta.version ? ' · reload the page for the new data' : '') : '';
      setTimeout(rebuildStatus, s.busy ? 3000 : 30000);
    } catch (e) { setTimeout(rebuildStatus, 30000); }
  }
  $('rebuild').onclick = async () => {
    const r = await fetch('/control/explorer', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({fresh: $('rebuild-fresh').checked})});
    if (r.status >= 400) $('rebuild-state').textContent = ((await r.json().catch(() => ({}))).error) || 'HTTP ' + r.status;
    rebuildStatus();
  };

  // ---------- events ----------
  function wire() {
    for (const [code, text] of AXES) { $('x-axis').add(new Option(text, code)); $('y-axis').add(new Option(text, code)); }
    $('x-axis').value = 0; $('y-axis').value = 1;
    $('x-axis').onchange = $('y-axis').onchange = fit; $('fit').onclick = fit;
    $('colour').onchange = () => { legend(); draw(); };
    for (const id of ['point', 'alpha', 'drift', 'drift-cell', 'drift-min', 'drift-scale']) $(id).oninput = () => { driftCache = id === 'drift-cell' ? null : driftCache; draw(); };
    for (const id of ['trail-on', 'trail', 'drift-trail']) $(id).oninput = () => { driftCache = null; draw(); stats(); };
    document.querySelectorAll('.show').forEach(c => { c.onchange = draw; });
    $('only-expanded').onchange = () => { draw(); };
    $('grid').onchange = () => { draw(); };
    $('cut').max = n; $('to').value = n; $('to').max = n; $('from').max = n;
    $('cut').oninput = () => { stopPlay(); setCut(Number($('cut').value)); };
    $('play').onclick = () => play(false); $('step-back').onclick = () => { stopPlay(); step(-1); }; $('step-fwd').onclick = () => { stopPlay(); step(1); };
    $('find').onclick = () => select(Number($('find-id').value));
    $('export-video').onclick = exportMP4;
    for (const [range, box] of [['per-step-range', 'per-step'], ['seconds-range', 'seconds']]) {
      $(range).oninput = () => { $(box).value = $(range).value; showLength(); };
      $(box).oninput = () => { if (Number($(box).value) <= Number($(range).max)) $(range).value = $(box).value; showLength(); };
    }
    for (const id of ['hold', 'from', 'to']) $(id).addEventListener('input', showLength);
    $('video-length').oninput = lengthChanged;
    $('theme').onchange = () => {
      const v = $('theme').value;
      if (v === 'auto') delete document.documentElement.dataset.theme; else document.documentElement.dataset.theme = v;
      try { localStorage.setItem('apn-explorer-theme', v); } catch (e) { /* private mode */ }
      legend(); draw();
    };
    try { const v = localStorage.getItem('apn-explorer-theme'); if (v) { $('theme').value = v; $('theme').onchange(); } } catch (e) { /* none */ }
    showLength();
    window.onresize = draw;
    const c = $('gl'); let drag = null, moved = false;
    c.onpointerdown = e => { drag = [e.clientX, e.clientY, view.slice()]; moved = false; c.classList.add('dragging'); c.setPointerCapture(e.pointerId); };
    c.onpointermove = e => {
      if (!drag) return; const dpr = window.devicePixelRatio || 1, dx = (e.clientX - drag[0]) * dpr, dy = (e.clientY - drag[1]) * dpr;
      if (Math.abs(dx) + Math.abs(dy) > 3) moved = true;
      const w = drag[2][1] - drag[2][0], h = drag[2][3] - drag[2][2];
      view = [drag[2][0] - dx / c.width * w, drag[2][1] - dx / c.width * w, drag[2][2] + dy / c.height * h, drag[2][3] + dy / c.height * h]; draw();
    };
    c.onpointerup = e => { c.classList.remove('dragging'); if (drag && !moved) { const r = c.getBoundingClientRect(), dpr = window.devicePixelRatio || 1; pick((e.clientX - r.left) * dpr, (e.clientY - r.top) * dpr); } drag = null; };
    c.onwheel = e => {
      e.preventDefault(); const r = c.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
      const [x, y] = toData((e.clientX - r.left) * dpr, (e.clientY - r.top) * dpr), k = Math.exp(e.deltaY * 0.0015);
      view = [x + (view[0] - x) * k, x + (view[1] - x) * k, y + (view[2] - y) * k, y + (view[3] - y) * k]; draw();
    };
  }

  (async () => {
    try {
      await load(); setupGL(); wire();
      applyState(new URLSearchParams(location.hash.slice(1)));
      $('message').hidden = true;
      experiments(); templates();
      $('tpl-save').onclick = saveTemplate;
      $('tpl-link').onclick = async () => {
        const url = location.origin + location.pathname + '#' + currentState().toString(); history.replaceState(null, '', url);
        try { await navigator.clipboard.writeText(url); $('tpl-state').textContent = 'Link copied.'; } catch (e) { $('tpl-state').textContent = 'Link in the address bar.'; }
      };
    } catch (error) {
      $('message').textContent = 'The explorer data is not available: ' + error.message + '. Use "Update the data" above.';
      $('message').classList.add('error');
    }
    rebuildStatus();
  })();
})();
