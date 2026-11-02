# Moving the pilot to another Mac

Seven git repos, one tarball, one optional chat transcript. Everything else is rebuilt.

## Repos (all public, github.com/hpreowned)

| repo | lands at | what it is |
|---|---|---|
| `adlc-pilot` | `~/ADLC` (any path works) | harness, tasks, arms, results, scorecard, DECISIONS, ADR, report |
| `adlc-kit` | `adlc-kit/` | the `adlc` CLI and templates; tagged `v0.1.7` |
| `kestrel-services` | `repos/kestrel-services/` | Java (booking) + Python (gateway) + C# (pricing) test subject |
| `kestrel-web` | `repos/kestrel-web/` | TypeScript test subject |
| `kestrel-ops` | `repos/kestrel-ops/` | ops test subject |
| `kestrel-notify` | `repos/kestrel-notify/` | Python test subject, adoption-test target |
| `adlc-backstage` | `adlc-backstage/` | Backstage TechDocs site, catalog entities, onboarding template; mirrors the kit at a pinned tag |

The six inner repos are gitignored by the pilot so each keeps its own history.
`org/kestrel-project/` and `org/.github-private/` are plain directories tracked by the pilot.

## Restore

```bash
git clone https://github.com/hpreowned/adlc-pilot.git ~/ADLC
cd ~/ADLC && make bootstrap
```

`make bootstrap` (`scripts/bootstrap.sh`) is idempotent and does, in order: Homebrew
packages (openjdk@21, maven, node, uv, gh), Copilot CLI pinned to 1.0.105, .NET SDK 8 +
runtime 10 into `.toolchain/dotnet`, clones the six inner repos, downloads the raw runs
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

## Backstage docs site (adlc-backstage)

Cloned by bootstrap into `adlc-backstage/`. It is independent of the pilot: it mirrors the
kit at the tag in its `kit.ref` and the pilot at a pinned SHA, and its CI fails on drift.

Build the site alone (no Backstage needed):

```bash
cd ~/ADLC/adlc-backstage && make venv sync build VENV=/tmp/techdocs-venv
```

`VENV` must be outside the repo: a venv inside the tree breaks TechDocs (symlinks that point
outside the source root). `make serve VENV=…` previews at localhost:8000 with diagrams.

Run a local Backstage against it, if you want the catalog, template and TechDocs tab:

1. `npx @backstage/create-app@latest` somewhere outside `~/ADLC` (Node 22 or 24, about 5 min).
2. `yarn --cwd packages/app add backstage-plugin-techdocs-addon-mermaid@0.29.0` so the
   diagrams render; the new frontend system discovers it, no code change.
3. `app-config.local.yaml`: `techdocs.generator.runIn: local`, catalog rules allowing
   `Group` and `Template`, and a `file:` location pointing at a **copy** of
   `adlc-backstage/catalog-info.yaml` (`rsync -a --exclude .git --exclude .venv`). The local
   builder patches `mkdocs.yml` inside a `file:` source tree; never point it at the checkout.
4. Start with the TechDocs venv on `PATH`: `PATH=/tmp/techdocs-venv/bin:$PATH yarn start`,
   then localhost:3000, guest sign-in.

In a real Backstage register `catalog-info.yaml` by URL and skip steps 3 and 4. The
onboarding template additionally needs `actions: write` on the docs repo for Backstage's
GitHub integration and the `ADLC_ONBOARD_TOKEN` secret on the docs repo.

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
