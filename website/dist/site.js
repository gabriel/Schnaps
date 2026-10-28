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
    const demo = document.querySelector("#demo");
    const demoToggle = document.querySelector("#demo-toggle");
    if (demo && demoToggle) {
      const motion = matchMedia("(prefers-reduced-motion: reduce)");
      let playing = !motion.matches;
      function showDemo() {
        demo.src = playing ? demo.dataset.animation : demo.dataset.poster;
        demoToggle.textContent = playing ? "Pause" : "Play";
        demoToggle.setAttribute("aria-label", playing ? "Pause animation" : "Play animation");
        demoToggle.setAttribute("aria-pressed", String(playing));
      }
      demoToggle.hidden = false;
      demoToggle.addEventListener("click", () => { playing = !playing; showDemo(); });
      motion.addEventListener("change", () => { playing = !motion.matches; showDemo(); });
      showDemo();
    }
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
