// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
import "./user_socket.js";

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { draw_graph } from "./draw_graph";
import topbar from "../vendor/topbar";

let hooks = {};
hooks.Graph = {
  mounted() {
    const div_id = document.getElementById("cy");
    const context = this;
    const { graph, node } = this.el.dataset;
    const elements = JSON.parse(graph);
    this.cy = draw_graph(div_id, elements);
    this.cy.on("tap", "node", function () {
      var n = this;
      context.pushEvent("node_clicked", { id: n.id() });
    });
    this.cy.elements().removeClass("selected");

    this.cy.$(`#${node}`).addClass("selected");
  },
  updated() {
    const { graph, node } = this.el.dataset;
    const newElements = JSON.parse(graph);

    // Update the existing Cytoscape instance
    // Option A: Update by setting new JSON (overwrites the entire set of elements)
    this.cy.json({ elements: newElements });
    this.cy.elements().removeClass("selected");

    this.cy.$(`#${node}`).addClass("selected");
    this.cy.layout({ name: "dagre" }).run();
  },
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: hooks,
  params: { _csrf_token: csrfToken },
  metadata: {
    keydown: (e, el) => {
      // console.log(e);
      // console.log(el);
      return {
        key: e.key,
        cmdKey: e.ctrlKey,
        metaKey: e.metaKey,
        repeat: e.repeat,
      };
    },
  },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
