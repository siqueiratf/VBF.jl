// Fixed-width baseline: one Range request per member (37 bytes each).
import { measure } from "./common.js";

window.runPoC = async ({ url, width, indices }) => {
  const out = [];
  for (const pass of ["cold", "warm"]) {
    for (const i of indices) {
      out.push({ pass, ...(await measure(`Q1 idx=${i}`, async () => {
        const start = (i - 1) * width;
        const r = await fetch(url, { headers: { Range: `bytes=${start}-${start + width - 1}` } });
        const b = new Uint8Array(await r.arrayBuffer());
        return [{ coeffs: [...b].map((x) => x.toString(16).padStart(2, "0")).join("") }];
      })) });
    }
  }
  return out;
};
