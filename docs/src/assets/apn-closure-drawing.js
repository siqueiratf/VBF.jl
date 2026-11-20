'use strict';
// Update controls of the drawing page. They need the `vlab dashboard` proxy,
// which answers /control/*; the read-only monitor alone returns 404 and the
// controls stay hidden.
(() => {
  const $ = id => document.getElementById(id);
  const time = value => value ? new Date(value).toLocaleString() : 'never';
  let status = null, waiting = false, timer = null;

  async function call(method, path, body) {
    const response = await fetch(path, {method, cache:'no-store', headers:body ? {'Content-Type':'application/json'} : {},
      body:body ? JSON.stringify(body) : undefined});
    const data = await response.json().catch(() => ({}));
    return {status:response.status, data};
  }
  function render() {
    const s = status, busy = s.busy;
    $('controls').hidden = false;
    $('no-pull').checked = !s.pull;
    $('pull-now').disabled = busy || !s.pull;
    $('redraw-now').disabled = busy;
    $('no-pull').disabled = busy;
    const parts = [busy ? 'Busy: ' + (s.phase || s.action) + ' since ' + time(s.started_utc) : 'Idle',
      'last pull ' + time(s.last_pull_utc), 'last draw ' + time(s.last_draw_utc),
      'next automatic ' + (s.pull ? 'pull and draw' : 'draw') + ' ' + time(s.next_auto_utc) + ' (every ' + s.auto_minutes + ' min)',
      'graph ' + (s.graph_version || 'none'), 'drawing ' + (s.drawing_version || 'none')];
    $('control-state').textContent = parts.join(' · ');
    $('control-error').textContent = s.last_error ? 'Last error: ' + s.last_error : '';
  }
  function schedule() {
    clearTimeout(timer);
    timer = setTimeout(poll, status && status.busy ? 2000 : 15000);
  }
  async function poll() {
    try {
      const reply = await call('GET', '/control/status');
      if (reply.status === 404) { $('controls').hidden = true; return; }
      if (reply.status !== 200) throw new Error('HTTP ' + reply.status);
      const before = status;
      status = reply.data; render();
      // A run that this page started has finished: show its drawing.
      if (waiting && before && !status.busy) {
        waiting = false;
        const shown = window.apnGraph && window.apnGraph.manifest.version;
        if (!status.last_error && status.drawing_version && status.drawing_version !== shown) { location.reload(); return; }
      }
    } catch (error) {
      $('control-error').textContent = 'Controls unavailable: ' + error.message;
    }
    schedule();
  }
  async function refresh(pull) {
    const reply = await call('POST', '/control/refresh', {pull});
    if (reply.status === 409) $('control-error').textContent = 'Another update is running; wait for it to finish.';
    else if (reply.status >= 400) $('control-error').textContent = reply.data.error || 'HTTP ' + reply.status;
    else waiting = true;
    poll();
  }
  $('pull-now').onclick = () => refresh(true);
  $('redraw-now').onclick = () => refresh(false);
  $('no-pull').onchange = async () => {
    const reply = await call('POST', '/control/settings', {pull: !$('no-pull').checked});
    if (reply.status === 200) { status = reply.data; render(); }
  };
  poll();
})();

// Catalog status overlays: cells with only new classes and 95% covariance
// ellipses, from cells.json and ellipses.json of the drawing (apn-layout --classes).
(() => {
  const $ = id => document.getElementById(id);
  const number = value => Number(value).toLocaleString();
  const css = name => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  const HALF_X = 1 / 140, HALF_Y = 0.5 / 100;  // half cell in page units (layout.rs)
  let cells = [], groups = [], view = null;

  function overlay(v) {
    view = v;
    const canvas = $('overlay'), ctx = canvas.getContext('2d');
    if (canvas.width !== v.width || canvas.height !== v.height) { canvas.width = v.width; canvas.height = v.height; }
    ctx.clearRect(0, 0, v.width, v.height);
    const s = v.zoom * v.height / 2;  // pixels per page unit, both axes
    const px = (x, y) => [v.width / 2 + (x - v.center[0]) * s, v.height / 2 - (y - v.center[1]) * s];
    if ($('hl-cells').checked) {
      ctx.strokeStyle = css('--fresh'); ctx.lineWidth = 1.5 * v.dpr;
      const minimum = 7 * v.dpr;
      for (const c of cells) {
        const [x, y] = px(c.x, c.y), w = Math.max(2 * HALF_X * s, minimum), h = Math.max(2 * HALF_Y * s, minimum);
        ctx.strokeRect(x - w / 2, y - h / 2, w, h);
      }
    }
    if ($('ellipses').checked) {
      const colour = {new: css('--fresh'), catalog: css('--found'), seeds: css('--seed')};
      ctx.lineWidth = 2 * v.dpr;
      for (const g of groups) {
        const [x, y] = px(g.page_centre[0], g.page_centre[1]);
        ctx.strokeStyle = colour[g.group];
        ctx.beginPath();
        ctx.ellipse(x, y, g.page_semi_axes[0] * s, g.page_semi_axes[1] * s, -g.page_angle_deg * Math.PI / 180, 0, 2 * Math.PI);
        ctx.stroke();
        const r = 6 * v.dpr;
        ctx.beginPath(); ctx.moveTo(x - r, y); ctx.lineTo(x + r, y); ctx.moveTo(x, y - r); ctx.lineTo(x, y + r); ctx.stroke();
      }
    }
  }
  window.apnGraphHooks = {draw: overlay};

  async function load() {
    const graph = window.apnGraph;
    if (!graph) { setTimeout(load, 300); return; }
    if (!graph.hasStatus) return;  // older drawing without status.bin: plain colours
    const base = graph.data + graph.manifest.version + '/';
    const [allCells, ellipses] = await Promise.all([fetch(base + 'cells.json').then(r => r.json()), fetch(base + 'ellipses.json').then(r => r.json())]);
    cells = allCells.filter(c => c.all_new);
    groups = ellipses.groups;
    const k = ellipses.counts;
    for (const element of document.querySelectorAll('.status-only')) element.hidden = false;
    $('legend').innerHTML = '';
    for (const [cls, label, n] of [['seed', 'Published seeds', k.seeds], ['fresh', 'New (outside the catalog)', k.new],
        ['', 'Catalog-matching', k.catalog], ['unknown', 'Unknown', k.unknown]]) {
      if (cls === 'unknown' && !n) continue;
      const span = document.createElement('span'), dot = document.createElement('i');
      dot.className = 'dot ' + cls; span.append(dot, label + ' ' + number(n)); $('legend').append(span);
    }
    $('new-cells-title').textContent = 'Cells with only new classes (' + number(k.cells_all_new) + ' of ' + number(k.cells) + ' occupied; ' +
      number(k.cells_no_new) + ' without new classes, ' + number(k.cells_mixed) + ' mixed)';
    const list = $('new-cells').querySelector('div');
    for (const c of [...cells].sort((a, b) => b.n - a.n || a.two - b.two || a.three - b.three)) {
      const button = document.createElement('button');
      button.textContent = '(' + c.two + ', ' + c.three + ') · ' + number(c.n);
      button.title = '2-dim ' + c.two + ', 3-dim ' + c.three + ': ' + number(c.n) + ' classes, all new';
      button.onclick = () => graph.setView([c.x, c.y], 60);
      list.append(button);
    }
    const name = {new: 'new', catalog: 'catalog-matching', seeds: 'published seeds'};
    const fmt = x => x.toFixed(1);
    const means = groups.map(g => name[g.group] + ' (' + fmt(g.mean[0]) + ', ' + fmt(g.mean[1]) + '), n = ' + number(g.n)).join('; ');
    const c = ellipses.containment.new_inside_catalog;
    $('ellipse-about').textContent = 'Ellipses: 95% regions (chi-square 2 dof, ' + ellipses.chi2_95.toFixed(3) + ') of the sample covariance of the raw (two, three) values per group. Means (two, three): ' + means + '. ' +
      (c ? 'The new-class ellipse is ' + (c.inside ? '' : 'not ') + 'inside the catalog-matching ellipse (' + Math.round(100 * c.boundary_share_inside) + '% of its boundary lies inside). ' : '') +
      'These are descriptive statistics of the explored region, not a statistical test.';
    $('status-about').hidden = false;
    for (const id of ['hl-cells', 'ellipses']) $(id).addEventListener('input', graph.redraw);
    graph.redraw();
  }
  load().catch(error => console.error('status overlay', error));
})();
