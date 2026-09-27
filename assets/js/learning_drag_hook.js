const LearningDrag = {
  mounted() {
    this.workspace = this.el.closest("#learning-workspace");
    this.draggedTitle = null;
    this.draggedFolderId = null;

    this.clearTarget = () => {
      this.workspace.querySelectorAll("[data-drag-over]").forEach((target) => {
        delete target.dataset.dragOver;
      });
    };

    this.onDragStart = (event) => {
      this.draggedTitle = null;
      this.draggedFolderId = null;
      const folder = event.target.closest("[data-learning-folder-drag]");
      if (folder && event.dataTransfer) {
        this.draggedFolderId = folder.dataset.learningFolderDrag;
        event.dataTransfer.setData("application/x-learning-folder", this.draggedFolderId);
        event.dataTransfer.effectAllowed = "move";
        return;
      }
      const handle = event.target.closest("[data-learning-drag]");
      if (!handle || !event.dataTransfer) return;
      this.draggedTitle = handle.dataset.gridTitle;
      event.dataTransfer.setData("application/x-rationalgrid", this.draggedTitle);
      event.dataTransfer.effectAllowed = "copy";
    };

    this.dropTarget = (event) => {
      if (this.draggedFolderId) {
        const target = event.target.closest("[data-learning-folder-drop]");
        return target?.dataset.learningFolderDrop !== this.draggedFolderId ? target : null;
      }
      return this.draggedTitle ? event.target.closest("[data-learning-drop]") : null;
    };

    this.onDragOver = (event) => {
      const target = this.dropTarget(event);
      this.clearTarget();
      if (!target) return;
      event.preventDefault();
      event.dataTransfer.dropEffect = this.draggedFolderId ? "move" : "copy";
      target.dataset.dragOver = "true";
    };

    this.onDragLeave = (event) => {
      const target = event.target.closest("[data-drag-over]");
      if (target && !target.contains(event.relatedTarget)) delete target.dataset.dragOver;
    };

    this.onDrop = (event) => {
      const target = this.dropTarget(event);
      if (!target) return;
      event.preventDefault();
      if (this.draggedFolderId) {
        this.pushEvent("drop_folder", {
          collection_id: this.draggedFolderId,
          parent_id: target.dataset.learningFolderDrop,
        });
      } else {
        this.pushEvent("drop_grid", {
          title: this.draggedTitle,
          collection_id: target.dataset.learningDrop,
        });
      }
      this.onDragEnd();
    };

    this.onDragEnd = () => {
      this.draggedTitle = null;
      this.draggedFolderId = null;
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
