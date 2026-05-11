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

## Tooling

Run these commands from the repository root before and after any code change:

- **Tests:** `bundle exec rspec`
- **Lint:** `bundle exec rubocop`

Do not claim a change is correct without having run both successfully. If either fails on the pre-change baseline, note the pre-existing failures and do not treat them as regressions you caused.

## YAGNI — No Speculative Abstractions

Do not add extension points, base classes, hook systems, or "future-proofing" scaffolding that nothing currently needs. Minimal viable change covers scope; this covers forward-looking over-engineering that nominally fits within scope but adds dead weight. If the justification for a design decision is "we might need this later," remove it.

## Dependency Hygiene

Do not add new gems without explicit direction. Prefer Ruby stdlib or gems already present in the `Gemfile`. Adding a new runtime dependency to a gem widens its transitive dependency footprint for all consumers and carries a 5–10× cost penalty. When a new gem is unavoidable, verify it has no known vulnerabilities before proposing it.

## Public API Stability

Treat the gem's public interface (method signatures, public constants, module structure) as high-cost to change. Do not rename public methods, remove them, change their parameter lists, or rename public constants without explicit direction. Breaking changes to the public API require a version bump and a changelog entry.

## Clarify Before Acting on Ambiguity

If a requirement is genuinely ambiguous — multiple valid interpretations exist, or the correct behavior is unclear — stop and ask rather than picking an interpretation and implementing it. Wrong-direction work is expensive to undo. State the ambiguity explicitly: "This could mean X or Y; which do you want?"

## Commit Hygiene

- One logical change per commit. Do not bundle formatting fixes, refactoring, and feature work in a single commit.
- Write commit messages in the imperative mood: "Fix X", not "Fixed X" or "Fixing X".
- Do not include `[skip ci]` or similar flags without explicit instruction.

## Security Baseline

- Never commit credentials, API keys, tokens, or secrets.
- Do not introduce `eval`, shell injection risks, or patterns that bypass existing security boundaries.
- Do not add code that writes user-controlled input to the filesystem or executes it without sanitization.

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
