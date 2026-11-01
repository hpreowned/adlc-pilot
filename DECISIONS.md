# DECISIONS.md — calls made without asking

Format: date · decision · why. Newest at the bottom. Nothing here is a promise;
everything here is reversible by the pilot owner.

## 2026-10-29

- **Workspace root is `/Users/hpatil/ADLC`**, not a nested `adlc-pilot/`. The spec's
  tree is reproduced one level down from here. One fewer directory to explain.
- **Subagent model routing.** Architecture, contracts, judgment, and the final report
  are done in the main (Fable) session. Bulk generation of the fictional Kestrel repos,
  fixtures, and boilerplate is delegated to Sonnet subagents; trivial chores to Haiku.
  Requested by the pilot owner mid-session to keep token spend proportional to the work.
- **Toolchain installed on the dev machine via Homebrew** (openjdk@21, maven, act) and
  Microsoft's `dotnet-install.sh` into `.toolchain/dotnet` (the Homebrew cask needs
  sudo). This is dev-machine convenience only; the devcontainer is the distributable.
  `.toolchain/env.sh` sources it. Nothing in the kit depends on these paths.
- **Python 3.12 for the kit and the gateway** (`uv python install 3.12`). Graphify pins
  `tree-sitter<0.26` wheels; 3.14 is too new to trust for a pinned toolchain.
- **Graphify pin: `graphifyy[leiden]==0.9.97`** (wheel sha256
  `eb24dd7f…65e01a`), latest on PyPI at verification time. Re-verify before tagging.
- **Serena pin: commit `ede329aaf0c824bea75455a2926f01420d7aa620`** (main,
  2026-10-28). LICENSE read: the Serena application is **GPL-3.0-or-later**, SolidLSP
  is MIT; the combined `serena-agent` package is GPL-3.0-or-later. Flagged for legal in
  the ADR. We run it as a separate MCP process, never link it, and ship it only inside
  the devcontainer image with source URL + commit recorded.
- **Copilot auth for the harness: `COPILOT_GITHUB_TOKEN` is read from env at run time
  only.** On the dev machine the Makefile obtains it via `gh auth token` into the
  process env; it is never written to disk or into results. Transcripts are scrubbed.
- **Copilot model: `auto`, resolved model recorded per run.** Every named `--model`
  value probed (`gpt-5.4`, `gpt-5-mini`, `claude-sonnet-4.5`, `claude-haiku-4.5`, and 15
  others) returns "not available" on this account's plan. The harness therefore runs
  `--model auto`, records `session.auto_mode_resolved.chosenModel` per run, and the
  scorecard stratifies by model. `ADLC_COPILOT_MODEL` overrides this for plans that can
  pin. Confound acknowledged in the report's confidence footnote.
- **Premium-request accounting:** `events.jsonl` `session.shutdown` is primary; the
  stdout `result` event (`usage.premiumRequests`, `totalApiDurationMs`) is the
  per-run cross-check instead of `/usage` (which is interactive-only). #1582 noted.
- **events.jsonl schema discovered from 22 real sessions** on this machine plus the
  smoke run. Documented in `adlc-kit/harness/EVENTS_SCHEMA.md`.
- **Graphify's own `merge-graphs` / `global` commands are NOT used for federation.**
  They merge into `~/.graphify/` (home directory — forbidden by principle 1) and do
  not namespace ids or add cross-repo resolvers. `adlc federate` is built on
  `graph.json` + NetworkX directly, as the spec requires.
- **`.graphifyrc` is key=value**, not YAML/JSON (verified in `rcfile.py`): supports
  `viz_node_limit=<int>` and `language.<ext>=<lang>` only. Template matches that.
- **Graphify skill for Copilot:** `graphify install --platform copilot` targets
  `~/.copilot/skills` (home). `adlc init` instead writes the skill project-scoped into
  `.github/skills/graphify/SKILL.md` with an `adlc stale` preamble prepended.
  Verified empirically (one Copilot run with probe skills in `.github/skills`,
  `.copilot/skills`, `.claude/skills`, `.agents/skills`): only `.github/skills` loads.
  Graphify's `--platform copilot --project` target (`.copilot/skills/`) is therefore
  dead weight for Copilot CLI 1.0.73; the kit copies the skill into place itself.

## 2026-10-30

- **Copilot workspace MCP config needs `--trust-folder`** in prompt mode; without it
  `.mcp.json` / `.github/mcp.json` are silently ignored (verified: `session.mcp_servers_loaded`
  shows only the builtin GitHub server). The harness and `adlc` pass `--trust-folder`
  on every headless run. Server entries must use `"type": "local"` (Copilot's own
  writer emits that; `"stdio"` is accepted but was not needed).
- **The `.mcp.json` `tools` allowlist does not trim what Serena advertises** (23 tools
  loaded regardless of the list). Enforcement moved to Serena's side: a committed
  `.serena/adlc-context.yml` (custom `--context` YAML) with `excluded_tools` yields
  exactly the 10 allowlisted tools. The allowlist is still written for documentation
  and for any future Copilot build that honours it.
- **Serena 2.x defaults to a REPL interface** (`agent_interface: REPL` → only
  `initial_instructions` + `serena_repl`). The kit passes `--agent-interface tools`.
  Also `--project-from-cwd` so the committed `.mcp.json` has no absolute paths, and a
  committed `.serena/project.yml` declares the language servers. Serena still writes
  `~/.serena/serena_config.yml` + logs on first run; that is runtime cache, not
  something any repo depends on (doctor checks nothing in `~`).
- **Serena memories live in `<repo>/.serena/memories/` and are committed**; the
  allowlist deliberately excludes `write_memory`/`edit_memory`/`delete_memory` so agents
  cannot mutate the contract surface at run time. Memory updates go through PRs.
- **Copilot CLI self-updates.** Mid-session `copilot --version` moved 1.0.73 → 1.0.105
  without any action from us (Homebrew cask binary is 1.0.60; the CLI downloads updates
  into its own store). `--no-auto-update` would fall back to the *bundled* 1.0.60, which
  predates the behaviours we verified (`.github/skills`, `--trust-folder`). Decision: on
  the dev machine the harness runs whatever is current, records
  `session.start.copilotVersion` per run, and the scorecard lists every version seen;
  a mixed-version tier is flagged. The devcontainer installs `@github/copilot@1.0.105`
  via npm and runs with `--no-auto-update`, where bundled == pinned. Pin bumped to 1.0.105.
- **LLM API keys in the developer's shell** (an `OPENAI_API_KEY` was present here) would
  make headless `graphify extract` pick a backend. `adlc baseline` and the harness strip
  `*_API_KEY` from the child environment and force `GRAPHIFY_BACKEND=none`; `adlc doctor`
  warns when such keys are set. Non-negotiable 2 is enforced in code, not by asking.
- **`adlc doctor` before `adlc baseline`**: a missing artifact is a WARN (not built yet),
  a stamped-but-stale one beyond threshold is a FAIL. Otherwise the documented order
  (init → fill prose → doctor → baseline) could never be green at step 3.
- **AGENTS.md skeleton uses bare TODO words**, not backticked fake paths — the lint's
  referenced-path drift check correctly flagged the template's own placeholder.
- **Copilot CLI hooks exist and work from the repo**: `.github/hooks/<name>.json` with
  `{"version":1,"hooks":{"preToolUse":[{"type":"command","bash":"…"}]}}`; the command
  receives `{sessionId,cwd,toolName,toolArgs}` on stdin (verified with a probe hook on
  `view`). The `graphify-guard` arm is therefore buildable on Copilot: a kit adapter
  (`adlc guard-hook`) maps Copilot's `view|grep|glob` to `graphify hook-guard read|grep|find`
  and emits Copilot's decision JSON. `graphify copilot install` itself ships no hook.
- **Skill on/off per arm** is `$COPILOT_HOME/settings.json` → `{"disabledSkills":["graphify"]}`
  (what `copilot skill disable` writes). Serena on/off is `--disable-mcp-server serena`.
  Arms differ only by what is disabled on top of the same committed repo state.
- **Reusable workflows live in `adlc-kit/.github/workflows/`** (the only path GitHub
  resolves for `workflow_call`); `adlc-kit/workflows/README.md` indexes them. The spec's
  `workflows/` directory is kept as that index rather than duplicating YAML.
- **Serena memories are derived, not authored**: `adlc baseline` regenerates
  `.serena/memories/adlc_contract.md` (from AGENTS.md sections) and
  `adlc_graph_summary.md` (from GRAPH_REPORT god nodes). One source of truth, same
  freshness stamp, no agent-run onboarding that would need `write_memory`.
- **Language-server pins corrected to versions that exist**: basedpyright 1.40.2,
  typescript-language-server 6.0.2 (+ typescript 5.9.3, not 7.x), jdtls 1.50.0 build
  202509041425, csharp-ls 0.28.0. My first guesses (1.29.5 / 4.3.4 / 1.43.0 / 0.18.0)
  failed to install — pins are now only written after a successful install.
- **csharp-ls over OmniSharp**: csharp-ls is a `dotnet tool` (one-line pin, no Mono, no
  bundled VS components); Serena has a first-class `csharp` server id for it.
- **Language servers are pinned by Serena, not by the kit.** Serena's solidlsp downloads
  exact versions (pyright 1.1.403, typescript-language-server 5.1.3 + typescript 5.9.3,
  a sha256-pinned jdtls VSIX, roslyn-language-server 5.5.0-2.26078.4). Installing
  separate binaries (`basedpyright`, `csharp-ls`) would be a second, unused copy;
  `csharp-ls` 0.23–0.28 also fails `dotnet tool install` on .NET 8 (package lacks
  DotnetToolSettings.xml). The devcontainer pre-warms with `serena
  download-ls-dependencies python typescript java csharp`; the Serena commit is the pin.
- **Premium requests ≠ model calls, and the harness reports both.** The kestrel-ops docs
  pass (one `-p` prompt) made 35 model calls (`session.usage_record`, cost 1.0 each) but
  `totalPremiumRequests` = 1 — Copilot bills per prompt × multiplier. `premium_requests`
  is the billing number; `model_calls` and `premium_cost_sum` (Σ cost) measure the work
  behind it. The scorecard shows all three; "fewer premium requests" is judged on billing,
  "fewer model calls" is reported alongside as the honest efficiency signal.
- **Headless `adlc baseline` must not overwrite a skill-built docs graph.** Tested on a
  copy of kestrel-ops after the `/graphify` pass: a full `graphify extract` (backend none)
  kept concept/rationale nodes but dropped 24 of 53 document nodes; `graphify update`
  ballooned document nodes 53 → 301 (duplicates). Decision: `adlc baseline --stamp-only`
  re-stamps an existing graph; on a docs-only repo `adlc baseline` defaults to stamp-only
  and prints that the docs semantic pass is refreshed only via `/graphify` in a Copilot
  session. Code repos keep full code-only extraction.
- **Docs semantic pass cost (kestrel-ops, 43 files):** 7 min 27 s wall, 35 model calls,
  1 premium request (billing), 2.96M input tokens (2.84M cache reads), 43k output tokens,
  model `gpt-6-luna` (auto). Output: 150 nodes (53 document, 24 concept, 16 rationale,
  57 code/structure), 168 edges. Recorded in `results/docs-pass.json`.
- **Roslyn language server needs the .NET 10 runtime** (Serena's `csharp` download failed
  on a .NET-8-only machine). Devcontainer installs the .NET 10 runtime next to the .NET 8
  SDK. `pyright` is fetched lazily by Serena at first use (0 B pre-download) — acceptable;
  the first Serena start on a Python repo pays ~0.5 min once per image.
- **Copilot hook protocol (verified):** a preToolUse hook's stdout JSON
  `{"permissionDecision":"deny","permissionDecisionReason":"…"}` blocks the tool and the
  reason reaches the model; `{"permissionDecision":"allow","additionalContext":"…"}` lets
  it run and injects the text. `adlc guard-hook` adapts graphify's `hook-guard read|search`
  (Claude-Code-shaped `tool_input`) to this; strict denies only `read` (graphify never
  blocks searches), non-strict nudges. Fails open if graphify is missing.
- **No Docker on the pilot machine.** Consequences, stated plainly: the devcontainer image
  is authored and reviewed but never built here; `act` cannot run, so the reusable
  workflows are verified by a stub runner (`tests/test_workflows.py`) that executes their
  `adlc …` steps against fixture repos and asserts the exit codes. Image build and a real
  `act` run are the first two items on the "could not complete" list.
- **Kit tagged `v0.1.0`** after the harness dry-run suite passed. Phase 8 retags on each
  adoption-test fix (`v0.1.1`, …). The `uv tool install git+<url>@v0.1.0` in ADOPT.md
  refers to the intended GitHub location; the pilot installs from the local path.
- **Arm purity is enforced by stripping, not by trust.** In the first live smoke run the
  `serena` arm ran `graphify query` through bash (AGENTS.md told it to, and
  `graphify-out/` was there). Each arm now removes the other context's files from the
  working copy (`graphify-out/`, the skill, `.mcp.json`, `.serena/`) and filters the
  kit-owned routing section to the tools that arm has; `baseline` is AGENTS.md prose
  only. Freshness is read from the pristine repo before stripping.
- **"Tokens" in the scorecard = prompt tokens = input + cache_read + cache_write.**
  Copilot's `input.tokenCount` is only the uncached slice (15–40 tokens per run in the
  smoke test while cache reads were 72k–371k). Output tokens are separate; the uncached
  slice is still shown.
- **Rubric lesson from the smoke task:** a 0/1/2 rubric must define the 1 for partial
  answers in *both* directions (code-only and UI-only), otherwise the judge scores a
  half-right answer 0. Added to the task review checklist.
- **Adoption test runs on the dev machine, not in the devcontainer** (no Docker). Same
  kit, same ADOPT.md steps, same clock; the stranger's AGENTS.md prose is supplied as
  `ADOPTION_PROSE.md` so the run is reproducible. The devcontainer variant is listed under
  "could not complete".
- **Skill size is a measurable cost; not changed mid-tier.** Graphify's Copilot skill is
  48 KB (`SKILL.md`, ~12k tokens) plus 48 KB of references. In the first Tier 1 records a
  `literal` task cost ~100k prompt tokens in the graphify arms vs ~46k in baseline/serena
  — the arm read the skill, then grepped exactly as the routing policy says. Decision:
  keep the vendor skill verbatim for the pilot so the measurement is of Graphify as
  shipped; file a kit follow-up `adlc init --skill-profile lean` (query/path/explain +
  freshness preamble only, ~4 KB) to be A/B'd as its own arm after Tier 1.
- **Edit tasks carry overlay tests** (fail on the pristine repo, pass after the reference
  fix; verified per task in scratch clones). Without them every edit task's test command
  already exited 0 before any change, so tests could not distinguish a fix from inaction.
- **Tier 1 verdict recorded in DECISION_ADR.md.** The headline is tool adoption, not
  tool quality: Serena MCP used in 1/36 runs; graphify skill auto-invoked 36/36 and
  queried 19–22/36. Thresholds were set from baseline (tokens ≤ 0.8×, correctness ≥
  −5 pts, wall ≤ 1.2×); no arm qualified. The contract + kit are adopted regardless —
  they are the vendor-neutral part and cost nothing per task.
- **Model stratification worked as designed:** 10 of 144 runs also used a
  `copilot-search-a` helper model under `auto`; the scorecard lists them separately.
- **Copilot monthly premium quota ran out in the last 9 runs (web-008, all three Tier 3
  arms).** Each ended with `session.error "exceeded your monthly quota"`, exit 1, no
  answer; their judge calls failed too. They are excluded (listed, never pooled) by
  `adlc scorecard`, which now treats any run with a session error or a non-zero exit
  and no answer as invalid. `adlc eval` now aborts on the first session error instead of
  burning the remaining matrix. Totals: 315 attempted, 306 valid, 306 agent + 246 judge
  premium requests, 2,074 model calls, 56.3 M prompt tokens, 2.9 h of agent wall-clock.
  web-008 re-runs next month (`make tier3` resumes).
- **The `both` arm was not run**, per the spec's condition: no context arm beat baseline
  alone in Tiers 1–2.

## 2026-11-01 — devcontainer is optional, not required
The kit never read the devcontainer; the pilot ran entirely on the dev machine. Made that explicit: `adlc init --no-devcontainer`, doctor WARN not FAIL, ADOPT.md bare-machine prerequisites. Devcontainer stays the distributable for teams with Docker. Unreleased in CHANGELOG; tag on next release, not for a flag.

## 2026-11-01 — devcontainer removed from the kit (supersedes the 2026-11-01 "optional" entry)
User: devcontainers are not approved for their use. Opt-out flag was the wrong shape; removed the Dockerfile, the devcontainer template, the `--no-devcontainer` flag and the doctor row entirely. `adlc-regress.yml` now installs uv + Node + Copilot CLI 1.0.105 + the kit on a plain ubuntu runner, with a `setup` input for the repo's own toolchain. INSTALL_MINUTES.md moved to the kit root and is now the per-machine cost sheet. Kit tagged v0.1.3. All four Kestrel repos: `.devcontainer/` removed, `adlc init` rerun (kit 0.1.3), graphs re-stamped, project/org graphs re-federated; stale/lint/doctor green.

## 2026-11-01 — lean-skill arm run; lean becomes the graphify default profile in the kit
36 Tier 1 runs, same judge, quota reset confirmed by a 1-request probe first. Lean skill = 1.9 KB kit-authored SKILL.md at the vendor path, same trigger description. Result: 142k prompt tokens p50 vs vendor 204k vs baseline 87k; correctness 90 % (best Tier 1 arm); graph queried in 31/36 runs vs 19/36. Call: `adlc init --skill-profile` default flips to `lean` — nobody should ship the 48 KB vendor text when a 2 KB one does the job better. Vendor profile kept for reproducing the original measurement. Threshold still not met (1.6× tokens), so graphify remains opt-in, not org default. Results file renamed to the dated convention (`2026-11-01-tier1-lean.jsonl`) because the scorecard globs `results/*.jsonl` and the report groups by date.

## 2026-11-01 — kit bug found by the forced-Serena smoke: Copilot CLI loads `.mcp.json` from cwd only
The first serena-forced smoke run (svc-003, cwd `gateway/`) used glob+view only and no Serena tool, with no hook denials. Probe: `copilot -p "list your serena tools"` from `gateway/` → NONE; from the repo root → all 10. So in the polyglot repo every serena-arm run on kestrel-services (Tier 1: 15, Tier 2: 9 — 24 of the 45 serena runs) had no Serena connected; the single Serena use in the pilot (web-010 r2) was in kestrel-web, whose tasks run at the root. Calls: (1) `adlc init` writes `<service>/.mcp.json` with `--project ..` and `--context ../.serena/adlc-context.yml` (Serena verified to activate the root project from a subdir); lint and doctor check every kit-owned `.mcp.json`. (2) The 24 affected records are marked `valid: false` with `invalid_reason` — not deleted, not pooled — and the scorecard lists them. (3) Plain serena is re-run on the 5 kestrel-services Tier 1 tasks (15) and Tier 2 (9) after the serena-forced run, so the ADR's Serena line is measured with Serena actually present. (4) The "Serena unproven" verdict in the ADR is downgraded to "Serena was absent on 24 of 45 runs" until those land. Per the spec, a manual step a team would do by hand is a kit bug; this was one.

## 2026-11-01 — second defect behind the Serena null result: Roslyn LS needs the .NET 10 runtime
With Serena finally connected from `gateway/`, every tool call returned success=false and the agent reported "Serena failed to initialize because .NET 10 is required and only .NET 8 is installed". The services root project lists csharp+java+python; the C# server failing takes the whole Serena project down. Installed the .NET 10 runtime next to the .NET 8 SDK (`dotnet-install.sh --channel 10.0 --runtime dotnet`, ~30 s); `adlc doctor` now has a red row ".NET 10 runtime (Roslyn LS)" whenever csharp is in `.serena/project.yml` — it should have caught this on day one. The 7 forced runs recorded against a dead Serena are not measurements: moved to `results/runs-invalid/` (suffix `.serena-dotnet10-missing`), results file deleted, run restarted from scratch.

## 2026-11-01 — third Serena defect: `--project ..` makes every path the agent passes wrong
With Serena connected and the .NET 10 runtime in place, svc-001 scored 2/2/2 but each run wasted 2 of ~5 Serena calls on FileNotFound: the agent in `gateway/` passes `errors.py`, Serena rooted at the repo wants `gateway/gateway/errors.py`. Call: a service is its own Serena project (`--project-from-cwd` from the service dir, own `.serena/` with only its languages). Side benefit: a broken C# server no longer kills Python symbol search in the same repo. The 3 affected forced runs are quarantined (`.serena-root-path-mismatch`), not kept. Root memories are not visible to service projects yet; derived memories per service are a follow-up, noted in the ADR.

## 2026-11-01 — serena-forced arm complete (36 runs)
Serena live in every service (probes: python 1 s, C# 2 s, Java 4 s). Result: 141k tokens p50 (1.6× baseline), 41 s wall (2.1×), 82 % correctness (−4), Serena used in 33/36 runs, 8 calls p50. Never beat baseline on a task. Verdict re-issued in the ADR as "measured, not recommended as default; keep for type-aware edits". Observation kept as a finding, not acted on mid-run: the agent probes 2–3 path forms before Serena accepts one; a one-line "paths are relative to this directory" hint belongs in a follow-up arm, not in this measurement.

## 2026-11-01 — operator error: two rerun chains ran at once for ~4 runs
My "is the chain running" check landed inside the chain's 30 s sleep, so I launched a second one; both wrote the same results file and ran Copilot sessions concurrently. Wall-clock is a reported metric, so the 4 affected records are quarantined (`.concurrent-duplicate-chain`) rather than kept; file deleted; one chain relaunched. Harness follow-up: `adlc eval` should take an exclusive lock on its out file.

## 2026-11-01 — plain serena re-measured (24 runs); Serena verdict final
Tier 1 services: 51k tokens / 80 % vs baseline 63k / 77 %, Serena used 1/15. Tier 2: 140k / 100 % vs 115k / 78 %, Serena used 2/9, both on svc-010 (Java JPA edit, baseline 0/0/2 → 2/2/2; one pass with zero Serena calls). Verdict written into the ADR: offered = ignored; forced = slower and no better; keep pinned per service for type-aware Java/C# edits; not a default. Scorecard regenerated (378 valid runs). Kit tagged v0.1.5 with the three Serena fixes, the eval lock, the lean default and the regress cache.

### 2026-11-01 — transfer to another machine: six public GitHub repos + raw-runs release
**Decision.** Pilot, kit and four Kestrel repos pushed as public repos under `VidurAI`
(`adlc-pilot`, `adlc-kit`, `kestrel-services`, `kestrel-web`, `kestrel-ops`, `kestrel-notify`).
`results/runs/` (311 MB, gitignored) shipped as `results-runs-2026-11-01.tgz` on the
pilot's `runs-2026-11-01` release. `make bootstrap` (`scripts/bootstrap.sh`) stands up a
bare Mac: brew packages, Copilot CLI 1.0.105, .NET 8 SDK + 10 runtime, inner clones, runs
tarball, `make kit`, `adlc doctor`. `.toolchain/env.sh` made relocatable (`ADLC_ROOT`,
JDK via brew path or `java_home`). `TRANSFER.md` documents it.
**Why.** None of the six repos had a remote; one disk failure would have erased the
evidence behind 378 published runs. The chat transcript is portable but compacted; the
repo is the durable continuation.
**Checked before push.** Secret-pattern sweep over every tracked file in all six repos
and all 1859 files under `results/`: zero hits (one scrubber test fixture excluded).
**Correction.** `org/kestrel-project` was called a separate repo in conversation; it is
a tracked directory of the pilot. Six repos, not seven.

### 2026-11-01 — repos moved to `hpreowned` (owner's call); VidurAI pushes blocked
**Decision.** All six repos recreated public under `hpreowned` and pushed there; raw-runs
release re-cut there; bootstrap default owner and `TRANSFER.md` updated. The `VidurAI`
copies were left in place, not deleted (destructive; owner decides).
**Why.** GitHub refused every push from `VidurAI` with "You must verify your email
address" after the repos went public; the Mac's git keychain credential is `hpreowned`.
**Verified.** `make bootstrap` from a fresh public clone: 5 inner clones, 387 run dirs from
the release, 73 kit tests, doctor green on all four Kestrel repos.

### 2026-11-01 — `make tier3` would have skipped the nine runs it exists to redo
**Found.** web-008's nine quota-killed Tier 3 records sit in `2026-10-30-tier3.jsonl` with
exit 1 and no answer. The scorecard already excluded them (378 valid = 411 − 24 flagged −
9 exit-1), but `adlc eval`'s resume set skipped any run_id present in the file, valid or
not. "Re-run resumes" was false for exactly the case it was written for.
**Fix.** Kit main (post-0.1.5): resume skips only records that pass the scorecard's
`is_valid`; invalid records stay in the file as history. Test added (74 tests).
**Cost of the pending reruns, estimated from web-006/web-007 Tier 3 runs.** 9 agent runs
+ 9 judge calls ≈ 18 premium requests; ≈ 2.0M prompt tokens (baseline ≈ 110k, graphify
≈ 300k, federated ≈ 265k per run, mostly cache reads), ≈ 30k output tokens, ≈ 7 min
sequential wall. Copilot bills premium requests, not tokens.

### 2026-11-01 — the kit was never installable outside this checkout; fixed in 0.1.7
**Found** while answering "how to consume this kit". Two defects, both invisible to the
pilot because every kit command ran from the editable venv:
1. `ADOPT.md` step 0 and all six reusable workflows installed from the fictional
   `kestrel-freight/adlc-kit`. Fixed in 0.1.6 (URL → `hpreowned/adlc-kit`, rendered into
   onboarded repos from `pins.json`).
2. `uv tool install` of any tag v0.1.0–v0.1.6 produced a CLI that died on
   `ModuleNotFoundError: harness`: the wheel shipped `harness` as data under `adlc/_data/`
   while `eval`, `regress`, `scorecard` import it as a top-level package. Fixed in 0.1.7:
   `harness` is a wheel package, `harness_dir()` resolves by import. 0.1.6 also shipped a
   `PINS.md` saying `adlc==0.1.5` because the lock was not refreshed before `adlc pins`.
**Guard.** `tests/test_wheel_install.py` builds the wheel, installs it into a clean venv,
runs `adlc init` on a scratch repo and asserts the rendered workflow URL. 75 tests. CI runs it.
**Verified.** `uv tool install git+https://github.com/hpreowned/adlc-kit@v0.1.7` into an
empty tool dir: 1 s; `adlc init` on a fresh Python repo writes 11 files; `adlc doctor`
all green; `adlc lint` OK; `adlc stale` reports STALE until `adlc baseline`.
**Repos.** All four Kestrel repos re-inited on 0.1.7 (3 files each: workflow, renovate,
AGENTS kit stamp), lint OK, pushed.
**Lesson for the ADR.** "Adoption ≤ 15 min" was measured with the kit on `sys.path`. An
adoption test that does not start from `uv tool install` of the tag is not an adoption test.
