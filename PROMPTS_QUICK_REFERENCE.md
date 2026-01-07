# Prompts Quick Reference Card

## 🎯 Goal
Reduce repetition in LLM responses by framing each response as **adding** to an existing exploration rather than restating what's already known.

## 🔑 Key Changes

### 1. Context → Foundation
**Before:** "Use the provided Context to ground your explanation"
**After:** "The Foundation has already been explored. ADD NEW insights beyond what's shown above."

### 2. Additive Language
Every prompt now emphasizes:
- **EXTEND BEYOND** what's in the Foundation
- **ADD NEW** perspectives/insights
- **Avoid repeating** what's already covered

### 3. System-Level Guidance
Both structured and creative modes now include:
```
When Foundation/Context is provided, treat it as already-covered territory.
Your role is to ADVANCE the exploration by adding NEW information.
Do NOT repeat or merely rephrase what has already been established.
```

## 📝 Updated Prompts Summary

| Prompt | Old Focus | New Focus |
|--------|-----------|-----------|
| **explain** | "ground your explanation" | "EXTEND BEYOND", add new aspects |
| **initial_explainer** | Basic answer | Answer + extension questions |
| **selection** | Vague "elaborate" | Unpack, examples, implications NOT in context |
| **synthesis** | Bridge positions | Create something NEW from integration |
| **thesis** | Detailed argument for | NEW reasoning not yet mentioned |
| **antithesis** | Detailed argument against | FRESH counterarguments not explored |
| **related_ideas** | "Tightly grounded" | Open NEW directions, not variations |
| **deep_dive** | "Write enough to understand" | Go BEYOND overview with depth/examples |

## 🧪 Quick Test

**Good Response (Additive):**
```
✅ Adds specific examples not in Foundation
✅ Introduces new frameworks/perspectives
✅ Explores edge cases or implications
✅ Feels like building upon, not repeating
```

**Bad Response (Repetitive):**
```
❌ Restates what's in Foundation
❌ Same examples as parent nodes
❌ Feels like summary vs extension
❌ No new information value
```

## 📂 Files Changed

1. `lib/dialectic/responses/prompts.ex` - All 8 prompt templates
2. `lib/dialectic/responses/prompts_structured.ex` - System prompt
3. `lib/dialectic/responses/prompts_creative.ex` - System prompt

## 🔄 Rollback (if needed)

```bash
git checkout HEAD~1 lib/dialectic/responses/prompts*.ex
mix compile
```

## 📊 What to Monitor

- User reports of repetition (should decrease)
- Response value/usefulness (should increase)
- Graph exploration depth (may increase)
- Regeneration rate (should decrease)

## 💡 Example Transformation

### Before
**Foundation:** "Quantum entanglement links particles across distance..."
**Prompt:** "Explain quantum entanglement using the Context."
**Result:** ❌ Restates that particles are linked across distance

### After
**Foundation:** "The following has already been explored: Quantum entanglement links particles across distance..."
**Prompt:** "Explain quantum entanglement by ADDING new insights that EXTEND BEYOND the Foundation. Focus on aspects like applications, experiments, or misconceptions."
**Result:** ✅ Discusses EPR paradox, Bell's theorem, quantum computing applications

## ✨ Benefits

- **For Users:** Less repetition, more value per node
- **For Exploration:** Deeper, more productive graphs
- **For Learning:** Progressive knowledge building
- **For Models:** Clearer task definition

## 🚀 Deployment

Changes are live immediately after:
```bash
mix compile
# Restart if running
```

No database migrations or data changes required.