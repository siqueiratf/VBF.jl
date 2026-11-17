// Shared by the runners: timing and server counters for one query.
export async function counters() {
  return (await fetch("/__stats")).json();
}
export async function reset() {
  await fetch("/__reset");
}
// Run `fn` and return its time and the server-side requests and bytes it caused.
export async function measure(label, fn) {
  await reset();
  const t0 = performance.now();
  let rows, error;
  try { rows = await fn(); } catch (e) { error = String(e); }
  const ms = performance.now() - t0;
  const s = await counters();
  return { label, ms, requests: s.requests, bytes: s.bytes, rows: rows ? rows.length : 0,
           first: rows && rows.length ? rows[0] : null, error };
}
