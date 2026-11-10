let pending;

export function loadMathStyles() {
  if (!pending) {
    pending = new Promise((resolve, reject) => {
      const link = document.createElement("link");
      link.rel = "stylesheet";
      link.dataset.mathStyles = "true";
      link.href = document.body.dataset.katexStylesheet || "/assets/katex.css";
      link.onload = () => resolve();
      link.onerror = () => {
        link.remove();
        pending = null;
        reject(new Error("Math stylesheet could not load"));
      };
      document.head.append(link);
    });
  }
  return pending;
}
