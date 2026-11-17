// Bundle the runners and the sqlite-wasm-http workers into public/js/.
import * as esbuild from "esbuild";
import fs from "node:fs";

const out = "public/js";
fs.mkdirSync(out, { recursive: true });
const shared = { bundle: true, format: "esm", platform: "browser", outdir: out, logLevel: "warning" };
await esbuild.build({ ...shared, entryPoints: ["src/httpvfs.js", "src/wasmhttp.js", "src/binary.js"] });
// The library starts classic workers: bundle them as IIFE scripts and resolve
// import.meta.url to the worker's own address, so sqlite3.wasm loads from js/.
await esbuild.build({ ...shared, format: "iife", define: { "import.meta.url": "self.location.href" }, entryPoints: [
  "node_modules/sqlite-wasm-http/dist/sqlite-worker.js",
  "node_modules/sqlite-wasm-http/dist/vfs-http-worker.js"] });
for (const f of ["sql.js-httpvfs/dist/sqlite.worker.js", "sql.js-httpvfs/dist/sql-wasm.wasm",
                 "sqlite-wasm-http/deps/dist/sqlite3.wasm"]) {
  fs.copyFileSync(`node_modules/${f}`, `${out}/${f.split("/").pop()}`);
}
for (const r of ["httpvfs", "wasmhttp", "binary"]) {
  fs.writeFileSync(`public/${r}.html`,
    `<!doctype html><meta charset="utf-8"><title>${r}</title><script type="module" src="js/${r}.js"></script>`);
}
console.log("built", fs.readdirSync(out).join(" "));
