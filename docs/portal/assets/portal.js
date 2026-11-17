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
