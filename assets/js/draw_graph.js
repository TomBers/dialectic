import cytoscape from "cytoscape";
import dagre from "cytoscape-dagre";
import { computePosition, autoUpdate, offset } from "@floating-ui/dom";

cytoscape.use(dagre);

// Create a single shared menu element for all nodes (better for performance with large graphs)
function createSharedMenu(context) {
  // Remove any existing menu to prevent duplicates
  const existingMenu = document.getElementById("cy-node-menu");
  if (existingMenu) {
    existingMenu.remove();
  }

  // Create the menu element
  const menu = document.createElement("div");
  menu.id = "cy-node-menu";
  menu.className = "graph-tooltip";
  menu.style.position = "absolute";
  menu.style.display = "none";
  menu.style.zIndex = "10";
  menu.style.backgroundColor = "white";
  menu.style.borderRadius = "4px";
  menu.style.boxShadow = "0 2px 10px rgba(0, 0, 0, 0.2)";
  menu.style.padding = "5px";
  menu.style.transition = "opacity 0.2s";

  // Define buttons with SVG icons
  const buttons = [
    {
      name: "reply",
      icon: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"></path></svg>`,
      label: "Ask Question",
    },
    {
      name: "branch",
      icon: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="6" y1="3" x2="6" y2="15"></line><circle cx="18" cy="6" r="3"></circle><circle cx="6" cy="18" r="3"></circle><path d="M18 9a9 9 0 0 1-9 9"></path></svg>`,
      label: "Pros and Cons",
    },
    {
      name: "combine",
      icon: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path><path d="M12 11h4"></path><path d="M12 16h4"></path><path d="M8 11h.01"></path><path d="M8 16h.01"></path></svg>`,
      label: "Combine and Summarise",
    },
    {
      name: "showfull",
      icon: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>`,
      label: "Full Text",
    },
  ];

  // Create the menu HTML
  const menuContent = document.createElement("div");
  menuContent.className = "menu-buttons";
  menuContent.style.display = "flex";
  menuContent.style.gap = "8px";

  // Add buttons to the menu
  buttons.forEach((button) => {
    const buttonEl = document.createElement("button");
    buttonEl.className = "menu-button";
    buttonEl.setAttribute("data-action", button.name);
    buttonEl.style.display = "flex";
    buttonEl.style.flexDirection = "column";
    buttonEl.style.alignItems = "center";
    buttonEl.style.background = "transparent";
    buttonEl.style.border = "none";
    buttonEl.style.borderRadius = "4px";
    buttonEl.style.cursor = "pointer";
    buttonEl.style.padding = "5px";
    buttonEl.style.minWidth = "55px";
    buttonEl.style.color = "#333";
    buttonEl.style.transition = "background-color 0.2s";

    // Add hover effect only for regular buttons
    buttonEl.addEventListener("mouseenter", () => {
      buttonEl.style.backgroundColor = "#f0f0f0";
    });
    buttonEl.addEventListener("mouseleave", () => {
      buttonEl.style.backgroundColor = "transparent";
    });

    // Set icon and label content
    buttonEl.innerHTML = `
      <span style="margin-bottom: 3px; color: #555;">${button.icon}</span>
      <span style="font-size: 12px;">${button.label}</span>
    `;

    menuContent.appendChild(buttonEl);
  });

  menu.appendChild(menuContent);
  document.body.appendChild(menu);

  // Keep track of the current node for event handling
  let currentNodeId = null;

  // Set up event delegation for button clicks
  menu.addEventListener("click", (event) => {
    // Find the button or its parent
    let target = event.target;
    while (target !== menu && !target.classList.contains("menu-button")) {
      target = target.parentElement;
    }

    if (target.classList.contains("menu-button")) {
      const action = target.getAttribute("data-action");
      // Send LiveView event with node ID and action
      if (action == "showfull") {
        const btns = document.getElementsByClassName("show_more_modal");
        console.log(btns);

        if (btns.length > 0) {
          btns[btns.length - 1].click();
        }
      } else {
        if (currentNodeId && action) {
          context.pushEvent(`node_${action}`, {
            id: currentNodeId,
            action: action,
          });
        }
      }

      // Hide the menu after action
      menu.style.display = "none";
    }
  });

  // Prevent mouseout when moving from node to menu
  menu.addEventListener("mouseenter", () => {
    // Keep menu visible when mouse is over it
    clearTimeout(menu._hideTimeout);
  });

  menu.addEventListener("mouseleave", () => {
    // Hide menu when mouse leaves it
    menu.style.display = "none";
    currentNodeId = null;
  });

  return {
    element: menu,
    show: (nodeId, position) => {
      currentNodeId = nodeId;
      menu.style.left = `${position.x}px`;
      menu.style.top = `${position.y}px`;
      menu.style.display = "block";
    },
    hide: () => {
      menu._hideTimeout = setTimeout(() => {
        menu.style.display = "none";
        currentNodeId = null;
      }, 300); // Small delay to check if we move to the menu
    },
  };
}

function style_graph(cols_str) {
  const base_style =
    // Base node style
    [
      {
        selector: "node",
        style: {
          "background-color": "#f3f4f6", // gray-100
          "border-width": 1,
          "border-color": "#d1d5db", // gray-300
          label: "data(id)",
          "text-valign": "center",
          "text-halign": "center",
          "font-family": "monospace",
          // "font-size": "18px",
          "font-weight": "400",
          color: "#374151", // gray-700
          padding: "4px",
          shape: "round-rectangle",
        },
      },
      // Clicked node highlight
      {
        selector: "node.selected",
        css: {
          "font-weight": "800",
          "border-color": "red",
          color: "red",
        },
      },
      // Edge styling
      {
        selector: "edge",
        style: {
          width: 2,
          "line-color": "#f3f4f6",
          "target-arrow-color": "#d1d5db", // gray-400
          "target-arrow-shape": "triangle",
          "curve-style": "bezier",
          "arrow-scale": 1.0,
        },
      },
    ];

  const cols = JSON.parse(cols_str);
  for (const nodeType in cols) {
    base_style.push({
      selector: `node[class = "${nodeType}"]`,
      css: {
        "border-color": cols[nodeType].border,
        "background-color": cols[nodeType].background,
        color: cols[nodeType].text,
      },
    });
    base_style.push({
      selector: `node[class = "${nodeType}"].selected`,
      css: {
        "font-weight": "800",
        "border-color": "red",
        color: "red",
      },
    });
  }
  return base_style;
}

export function draw_graph(graph, context, elements, cols, node) {
  const cy = cytoscape({
    container: graph, // container to render in
    elements: elements,
    style: style_graph(cols),
    layout: {
      name: "dagre",
      nodeSep: 20,
      edgeSep: 15,
      rankSep: 30,
    },
  });

  cy.minZoom(0.5);
  cy.maxZoom(10);

  // Create a single shared menu for all nodes (better for performance with large graphs)
  const nodeMenu = createSharedMenu(context);

  // Set up event handlers using event delegation (works for dynamically added nodes)

  // cy.on("mouseout", "node", function () {
  //   nodeMenu.hide();
  // });

  // Node selection handling (kept from your original code)
  cy.on("tap", "node", function (event) {
    var n = this;
    context.pushEvent("node_clicked", { id: n.id() });
    cy.animate({
      center: {
        eles: n,
      },
      zoom: 2,
      duration: 500, // duration in milliseconds for the animation
    });

    setTimeout(() => {
      const node = event.target;
      const nodeId = node.id();

      // Create a virtual reference element based on the node's rendered bounding box
      const virtualReference = {
        getBoundingClientRect: () => {
          const bb = node.renderedBoundingBox();
          return {
            width: bb.x2 - bb.x1,
            height: bb.y2 - bb.y1,
            top: bb.y1,
            bottom: bb.y2,
            left: bb.x1,
            right: bb.x2,
          };
        },
      };

      // Use Floating UI to position the menu below the node
      computePosition(virtualReference, nodeMenu.element, {
        placement: "bottom",
        middleware: [offset(10)], // Adds a 10px offset
      }).then(({ x, y }) => {
        nodeMenu.show(nodeId, { x, y });
      });
    }, 500);
  });

  cy.elements().removeClass("selected");
  cy.$(`#${node}`).addClass("selected");
  cy.animate({
    center: {
      eles: `#${node}`,
    },
    zoom: 2,
    duration: 500, // duration in milliseconds for the animation
  });

  return cy;
}
