const DEFAULT_ALLOWED_TYPES = ["image/png", "image/jpeg", "image/webp"];

export const createImageCropperHook = (config) => ({
  mounted() {
    this.config = {
      allowedTypes: DEFAULT_ALLOWED_TYPES,
      wheelStep: 0.05,
      minScale: 1,
      maxScale: 3,
      outputType: "image/webp",
      outputQuality: 0.9,
      allowRotation: false,
      ...config,
    };

    const prefix = this.config.prefix;
    this.input = this.el.querySelector(`[data-${prefix}-input]`);
    this.editor = this.el.querySelector(`[data-${prefix}-editor]`);
    this.canvas = this.el.querySelector(`[data-${prefix}-canvas]`);
    this.zoom = this.el.querySelector(`[data-${prefix}-zoom]`);
    this.error = this.el.querySelector(`[data-${prefix}-error]`);
    this.saveButton = this.el.querySelector(`[data-${prefix}-save]`);
    this.cancelButton = this.el.querySelector(`[data-${prefix}-cancel]`);
    this.rotateLeftButton = this.el.querySelector(
      `[data-${prefix}-rotate-left]`,
    );
    this.rotateRightButton = this.el.querySelector(
      `[data-${prefix}-rotate-right]`,
    );
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

    if (this.config.allowRotation) {
      this.rotateLeftButton?.addEventListener("click", () => this.rotate(-90));
      this.rotateRightButton?.addEventListener("click", () => this.rotate(90));
    }

    this.canvas?.addEventListener("pointerdown", (event) =>
      this.startDrag(event),
    );
    this.canvas?.addEventListener("pointermove", (event) => this.drag(event));
    this.canvas?.addEventListener("pointerup", (event) => this.endDrag(event));
    this.canvas?.addEventListener("pointercancel", (event) =>
      this.endDrag(event),
    );
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

    if (!this.config.allowedTypes.includes(file.type)) {
      this.showError("Choose a PNG, JPG, or WebP image.");
      this.input.value = "";
      return;
    }

    if (file.size > this.config.maxSourceBytes) {
      this.showError(this.config.maxSourceBytesMessage);
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
    if (!this.image || !this.config.allowRotation) return;
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
    const direction =
      event.deltaY > 0 ? -this.config.wheelStep : this.config.wheelStep;
    const nextScale = Math.min(
      this.config.maxScale,
      Math.max(this.config.minScale, this.scale + direction),
    );
    this.scale = nextScale;
    this.zoom.value = String(nextScale);
    this.draw();
  },

  save() {
    if (!this.image) {
      this.showError(this.config.emptyError);
      return;
    }

    this.clearError();
    const output = document.createElement("canvas");
    output.width = this.config.outputWidth;
    output.height = this.config.outputHeight;
    const outputCtx = output.getContext("2d");

    outputCtx.scale(
      this.config.outputWidth / this.config.canvasWidth,
      this.config.outputHeight / this.config.canvasHeight,
    );
    this.drawToContext(
      outputCtx,
      this.config.canvasWidth,
      this.config.canvasHeight,
    );

    const imageData = output.toDataURL(
      this.config.outputType,
      this.config.outputQuality,
    );
    this.saveButton.disabled = true;
    this.saveButton.textContent = "Saving...";

    this.pushEvent(this.config.eventName, { image_data: imageData }, () => {
      this.saveButton.disabled = false;
      this.saveButton.textContent = this.config.saveButtonText;
      this.resetEditor();
    });
  },

  draw() {
    if (!this.ctx) return;
    this.ctx.clearRect(0, 0, this.config.canvasWidth, this.config.canvasHeight);
    this.ctx.fillStyle = "#f4f4f5";
    this.ctx.fillRect(0, 0, this.config.canvasWidth, this.config.canvasHeight);

    if (!this.image) return;
    this.drawToContext(
      this.ctx,
      this.config.canvasWidth,
      this.config.canvasHeight,
    );
  },

  drawToContext(ctx, width, height) {
    const rotated = this.config.allowRotation && this.rotation % 180 !== 0;
    const imageWidth = rotated
      ? this.image.naturalHeight
      : this.image.naturalWidth;
    const imageHeight = rotated
      ? this.image.naturalWidth
      : this.image.naturalHeight;
    const baseScale = Math.max(width / imageWidth, height / imageHeight);
    const drawScale = baseScale * this.scale;

    ctx.save();
    ctx.translate(width / 2 + this.offsetX, height / 2 + this.offsetY);

    if (this.config.allowRotation) {
      ctx.rotate((this.rotation * Math.PI) / 180);
    }

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
});
