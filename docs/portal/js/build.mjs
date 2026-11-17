// Bundle the member view and the sqlite-wasm-http workers into ../assets/js/ (ignored by git).
import * as esbuild from "esbuild";
import fs from "node:fs";

const out = "../assets/js";
fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });
const shared = { bundle: true, platform: "browser", outdir: out, logLevel: "warning", minify: true };
await esbuild.build({ ...shared, format: "esm", entryPoints: ["members.js"] });
// The library starts classic workers: IIFE bundles, with import.meta.url = the worker address.
await esbuild.build({ ...shared, format: "iife", define: { "import.meta.url": "self.location.href" },
  entryPoints: ["node_modules/sqlite-wasm-http/dist/sqlite-worker.js",
                "node_modules/sqlite-wasm-http/dist/vfs-http-worker.js"] });
fs.copyFileSync("node_modules/sqlite-wasm-http/deps/dist/sqlite3.wasm", `${out}/sqlite3.wasm`);
console.log("built", fs.readdirSync(out).join(" "));
