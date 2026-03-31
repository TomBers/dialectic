/**
 * VoiceRecord Hook
 *
 * Captures audio from the browser microphone using MediaRecorder API,
 * encodes it as base64 WebM/opus, and sends it to the LiveView for
 * transcription via Gemini's audio understanding API.
 *
 * Usage in HEEx:
 *   <button phx-hook="VoiceRecord" id="voice-record-btn" ...>
 *
 * The hook pushes a "voice_audio" event to the server with:
 *   %{"audio" => base64_string, "mime_type" => "audio/webm"}
 *
 * It also listens for server-pushed events:
 *   - "voice_transcription" => %{"text" => transcribed_text}
 *     Fills the chat input with the transcribed text.
 *   - "voice_error" => %{"message" => error_string}
 *     Shows an error state on the button.
 */

const VoiceRecordHook = {
  mounted() {
    this.recording = false;
    this.mediaRecorder = null;
    this.audioChunks = [];
    this.stream = null;

    // Visual state management
    this.defaultClasses = this.el.className;

    // Click handler toggles recording
    this.el.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();

      if (this.recording) {
        this.stopRecording();
      } else {
        this.startRecording();
      }
    });

    // Listen for server responses
    this.handleEvent("voice_transcription", ({ text }) => {
      this.setIdle();
      if (!text || text.trim() === "") return;

      // Find the chat input — prefer the textarea in our sibling form,
      // then fall back to well-known IDs and finally any matching name.
      const form = this.el.closest("[data-role=ask-form-container]");
      const input =
        (form && form.querySelector('textarea[name="vertex[content]"]')) ||
        document.getElementById("global-chat-input") ||
        document.getElementById("linear-chat-input") ||
        document.querySelector('[name="vertex[content]"]');

      if (input) {
        // Set value using native setter to ensure frameworks pick it up
        const nativeSetter = Object.getOwnPropertyDescriptor(
          window.HTMLTextAreaElement.prototype,
          "value",
        ).set;
        nativeSetter.call(input, text);

        // Dispatch input event so LiveView and auto-expand hooks react
        input.dispatchEvent(new Event("input", { bubbles: true }));
        input.focus();

        // Trigger auto-expand if hook is present
        input.style.height = "auto";
        input.style.height = input.scrollHeight + "px";

        // Auto-submit: find the form and click the Ask button to trigger
        // phx-submit with the correct event name ("reply-and-answer").
        // We use requestAnimationFrame to let LiveView process the input change first.
        requestAnimationFrame(() => {
          const inputForm = input.closest("form");
          if (inputForm) {
            // Click the Ask (default submit) button so phx-submit fires naturally
            const askBtn = inputForm.querySelector(
              'button[type="submit"]:not([name="submit_action"])',
            );
            if (askBtn) {
              askBtn.click();
            } else {
              inputForm.requestSubmit();
            }
          }
        });
      }
    });

    this.handleEvent("voice_error", ({ message }) => {
      this.setError(message);
      setTimeout(() => this.setIdle(), 3000);
    });

    this.handleEvent("voice_processing", (_payload) => {
      this.setProcessing();
    });
  },

  destroyed() {
    this.cleanup();
  },

  async startRecording() {
    // Microphone access requires a "secure context" (HTTPS or localhost).
    // The IP 127.0.0.1 is NOT treated as secure by most browsers, so
    // navigator.mediaDevices will be undefined there.
    if (!window.isSecureContext) {
      const isLocalIP =
        location.hostname === "127.0.0.1" || location.hostname === "0.0.0.0";
      if (isLocalIP) {
        this.setError(
          "Microphone requires localhost — visit http://localhost:" +
            location.port +
            location.pathname,
        );
      } else {
        this.setError("Microphone requires HTTPS");
      }
      setTimeout(() => this.setIdle(), 5000);
      return;
    }

    // Check for browser support
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      this.setError("Microphone not supported in this browser");
      setTimeout(() => this.setIdle(), 3000);
      return;
    }

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          channelCount: 1,
          sampleRate: 16000,
          echoCancellation: true,
          noiseSuppression: true,
        },
      });

      this.audioChunks = [];

      // Prefer webm/opus, fall back to whatever the browser supports
      const mimeType = this.selectMimeType();

      this.mediaRecorder = new MediaRecorder(this.stream, {
        mimeType: mimeType,
        audioBitsPerSecond: 64000,
      });

      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.audioChunks.push(event.data);
        }
      };

      this.mediaRecorder.onstop = () => {
        this.processAudio();
      };

      // Collect data every 250ms for responsive feel
      this.mediaRecorder.start(250);
      this.recording = true;
      this.setRecording();
    } catch (err) {
      console.error("Microphone access error:", err);

      let message = "Could not access microphone";
      if (err.name === "NotAllowedError") {
        message = "Microphone permission denied";
      } else if (err.name === "NotFoundError") {
        message = "No microphone found";
      }

      this.setError(message);
      setTimeout(() => this.setIdle(), 3000);
    }
  },

  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state !== "inactive") {
      this.mediaRecorder.stop();
    }
    this.recording = false;

    // Stop all tracks to release the microphone
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }
  },

  async processAudio() {
    if (this.audioChunks.length === 0) {
      this.setIdle();
      return;
    }

    this.setProcessing();

    const mimeType = this.mediaRecorder?.mimeType || "audio/webm";
    const audioBlob = new Blob(this.audioChunks, { type: mimeType });

    // Skip very short recordings (likely accidental clicks)
    if (audioBlob.size < 1000) {
      this.setIdle();
      return;
    }

    // Convert to base64 and send to server
    try {
      const base64 = await this.blobToBase64(audioBlob);
      // Use pushEventTo with a selector targeting the LiveView root,
      // not the LiveComponent that renders this hook.
      this.pushEventTo("[data-phx-main]", "voice_audio", {
        audio: base64,
        mime_type: this.normalizeMimeType(mimeType),
      });
    } catch (err) {
      console.error("Audio encoding error:", err);
      this.setError("Failed to encode audio");
      setTimeout(() => this.setIdle(), 3000);
    }
  },

  blobToBase64(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => {
        // reader.result is "data:<mime>;base64,<data>" — extract just the base64 part
        const base64 = reader.result.split(",")[1];
        resolve(base64);
      };
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  },

  selectMimeType() {
    // Prefer formats Gemini supports well
    const preferred = [
      "audio/webm;codecs=opus",
      "audio/webm",
      "audio/ogg;codecs=opus",
      "audio/ogg",
      "audio/mp4",
    ];

    for (const mime of preferred) {
      if (MediaRecorder.isTypeSupported(mime)) {
        return mime;
      }
    }

    // Fall back to browser default
    return "";
  },

  normalizeMimeType(mimeType) {
    // Strip codec info for the server side — Gemini accepts the base types
    if (mimeType.startsWith("audio/webm")) return "audio/webm";
    if (mimeType.startsWith("audio/ogg")) return "audio/ogg";
    if (mimeType.startsWith("audio/mp4")) return "audio/mp4";
    return mimeType;
  },

  // ── Visual state management ───────────────────────────────────

  setRecording() {
    this.el.setAttribute("data-voice-state", "recording");
    this.el.setAttribute("aria-label", "Stop recording");
    this.el.title = "Stop recording";

    // Swap icon to a stop indicator
    const icon = this.el.querySelector("[data-voice-icon]");
    if (icon) {
      icon.innerHTML =
        '<div class="w-3 h-3 rounded-sm bg-red-500 animate-pulse"></div>';
    }

    // Add recording ring animation
    this.el.classList.add("ring-2", "ring-red-400", "ring-offset-1");
  },

  setProcessing() {
    this.el.setAttribute("data-voice-state", "processing");
    this.el.setAttribute("aria-label", "Processing audio...");
    this.el.title = "Processing audio...";
    this.el.disabled = true;

    const icon = this.el.querySelector("[data-voice-icon]");
    if (icon) {
      icon.innerHTML = `<svg class="w-4 h-4 animate-spin text-indigo-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
      </svg>`;
    }

    this.el.classList.remove("ring-2", "ring-red-400", "ring-offset-1");
  },

  setError(message) {
    this.el.setAttribute("data-voice-state", "error");
    this.el.disabled = false;

    const icon = this.el.querySelector("[data-voice-icon]");
    if (icon) {
      icon.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-red-500" viewBox="0 0 20 20" fill="currentColor">
        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
      </svg>`;
    }

    this.showToast(message);
  },

  setIdle() {
    this.el.setAttribute("data-voice-state", "idle");
    this.el.setAttribute("aria-label", "Record voice question");
    this.el.title = "Record voice question";
    this.el.disabled = false;

    const icon = this.el.querySelector("[data-voice-icon]");
    if (icon) {
      icon.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 20 20" fill="currentColor">
        <path fill-rule="evenodd" d="M7 4a3 3 0 016 0v4a3 3 0 11-6 0V4zm4 10.93A7.001 7.001 0 0017 8a1 1 0 10-2 0A5 5 0 015 8a1 1 0 00-2 0 7.001 7.001 0 006 6.93V17H6a1 1 0 100 2h8a1 1 0 100 0h-3v-2.07z" clip-rule="evenodd" />
      </svg>`;
    }

    this.el.classList.remove("ring-2", "ring-red-400", "ring-offset-1");
  },

  showToast(message) {
    // Remove any existing toast
    this.dismissToast();

    const toast = document.createElement("div");
    toast.id = "voice-toast";
    toast.className =
      "absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-3 py-1.5 rounded-lg bg-gray-900 text-white text-xs whitespace-nowrap shadow-lg z-50 animate-fade-in pointer-events-auto";
    toast.textContent = message;

    // Position relative to the mic button
    this.el.style.position = "relative";
    this.el.appendChild(toast);

    // Auto-dismiss after 4s
    this._toastTimer = setTimeout(() => this.dismissToast(), 4000);
  },

  dismissToast() {
    if (this._toastTimer) {
      clearTimeout(this._toastTimer);
      this._toastTimer = null;
    }
    const existing = this.el.querySelector("#voice-toast");
    if (existing) existing.remove();
  },

  cleanup() {
    if (this.mediaRecorder && this.mediaRecorder.state !== "inactive") {
      this.mediaRecorder.stop();
    }
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
    }
    this.recording = false;
    this.mediaRecorder = null;
    this.audioChunks = [];
    this.stream = null;
  },
};

export default VoiceRecordHook;
