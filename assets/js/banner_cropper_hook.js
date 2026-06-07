const CANVAS_WIDTH = 640;
const CANVAS_HEIGHT = 168;
const OUTPUT_WIDTH = 1600;
const OUTPUT_HEIGHT = 420;
const MAX_SOURCE_BYTES = 12 * 1024 * 1024;

const BannerCropper = {
  mounted() {
    this.input = this.el.querySelector("[data-banner-input]");
    this.editor = this.el.querySelector("[data-banner-editor]");
    this.canvas = this.el.querySelector("[data-banner-canvas]");
    this.zoom = this.el.querySelector("[data-banner-zoom]");
    this.error = this.el.querySelector("[data-banner-error]");
    this.saveButton = this.el.querySelector("[data-banner-save]");
    this.cancelButton = this.el.querySelector("[data-banner-cancel]");
    this.ctx = this.canvas?.getContext("2d");
    this.image = null;
    this.imageUrl = null;
    this.scale = 1;
    this.offsetX = 0;
    this.offsetY = 0;
    this.dragging = false;
    this.lastPointer = null;

    this.input?.addEventListener("change", (event) => this.loadFile(event));
    this.zoom?.addEventListener("input", () => {
      this.scale = Number(this.zoom.value || "1");
      this.draw();
    });
    this.saveButton?.addEventListener("click", () => this.save());
    this.cancelButton?.addEventListener("click", () => this.resetEditor());
    this.canvas?.addEventListener("pointerdown", (event) => this.startDrag(event));
    this.canvas?.addEventListener("pointermove", (event) => this.drag(event));
    this.canvas?.addEventListener("pointerup", (event) => this.endDrag(event));
    this.canvas?.addEventListener("pointercancel", (event) => this.endDrag(event));
    this.canvas?.addEventListener("wheel", (event) => this.handleWheel(event), {
      passive: false,
    });
  },

  destroyed() {
    this.revokeImageUrl();
  },

  loadFile(event) {
    const file = event.target.files?.[0];
    if (!file) return;

    if (!["image/png", "image/jpeg", "image/webp"].includes(file.type)) {
      this.showError("Choose a PNG, JPG, or WebP image.");
      this.input.value = "";
      return;
    }

    if (file.size > MAX_SOURCE_BYTES) {
      this.showError("Choose an image smaller than 12 MB.");
      this.input.value = "";
      return;
    }

    this.clearError();
    this.revokeImageUrl();

    const image = new Image();
    image.onload = () => {
      this.image = image;
      this.imageUrl = image.src;
      this.scale = 1;
      this.offsetX = 0;
      this.offsetY = 0;
      if (this.zoom) this.zoom.value = "1";
      this.editor?.classList.remove("hidden");
      this.draw();
    };
    image.onerror = () => {
      this.showError("Unable to read that image.");
      this.revokeImageUrl();
    };
    image.src = URL.createObjectURL(file);
  },

  startDrag(event) {
    if (!this.image) return;
    this.dragging = true;
    this.lastPointer = { x: event.clientX, y: event.clientY };
    this.canvas.setPointerCapture(event.pointerId);
  },

  drag(event) {
    if (!this.dragging || !this.lastPointer) return;
    this.offsetX += event.clientX - this.lastPointer.x;
    this.offsetY += event.clientY - this.lastPointer.y;
    this.lastPointer = { x: event.clientX, y: event.clientY };
    this.draw();
  },

  endDrag(event) {
    this.dragging = false;
    this.lastPointer = null;
    if (this.canvas?.hasPointerCapture(event.pointerId)) {
      this.canvas.releasePointerCapture(event.pointerId);
    }
  },

  handleWheel(event) {
    if (!this.image || !this.zoom) return;
    event.preventDefault();
    const direction = event.deltaY > 0 ? -0.04 : 0.04;
    const nextScale = Math.min(3, Math.max(1, this.scale + direction));
    this.scale = nextScale;
    this.zoom.value = String(nextScale);
    this.draw();
  },

  save() {
    if (!this.image) {
      this.showError("Choose a banner image first.");
      return;
    }

    this.clearError();
    const output = document.createElement("canvas");
    output.width = OUTPUT_WIDTH;
    output.height = OUTPUT_HEIGHT;
    const outputCtx = output.getContext("2d");

    outputCtx.scale(OUTPUT_WIDTH / CANVAS_WIDTH, OUTPUT_HEIGHT / CANVAS_HEIGHT);
    this.drawToContext(outputCtx, CANVAS_WIDTH, CANVAS_HEIGHT);

    const imageData = output.toDataURL("image/png", 0.92);
    this.saveButton.disabled = true;
    this.saveButton.textContent = "Saving...";

    this.pushEvent("save_banner", { image_data: imageData }, () => {
      this.saveButton.disabled = false;
      this.saveButton.textContent = "Save banner";
      this.resetEditor();
    });
  },

  draw() {
    if (!this.ctx) return;
    this.ctx.clearRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
    this.ctx.fillStyle = "#f4f4f5";
    this.ctx.fillRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);

    if (!this.image) return;
    this.drawToContext(this.ctx, CANVAS_WIDTH, CANVAS_HEIGHT);
  },

  drawToContext(ctx, width, height) {
    const baseScale = Math.max(
      width / this.image.naturalWidth,
      height / this.image.naturalHeight,
    );
    const drawScale = baseScale * this.scale;

    ctx.save();
    ctx.translate(width / 2 + this.offsetX, height / 2 + this.offsetY);
    ctx.scale(drawScale, drawScale);
    ctx.drawImage(
      this.image,
      -this.image.naturalWidth / 2,
      -this.image.naturalHeight / 2,
      this.image.naturalWidth,
      this.image.naturalHeight,
    );
    ctx.restore();
  },

  resetEditor() {
    this.revokeImageUrl();
    this.image = null;
    this.scale = 1;
    this.offsetX = 0;
    this.offsetY = 0;
    if (this.input) this.input.value = "";
    if (this.zoom) this.zoom.value = "1";
    this.editor?.classList.add("hidden");
    this.clearError();
    this.draw();
  },

  showError(message) {
    if (!this.error) return;
    this.error.textContent = message;
    this.error.classList.remove("hidden");
  },

  clearError() {
    if (!this.error) return;
    this.error.textContent = "";
    this.error.classList.add("hidden");
  },

  revokeImageUrl() {
    if (this.imageUrl) {
      URL.revokeObjectURL(this.imageUrl);
      this.imageUrl = null;
    }
  },
};

export default BannerCropper;
