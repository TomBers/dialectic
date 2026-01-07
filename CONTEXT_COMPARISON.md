# Context Presentation: Before vs After Comparison

## Overview

This document shows how context is presented to the LLM in the old vs new prompt system, demonstrating how the new framing reduces repetition.

---

## Example Scenario

A user creates a graph exploring quantum mechanics:
1. **Origin Node**: "What is quantum entanglement?"
2. **Answer Node**: Explains entanglement basics
3. **Deepdive Node**: User wants more depth

Let's see how the Deepdive prompt differs...

---

## OLD SYSTEM (Before Changes)

### Context Presented to LLM

```
### Context
```text
Quantum entanglement is a quantum mechanical phenomenon where two or more particles become correlated in such a way that the quantum state of each particle cannot be described independently of the others, even when separated by large distances. When a measurement is made on one particle, it instantaneously affects the state of the other particle, regardless of the distance between them. This "spooky action at a distance," as Einstein called it, does not violate causality because no information is transmitted faster than light.
```
```

### Instruction to LLM

```
Write a deep dive on Quantum Entanglement. Feel free to go beyond the previous word limits, write enough to understand the topic.
```

### What the LLM Receives

The LLM sees:
- Context labeled generically as "Context"
- No signal that this is "already covered"
- Instruction to "write enough to understand the topic"
- No guidance to avoid repetition

### Typical Result ❌

```markdown
# Deep Dive: Quantum Entanglement

Quantum entanglement is a phenomenon where particles become correlated across 
distances. When particles are entangled, measuring one affects the other 
instantaneously, which Einstein famously called "spooky action at a distance."

This correlation means that the quantum state of each particle cannot be 
described independently...
```

**Problem:** The response restates what's in the context rather than adding new depth.

---

## NEW SYSTEM (After Changes)

### Context Presented to LLM

```
### Foundation

The following has already been explored:

```text
Quantum entanglement is a quantum mechanical phenomenon where two or more particles become correlated in such a way that the quantum state of each particle cannot be described independently of the others, even when separated by large distances. When a measurement is made on one particle, it instantaneously affects the state of the other particle, regardless of the distance between them. This "spooky action at a distance," as Einstein called it, does not violate causality because no information is transmitted faster than light.
```

↑ This is already covered. Your response should ADD NEW insights beyond what's shown above.
```

### Instruction to LLM

```
The Foundation provides an overview of Quantum Entanglement.

**Your task:** Write a deep dive that goes BEYOND the overview by:
- Adding technical depth, nuance, or complexity
- Providing concrete examples, case studies, or applications
- Exploring implications, edge cases, or subtleties
- Addressing questions the overview raises but doesn't answer

You may write at length (beyond normal 500-word limit). Focus on adding substantial new understanding.

**Important:** Do not repeat or merely rephrase what's in the Foundation section. Focus on adding genuinely new information, perspectives, or insights.
```

### What the LLM Receives

The LLM sees:
- Context reframed as "Foundation" (already established knowledge)
- Clear signal: "This is already covered"
- Explicit instruction to "go BEYOND the overview"
- Concrete guidance on what to add
- Anti-repetition footer

### Typical Result ✅

```markdown
# Deep Dive: The Mathematics and Applications of Quantum Entanglement

## The EPR Paradox and Bell's Theorem

While the basic correlation is well-established, the EPR paradox (Einstein, 
Podolsky, Rosen, 1935) challenged whether entanglement implied "hidden variables." 
John Bell's theorem (1964) provided a testable prediction: if local hidden 
variables exist, certain correlations must obey Bell inequalities.

Experiments by Aspect (1982) and others have violated these inequalities, 
confirming that quantum mechanics' predictions about entanglement are correct 
and local realism is incompatible with quantum phenomena.

## Practical Applications

**Quantum Computing**: Entanglement enables quantum gates that create 
superpositions of multiple qubits, allowing parallel computation. For example, 
Shor's algorithm uses entanglement to factor large numbers exponentially faster 
than classical computers.

**Quantum Cryptography**: BB84 protocol uses entangled photon pairs to detect 
eavesdropping. Any measurement by an interceptor disturbs the entangled state, 
revealing their presence.

**Quantum Teleportation**: Using entanglement and classical communication, the 
quantum state of a particle can be transferred to another location without 
physically moving the particle itself.

## Common Misconceptions

Entanglement does NOT allow faster-than-light communication. While the correlation 
is instantaneous, extracting meaningful information requires comparing measurements 
via classical channels (limited by light speed). The "spookiness" is in the 
correlation pattern, not in signal transmission...
```

**Success:** The response adds technical frameworks (EPR, Bell's theorem), applications (quantum computing, cryptography), and clarifies misconceptions—all NEW information.

---

## Side-by-Side Comparison

| Aspect | OLD | NEW |
|--------|-----|-----|
| **Context Label** | "Context" | "Foundation" |
| **Framing** | Generic reference | "Already explored" |
| **Visual Signal** | None | "↑ This is already covered" |
| **Task Instruction** | "Write enough to understand" | "Go BEYOND by adding..." |
| **Specific Guidance** | None | Bullets listing what to add |
| **Anti-Repetition** | Not mentioned | Explicit footer |
| **Result** | Often repetitive | Consistently additive |

---

## System Prompt Enhancement

### OLD System Prompt

```
Persona: A precise lecturer aiming to provide a university level introduction to the topic.
...
Style for structured mode
- Precise, concise, neutral.
- Define key terms briefly when they first appear.
- Try and keep the response concise and focused, aim for a maximum of 500 words.
```

### NEW System Prompt (Addition)

```
Graph-based exploration context
- You are part of a conversation graph where each node builds on previous nodes.
- When Foundation/Context is provided, treat it as already-covered territory.
- Your role is to ADVANCE the exploration by adding NEW information, perspectives, or insights.
- Do NOT repeat or merely rephrase what has already been established in the Foundation.
- Each response should contribute something genuinely new to the exploration.
```

---

## Impact Across All Prompt Types

### Explain
**Old:** "Use the provided Context to ground your explanation"
**New:** "EXTEND BEYOND what's already in the Foundation"

### Thesis/Antithesis
**Old:** "Provide a detailed argument using the Context"
**New:** "Provide NEW reasoning, evidence, or examples not yet mentioned"

### Related Ideas
**Old:** "Ensure your suggestions are tightly grounded in the provided Context"
**New:** "Prioritize suggestions that open NEW directions, not variations on what's discussed"

### Selection
**Old:** "Explain or elaborate on the following selection"
**New:** "Add details and perspectives NOT already covered in the Foundation"

---

## Why This Works

### Cognitive Framing
- **Old:** Context = "grounding" → encourages restating
- **New:** Context = "foundation" → encourages building upward

### Explicit Instructions
- **Old:** Implicit expectation not to repeat
- **New:** Explicit "Do NOT repeat" instruction

### Task Clarity
- **Old:** Generic "explain" or "write about"
- **New:** Specific "add X, Y, Z that aren't in the foundation"

### Visual Cues
- **Old:** No visual separation
- **New:** "↑ This is already covered" creates clear boundary

---

## Testing Checklist

When testing the new system, verify:

1. ✅ Context is labeled "Foundation" not "Context"
2. ✅ "↑ This is already covered" message appears
3. ✅ Instructions include "BEYOND", "ADD NEW", or similar
4. ✅ Anti-repetition footer is present
5. ✅ Concrete guidance (bullets) on what to add
6. ✅ Responses avoid restating foundation content
7. ✅ Responses add genuinely new information

---

## Conclusion

The new system transforms how context is presented and interpreted:

- **Psychological:** Foundation (base to build on) vs Context (reference to use)
- **Explicit:** Clear instructions to avoid repetition
- **Structured:** Concrete guidance on what to add
- **Visual:** Clear boundary between "already covered" and "what to add"

Result: LLM responses that consistently **add value** rather than **repeat information**.