// Copy buttons: copy data-command; a short "Copied" note follows the icon for a moment.
document.addEventListener("click", async (event) => {
  const button = event.target.closest("button.copy");
  if (!button) return;
  const text = button.dataset.command;
  let note = button.nextElementSibling;
  if (!note || !note.classList.contains("copy-note")) {
    note = document.createElement("span");
    note.className = "copy-note small";
    note.setAttribute("role", "status");
    button.after(note);
  }
  try {
    await navigator.clipboard.writeText(text);
    note.textContent = " Copied";
    button.classList.add("copied");
  } catch {
    window.prompt("Copy the command:", text);
  }
  setTimeout(() => { note.textContent = ""; button.classList.remove("copied"); }, 1500);
});

// Mathematics in $...$ (KaTeX); code and pre blocks are left as they are.
document.addEventListener("DOMContentLoaded", () => {
  if (window.renderMathInElement && document.querySelector("main")) {
    renderMathInElement(document.querySelector("main"), {
      delimiters: [{ left: "$", right: "$", display: false }], throwOnError: false });
  }
  glueMath(document.body);
  // Documenter renders the Library mathematics later: glue it when it appears.
  if (document.getElementById("documenter")) {
    let pending = false;
    new MutationObserver(() => {
      if (pending) return;
      pending = true;
      requestAnimationFrame(() => { pending = false; glueMath(document.body); });
    }).observe(document.getElementById("documenter"), { childList: true, subtree: true });
  }
});

// An inline formula and the punctuation right after it ("$n$." or "$x^9$),") stay on one line:
// both go into a span that does not wrap.
function glueMath(root) {
  for (const k of root.querySelectorAll(".katex")) {
    if (k.closest(".katex-display, .math-glue")) continue;
    // The formula's outermost wrapper: auto-render and Documenter put each formula in a span
    // that holds only it.
    let el = k;
    while (el.parentElement && el.parentElement.tagName === "SPAN" && el.parentElement.childNodes.length === 1) el = el.parentElement;
    const next = el.nextSibling;
    if (!next || next.nodeType !== Node.TEXT_NODE) continue;
    const m = next.textContent.match(/^[.,;:!?)\]]+/);
    if (!m) continue;
    const glue = document.createElement("span");
    glue.className = "math-glue";
    el.before(glue);
    glue.append(el, document.createTextNode(m[0]));
    next.textContent = next.textContent.slice(m[0].length);
  }
}

// Function list: filters, sort and page in the URL (?n=8&is_apn=1&sort=linearity&dir=desc&page=2),
// so a view can be shared and linked. The filter names are the column names of the catalog's
// functions table; q matches the name or the function key.
(() => {
  const form = document.getElementById("function-filters");
  const table = document.getElementById("function-table");
  if (!form || !table) return;
  const sizeSelect = document.getElementById("function-size");
  const fields = [...form.elements].filter((e) => e.name);
  const rows = [...table.tBodies[0].rows];
  const pagers = [document.getElementById("function-pager-top"), document.getElementById("function-pager")].filter(Boolean);
  const fmt = (n) => n.toLocaleString("en-US");
  const params = new URLSearchParams(location.search);
  for (const f of fields) if (params.has(f.name)) f.value = params.get(f.name);
  let sort = params.get("sort") || "", dir = params.get("dir") === "desc" ? "desc" : "asc";
  let page = Number(params.get("page")) || 1;
  if (sizeSelect && params.has("size")) sizeSelect.value = params.get("size");
  const pageSize = () => (sizeSelect && sizeSelect.value === "all" ? Infinity : Number(sizeSelect ? sizeSelect.value : 50));
  const numeric = new Set(["n", "m", "is_apn", "algebraic_degree", "differential_uniformity", "linearity"]);
  const value = (row, col) => {
    const v = row.dataset[col] ?? "";
    return numeric.has(col) ? (v === "" ? Infinity : Number(v)) : v.toLowerCase();
  };
  const apply = (keepPage = false) => {
    const want = fields.filter((f) => f.value.trim() !== "");
    const q = form.elements.q ? form.elements.q.value.trim().toLowerCase() : "";
    let shown = rows.filter((row) => want.every((f) => f.name === "q" ? row.dataset.q.includes(q)
      : (row.dataset[f.name] || "") === f.value.trim()));
    if (sort) {
      const k = dir === "desc" ? -1 : 1;
      shown = shown.slice().sort((a, b) => { const x = value(a, sort), y = value(b, sort);
        const c = typeof x === "string" ? x.localeCompare(y, "en", { numeric: true }) : x < y ? -1 : x > y ? 1 : 0;
        // Equal values: the natural order of the names (reprs8_2 before reprs8_10), ascending.
        return c !== 0 ? k * c : a.dataset.name.localeCompare(b.dataset.name, "en", { numeric: true }); });
    }
    const PAGE = pageSize();
    const pages = Math.max(1, Math.ceil(shown.length / PAGE));
    if (!keepPage) page = 1;
    page = Math.min(Math.max(1, page), pages);
    const body = table.tBodies[0];
    for (const row of rows) row.hidden = true;
    shown.forEach((row, i) => { body.appendChild(row); row.hidden = i < (page - 1) * PAGE || i >= page * PAGE; });
    for (const th of table.tHead.rows[0].cells) {
      th.setAttribute("aria-sort", th.dataset.col === sort ? (dir === "desc" ? "descending" : "ascending") : "none");
    }
    const first = shown.length ? (page - 1) * PAGE + 1 : 0, last = Math.min(page * PAGE, shown.length);
    document.getElementById("function-count").textContent = shown.length <= PAGE ? `${fmt(shown.length)} functions`
      : `Functions ${fmt(first)}–${fmt(last)} of ${fmt(shown.length)}`;
    const state = new URLSearchParams(want.map((f) => [f.name, f.value.trim()]));
    if (sort) { state.set("sort", sort); state.set("dir", dir); }
    if (sizeSelect && sizeSelect.value !== "50") state.set("size", sizeSelect.value);
    if (page > 1) state.set("page", page);
    const link = (p, text, rel) => `<a href="?${(s => (s.set("page", p), s))(new URLSearchParams(state))}" data-page="${p}"${rel ? ` rel="${rel}"` : ""}>${text}</a>`;
    const pagerHtml = pages === 1 ? "" : `${page > 1 ? link(1, "First") + " " + link(page - 1, "Previous", "prev") : ""}
      <span>Page ${fmt(page)} of ${fmt(pages)}</span>
      ${page < pages ? link(page + 1, "Next", "next") + " " + link(pages, "Last") : ""}`;
    for (const p of pagers) p.innerHTML = pagerHtml;
    history.replaceState(null, "", state.toString() ? `?${state}` : location.pathname);
  };
  form.addEventListener("input", () => apply());
  form.addEventListener("submit", (e) => e.preventDefault());
  form.addEventListener("reset", () => setTimeout(() => { sort = ""; apply(); }));
  table.tHead.addEventListener("click", (e) => {
    const th = e.target.closest("th[data-col]");
    if (!th) return;
    dir = sort === th.dataset.col && dir === "asc" ? "desc" : "asc";
    sort = th.dataset.col;
    apply();
  });
  for (const pager of pagers) pager.addEventListener("click", (e) => {
    const a = e.target.closest("a[data-page]");
    if (!a) return;
    e.preventDefault();
    page = Number(a.dataset.page);
    apply(true);
    if (pager.id === "function-pager") table.scrollIntoView({ block: "start" });
  });
  if (sizeSelect) sizeSelect.addEventListener("change", () => apply());
  apply(true);
})();

// Mobile menu: a button that shows or hides the navigation (keyboard and touch).
(() => {
  const button = document.querySelector(".menu-toggle");
  const nav = document.getElementById("site-nav");
  if (!button || !nav) return;
  button.addEventListener("click", () => {
    const open = button.getAttribute("aria-expanded") === "true";
    button.setAttribute("aria-expanded", String(!open));
    nav.classList.toggle("open", !open);
  });
})();

// Publication search: keep the items whose title, authors or year contain every word.
(() => {
  const input = document.getElementById("publication-search");
  if (!input) return;
  const items = [...document.querySelectorAll("ol.publications > li[data-search]")];
  const count = document.getElementById("publication-count");
  const apply = () => {
    const words = input.value.toLowerCase().split(/\s+/).filter(Boolean);
    let shown = 0;
    for (const li of items) {
      const ok = words.every((w) => li.dataset.search.includes(w));
      li.hidden = !ok;
      if (ok) shown += 1;
    }
    for (const ol of document.querySelectorAll("ol.publications")) {
      const visible = [...ol.children].some((li) => !li.hidden);
      ol.hidden = !visible;
      ol.previousElementSibling.hidden = !visible;           // the year heading
    }
    count.textContent = words.length ? `${shown} of ${items.length} publications` : "";
  };
  input.addEventListener("input", apply);
})();
