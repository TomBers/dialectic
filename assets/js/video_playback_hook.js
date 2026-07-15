const VideoPlaybackHook = {
  mounted() {
    this.el.playbackRate = Number(this.el.dataset.playbackRate || "1.5");
  },
};

export default VideoPlaybackHook;
