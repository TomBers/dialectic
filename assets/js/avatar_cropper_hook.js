import { createImageCropperHook } from "./image_cropper_hook.js";

const AvatarCropper = createImageCropperHook({
  prefix: "avatar",
  eventName: "save_avatar",
  canvasWidth: 320,
  canvasHeight: 320,
  outputWidth: 512,
  outputHeight: 512,
  maxSourceBytes: 10 * 1024 * 1024,
  maxSourceBytesMessage: "Choose an image smaller than 10 MB.",
  wheelStep: 0.05,
  allowRotation: true,
  saveButtonText: "Save photo",
  emptyError: "Choose a photo first.",
});

export default AvatarCropper;
