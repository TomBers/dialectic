import { createImageCropperHook } from "./image_cropper_hook.js";

const BannerCropper = createImageCropperHook({
  prefix: "banner",
  eventName: "save_banner",
  canvasWidth: 640,
  canvasHeight: 168,
  outputWidth: 1600,
  outputHeight: 420,
  maxSourceBytes: 12 * 1024 * 1024,
  maxSourceBytesMessage: "Choose an image smaller than 12 MB.",
  wheelStep: 0.04,
  saveButtonText: "Save banner",
  emptyError: "Choose a banner image first.",
});

export default BannerCropper;
