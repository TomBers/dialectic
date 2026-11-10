---
name: rationalgrid
description: Apply RationalGrid critical-thinking methods in a chat, or save selected ideas and their relationships as a private RationalGrid when the user requests it.
---

Use the user's chosen idea or passage as the focus. If the target is unclear, clarify it before applying a method. Respect explicit user instructions about scope, depth, and which ideas to save.

For critical thinking, retrieve the relevant method using one of these tools, then apply the returned guidance in your own reply:

- `get_clarify_method`: clarify terms and meaningful ambiguities.
- `get_assumptions_method`: identify premises the argument depends on.
- `get_counterexample_method`: test the scope of a claim with a counterexample.
- `get_implications_method`: trace consequences and dependencies.
- `get_blind_spots_method`: examine consequential omissions.
- `get_says_who_method`: examine sources and evidential support.
- `get_who_disagrees_method`: fairly explore opposing perspectives.
- `get_steel_man_method`: reconstruct the strongest defensible argument.
- `get_what_if_method`: explore an explicitly hypothetical change.

The tools return method templates, not completed analysis. Substitute the selected idea for `{{selected_idea}}` locally. The methods do not need conversation content sent to the server. Do not manufacture objections or imply that a source has been checked unless it has. Answer in chat without saving anything unless the user asks to save.

When the user asks to make a grid, prepare a focused map of the ideas they want transferred. Preserve distinctions between their claims, your interpretations, objections, and unresolved questions. Do not send raw conversation history, prior-turn arrays, unrelated personal details, or invented quotations. Prefer a small useful map over a transcript converted into nodes.

Call `create_grid` with a title, idea nodes, and directed edges. Include exactly one node of kind `origin` for the main question; every other node must be reachable from it, with no cycles. Use `thesis` and `antithesis` only for actual supporting and opposing arguments. Use `question` for unresolved questions and the relevant thinking-method kind for its results. Temporary node IDs connect the submitted nodes; RationalGrid assigns stored IDs.

Use a fresh UUID `request_id` for each intended grid creation. If the call has an uncertain outcome, retry the identical payload with the same UUID. Never retry an uncertain save with a new UUID. If the user changes the intended grid, use a new UUID. Authentication may be requested on the first save. Ownership comes from the linked account, never from a tool argument.

Grids are saved privately. Return the actual URL from a successful tool result. Use `read_my_grid` to inspect an owned grid when requested. Existing public search and `read_grid` remain available for public sources. This integration cannot append to, overwrite, delete, or publish an existing grid; do not claim otherwise.
