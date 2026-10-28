(() => {
  let preference = "system";
  try {
    const saved = localStorage.getItem("schnaps-appearance");
    if (saved === "light" || saved === "dark") preference = saved;
  } catch { /* System appearance still works when storage is unavailable. */ }

  const systemAppearance = matchMedia("(prefers-color-scheme: dark)");
  const isDark = () => preference === "dark" || (preference === "system" && systemAppearance.matches);
  function apply() {
    if (preference === "system") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.dataset.theme = preference;
  }
  apply();

  document.addEventListener("DOMContentLoaded", () => {
    const control = document.querySelector("#theme");
    function updateIcon() {
      control.dataset.dark = String(isDark());
      const action = isDark() ? "Switch to light mode" : "Switch to dark mode";
      control.setAttribute("aria-label", action);
      control.title = action;
    }
    updateIcon();
    control.hidden = false;
    systemAppearance.addEventListener("change", updateIcon);
    control.addEventListener("click", () => {
      preference = isDark() ? "light" : "dark";
      apply();
      updateIcon();
      try { localStorage.setItem("schnaps-appearance", preference); }
      catch { /* The current page can still switch appearance. */ }
    });
  });
})();
