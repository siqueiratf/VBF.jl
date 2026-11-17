// sql.js-httpvfs runner.
import { createDbWorker } from "sql.js-httpvfs";
import { measure } from "./common.js";

window.runPoC = async ({ url, pageSize, queries }) => {
  const out = [];
  let worker;
  out.push(await measure("open", async () => {
    worker = await createDbWorker(
      [{ from: "inline", config: { serverMode: "full", url: new URL(url, location.href).href, requestChunkSize: pageSize } }],
      new URL("./sqlite.worker.js", import.meta.url).href,
      new URL("./sql-wasm.wasm", import.meta.url).href, 10 * 1024 * 1024 * 1024);
    return [];
  }));
  for (const pass of ["cold", "warm"]) {
    for (const q of queries) {
      out.push({ pass, ...(await measure(q.id, () => worker.db.query(q.sql))) });
    }
  }
  return out;
};
