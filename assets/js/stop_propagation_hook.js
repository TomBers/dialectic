const StopPropagationHook = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.stopPropagation();
    });
  }
};

export default StopPropagationHook;
