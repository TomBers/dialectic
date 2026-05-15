Create a RationalGrid graph JSON artifact from the text below, save it to `priv/static/graphs/[slug].json`, validate it, and import it locally using `Dialectic.Graph.Importer`.

Requirements:

- Use top-level JSON keys: `"nodes"` and `"edges"`.
- Each node must include:
  - `id`
  - `content`
  - `class`
  - `user`
  - `parent`
  - `noted_by`
  - `deleted`
  - `compound`
  - `source_text`
- Each edge must be:
  - `{"data": {"id": "e1", "source": "1", "target": "2"}}`
- Root node:
  - id `"1"`
  - class `"origin"`
  - parent `null`
- Group nodes:
  - ids like `"group-claim"`
  - `compound: true`
  - `class: ""`
  - `user: ""`
  - `parent: null`
- Content nodes:
  - use classes: `premise`, `thesis`, `antithesis`, `synthesis`, `conclusion`, or `question`
  - `compound: false`
  - `parent` should point to a group node where appropriate

Graph design:

- Make a compact argument graph, not a paragraph outline.
- Aim for 18–25 total nodes including 4–6 group nodes.
- Merge similar ideas into stronger nodes.
- Use edges to show the argument path.
- First line of each content node should be a short title.
- After a blank line, include the explanation in markdown.
- Include direct source quotes where useful.
- Format longer quotes as markdown blockquotes with `>`.
- Use Pro / Con labels only for genuine paired argumentation around a proposition.
- Otherwise use normal classes like premise/thesis/antithesis/synthesis/conclusion.

Quality goals:

- Help the reader follow the text’s structure of thinking.
- Preserve some flavour of the author’s language.
- Explain enough context inside each node so it is useful when opened.
- Avoid over-fragmentation.
- Avoid unsupported claims not present in the text.
- If the text is modern/copyrighted, keep direct quotes short and rely more on paraphrase.

Validation:

- Ensure JSON is valid.
- Ensure node ids are unique.
- Ensure all edge endpoints exist.
- Ensure every content node has the required fields.
- Import into local DB with:
  - title: `[TITLE]`
  - slug: `[SLUG]`
  - tags: `[TAGS]`
  - is_public: true
  - is_published: true
  - prompt_mode: "university"

After import, report:
- JSON path
- title
- slug
- node count
- edge count
- tags
- test/validation result

Text:

[PASTE TEXT HERE]
