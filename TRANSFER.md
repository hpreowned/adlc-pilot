# Moving the pilot to another Mac

Six git repos, one tarball, one optional chat transcript. Everything else is rebuilt.

## Repos (all public, github.com/hpreowned)

| repo | lands at | what it is |
|---|---|---|
| `adlc-pilot` | `~/ADLC` (any path works) | harness, tasks, arms, results, scorecard, DECISIONS, ADR, report |
| `adlc-kit` | `adlc-kit/` | the `adlc` CLI and templates; tagged `v0.1.7` |
| `kestrel-services` | `repos/kestrel-services/` | Java (booking) + Python (gateway) + C# (pricing) test subject |
| `kestrel-web` | `repos/kestrel-web/` | TypeScript test subject |
| `kestrel-ops` | `repos/kestrel-ops/` | ops test subject |
| `kestrel-notify` | `repos/kestrel-notify/` | Python test subject, adoption-test target |

The five inner repos are gitignored by the pilot so each keeps its own history.
`org/kestrel-project/` and `org/.github-private/` are plain directories tracked by the pilot.

## Restore

```bash
git clone https://github.com/hpreowned/adlc-pilot.git ~/ADLC
cd ~/ADLC && make bootstrap
```

`make bootstrap` (`scripts/bootstrap.sh`) is idempotent and does, in order: Homebrew
packages (openjdk@21, maven, node, uv, gh), Copilot CLI pinned to 1.0.105, .NET SDK 8 +
runtime 10 into `.toolchain/dotnet`, clones the five inner repos, downloads the raw runs
from release `runs-2026-11-01` into `results/runs/`, `make kit` (venv + 73 tests), and
`adlc doctor` on every Kestrel repo. Then `gh auth login` if needed; every `make tier*`
target reads `COPILOT_GITHUB_TOKEN` from `gh auth token`. Nothing is written to `~`
except Homebrew and npm globals.

Check: `make scorecard` must print `378 valid runs` before any new eval is started.

## Raw runs

`results/runs/` (311 MB, 387 run dirs: Copilot `events.jsonl`, scrubbed transcripts,
judge output) is the evidence behind every number in `DECISION_ADR.md`. It is gitignored
and shipped as `results-runs-2026-11-01.tgz` on the pilot's `runs-2026-11-01` release.
Later eval batches: add a new release tag and bump `ADLC_RUNS_TAG` in the bootstrap call.

## Chat session (optional)

The Claude Code session that built this lives at
`~/.claude/projects/-Users-hpatil-ADLC/a240cf7f-ac6b-4c86-9e88-be04e5c19c2c.jsonl`
(12 MB, already compacted once) with its memory in `~/.claude/projects/-Users-hpatil-ADLC/memory/`.
Copy both into the same folder on the new machine; the folder name encodes the absolute
project path, so either clone to `/Users/hpatil/ADLC` or rename the folder to match the
new path. Resume with `claude --resume a240cf7f-ac6b-4c86-9e88-be04e5c19c2c` from the
project root. Background tasks and permission approvals do not carry over.

The intended continuation path is a fresh session: `DECISIONS.md`, `DECISION_ADR.md`,
`results/REPORT.md` and `adlc-kit/PINS.md` are written so a cold agent can pick up
without the transcript. If that turns out false, it is a kit bug.

## Disposable

`.toolchain/dotnet` (686 MB), every `.venv`, `node_modules`, `~/.serena/language_servers`.
All rebuilt by bootstrap or first use.
