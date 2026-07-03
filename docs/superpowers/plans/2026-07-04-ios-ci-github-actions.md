# iOS CI (GitHub Actions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a GitHub Actions workflow that runs `flutter analyze`/`flutter test` on ubuntu and verifies the iOS build (`flutter build ios --no-codesign`) on a macOS runner, on every push/PR to `main` and on manual dispatch.

**Architecture:** A single workflow file `.github/workflows/ci.yml` with two independent parallel jobs — `analyze-and-test` (ubuntu-latest, cheap) and `build-ios` (macos-latest, iOS build only). No `needs` dependency between them, so one failure does not cancel the other. Flutter is pinned to 3.44.4 (stable) to match local, with SDK/pub caching. A concurrency group cancels superseded runs to save macOS minutes.

**Tech Stack:** GitHub Actions, `actions/checkout@v4`, `subosito/flutter-action@v2`, Flutter 3.44.4 / Dart 3.12.2.

## Global Constraints

- Flutter version: **3.44.4**, channel **stable** (verbatim match to local — setup plan §6).
- iOS build must use **`--no-codesign`** (no Apple Developer account/certs).
- macOS runner is used **only** in the `build-ios` job (cost control).
- Triggers: `push` → `main`, `pull_request` → `main`, `workflow_dispatch`.
- The two jobs run in parallel with **no `needs` between them**.
- Repo: `HappyMarmot123/EDMM-flutter`, default branch `main`. `gh` CLI is authenticated.

---

### Task 1: Create the CI workflow file

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: a workflow named `CI` with jobs `analyze-and-test` and `build-ios`. Task 2 verifies these job names in the Actions run.

- [ ] **Step 1: Create `.github/workflows/ci.yml` with the exact content below**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.44.4
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.44.4
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter build ios --no-codesign
```

- [ ] **Step 2: Validate the YAML parses locally**

Run (Git Bash):
```bash
cd /c/Users/a6r79/edmm-flutter && python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml')); print('YAML OK')"
```
Expected: `YAML OK` (no traceback). If `python` is unavailable, run `python3` instead; if neither exists, skip this step — Step 3 of Task 2 is the authoritative validation.

- [ ] **Step 3: Confirm no unrelated files are staged, then commit only the workflow**

Run:
```bash
cd /c/Users/a6r79/edmm-flutter && git add .github/workflows/ci.yml && git status --short
```
Expected: the staged list shows only `A  .github/workflows/ci.yml` (the modified `README.md` stays unstaged).

```bash
git commit -m "$(cat <<'EOF'
Add iOS CI workflow (GitHub Actions)

analyze + test on ubuntu, iOS build (--no-codesign) on macOS.
Triggers on push/PR to main and manual dispatch.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01DREwZmA42YgY5Q7kwwSGcg
EOF
)"
```

---

### Task 2: Trigger the workflow and verify both jobs pass

**Files:** none (verification task).

**Interfaces:**
- Consumes: the committed `.github/workflows/ci.yml` and job names `analyze-and-test`, `build-ios` from Task 1.
- Produces: a green workflow run on GitHub — the plan's success criteria (spec §7).

- [ ] **Step 1: Push `main` to trigger the `push` event**

Run:
```bash
cd /c/Users/a6r79/edmm-flutter && git push origin main
```
Expected: push succeeds; the new commit appears on `origin/main`.

- [ ] **Step 2: Confirm the run started and inspect its jobs**

Run:
```bash
cd /c/Users/a6r79/edmm-flutter && gh run list --workflow=ci.yml --limit 1
```
Expected: one run for workflow `CI` on branch `main`, status `in_progress` or `queued`.

- [ ] **Step 3: Watch the run to completion**

Run:
```bash
cd /c/Users/a6r79/edmm-flutter && gh run watch --exit-status $(gh run list --workflow=ci.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```
Expected: both `analyze-and-test` and `build-ios` complete; command exits `0` (all jobs passed). The macOS `build-ios` job may take several minutes (CocoaPods + iOS build).

- [ ] **Step 4: If any job fails, diagnose before re-running**

Run:
```bash
cd /c/Users/a6r79/edmm-flutter && gh run view $(gh run list --workflow=ci.yml --limit 1 --json databaseId --jq '.[0].databaseId') --log-failed
```
Read the failing step's log. Common causes and fixes:
- **iOS build fails on CocoaPods / min deployment target** → note the exact error; fix belongs in `ios/` config (e.g. `ios/Podfile` platform line), not the workflow. Apply the minimal fix, commit, push, re-watch (Step 3).
- **`flutter analyze` / `flutter test` fails** → a real regression surfaced by CI; fix the Dart code, commit, push, re-watch.
- **Flutter version resolution error** → confirm `flutter-version: 3.44.4` exists on the stable channel; do not change the pin without updating the spec.

Do not mark this task complete until Step 3 exits `0`.

---

## Self-Review

**Spec coverage:**
- Spec §2 decision 1 (integrated CI, 2 jobs) → Task 1 (both jobs). ✓
- §2 decision 2 (push/PR/dispatch triggers) → Task 1 `on:` block. ✓
- §2 decision 3 (Flutter 3.44.4 pin) → Task 1, both jobs `flutter-version: 3.44.4`. ✓
- §2 decision 4 (`--no-codesign`) → Task 1 `build-ios`. ✓
- §3 architecture (parallel, no `needs`) → Task 1 (no `needs` keys). ✓
- §5 cost control (concurrency, macOS only in build-ios, cache) → Task 1 `concurrency` block + job placement + `cache: true`. ✓
- §6 command parity (analyze/test/build ios --no-codesign) → Task 1 run steps. ✓
- §7 success criteria (workflow triggers, both jobs pass, concurrency/cache in logs) → Task 2 verification. ✓
- §8 out of scope items → not present in plan. ✓

**Placeholder scan:** No TBD/TODO; all YAML and commands are literal. ✓

**Type consistency:** Job names `analyze-and-test` / `build-ios` referenced identically across Task 1 and Task 2. Flutter pin `3.44.4` identical in both jobs. ✓
