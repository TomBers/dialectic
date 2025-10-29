/**
 * PdfViewer Hook
 *
 * Renders a PDF with a selectable text layer using PDF.js, so users can select
 * and copy text. This hook expects to be mounted on a container element with:
 *
 *   - data-url: the URL of the PDF to render
 *   - data-scale (optional): render scale (default 1.2)
 *   - data-pages (optional): number of pages to render (default 3, use 0 or -1 for all)
 *
 * Example:
 *   <div id="pdf-view"
 *        phx-hook="PdfViewer"
 *        data-url="/uploads/some.pdf"
 *        data-scale="1.2"
 *        data-pages="2"></div>
 */
const PdfViewer = {
  async mounted() {
    this.url = this.el.dataset.url || "";
    this.scale = parseFloat(this.el.dataset.scale || "1.2");
    this.pages = parseInt(this.el.dataset.pages || "3", 10);

    injectTextLayerStyleOnce();

    if (!this.url) return;
    await ensurePdfJs();
    await this.renderPdf(this.url, this.scale, this.pages);
  },

  async updated() {
    const newUrl = this.el.dataset.url || "";
    const newScale = parseFloat(this.el.dataset.scale || "1.2");
    const newPages = parseInt(this.el.dataset.pages || "3", 10);

    if (
      newUrl !== this.url ||
      newScale !== this.scale ||
      newPages !== this.pages
    ) {
      this.url = newUrl;
      this.scale = newScale;
      this.pages = newPages;

      if (!this.url) return;
      await ensurePdfJs();
      await this.renderPdf(this.url, this.scale, this.pages);
    }
  },

  destroyed() {
    // nothing to clean beyond DOM removal
  },

  async renderPdf(url, scale, pagesToRender) {
    try {
      clearChildren(this.el);

      const pdf = await window.pdfjsLib.getDocument({ url }).promise;
      const total = pdf.numPages;

      // Pages to render
      const maxPages =
        isNaN(pagesToRender) || pagesToRender < 0 || pagesToRender === 0
          ? total
          : Math.min(total, pagesToRender);

      for (let i = 1; i <= maxPages; i++) {
        await renderPageInto(this.el, pdf, i, scale);
      }
    } catch (err) {
      console.error("PdfViewer: failed to render PDF", err);
      // Fallback UI
      const fallback = document.createElement("div");
      fallback.className =
        "p-4 text-sm rounded border border-rose-200 bg-rose-50 text-rose-700";
      fallback.textContent = "Failed to render PDF preview.";
      this.el.appendChild(fallback);
    }
  },
};

/**
 * Utilities
 */

function clearChildren(el) {
  while (el.firstChild) el.removeChild(el.firstChild);
}

async function ensurePdfJs() {
  if (window.pdfjsLib && window.pdfjsLib.GlobalWorkerOptions) {
    return;
  }

  // Load PDF.js core and worker from CDN (pinned version).
  const coreUrl = "https://unpkg.com/pdfjs-dist@2.16.105/build/pdf.js";
  const workerUrl = "https://unpkg.com/pdfjs-dist@2.16.105/build/pdf.worker.js";

  await loadScript(coreUrl);
  if (!window.pdfjsLib) {
    throw new Error("pdfjsLib failed to load");
  }
  window.pdfjsLib.GlobalWorkerOptions.workerSrc = workerUrl;
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
    // If already present, resolve
    if (document.querySelector(`script[src="${src}"]`)) {
      resolve();
      return;
    }

    const s = document.createElement("script");
    s.src = src;
    s.async = true;
    s.onload = () => resolve();
    s.onerror = (e) => reject(e);
    document.head.appendChild(s);
  });
}

async function renderPageInto(container, pdf, pageNumber, scale) {
  const page = await pdf.getPage(pageNumber);
  const viewport = page.getViewport({ scale });

  const pageWrapper = document.createElement("div");
  pageWrapper.className =
    "pdf-page relative overflow-hidden border rounded bg-white my-3 shadow-sm";
  pageWrapper.style.width = `${viewport.width}px`;
  pageWrapper.style.height = `${viewport.height}px`;
  pageWrapper.style.position = "relative";

  const canvas = document.createElement("canvas");
  const ctx = canvas.getContext("2d");
  canvas.width = viewport.width;
  canvas.height = viewport.height;
  canvas.style.width = `${viewport.width}px`;
  canvas.style.height = `${viewport.height}px`;
  canvas.style.display = "block";
  canvas.style.pointerEvents = "none";
  canvas.style.position = "absolute";
  canvas.style.left = "0";
  canvas.style.top = "0";
  canvas.style.zIndex = "1";

  const textLayerDiv = document.createElement("div");
  textLayerDiv.className = "textLayer";
  textLayerDiv.style.position = "absolute";
  textLayerDiv.style.left = "0";
  textLayerDiv.style.top = "0";
  textLayerDiv.style.width = `${viewport.width}px`;
  textLayerDiv.style.height = `${viewport.height}px`;
  textLayerDiv.style.pointerEvents = "auto";
  textLayerDiv.style.userSelect = "text";
  textLayerDiv.style.zIndex = "2";
  // Attach the selection hook directly to the text layer container
  textLayerDiv.setAttribute("phx-hook", "TextSelectionHook");
  // Inject selection actions container for the hook
  const selectionActions = document.createElement("div");
  selectionActions.className = "selection-actions hidden absolute z-10";
  selectionActions.innerHTML =
    '<button type="button" class="px-2 py-1 text-sm rounded-md bg-blue-600 text-white shadow">Save selection</button>';
  textLayerDiv.appendChild(selectionActions);

  pageWrapper.appendChild(canvas);
  pageWrapper.appendChild(textLayerDiv);
  container.appendChild(pageWrapper);

  // Render canvas
  await page.render({ canvasContext: ctx, viewport }).promise;

  // Render selectable text layer
  const textContent = await page.getTextContent({ includeMarkedContent: true });

  // Some builds expose renderTextLayer from pdfjsLib; use it if available.
  // Otherwise, do a minimal fallback that still enables selection.
  if (window.pdfjsLib.renderTextLayer) {
    await window.pdfjsLib.renderTextLayer({
      textContent,
      container: textLayerDiv,
      viewport,
      textDivs: [],
    }).promise;
  } else {
    // Minimal fallback: create absolutely positioned spans.
    // Note: This is less accurate than renderTextLayer but still selectable.
    textContent.items.forEach((item) => {
      const span = document.createElement("span");
      span.textContent = item.str;

      const tx = window.pdfjsLib.Util.transform(
        viewport.transform,
        item.transform,
      );
      const x = tx[4];
      const y = tx[5];

      // Font size approximation
      const fontHeight = Math.hypot(tx[2], tx[3]);

      span.style.position = "absolute";
      span.style.left = `${x}px`;
      // PDF y=0 is bottom; CSS y=0 is top
      span.style.top = `${viewport.height - y}px`;
      span.style.fontSize = `${fontHeight}px`;
      span.style.whiteSpace = "pre";
      span.style.transformOrigin = "0% 0%";
      // Rotate/skew if needed
      const angle = Math.atan2(tx[1], tx[0]);
      span.style.transform = `rotate(${angle}rad)`;

      // Invisible text but selectable; canvas provides visible glyphs
      span.style.color = "transparent";

      textLayerDiv.appendChild(span);
    });
  }

  // Optional: add page label
  const label = document.createElement("div");
  label.textContent = `Page ${pageNumber}`;
  label.className =
    "absolute right-2 bottom-2 text-xs rounded bg-black/50 text-white px-1.5 py-0.5";
  pageWrapper.appendChild(label);
}

function injectTextLayerStyleOnce() {
  if (document.getElementById("pdf-text-layer-style")) return;

  const style = document.createElement("style");
  style.id = "pdf-text-layer-style";
  style.textContent = `
    /* Minimal textLayer styling to allow selection highlight */
    .pdf-page { position: relative; }
    .pdf-page canvas { pointer-events: none; }
    .textLayer { position: absolute; inset: 0; z-index: 2; color: transparent; pointer-events: auto; }
    .textLayer span { user-select: text; -webkit-user-select: text; }
    .textLayer ::selection { background: rgba(180, 213, 255, 0.6); }
    .textLayer ::-moz-selection { background: rgba(180, 213, 255, 0.6); }
  `;
  document.head.appendChild(style);
}

export default PdfViewer;
