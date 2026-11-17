// Static file server for the catalog PoC. It behaves like GitHub Pages for this test:
// it answers HTTP Range requests (206) and sends no COOP/COEP headers. It also counts
// the requests and bytes of each test and can add a delay to imitate a remote host.
//
//   node server.mjs PORT ROOT [LATENCY_MS] [BYTES_PER_SECOND]
//
// GET /__stats returns {requests, bytes}; GET /__reset sets them to zero.
import http from "node:http";
import fs from "node:fs";
import path from "node:path";

const [port, root, latency = "0", rate = "0"] = process.argv.slice(2);
const types = { ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript",
  ".wasm": "application/wasm", ".json": "application/json" };
let stats = { requests: 0, bytes: 0 };

const delay = (ms) => new Promise((r) => setTimeout(r, ms));

http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://x");
  if (url.pathname === "/__stats") { res.end(JSON.stringify(stats)); return; }
  if (url.pathname === "/__reset") { stats = { requests: 0, bytes: 0 }; res.end("{}"); return; }
  const file = path.join(root, decodeURIComponent(url.pathname));
  if (!file.startsWith(path.resolve(root)) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404); res.end(); return;
  }
  const size = fs.statSync(file).size;
  let start = 0, end = size - 1, status = 200;
  const range = /bytes=(\d+)-(\d*)/.exec(req.headers.range || "");
  if (range) {
    start = Number(range[1]);
    end = range[2] ? Math.min(Number(range[2]), size - 1) : size - 1;
    status = 206;
  }
  const length = end - start + 1;
  const counted = url.pathname.endsWith(".sqlite") || url.pathname.endsWith(".bin");
  // A HEAD request transfers no body: count the request, not the length.
  const body = req.method === "HEAD" ? 0 : length;
  if (counted) { stats.requests += 1; stats.bytes += body; }
  if (counted && Number(latency) > 0) await delay(Number(latency));
  if (counted && Number(rate) > 0) await delay((1000 * body) / Number(rate));
  const headers = { "Content-Type": types[path.extname(file)] || "application/octet-stream",
    "Accept-Ranges": "bytes", "Content-Length": length, "Access-Control-Allow-Origin": "*",
    "Cache-Control": "no-store" };
  if (status === 206) headers["Content-Range"] = `bytes ${start}-${end}/${size}`;
  res.writeHead(status, headers);
  if (req.method === "HEAD") { res.end(); return; }
  fs.createReadStream(file, { start, end }).pipe(res);
}).listen(Number(port), () => console.log(`serving ${root} on ${port}`));
