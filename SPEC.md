# SPEC — nix-lefthook-ci-action

## §G Goal

Composite GitHub Action for Nix + lefthook CI. One-line drop-in for repos using `nix-dev-shell-agentic`. Installs Nix, builds the flake, then runs all lefthook pre-commit hooks on PR files and all pre-push hooks on the full repo. Pin by commit SHA for deterministic CI. Opensource-safe: zero credentials, zero local paths, zero private refs.

## §C Constraints

- C1: GitHub composite action — `action.yml`, no Docker, no JS runtime
- C2: SHA-pinnable — consumers pin `@<commit-sha>` for deterministic builds
- C3: MIT license
- C4: Zero-config default — works without any `with:` inputs for standard nix-lefthook repos
- C5: Assumes consumer has `.#ci` devShell (provided by `nix-dev-shell-agentic.lib.mkShells`)
- C6: Isolated environment — `--ignore-environment` prevents host tool leakage into nix develop
- C7: No circular dependency — this repo must NOT depend on `nix-dev-shell-agentic` for its own CI
- C8: Detached from parent project — no credential leaks, no hardcoded local paths, no private repo refs

## §I Interfaces

- I.action: `uses: pr0d1r2/nix-lefthook-ci-action@<SHA>` — composite action, runs in consumer's job
- I.inputs:
  - `accept-flake-config` (bool, default `true`) — pass `--accept-flake-config` to nix commands
  - `pre-build-commands` (string, default `""`) — shell commands run before `nix build`
  - `extra-env` (string, default `""`) — env vars prepended to lefthook commands
  - `flake-check-timeout` (string, default `""`) — override `LEFTHOOK_NIX_FLAKE_CHECK_TIMEOUT`
  - `keep-home` (bool, default `false`) — keep `HOME` in `nix develop` (GNU parallel needs this)
  - `skip-pre-commit` (bool, default `false`) — skip pre-commit stage, run only pre-push
- I.ci: `.github/workflows/ci.yml` — self-CI: validate action.yml syntax + markdownlint

## §V Invariants

- V1: Action installs Nix with flakes enabled via `cachix/install-nix-action`
- V2: `nix build` runs before any lefthook checks — ensures flake evaluates cleanly
- V3: `lefthook install` fetches remotes before running hooks
- V4: Pre-commit runs `lefthook run pre-commit --all-files` — all staged-file hooks on all files
- V5: Pre-push runs `lefthook run pre-push --all-files` — all repo-wide hooks on all files
- V6: `--ignore-environment` isolates from host — only `TERM` (and optionally `HOME`) kept
- V7: `TERM=dumb` prevents terminal control sequences in CI logs
- V8: Pre-build commands execute before `nix build` — enables setup like copying whitelist files
- V9: `skip-pre-commit=true` skips pre-commit stage entirely — for repos where pre-push subsumes pre-commit
- V10: `keep-home=true` also runs `mkdir -p "$HOME/.parallel" && touch "$HOME/.parallel/will-cite"` — suppresses GNU parallel citation prompt
- V11: Empty/unset optional inputs produce no extra flags — clean command lines by default
- V12: Self-CI validates `action.yml` is valid YAML with required fields: `name`, `description`, `inputs`, `runs`
- V13: Self-CI does NOT use nix-dev-shell-agentic — avoids circular dependency (C7)
- V14: No credentials, secrets, tokens, API keys, or private paths in any tracked file

## §T Tasks

| id | status | task | cites |
|----|--------|------|-------|
| T1 | x | composite action with nix install + build + lefthook install + pre-commit + pre-push | V1,V2,V3,V4,V5,I.action |
| T2 | x | input parameters for all variation axes | I.inputs,V8,V9,V10,V11 |
| T3 | x | isolated nix develop with --ignore-environment | V6,V7,C6 |
| T4 | x | self-CI: action.yml validation + markdownlint | V12,V13,C7,I.ci |
| T5 | x | README with usage examples + pinning guidance | C4,C2 |
| T6 | x | branch protection requiring PRs | C8 |
| T7 | | test action on consumer repo (nix-lefthook-ascii-only PR) | C4 |
| T8 | | roll out to all 50+ nix-lefthook-* repos | C2,C4 |

## §B Bugs

(none yet)
