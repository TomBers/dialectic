import { AppBridge, PostMessageTransport } from "@modelcontextprotocol/ext-apps/app-bridge";
import { previewResult } from "../src/draft.js";

const frame = document.getElementById("preview-frame") as HTMLIFrameElement;
const status = document.getElementById("demo-status")!;
const draft = {
  request_id: crypto.randomUUID(), title: "Should our team adopt a four-day week?", tags: ["work", "decision-making"],
  nodes: [
    { id: "question", kind: "origin", content: "Should we trial a four-day working week?" },
    { id: "support", kind: "thesis", content: "A shorter week might improve focus and reduce burnout." },
    { id: "assumption", kind: "assumptions", content: "We assume current output can be maintained with fewer hours. That needs testing, not treating as established fact." },
    { id: "objection", kind: "antithesis", content: "Customer coverage may suffer if everyone is unavailable on the same day." },
    { id: "next", kind: "question", content: "Which measures would make a small, reversible trial informative?" },
  ],
  edges: [{ from: "question", to: "support" }, { from: "support", to: "assumption" }, { from: "question", to: "objection" }, { from: "question", to: "next" }],
};

const bridge = new AppBridge(null, { name: "RationalGrid local demo", version: "0.1.0" }, { serverTools: {}, message: { text: {} } });
bridge.oncalltool = async () => {
  status.textContent = "Save requested. This demo deliberately does not save anything. Connect the MCP server in a host with OAuth to test a real private save.";
  return { isError: true, content: [{ type: "text", text: "Read-only local demo: account linking is unavailable." }], _meta: { "mcp/www_authenticate": ["Bearer error=\"invalid_token\""] } };
};
bridge.onmessage = async () => {
  status.textContent = "The card requested an account-linking follow-up in chat with the same reviewed draft. This demo has no chat model; nothing was saved.";
  return {};
};
bridge.oninitialized = async () => {
  await bridge.sendToolInput({ arguments: draft });
  await bridge.sendToolResult(previewResult(draft));
  status.textContent = "Preview connected. Expand an idea to review its content and connections.";
};
await bridge.connect(new PostMessageTransport(frame.contentWindow!, frame.contentWindow!));
frame.src = `${window.location.pathname.replace(/\/$/, "")}/widget`;
