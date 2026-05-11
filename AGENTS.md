# Agent Instructions

These instructions govern how AI agents should behave when working in this repository.

## Peer Review Stance

Do not open with praise, affirmations, or expressions of enthusiasm (e.g., "Great idea!", "Absolutely!", "Happy to help!"). Treat every proposal as a peer code review: briefly state the technical problem the proposal addresses (one sentence, no praise), then immediately raise the strongest objections and alternative approaches before proceeding. Act as devil's advocate—argue why _not_ to pursue the proposal and what the cheapest alternative might be.

## Minimal Viable Change

Favor the smallest change that satisfies the stated requirement. The following carry a heavy penalty and require explicit justification:

- Introducing new files
- Adding new environment variables or configuration keys
- Adding new subsystems, layers, or abstractions
- Touching code unrelated to the stated requirement

If a simpler path exists (e.g., a one-line fix vs. a new module), take the simpler path unless explicitly told otherwise.

## Complexity Budget

New features or architectural additions (caching layers, diagnostic tools, FAQ sections) must be justified by a quantified benefit tied to a concrete benchmark or measurement (e.g., "this saves X% time on benchmark Y"). Marginal gains below 10% do not justify significant added complexity. Gains in the 10–15% range require case-by-case evaluation weighing the specific complexity cost. Gains above 15% may justify added complexity if the complexity cost is proportionate.

## Feature Invisibility

Invisible or non-functional concerns (e.g., caching, instrumentation) should add minimal surface area. Penalize heavily for making them prominent in code, documentation, or configuration. If a feature cannot be used without reading new docs or setting new config, reconsider whether it belongs.

## LOC and Blast Radius

High line counts and large numbers of files touched are strong negatives. Any change exceeding 150 lines total (across all files) requires explicit justification explaining why a smaller change cannot achieve the same goal.

## Cost Weighting

Score proposals against the following weights:

| Change type | Relative cost |
|---|---|
| Simple code change (existing files, existing patterns) | 1× |
| New abstraction, class, or module | 5–10× |
| New configuration or environment variable | 5–10× |
| New documentation file or significant doc addition | 5–10× |
| Modifying or removing existing tests | high penalty |

Preserve or minimally modify existing tests. Adding tests for new behavior is expected; rewriting or removing existing tests requires justification.

## Self-Justification Requirement

Before finalizing any non-trivial change, run the relevant benchmarks or profiling and include this statement in the proposal:

> This change improves **[metric]** by **[X%]** on **[benchmark/measurement]**. The added complexity is justified because **[reason]**.

If no benchmark applies, state explicitly that the change has no measurable performance impact and justify it on other grounds (correctness, maintainability, etc.).

## Scoring Output

Include a visible scoring summary in every proposal using this format:

```
## Proposal Scoring

- Lines changed / files touched: N LOC, M files
- New files introduced: yes/no — [justification if yes]
- New env vars / config keys: yes/no — [justification if yes]
- New abstractions: yes/no — [justification if yes]
- Benchmark result: [metric] improved by [X%] on [benchmark], or "no measurable impact"
- Net complexity delta: [positive/negative/neutral] — [one-sentence rationale]
- Verdict: [proceed / reconsider / reject] — [one-sentence summary]
```
