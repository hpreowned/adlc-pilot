# ADLC pilot — Kestrel Freight

Proves (or disproves) a repo-context layer for GitHub Copilot and packages it as a kit.

- `adlc-kit/` — the distributable (own git repo, tagged). `adlc` is the only CLI teams learn.
- `repos/` — Kestrel's repos (own git repos), onboarded by `adlc init`, never by hand.
- `org/kestrel-project/` — L1 project graph; `org/.github-private/` — L2 org graph + aggregator.
- `results/` — every number in the report, reproducible by `make all`.
- `DECISIONS.md` — every call made without asking. `DECISION_ADR.md` — the decision + rollout plan.

Move to another Mac: `TRANSFER.md` (six public repos + one release tarball; `make bootstrap`).

Reproduce: `make kit org init doctor baseline federate tasks tier1 scorecard` (or `make all`).
