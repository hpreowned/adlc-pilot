#!/usr/bin/env bash
# Bare macOS -> everything `make all` needs. Idempotent; re-run until it prints OK.
# Pins: Copilot CLI 1.0.105, .NET SDK 8.0 + runtime 10.0 (Roslyn LS), JDK 21, kit v0.1.5.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GH_OWNER="${ADLC_GH_OWNER:-hpreowned}"
RUNS_TAG="${ADLC_RUNS_TAG:-runs-2026-11-01}"
cd "$ROOT"

step() { printf '\n== %s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1; }

step "Homebrew"
need brew || { echo "install Homebrew first: https://brew.sh"; exit 1; }
for pkg in openjdk@21 maven node uv gh; do
  brew list --versions "$pkg" >/dev/null 2>&1 || brew install "$pkg"
done

step "GitHub Copilot CLI 1.0.105 (pinned)"
if ! copilot --version 2>/dev/null | grep -q '1\.0\.105'; then
  npm install -g @github/copilot@1.0.105
fi

step ".NET SDK 8.0 + runtime 10.0 -> .toolchain/dotnet"
mkdir -p .toolchain
if [ ! -x .toolchain/dotnet-install.sh ]; then
  curl -fsSL https://dot.net/v1/dotnet-install.sh -o .toolchain/dotnet-install.sh
  chmod +x .toolchain/dotnet-install.sh
fi
.toolchain/dotnet/dotnet --list-sdks 2>/dev/null | grep -q '^8\.' \
  || .toolchain/dotnet-install.sh --channel 8.0 --install-dir .toolchain/dotnet
.toolchain/dotnet/dotnet --list-runtimes 2>/dev/null | grep -q 'Microsoft.NETCore.App 10\.' \
  || .toolchain/dotnet-install.sh --channel 10.0 --runtime dotnet --install-dir .toolchain/dotnet

step "nested repos (own history, gitignored here)"
clone() { [ -d "$2/.git" ] || git clone -q "https://github.com/$GH_OWNER/$1.git" "$2"; echo "  $2: $(git -C "$2" rev-parse --short HEAD)"; }
clone adlc-kit          adlc-kit
clone kestrel-services  repos/kestrel-services
clone kestrel-web       repos/kestrel-web
clone kestrel-ops       repos/kestrel-ops
clone kestrel-notify    repos/kestrel-notify
clone adlc-backstage    adlc-backstage

step "raw runs (results/runs, gitignored; evidence behind every published number)"
if [ ! -d results/runs ]; then
  if gh release view "$RUNS_TAG" --repo "$GH_OWNER/adlc-pilot" >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    gh release download "$RUNS_TAG" --repo "$GH_OWNER/adlc-pilot" --pattern '*.tgz' --dir "$tmp"
    tar -xzf "$tmp"/*.tgz -C results
    rm -rf "$tmp"
  else
    echo "  release $RUNS_TAG not found; results/runs stays empty (numbers still reproducible via make all)"
  fi
fi
echo "  $(ls results/runs 2>/dev/null | wc -l | tr -d ' ') run dirs"

step "kit venv + tests"
make kit

step "doctor"
export ADLC_ROOT="$ROOT"; source .toolchain/env.sh
for r in kestrel-services kestrel-web kestrel-ops kestrel-notify; do
  (cd "repos/$r" && "$ROOT/adlc-kit/.venv/bin/adlc" doctor) | tail -1
done

step "auth"
gh auth status >/dev/null 2>&1 && echo "  gh: ok (eval targets read COPILOT_GITHUB_TOKEN from gh auth token)" \
  || echo "  gh: run 'gh auth login' before any make tier* target"
echo; echo "OK"
