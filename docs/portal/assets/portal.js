// Copy buttons: copy the command in data-command and say "Copied" for a moment.
document.addEventListener("click", async (event) => {
  const button = event.target.closest("button.copy");
  if (!button) return;
  const text = button.dataset.command;
  try {
    await navigator.clipboard.writeText(text);
    button.textContent = "Copied";
  } catch {
    button.textContent = "Select and copy";
    window.prompt("Command", text);
  }
  button.setAttribute("aria-live", "polite");
  setTimeout(() => { button.textContent = "Copy"; }, 1500);
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
