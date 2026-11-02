# DECISION_ADR.md — repo-context layer for Copilot: adopt, and how

Status: PROPOSED — all tiers complete (411 runs attempted, 378 valid, 2026-11-01; nine web-008 Tier 3 reruns pending, see Not-completed). Numbers are copied from `results/scorecard.md` (reproduce: `make tier1 tier2 tier3 scorecard`).
copied from `results/scorecard.md` (reproduce: `make tier1 tier2 tier3 scorecard`).

## Context
Kestrel Freight's agent is GitHub Copilot CLI. The question was whether a repo-context
layer (Graphify, Serena, or both) lets it complete real tasks with fewer tokens, fewer
premium requests, less wall-clock and equal-or-better correctness than a grep/read
baseline — and whether the pattern can be packaged so any repo adopts it in ≤ 15 minutes.

## What was measured, and each metric's confidence
| Metric | Source | Confidence |
|---|---|---|
| input/output/cache tokens | `events.jsonl` `session.shutdown.tokenDetails` | high — exact per session |
| model calls | count of `session.usage_record` | high |
| premium requests (billing) | `session.shutdown.totalPremiumRequests`, cross-checked with stdout `result` | high for the number; note it is per prompt × multiplier, not per call (#1582 concerns `/usage`, which we do not use) |
| wall-clock | harness clock around the `copilot` process | high |
| turns, tool calls, MCP tool calls | `assistant.turn_start`, `tool.execution_start` | high |
| bytes read | result length of view/grep/glob/bash tool calls | medium — proxy |
| correctness | arm-blind Copilot judge 0/1/2 with rubric + expected; edit tasks by tests | medium — judge/human agreement reported from the 20 % spot-check |
| model | `auto` on this account; resolved model recorded per run and stratified | confound acknowledged: compare within a model |

## Results — Tier 1 (Python gateway + TypeScript web, 12 tasks × 4 arms × 3 runs)
Same resolved model in every arm (`gpt-6-luna`; a `copilot-search-a` helper appeared in 10
baseline/serena runs). Prompt tokens = input + cache reads + cache writes per session.

| arm | n | prompt tokens p50 / p90 | model calls p50 | wall p50 / p90 | correctness | edit pass |
|---|---|---|---|---|---|---|
| baseline | 36 | 87k / 167k | 5 | 19.3s / 39.7s | 86% | 89% |
| serena § | 36 | 86k / 190k | 5 | 22.0s / 46.2s | 90% | 100% |
| graphify | 36 | 204k / 319k | 7 | 31.4s / 60.4s | 85% | 100% |
| graphify-lean † | 36 | 142k / 230k | 8 | 33.4s / 50.5s | 90% | 100% |
| graphify-guard | 36 | 242k / 462k | 8 | 38.6s / 75.6s | 82% | 100% |

§ 21 web runs from 2026-10-30 + 15 services runs re-run 2026-11-01 with Serena actually connected (see Correction). Serena tools used in 2 of 36.
† Run 2026-11-01 (new quota month), same tasks, same judge, same resolved model. Kit-authored
1.9 KB skill in place of the vendor's 48 KB SKILL.md + 48 KB references; everything else
identical to the graphify arm. Graph actually queried in 31/36 runs (vendor: 19/36).

Per category (correctness; prompt tokens p50):

| category | baseline | serena | graphify | graphify-lean | graphify-guard |
|---|---|---|---|---|---|
| literal (n=9) | 83%; 47k | 83%; 45k | 83%; 131k | 94%; 101k | 89%; 104k |
| locate (n=3) | 100%; 63k | 100%; 62k | 100%; 136k | 100%; 102k | 67%; 164k |
| trace (n=15) | 83%; 89k | 83%; 87k | 73%; 205k | 80%; 144k | 70%; 408k |
| edit (n=9) | 89%; 163k | 100%; 174k | 100%; 279k | 100%; 202k | 100%; 277k |

**Lean-skill result.** Cutting the skill text 25× removed about a third of the graphify
arm's token cost (205k → 142k) and raised correctness to the best Tier 1 figure (90 %),
with the graph consulted far more often. It did not close the gap to baseline: 1.6×
tokens, 1.7× wall. On every one of the 12 tasks lean sat between baseline and vendor on
tokens; it never beat baseline. The remaining cost is the graph output and the extra model
calls it triggers (8 vs 5), not the instructions.

**Correction (2026-11-01) — the serena arm was not what it claimed on kestrel-services.**
Two defects, both found only when an arm forced the agent onto Serena:
1. Copilot CLI 1.0.105 loads `.mcp.json` from the *working directory only*. Services tasks
   run inside `gateway/`, `booking/` or `pricing/`, so Serena was never connected there
   (probe: 0 serena tools from `gateway/`, 10 from the root). 15 Tier 1 and 9 Tier 2
   serena-arm records are re-labelled invalid (`invalid_reason` set, listed in the
   scorecard, never pooled). The kit now writes `<service>/.mcp.json`.
2. With Serena connected, every call failed: Roslyn LS 5.5 needs the .NET 10 runtime and
   the machine had .NET 8 only; one failing language server takes the whole Serena project
   down. Runtime installed; `adlc doctor` now fails red on this.
The serena row above is therefore kestrel-web only (n = 21, Serena connected, used once).
The services numbers are being re-measured; see the 2026-11-01 rows below when present.

**Tool adoption (the finding that explains the table).** Serena's MCP tools were used in
**1 of 36** serena-arm runs (web-010 r2: `get_symbols_overview`, `find_symbol`); every other
run used `rg`/`view`. The serena arm is therefore baseline with Serena connected and
ignored — its differences from baseline (−11k tokens, +3 pts correctness, one fewer edit
failure) are within run-to-run variance (tokens CV 0.5–0.6). The graphify skill was
invoked in **36 of 36** graphify-arm runs (Copilot auto-selects it from its description),
and `graphify query` actually ran in 19/36 (graphify) and 22/36 (guard). The skill text is
48 KB (~12k tokens) and is the bulk of the 2.3×–2.8× token cost; on `literal` tasks the
agent read the skill and then grepped, exactly as the routing policy says.

**Wins.** No context arm beat baseline on tokens or wall-clock in any Tier 1 category.
Correctness: all three context arms reached 100 % edit pass vs 89 % baseline (one
baseline failure on web-009, n=9 — suggestive, not significant). Graphify arms lost on
`trace` (−10 to −13 pts), the category the graph was expected to win; the per-task table
shows the loss concentrated on svc-003 (gateway dead-module trace) and web-005.

**KB currency.** Every run started with a FRESH artifact (p50 = p95 = 0 commits behind);
graph queries p50 = 1 in graphify arms. The ever-current claim holds for L0 in CI-shaped
runs; it has not yet been stressed by drift.

**Judge/human agreement.** `results/spotcheck.md` (29 answers, arm hidden) awaits the
owner; `adlc scorecard --spotcheck results/spotcheck.md` prints agreement. Edit tasks are
judged by overlay tests, not by the model.

## Results — Tier 2 (Java booking + C# pricing, 3 tasks × 4 arms × 3 runs = 36 runs)
| arm | n | prompt tokens p50 | calls p50 | wall p50 | correctness | Serena used | graph queried |
|---|---|---|---|---|---|---|---|
| baseline | 9 | 115k | 6 | 30s | 78% | — | — |
| serena ¶ | 9 | 140k / 159k | 6 | 36.2s / 48.9s | 100% | 100% |
| graphify | 9 | 230k | 8 | 33s | 100% | — | 1/9 |
| graphify-guard | 9 | 265k | 9 | 36s | 89% | — | 2/9 |

Per task: svc-002 (locate, C#) 100/83/100/100 %; svc-009 (edit, C# rounding) 100 % in all
arms; **svc-010 (edit, Java JPA `@ManyToOne`) 33/33/100/67 %** — the only Tier 1+2 cell where
a context arm clearly beat baseline on correctness (n=3 per cell; baseline and serena
failed the overlay test twice each). Serena was again unused in 0/9 runs, so the Java/C#
hypothesis ("symbol tools matter where grep is weakest") is untested, not refuted.
Graphify arms queried the graph in only 1–2 of 9 runs here; the svc-010 win came with the
skill loaded but mostly without graph queries — the mechanism is unclear and the sample
is small. Thresholds below are unchanged by Tier 2.

¶ Tier 2 serena re-run 2026-11-01 with Serena connected (original 9 runs had no Serena: invalid). Tools used in 2 of 9, both on the Java JPA edit svc-010, which went 0/0/2 (baseline) → 2/2/2; one of those three passes made no Serena call. svc-002 and svc-009 were already 3/3 in every arm.

## Results — Tier 3 (KB, cross-repo, cross-project; 15 tasks × 3 arms × 3 runs = 135 attempted, 126 valid)
Arms: baseline, graphify, graphify-federated (graphify + `project-graph.json` so `adlc query --level`
works). The `both` arm was not run: no arm beat baseline alone in Tiers 1–2. **web-008's 9 runs are
excluded**: the account's monthly Copilot premium-request quota ran out during them (`session.error`
"exceeded your monthly quota"); they cannot be re-run this month.

| arm | n | prompt tokens p50 / p90 | calls p50 | wall p50 / p90 | correctness | graph queried |
|---|---|---|---|---|---|---|
| baseline | 42 | 59k / 113k | 4 | 18.2s / 31.6s | 79% | 0/42 |
| graphify | 42 | 191k / 434k | 6 | 35.6s / 69.3s | 77% | 37/42 |
| graphify-federated | 42 | 230k / 487k | 7 | 40.8s / 76.6s | 85% | 36/42 |

| category | baseline | graphify | graphify-federated |
|---|---|---|---|
| archaeology | 90%; 56k (n=15) | 80%; 186k (n=15) | 90%; 200k (n=15) |
| cross-repo | 50%; 102k (n=9) | 56%; 373k (n=9) | 67%; 271k (n=9) |
| cross-project | 94%; 71k (n=9) | 94%; 199k (n=9) | 100%; 246k (n=9) |
| locate | 75%; 55k (n=6) | 83%; 166k (n=6) | 75%; 154k (n=6) |
| literal | 67%; 28k (n=3) | 67%; 71k (n=3) | 83%; 29k (n=3) |

**Knowledge base (kestrel-ops, 10 tasks × 3 runs per arm):** baseline 90% at 55k / graphify 87% at 169k / graphify-federated 93% at 171k. A 40-file docs repo fits in
Copilot's context, so the LLM-built docs graph (7.5 min, 35 model calls to build) did not pay for
itself; the federated arm's edge is within noise. **Federated impact question** (ops-008, "who is
affected if pricing changes /v1/quote"): the federated arm called `adlc query --level` 3–5 times per
run and scored 100 % in all 3 runs, as did baseline — the question was answerable from CODEOWNERS plus
grep on this small org. **Cross-repo** (web-006/007, svc-007): the hardest category for every arm
(50 / 56 / 67 %); web-007 (the `reference` vs `client_reference` idempotency bug) scored 17 % baseline vs
50 % federated (3 runs each) — the one place the project graph plausibly helped; n=3 per cell.

**Totals across tiers:** 315 runs attempted, 306 valid; agent premium requests (billing) 306, judge premium requests 246, model calls 2074, prompt tokens 56.3 M, agent wall-clock 2.9 h.

## Thresholds (set FROM baseline numbers)
Adopt an arm for a category when, within the same resolved model and over ≥ 3 runs:
prompt tokens p50 ≤ 0.8 × baseline (Tier 1 baseline: 87k → ≤ 70k), correctness ≥
baseline − 5 pts (≥ 81 %), wall p50 ≤ 1.2 × baseline (≤ 23 s). `literal` is excluded from
the token criterion by design (grep should win).
**Tier 1 outcome against these thresholds: no arm qualifies.** Serena meets the
correctness and wall criteria but not tokens (76k) and, more importantly, was not used.
Graphify arms fail tokens and wall in every category; graphify-lean is the closest
(142k vs ≤ 70k; 33 s vs ≤ 23 s) and the only arm to clear the correctness bar by a margin.

## Decision
1. **Adopt the contract and the kit now** (AGENTS.md + adlc block, routing, freshness,
   CI enforcement, federation). They are vendor-neutral, cost nothing per task, and the
   adoption test shows ≤ 15 min onboarding. This is the durable asset.
2. **Do not roll out Graphify as the default context layer on Copilot CLI.** At the
   vendor's shipped skill size it costs 2.3× tokens and 1.6× time for no correctness gain
   on Tier 1. The lean-skill re-test (2026-11-01) is done: `adlc init --skill-profile lean`
   is now the kit default *when a team opts into graphify* because it is strictly better
   than the vendor skill on every axis (−31 % tokens, +5 pts correctness, graph used in
   86 % of runs), but it still costs 1.6× baseline tokens for +4 pts, which does not meet
   the threshold. Keep the graph build in CI because federation and the Tier 3 KB tasks
   depend on it; offer graphify-lean to teams whose work is edit-heavy on typed code
   (Tier 2 Java JPA edit 100 % vs 33 %), not as an org default.
3. **Serena: the pilot's original verdict ("unproven, agent ignores it") rested on 24
   runs where Serena was not connected and 21 where it was connected but idle.** Both
   causes were kit/environment defects, now fixed (per-service `.mcp.json`; .NET 10
   runtime; doctor checks for both). The verdict is re-issued from the 2026-11-01 runs:
   plain serena re-measured on services + Tier 2, and `serena-forced` (text search denied,
   Serena the only search) on all of Tier 1. See "Serena, re-measured" below.
4. The hierarchy (L1/L2) is kept: it is cheap (1.4 s build, 0 ambiguous contract edges on
   Kestrel) and answers questions no single-repo tool can. Tier 3 shows the federated arm
   actually using `adlc query --level` and a small edge on cross-repo tasks (67 % vs 50 %,
   n=12), at 3.8× baseline tokens; on an org this small the same questions were mostly
   answerable from CODEOWNERS + grep. Its value is a bet on org size, not a Kestrel result.

## Serena, re-measured (2026-11-01)
Three defects stood between the pilot and a real Serena number: `.mcp.json` not loaded
from service subdirectories, Roslyn needing the .NET 10 runtime, and `--project ..` making
every agent-supplied path wrong. All three are fixed in the kit (each service is now its
own Serena project); 10 forced runs recorded against a broken Serena are quarantined, not
counted. Then two arms ran on Tier 1 with Serena verified live in all three services:

| arm | n | prompt tokens p50 / p90 | calls p50 | wall p50 / p90 | correctness | edit pass | Serena calls p50 | runs using Serena |
|---|---|---|---|---|---|---|---|---|
| baseline | 36 | 88k / 172k | 5 | 19.4s / 42.4s | 86% | 89% | 0 | 0/36 |
| serena-forced ‡ | 36 | 141k / 284k | 6 | 41.2s / 57.5s | 82% | 89% | 8 | 33/36 |
| graphify-lean | 36 | 142k / 230k | 8 | 33.4s / 50.5s | 90% | 100% | 0 | 0/36 |

‡ Text search denied (`rg`, `grep_search`, code-search subagent, grep-family shell
commands via a preToolUse hook) and an imperative routing section; Serena is the only
search in the room. `glob` and `view` stay allowed.

By category (correctness; tokens p50), baseline / serena-forced: literal 83 %; 47k /
83 %; 104k · locate 100 %; 63k / 100 %; 99k · trace 83 %; 89k / 73 %; 141k · edit 89 %;
163k / 89 %; 217k. By repo: services 77 % → 73 %, web 93 % → 88 %.

**Reading.** When the agent is made to use Serena it does: 8 symbol calls per run, 33 of
36 runs. The result is 1.6× baseline tokens, 2.1× wall-clock, and 4 points less correct.
Per task it never beat baseline; it lost on svc-004 (trace) and web-010 (edit) and tied
elsewhere. Wall-clock is the worst axis because each language server answers in 0.5–3 s
and a run makes 8–25 such calls. The one place Serena matched a graph arm was svc-003
(1/1/1 vs baseline 1/0/1). Serena's path-rooted API is a real cost: when the agent is
unsure of the project root it probes two or three path forms before one lands.

**Verdict, re-issued.** Serena on Copilot CLI 1.0.105 / gpt-6-luna is now *measured*, not
unproven: the agent does not reach for it voluntarily (1/21 on web, where it was always
available), and when forced to it is slower and no more correct than grep on this org's
code. It is not recommended as a default context layer. It remains the right tool for the
one job grep cannot do, type-aware symbol edits across files, and the kit keeps the
pin and the per-service configuration for teams that want it. 
Plain serena, re-run with Serena present (24 runs, 2026-11-01):

| slice | arm | n | prompt tokens p50 | wall p50 | correctness | edit pass | runs using Serena |
|---|---|---|---|---|---|---|---|
| Tier 1 services (5 tasks) | baseline | 15 | 63k | 17.6s | 77% | 100% | 0/15 |
| Tier 1 services | serena | 15 | 51k | 22.2s | 80% | 100% | 1/15 |
| Tier 1 services | serena-forced | 15 | 134k | 36.5s | 73% | 100% | 12/15 |
| Tier 2 Java + C# (3 tasks) | baseline | 9 | 115k | 30.0s | 78% | 67% | 0/9 |
| Tier 2 Java + C# | serena | 9 | 140k | 36.2s | 100% | 100% | 2/9 |
| Tier 2 Java + C# | graphify | 9 | 230k | 33.4s | 100% | 100% | 0/9 |

**Final Serena verdict.** Offered, Serena is used in 2 of 36 Tier 1 runs and 2 of 9 Tier 2
runs; the plain arm is baseline with a 0.8 s MCP launch tax and run-to-run noise. Forced,
it is 1.6× tokens, 2.1× wall, −4 pts. The one task where Serena-arm runs beat baseline is
the Java JPA edit (3/3 vs 1/3, n = 3, one pass without any Serena call), the same task
Graphify wins. Not a default context layer; keep it pinned and configured per service for
teams doing type-aware edits in Java/C#, and re-test when Copilot CLI changes how it
selects tools.

## Operating cost per tool (measured where marked)
| Item | Cost | Measured? |
|---|---|---|
| L0 graph build (code only, no LLM) | kestrel-services 1584 nodes in 5.8 s; kestrel-web 2.2 s; kestrel-ops stamp-only | yes |
| Docs semantic pass (`/graphify .` in a Copilot session, 43 files) | 7 min 27 s, 35 model calls, 1 premium request, 2.96 M input tokens (2.84 M cache reads) | yes — `results/docs-pass.json` |
| L1 federation (3 repos, 4 resolvers) | 1.4 s; http-contract 29 edges / 0 ambiguous after prefix resolution; doc-reference 243 edges | yes |
| L1 resolver false-positive rate | 29 http-contract edges, 0 ambiguous; every provider→consumer pair in PROJECT_REPORT.md matches the spec's contract table (16 routes, 10 consumed) — 0 false positives on Kestrel; this is the number that decides whether Graphify Cloud's cross-repo graph is worth paying for | yes (by inspection of the report) |
| Serena language servers | pinned by Serena commit; jdtls download 322 MB, ts-ls 25 MB, pyright lazy, Roslyn needs .NET 10 runtime | yes (download), first-activation latency ⏳ |
| Devcontainer image | Dockerfile authored; **not built** (no Docker on pilot machine); estimate 3–4 GB | no |
| Serena licence | GPL-3.0-or-later (application) / MIT (SolidLSP). Run as a separate process, shipped in the image with source URL + commit. **Legal review required before org-wide rollout.** | n/a |

## What survives a vendor change
`AGENTS.md` + the `adlc` block, the golden tasks, the harness and its results, this ADR,
the kit's CLI surface and workflows. Graphify and Serena sit behind `adlc baseline` /
`.mcp.json`; removing either touches the kit, not a consuming repo's prose.

## Non-code knowledge
Served, but not better than reading: the kestrel-ops docs pass produced 53 document, 24
concept and 16 rationale nodes, and the arms with it scored 87–93 % on the 10 KB tasks vs
90 % for baseline reading markdown directly, at 3× the tokens. At 40 files the KB fits in
context; the docs graph is a bet on corpus size. Gap confirmed: the semantic pass is a
Copilot-session-only step (never headless by policy), so docs freshness lags code freshness.

## Graphify Cloud — procurement questions (asked before any purchase)
1. Data location and access: where do graphs and source excerpts live, who at the vendor can read them, is there a single-tenant option?
2. SOC 2 Type II report and data-residency commitments (EU/US).
3. Export and exit: full `graph.json` export at any time, format stability, deletion SLA.
4. Pricing at 50 / 200 / 1000 repos, and what "cross-repo graph" costs separately.
5. OSS roadmap now that Cloud exists: which of `merge-graphs`, federation and MCP stay in the Apache-2.0 CLI.

## Rollout plan
| Wave | Scope | Mechanism | Exit criterion (read off the aggregated scorecard) |
|---|---|---|---|
| Canary | kestrel-services, kestrel-web, kestrel-ops | this pilot | Tier 1 thresholds met for ≥ 2 categories; adoption test ≤ 15 min |
| 1 | one volunteer team | opt-in `adlc init` | 4 weekly regress rows with no >15 % drift; zero kit bugs filed in week 4 |
| 2 | new repos | org ruleset makes `adlc-contract-lint` a required check for new repos | 90 % of new repos green on first PR |
| 3 | existing repos | bot PR running `adlc init` | team fills AGENTS.md prose within 2 weeks; drift alarms < 1/repo/month |

Owner: **Platform Engineering lead** (role, not a committee). Revisit: **2027-04-30**.
