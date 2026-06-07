const CANVAS_SIZE = 320;
const OUTPUT_SIZE = 512;
const MAX_SOURCE_BYTES = 10 * 1024 * 1024;

const AvatarCropper = {
  mounted() {
    this.input = this.el.querySelector("[data-avatar-input]");
    this.editor = this.el.querySelector("[data-avatar-editor]");
    this.canvas = this.el.querySelector("[data-avatar-canvas]");
    this.zoom = this.el.querySelector("[data-avatar-zoom]");
    this.error = this.el.querySelector("[data-avatar-error]");
    this.saveButton = this.el.querySelector("[data-avatar-save]");
    this.cancelButton = this.el.querySelector("[data-avatar-cancel]");
    this.rotateLeftButton = this.el.querySelector("[data-avatar-rotate-left]");
    this.rotateRightButton = this.el.querySelector("[data-avatar-rotate-right]");
    this.ctx = this.canvas?.getContext("2d");
    this.image = null;
    this.imageUrl = null;
    this.scale = 1;
    this.rotation = 0;
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
    this.rotateLeftButton?.addEventListener("click", () => this.rotate(-90));
    this.rotateRightButton?.addEventListener("click", () => this.rotate(90));

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
      this.showError("Choose an image smaller than 10 MB.");
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
      this.rotation = 0;
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

  rotate(degrees) {
    if (!this.image) return;
    this.rotation = (this.rotation + degrees + 360) % 360;
    this.offsetX = 0;
    this.offsetY = 0;
    this.draw();
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
    const direction = event.deltaY > 0 ? -0.05 : 0.05;
    const nextScale = Math.min(3, Math.max(1, this.scale + direction));
    this.scale = nextScale;
    this.zoom.value = String(nextScale);
    this.draw();
  },

  save() {
    if (!this.image) {
      this.showError("Choose a photo first.");
      return;
    }

    this.clearError();
    const output = document.createElement("canvas");
    output.width = OUTPUT_SIZE;
    output.height = OUTPUT_SIZE;
    const outputCtx = output.getContext("2d");

    outputCtx.scale(OUTPUT_SIZE / CANVAS_SIZE, OUTPUT_SIZE / CANVAS_SIZE);
    this.drawToContext(outputCtx, CANVAS_SIZE);

    const imageData = output.toDataURL("image/png", 0.92);
    this.saveButton.disabled = true;
    this.saveButton.textContent = "Saving...";

    this.pushEvent("save_avatar", { image_data: imageData }, () => {
      this.saveButton.disabled = false;
      this.saveButton.textContent = "Save photo";
      this.resetEditor();
    });
  },

  draw() {
    if (!this.ctx) return;
    this.ctx.clearRect(0, 0, CANVAS_SIZE, CANVAS_SIZE);
    this.ctx.fillStyle = "#f4f4f5";
    this.ctx.fillRect(0, 0, CANVAS_SIZE, CANVAS_SIZE);

    if (!this.image) return;
    this.drawToContext(this.ctx, CANVAS_SIZE);
  },

  drawToContext(ctx, size) {
    const rotated = this.rotation % 180 !== 0;
    const imageWidth = rotated ? this.image.naturalHeight : this.image.naturalWidth;
    const imageHeight = rotated ? this.image.naturalWidth : this.image.naturalHeight;
    const baseScale = Math.max(size / imageWidth, size / imageHeight);
    const drawScale = baseScale * this.scale;

    ctx.save();
    ctx.translate(size / 2 + this.offsetX, size / 2 + this.offsetY);
    ctx.rotate((this.rotation * Math.PI) / 180);
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
    this.rotation = 0;
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

export default AvatarCropper;
