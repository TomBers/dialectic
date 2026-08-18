const YouTubeFacadeHook = {
  mounted() {
    this.playButton = this.el.querySelector("button");
    this.loadVideo = () => {
      const videoId = this.el.dataset.videoId;
      if (!videoId) return;

      const iframe = document.createElement("iframe");
      iframe.className = "h-full w-full";
      iframe.src = `https://www.youtube-nocookie.com/embed/${encodeURIComponent(videoId)}?autoplay=1`;
      iframe.title = this.el.dataset.videoTitle || "Video";
      iframe.allow =
        "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share";
      iframe.referrerPolicy = "strict-origin-when-cross-origin";
      iframe.allowFullscreen = true;

      this.el.replaceChildren(iframe);
    };

    this.playButton?.addEventListener("click", this.loadVideo, { once: true });
  },

  destroyed() {
    this.playButton?.removeEventListener("click", this.loadVideo);
  },
};

export default YouTubeFacadeHook;
