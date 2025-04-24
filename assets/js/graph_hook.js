import { draw_graph } from "./draw_graph";

const layoutGraph = (cy) => {
  const layout = cy.layout({
    name: "dagre",
    rankDir: "TB",
    nodeSep: 20,
    edgeSep: 15,
    rankSep: 30,
    // Add a callback for when layout is done
    ready: function () {
      // cy.style().update();
    },
  });

  // Run the layout
  layout.run();
};

const graphHook = {
  mounted() {
    const { graph, node, div } = this.el.dataset;

    const div_id = document.getElementById(div);
    const elements = JSON.parse(graph);

    this.cy = draw_graph(div_id, this, elements, node);
  },
  updated() {
    const { graph, node } = this.el.dataset;

    const newElements = JSON.parse(graph);

    this.cy.batch(() => {
      // 1 – replace the data
      this.cy.json({ elements: newElements });

      // 2 – update classes
      this.cy.elements().removeClass("selected");
      const tgt = this.cy.$(`#${node}`).addClass("selected");

      // 3 – ***invalidate the cached body/label***
      tgt.dirtyStyleCache(); // <-- this line
    });

    // 4 – tell the styler to rebuild the textures now
    this.cy.style().update(); // <-- and this line

    layoutGraph(this.cy); // only the layout, no extra style call
  },
};

export default graphHook;
