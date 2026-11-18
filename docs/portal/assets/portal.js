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
  if (window.renderMathInElement) {
    renderMathInElement(document.querySelector("main"), {
      delimiters: [{ left: "$", right: "$", display: false }], throwOnError: false });
  }
});

// Function list: filters in the URL (?n=8&is_apn=1&family=...), so a filtered list can be
// shared and linked. The names are the column names of the catalog's functions table.
(() => {
  const form = document.getElementById("function-filters");
  const table = document.getElementById("function-table");
  if (!form || !table) return;
  const fields = [...form.elements].filter((e) => e.name);
  const params = new URLSearchParams(location.search);
  for (const f of fields) if (params.has(f.name)) f.value = params.get(f.name);
  const apply = () => {
    const want = fields.filter((f) => f.value.trim() !== "");
    let shown = 0;
    for (const row of table.tBodies[0].rows) {
      const ok = want.every((f) => (row.dataset[f.name] || "") === f.value.trim());
      row.hidden = !ok;
      if (ok) shown += 1;
    }
    document.getElementById("function-count").textContent = `${shown} functions`;
    const q = new URLSearchParams(want.map((f) => [f.name, f.value.trim()]));
    history.replaceState(null, "", q.toString() ? `?${q}` : location.pathname);
  };
  form.addEventListener("input", apply);
  form.addEventListener("submit", (e) => e.preventDefault());
  apply();
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
