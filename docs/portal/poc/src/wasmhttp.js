// sqlite-wasm-http runner (official SQLite WASM with an HTTP VFS).
import { createSQLiteThread, createHttpBackend } from "sqlite-wasm-http";
import { measure } from "./common.js";

window.runPoC = async ({ url, pageSize, queries }) => {
  const out = [];
  let db, backend;
  out.push(await measure("open", async () => {
    backend = createHttpBackend({ maxPageSize: pageSize, timeout: 60000, cacheSize: 4096 });
    db = await createSQLiteThread({ http: backend });
    await db("open", { filename: "file:" + encodeURI(new URL(url, location.href).href), vfs: "http" });
    return [];
  }));
  const run = (sql) => new Promise((resolve, reject) => {
    const rows = [];
    db("exec", { sql, rowMode: "object", callback: (m) => { m.row ? rows.push(m.row) : resolve(rows); } })
      .catch(reject);
  });
  for (const pass of ["cold", "warm"]) {
    for (const q of queries) out.push({ pass, ...(await measure(q.id, () => run(q.sql))) });
  }
  return out;
};
