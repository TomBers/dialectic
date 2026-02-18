# Adding LaTeX Math Rendering to a Phoenix LiveView App — The Hard Way (That's Actually Easy)

I recently needed to add mathematical notation rendering to [Dialectic](https://dialectic.chat), a Phoenix LiveView application that uses AI-generated content. The AI models frequently produce LaTeX-style math — inline expressions like `$E = mc^2$` and block equations like `$$\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}$$` — but they were showing up as raw dollar-sign-wrapped strings. Not a great look.

Here's how I got beautiful math rendering working with KaTeX, Marked, and DOMPurify — and the security pitfall I almost fell into along the way.

---

## The Stack

Dialectic renders markdown client-side using a Phoenix LiveView hook. The rendering pipeline looks like this:

1. **Server** sends raw markdown via LiveView assigns
2. **LiveView Hook** (`Markdown`) picks up the content from a `data-md` attribute or `<template>` tag
3. **Marked** parses the markdown into HTML
4. **DOMPurify** sanitizes it (we're rendering AI output — sanitization isn't optional)
5. The result gets injected into the DOM

The challenge: we need to insert KaTeX rendering into step 3 *without* having step 4 strip it all out.

## Attempt 1: A Single Extension (The Naive Approach)

My first commit added `katex` as an npm dependency and wrote a custom Marked extension:

```javascript
import katex from "katex";

const katexPlugin = {
  extensions: [
    {
      name: "katex",
      level: "inline",
      start(src) {
        return src.indexOf("$");
      },
      tokenizer(src, _tokens) {
        // Block math $$...$$
        const blockMatch = /^\$\$([\s\S]+?)\$\$/.exec(src);
        if (blockMatch) {
          return {
            type: "katex",
            raw: blockMatch[0],
            text: blockMatch[1].trim(),
            displayMode: true,
          };
        }

        // Inline math $...$
        const inlineMatch = /^\$([^$\n]+?)\$/.exec(src);
        if (inlineMatch) {
          return {
            type: "katex",
            raw: inlineMatch[0],
            text: inlineMatch[1].trim(),
            displayMode: false,
          };
        }
      },
      renderer(token) {
        return katex.renderToString(token.text, {
          displayMode: token.displayMode,
          throwOnError: false,
        });
      },
    },
  ],
};

marked.use(katexPlugin);
```

This *worked*… mostly. I also had to update the DOMPurify config to stop it from stripping KaTeX's output:

```javascript
const safe = DOMPurify.sanitize(html, {
  USE_PROFILES: { html: true, mathMl: true },
  ADD_ATTR: ["style"],
});
```

And I loaded the KaTeX CSS from a CDN in the root layout:

```html
<link rel="stylesheet"
      href="https://cdn.jsdelivr.net/npm/katex@0.16.28/dist/katex.min.css" />
```

Equations were rendering. Ship it? Not so fast.

## The PR Review: Three Problems

### Problem 1: Block vs. Inline Token Ordering

Marked processes block-level tokens *before* inline tokens. By registering both `$$...$$` and `$...$` patterns as `level: "inline"`, I was relying on the tokenizer function's internal ordering to match `$$` before `$`. This is fragile — Marked doesn't guarantee the order inline tokenizers are tried within the same extension.

The fix was to split into **two separate extensions**: a `katexBlock` extension at `level: "block"` and a `katex` extension at `level: "inline"`:

```javascript
const katexPlugin = {
  extensions: [
    {
      name: "katexBlock",
      level: "block",
      start(src) {
        return src.indexOf("$$");
      },
      tokenizer(src, _tokens) {
        const blockMatch = /^\$\$([\s\S]+?)\$\$/.exec(src);
        if (blockMatch) {
          return {
            type: "katexBlock",
            raw: blockMatch[0],
            text: blockMatch[1].trim(),
            displayMode: true,
          };
        }
      },
      renderer(token) {
        return katex.renderToString(token.text, {
          displayMode: true,
          throwOnError: false,
        });
      },
    },
    {
      name: "katex",
      level: "inline",
      start(src) {
        return src.indexOf("$");
      },
      tokenizer(src, _tokens) {
        const inlineMatch = /^\$([^$\n]+?)\$/.exec(src);
        if (inlineMatch) {
          return {
            type: "katex",
            raw: inlineMatch[0],
            text: inlineMatch[1].trim(),
            displayMode: false,
          };
        }
      },
      renderer(token) {
        return katex.renderToString(token.text, {
          displayMode: false,
          throwOnError: false,
        });
      },
    },
  ],
};
```

Now `$$...$$` gets consumed during block parsing, before the inline parser ever sees it. No ambiguity.

### Problem 2: `ADD_ATTR: ["style"]` Is a Security Hole

KaTeX renders math using inline `style` attributes on its generated `<span>` elements. My initial approach was to blanket-allow `style` attributes across the entire sanitized output:

```javascript
ADD_ATTR: ["style"]  // ← Don't do this
```

This is dangerous. We're rendering AI-generated content. A model could (intentionally or through prompt injection) produce HTML with malicious `style` attributes — think CSS-based data exfiltration, content overlay attacks, or UI redressing.

The fix: a **DOMPurify hook** that selectively allows `style` only on elements that are inside a KaTeX container:

```javascript
DOMPurify.addHook("uponSanitizeAttribute", (node, data) => {
  if (data.attrName === "style") {
    if (
      node.closest &&
      (node.closest(".katex") || node.closest(".katex-display"))
    ) {
      data.keepAttr = true;
    } else {
      data.keepAttr = false;
    }
  }
});
```

This is the key insight of the entire implementation. The `uponSanitizeAttribute` hook fires for every attribute on every node. When it encounters a `style` attribute, it checks whether that node lives inside a `.katex` or `.katex-display` container. If it does, it's KaTeX's own styling — keep it. If it doesn't, it's potentially malicious — strip it.

With this in place, the DOMPurify call becomes cleaner too:

```javascript
const safe = DOMPurify.sanitize(html, {
  USE_PROFILES: { html: true, mathMl: true },
  // No ADD_ATTR needed — the hook handles styles selectively
});
```

### Problem 3: CDN vs. Bundled CSS

Loading KaTeX CSS from jsDelivr works but introduces an external dependency. If the CDN is slow or down, your math looks broken (unstyled KaTeX output is a mess of overlapping spans).

Since `katex` was already an npm dependency, I just imported the CSS directly:

```css
/* assets/css/app.css */
@import "tailwindcss/base";
@import "tailwindcss/components";
@import "tailwindcss/utilities";
@import "katex/dist/katex.min.css";
```

This bundles the KaTeX styles with the application's CSS via esbuild. One fewer network request, no CDN dependency, and the styles are guaranteed to be available when the math renders.

## The Marked Version Dance

One more wrinkle. I initially downgraded `marked` from v17 to v12 because I started with the `marked-katex-extension` package, which didn't support v17 at the time. But since I ended up writing a **custom extension** instead of using the third-party one, the downgrade was unnecessary. The final commit reverted `marked` back to v17.

Lesson learned: before reaching for a third-party extension, check whether the library's extension API is straightforward enough to write it yourself. Marked's extension API is well-documented, and the custom approach gave me more control over the tokenizer regex patterns and let me stay on the latest version.

## The Final Pipeline

Here's what the complete rendering pipeline looks like now:

```
Raw markdown with $...$ and $$...$$ notation
        │
        ▼
  Marked parser (with katexBlock + katex extensions)
        │
        ├── Block pass: $$...$$ → KaTeX HTML (display mode)
        │
        ├── Inline pass: $...$ → KaTeX HTML (inline mode)
        │
        ├── Standard markdown → HTML
        │
        ▼
  DOMPurify sanitizer
        │
        ├── HTML + MathML profiles enabled
        │
        ├── Style attributes: allowed ONLY inside .katex containers
        │
        ├── Everything else: standard sanitization
        │
        ▼
  Clean HTML with rendered equations → DOM
```

## Key Takeaways

1. **Split block and inline math into separate Marked extensions.** Marked processes block tokens first, so `$$...$$` as a block extension will always be consumed before the inline `$...$` tokenizer sees it.

2. **Never blanket-allow `style` attributes in DOMPurify.** Use the `uponSanitizeAttribute` hook to selectively allow them only where needed (inside KaTeX containers). This is especially critical when you're rendering user or AI-generated content.

3. **Bundle your CSS.** If the library is already in your `node_modules`, import the CSS directly rather than loading it from a CDN. Fewer external dependencies = fewer failure modes.

4. **Write your own extension before reaching for a third-party wrapper.** Marked's extension API (`start`, `tokenizer`, `renderer`) is clean and predictable. Rolling your own means no version compatibility headaches and full control over the regex patterns.

5. **`throwOnError: false` is your friend.** KaTeX will encounter malformed LaTeX from AI models. Letting it fail gracefully (showing the raw source instead of crashing) is far better than a broken page.

The total math-specific code added was roughly 50 lines of JavaScript and 1 line of CSS. Not bad for rendering publication-quality equations in a real-time LiveView app.

---

*If you're building something with Phoenix LiveView and need to render rich content from AI models, I'd love to hear about your approach. What rendering challenges have you run into?*