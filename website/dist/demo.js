const canvas = document.querySelector("#canvas");
const box = document.querySelector("#selection");
const label = document.querySelector("#dimensions");
const hint = document.querySelector("#demo-hint");
const pins = document.querySelector("#pins");
let mode = "find",
  held = false,
  start = null,
  rect = null;
const targets = () =>
  [...canvas.querySelectorAll("[data-measure]")].map((el) => {
    const a = el.getBoundingClientRect(),
      b = canvas.getBoundingClientRect();
    return { x: a.left - b.left, y: a.top - b.top, w: a.width, h: a.height };
  });
function draw(r) {
  rect = r;
  box.hidden = !r;
  if (!r) return;
  Object.assign(box.style, {
    left: r.x + "px",
    top: r.y + "px",
    width: r.w + "px",
    height: r.h + "px",
  });
  label.textContent = `${Math.round(r.w)} × ${Math.round(r.h)} px`;
}
function point(e) {
  const b = canvas.getBoundingClientRect();
  return {
    x: Math.max(0, Math.min(b.width, e.clientX - b.left)),
    y: Math.max(0, Math.min(b.height, e.clientY - b.top)),
  };
}
function find(p) {
  const t = targets().find(
    (r) => p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h,
  );
  if (t) return t;
  let l = 0,
    r = canvas.clientWidth,
    t0 = 0,
    b = canvas.clientHeight;
  for (const a of targets()) {
    if (p.y >= a.y && p.y <= a.y + a.h) {
      if (a.x + a.w <= p.x) l = Math.max(l, a.x + a.w);
      if (a.x >= p.x) r = Math.min(r, a.x);
    }
    if (p.x >= a.x && p.x <= a.x + a.w) {
      if (a.y + a.h <= p.y) t0 = Math.max(t0, a.y + a.h);
      if (a.y >= p.y) b = Math.min(b, a.y);
    }
  }
  return { x: l, y: t0, w: r - l, h: b - t0 };
}
canvas.addEventListener("pointerdown", (e) => {
  if (e.button !== 0) return;
  canvas.focus({ preventScroll: true });
  start = point(e);
  held = false;
  canvas.setPointerCapture(e.pointerId);
});
canvas.addEventListener("pointermove", (e) => {
  const p = point(e);
  if (start) {
    let w = Math.abs(p.x - start.x),
      h = Math.abs(p.y - start.y);
    if (e.shiftKey) {
      const s = Math.min(
        Math.max(w, h),
        p.x < start.x ? start.x : canvas.clientWidth - start.x,
        p.y < start.y ? start.y : canvas.clientHeight - start.y,
      );
      w = h = s;
    }
    draw({
      x: p.x < start.x ? start.x - w : start.x,
      y: p.y < start.y ? start.y - h : start.y,
      w,
      h,
    });
  } else if (!held && mode === "find") draw(find(p));
});
canvas.addEventListener("pointerup", (e) => {
  if (!start) return;
  const p = point(e),
    dragged = Math.hypot(p.x - start.x, p.y - start.y) > 3;
  if (!dragged) draw(mode === "find" ? find(p) : null);
  else if (mode === "find" && !e.altKey && !e.shiftKey && rect) {
    const enclosed = targets().filter(
      (t) =>
        t.x >= rect.x &&
        t.y >= rect.y &&
        t.x + t.w <= rect.x + rect.w &&
        t.y + t.h <= rect.y + rect.h,
    );
    if (enclosed.length) {
      const x = Math.min(...enclosed.map((t) => t.x)),
        y = Math.min(...enclosed.map((t) => t.y));
      draw({
        x,
        y,
        w: Math.max(...enclosed.map((t) => t.x + t.w)) - x,
        h: Math.max(...enclosed.map((t) => t.y + t.h)) - y,
      });
    }
  }
  start = null;
  held = !!rect;
  hint.textContent = rect
    ? "Measurement held. Pin it, or drag another region."
    : "Drag an area to measure.";
});
canvas.addEventListener("pointercancel", () => {
  start = null;
  held = false;
  draw(null);
});
function pin() {
  if (!rect) return;
  const node = document.createElement("div");
  node.className = "pin";
  Object.assign(node.style, {
    left: rect.x + "px",
    top: rect.y + "px",
    width: rect.w + "px",
    height: rect.h + "px",
  });
  const text = document.createElement("span");
  text.className = "pin-label";
  text.textContent = label.textContent;
  node.append(text);
  pins.append(node);
  held = false;
  draw(null);
  hint.textContent = "Pinned. Keep measuring.";
}
function clear() {
  pins.replaceChildren();
  held = false;
  draw(null);
  hint.textContent = "Move over an element, or drag around it.";
}
document.querySelector("#pin").addEventListener("click", pin);
document.querySelector("#clear").addEventListener("click", clear);
canvas.addEventListener("keydown", (e) => {
  if (e.key === "Escape") clear();
  if (e.code === "Space") {
    e.preventDefault();
    pin();
  }
});
document.querySelectorAll("[data-mode]").forEach((button) =>
  button.addEventListener("click", () => {
    mode = button.dataset.mode;
    held = false;
    draw(null);
    document.querySelectorAll("[data-mode]").forEach((b) => {
      b.classList.toggle("active", b === button);
      b.setAttribute("aria-pressed", String(b === button));
    });
    hint.textContent =
      mode === "find"
        ? "Move over an element, or drag around it."
        : "Drag an exact rectangle. Shift makes a square.";
  }),
);
new ResizeObserver(() => {
  pins.replaceChildren();
  held = false;
  draw(null);
}).observe(canvas);
requestAnimationFrame(() => requestAnimationFrame(() => draw(targets()[0])));
