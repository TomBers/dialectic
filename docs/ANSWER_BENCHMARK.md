# Comparing models with the answer benchmark

The benchmark runs 20 learning cases through the application's prompts, answer depths and Google Search settings. It checks response structure and measures streaming times; people must judge factual accuracy and learning value. Cases and review rubrics live in [learning_cases.json](../priv/evaluation/learning_cases.json).

## Run a comparison

Use the configured local development environment, including its database and `GOOGLE_API_KEY`. These commands make real, billable API requests. The harness currently supports **Google models only**; testing another provider requires extending it.

From the project root:

```sh
# Current application model and depth-specific thinking settings
MIX_ENV=dev mix llm.benchmark --concurrency 1 --output tmp/benchmark-baseline-1.json

# Replace CANDIDATE_GOOGLE_MODEL_ID with the model to evaluate
MIX_ENV=dev mix llm.benchmark --model CANDIDATE_GOOGLE_MODEL_ID --concurrency 1 --output tmp/benchmark-candidate-1.json
```

Useful options:

- `--case hbs-retrieval`: run one named case, useful for checking model compatibility first.
- `--limit 3`: run the first three cases for a quick smoke check.
- `--thinking minimal|low|medium|high`: override thinking for every case. Omit it to preserve application depth defaults; check that the candidate supports those settings.
- `--concurrency 1..4`: defaults to 2; use the same value for both models.

`--model` affects this run only. Reports under `tmp/` are ignored by Git, so retain useful reports with the comparison record elsewhere.

## Judge the results

Match results by case ID and compare separately by answer depth and task type.

| Signal | What to inspect |
|---|---|
| Answer quality | Read `output` against `rubric` and `reference_sources`. Manually score accuracy, source support, uncertainty and learning usefulness from 0–3 using the report's `review_scale`. `review: null` means ungraded. |
| Perceived speed | `first_token_ms` measures first nonblank content; `first_50_words_ms` is a useful passage-length proxy. Neither measures browser rendering. |
| Streaming stalls | `longest_content_gap_ms` measures gaps between nonblank chunks. |
| Learning plans | `estimated_first_visible_ms` includes buffering and any format repair. Invalid plans have no visible-answer estimate. |
| Reliability and cost | Inspect `status`, `repair_count`, `total_ms` and every entry in `attempts`. Sum usage across attempts; the final attempt alone misses repair cost. SDK cost estimates may omit search fees. |
| Concision and evidence | Check `within_word_range` and `source_links`. A longer answer or more links does not establish higher quality. Open the sources and check the claims. |

## Decide whether the project benefits

1. Define the intended improvement first: fewer unsupported claims, better explanations, more useful learning actions, lower cost or less waiting.
2. Use the same code revision, cases, settings and concurrency. Rerun the baseline after prompt or benchmark changes. Repeat both models several times with fresh filenames, alternating run order; review answers without model labels where practical.
3. Compare quality wins and regressions alongside median and slowest waits. Keep errors and incomplete answers in the results. This small suite is a screening tool, not proof of improved learning outcomes.
4. For a promising candidate, exercise actual grid creation, follow-ups, source checks and learning plans in the browser. Measure click-to-readable-content, stalls and completion. The harness does not reproduce the full queue, transport retry and browser experience.
5. Record the decision with examples, timings, costs, settings and code revision. A slower model might earn a role for deeper research while the faster default remains preferable for everyday exploration. If benefits are marginal, retain the existing model and add cases for weaknesses uncovered.
