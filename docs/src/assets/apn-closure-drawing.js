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
