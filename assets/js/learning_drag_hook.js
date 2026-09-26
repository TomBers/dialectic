const LearningDrag = {
  mounted() {
    this.workspace = this.el.closest("#learning-workspace");
    this.draggedTitle = null;

    this.clearTarget = () => {
      this.workspace.querySelectorAll("[data-drag-over]").forEach((target) => {
        delete target.dataset.dragOver;
      });
    };

    this.onDragStart = (event) => {
      const handle = event.target.closest("[data-learning-drag]");
      if (!handle || !event.dataTransfer) return;
      this.draggedTitle = handle.dataset.gridTitle;
      event.dataTransfer.setData("application/x-rationalgrid", this.draggedTitle);
      event.dataTransfer.effectAllowed = "copy";
    };

    this.onDragOver = (event) => {
      const target = event.target.closest("[data-learning-drop]");
      if (!this.draggedTitle || !target) return;
      event.preventDefault();
      event.dataTransfer.dropEffect = "copy";
      this.clearTarget();
      target.dataset.dragOver = "true";
    };

    this.onDragLeave = (event) => {
      const target = event.target.closest("[data-learning-drop]");
      if (target && !target.contains(event.relatedTarget)) delete target.dataset.dragOver;
    };

    this.onDrop = (event) => {
      const target = event.target.closest("[data-learning-drop]");
      if (!this.draggedTitle || !target) return;
      event.preventDefault();
      this.pushEvent("drop_grid", {
        title: this.draggedTitle,
        collection_id: target.dataset.learningDrop,
      });
      this.draggedTitle = null;
      this.clearTarget();
    };

    this.onDragEnd = () => {
      this.draggedTitle = null;
      this.clearTarget();
    };

    this.listeners = [
      ["dragstart", this.onDragStart],
      ["dragover", this.onDragOver],
      ["dragleave", this.onDragLeave],
      ["drop", this.onDrop],
      ["dragend", this.onDragEnd],
    ];
    this.listeners.forEach(([name, handler]) => this.workspace.addEventListener(name, handler));
  },

  destroyed() {
    this.listeners.forEach(([name, handler]) => this.workspace.removeEventListener(name, handler));
    this.clearTarget();
  },
};

export default LearningDrag;
