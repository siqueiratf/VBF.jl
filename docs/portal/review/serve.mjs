// Static server for the built portal, as GitHub Pages serves it: the build folder under a
// base path (/VBF.jl/), index.html for a folder, HTTP Range requests (206) for the query
// database, and 404 outside the base path. The browser tests and the screenshots use it.
//
//   node serve.mjs [PORT] [BUILD_DIR] [BASE]
//   defaults: 8430, docs/portal/build (next to this folder), /VBF.jl/
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const [port = "8430", dir = path.join(here, "..", "build"), base = "/VBF.jl/"] = process.argv.slice(2);
const root = fs.realpathSync(dir);
const types = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".mjs": "text/javascript",
  ".wasm": "application/wasm", ".json": "application/json", ".css": "text/css", ".svg": "image/svg+xml",
  ".png": "image/png", ".woff2": "font/woff2", ".woff": "font/woff", ".ttf": "font/ttf", ".txt": "text/plain" };

http.createServer((req, res) => {
  const url = new URL(req.url, "http://x");
  if (!url.pathname.startsWith(base)) { res.writeHead(404); res.end(); return; }
  let file = path.join(root, decodeURIComponent(url.pathname.slice(base.length)));
  if (!file.startsWith(root)) { res.writeHead(404); res.end(); return; }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) {
    // As GitHub Pages: a folder without the final slash redirects to it.
    if (!url.pathname.endsWith("/")) { res.writeHead(301, { Location: url.pathname + "/" + url.search }); res.end(); return; }
    file = path.join(file, "index.html");
  }
  if (!fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
  const size = fs.statSync(file).size;   // statSync follows the query.sqlite symbolic link
  let start = 0, end = size - 1, status = 200;
  const range = /bytes=(\d+)-(\d*)/.exec(req.headers.range || "");
  if (range) {
    start = Number(range[1]);
    end = range[2] ? Math.min(Number(range[2]), size - 1) : size - 1;
    status = 206;
  }
  const headers = { "Content-Type": types[path.extname(file)] || "application/octet-stream",
    "Accept-Ranges": "bytes", "Content-Length": end - start + 1, "Cache-Control": "no-store" };
  if (status === 206) headers["Content-Range"] = `bytes ${start}-${end}/${size}`;
  res.writeHead(status, headers);
  if (req.method === "HEAD") { res.end(); return; }
  fs.createReadStream(file, { start, end }).pipe(res);
}).listen(Number(port), "127.0.0.1", () => console.log(`serving ${root} at http://127.0.0.1:${port}${base}`));
