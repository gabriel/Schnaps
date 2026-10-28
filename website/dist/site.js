(() => {
  let preference = "system";
  try {
    const saved = localStorage.getItem("schnaps-appearance");
    if (saved === "light" || saved === "dark") preference = saved;
  } catch { /* System appearance still works when storage is unavailable. */ }

  function apply(value) {
    if (value === "system") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.dataset.theme = value;
  }
  apply(preference);

  document.addEventListener("DOMContentLoaded", () => {
    const control = document.querySelector("#theme");
    control.value = preference;
    control.addEventListener("change", () => {
      preference = control.value;
      apply(preference);
      try {
        if (preference === "system") localStorage.removeItem("schnaps-appearance");
        else localStorage.setItem("schnaps-appearance", preference);
      } catch { /* The current page can still switch appearance. */ }
    });
  });
})();
