const graphEvents = [
  "update_node_label", "center_node", "highlight_search_results",
  "clear_search_highlights", "presentation_highlight_slides",
  "presentation_clear_slides", "presentation_filter_graph",
  "presentation_unfilter_graph", "combine_highlight_nodes",
  "combine_clear_highlights", "copy_to_clipboard",
];
const lifecycle = new Set(["mounted", "beforeUpdate", "updated", "destroyed", "disconnected", "reconnected"]);

export function lazyGraphHook(load = () => import("./graph_hook.js")) {
  return {
    mounted() {
      const state = { cancelled: false, events: [], refs: [], definition: null, disconnected: false };
      this.graphLoad = state;
      const container = this.el.querySelector(`#${this.el.dataset.div}`);
      container?.setAttribute("aria-busy", "true");
      state.refs = graphEvents.map(name => this.handleEvent(name, payload => state.events.push([name, payload])));
      state.promise = load().then(({default: definition}) => {
        if (state.cancelled || !this.el.isConnected) return;
        for (const [name, value] of Object.entries(definition)) {
          if (!lifecycle.has(name)) this[name] = value;
        }
        const callbacks = new Map();
        const handleEvent = this.handleEvent;
        this.handleEvent = (name, callback) => {
          callbacks.set(name, callback);
          return handleEvent.call(this, name, callback);
        };
        state.definition = definition;
        try {
          definition.mounted.call(this);
        } finally {
          this.handleEvent = handleEvent;
          state.refs.forEach(ref => this.removeHandleEvent(ref));
          state.refs = [];
        }
        for (const [name, payload] of state.events) callbacks.get(name)?.(payload);
        state.events = [];
        if (state.disconnected) definition.disconnected?.call(this);
      }).catch(error => {
        if (state.cancelled) return;
        console.error("Unable to load grid", error);
        state.refs.forEach(ref => this.removeHandleEvent(ref));
        state.refs = [];
        state.events = [];
        state.definition?.destroyed?.call(this);
        state.definition = null;
        container?.removeAttribute("aria-busy");
        const message = document.createElement("p");
        message.id = `${this.el.id}-load-error`;
        message.setAttribute("role", "alert");
        message.append("The grid could not load. ");
        const reload = document.createElement("button");
        reload.type = "button";
        reload.textContent = "Reload grid";
        reload.addEventListener("click", () => window.location.reload());
        message.append(reload);
        this.el.append(message);
      });
    },
    beforeUpdate() { this.graphLoad.definition?.beforeUpdate?.call(this); },
    updated() { this.graphLoad.definition?.updated?.call(this); },
    disconnected() {
      this.graphLoad.disconnected = true;
      this.graphLoad.definition?.disconnected?.call(this);
    },
    reconnected() {
      this.graphLoad.disconnected = false;
      this.graphLoad.definition?.reconnected?.call(this);
    },
    destroyed() {
      const state = this.graphLoad;
      state.cancelled = true;
      state.refs.forEach(ref => this.removeHandleEvent(ref));
      state.refs = [];
      state.events = [];
      state.definition?.destroyed?.call(this);
    },
  };
}

export default lazyGraphHook();
