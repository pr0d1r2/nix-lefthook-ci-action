# SPEC — nix-lefthook-ci-action

## §G Goal

Composite GitHub Action for Nix + lefthook CI. One-line drop-in for repos using `nix-dev-shell-agentic`. Checks out code, installs Nix with flakes, sets up cachix, builds the flake, then runs all lefthook pre-commit and pre-push hooks on all files. Pin by commit SHA for deterministic CI. Opensource-safe: zero credentials, zero local paths, zero private refs.

## §C Constraints

- C1: GitHub composite action — `action.yml`, no Docker, no JS runtime
- C2: Fully SHA-pinned — consumers pin `@<commit-sha>`, action pins all its dependencies (`actions/checkout`, `cachix/install-nix-action`, `cachix/cachix-action`) by SHA too
- C3: MIT license
- C4: Zero-config default — works without any `with:` inputs for standard nix-lefthook repos
- C5: Assumes consumer has devShell (default `.#ci`, configurable via `devshell` input) provided by `nix-dev-shell-agentic.lib.mkShells`
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
  - `devshell` (string, default `ci`) — nix devShell to use (e.g. `ci`, `checks`)
  - `skip-build` (bool, default `false`) — skip `nix build` step (for repos with no default package)
  - `cachix-cache` (string, default `pr0d1r2`) — cachix cache name for nix store caching; empty string disables cachix
- I.ci: `.github/workflows/ci.yml` — self-CI: validate action.yml syntax + markdownlint

## §V Invariants

- V1: Action installs Nix with `experimental-features = nix-command flakes` via `cachix/install-nix-action` (SHA-pinned)
- V1b: When `cachix-cache` is non-empty, action sets up cachix binary cache via `cachix/cachix-action` (SHA-pinned) — pull-only (no auth token needed for public caches)
- V2: Action checks out code via `actions/checkout` (SHA-pinned)
- V3: `nix build` runs before any lefthook checks — ensures flake evaluates cleanly (skippable via `skip-build`)
- V4: `lefthook install` fetches remotes before running hooks
- V5: Pre-commit runs `lefthook run pre-commit --all-files` — hooks use `{staged_files}` template, `--all-files` substitutes all tracked files
- V6: Pre-push runs `lefthook run pre-push --all-files` — hooks use `{push_files}` template, `--all-files` substitutes all tracked files
- V6b: Step ordering: checkout → cachix → nix install → pre-build commands → build → lefthook install → pre-commit → pre-push
- V7: `--ignore-environment` isolates from host — only `TERM` (and optionally `HOME`) kept
- V8: `TERM=dumb` prevents terminal control sequences in CI logs
- V9: Pre-build commands execute before `nix build` — enables setup like copying whitelist files
- V10: `skip-pre-commit=true` skips pre-commit stage entirely — for repos where pre-push subsumes pre-commit
- V11: `keep-home=true` also runs `mkdir -p "$HOME/.parallel" && touch "$HOME/.parallel/will-cite"` — suppresses GNU parallel citation prompt
- V12: Empty/unset optional inputs produce no extra flags — clean command lines by default
- V13: Self-CI validates `action.yml` is valid YAML with required fields: `name`, `description`, `inputs`, `runs`
- V14: Self-CI runs markdownlint on all `.md` files (SHA-pinned `DavidAnson/markdownlint-cli2-action`)
- V15: Self-CI does NOT use nix-dev-shell-agentic — avoids circular dependency (C7)
- V16: No credentials, secrets, tokens, API keys, or private paths in any tracked file
- V17: `devshell` input controls which nix devShell is used — defaults to `ci`, passed as `.#<devshell>` in all `nix develop` commands

## §T Tasks

| id | status | task | cites |
|----|--------|------|-------|
| T1 | x | composite action with checkout + cachix + nix install + build + lefthook install + pre-commit + pre-push | V1,V1b,V2,V3,V4,V5,V6,V6b,I.action |
| T2 | x | SHA-pin all action dependencies (checkout, install-nix-action, cachix-action, markdownlint-cli2-action) | C2 |
| T3 | x | input parameters for all variation axes including `devshell`, `skip-build`, `cachix-cache` | I.inputs,V9,V10,V11,V12,V17 |
| T4 | x | isolated nix develop with --ignore-environment | V7,V8,C6 |
| T6 | x | self-CI: action.yml validation + markdownlint | V13,V14,V15,C7,I.ci |
| T7 | x | README with usage examples + pinning guidance | C4,C2 |
| T8 | x | branch protection requiring PRs | C8 |
| T9 | | test action on consumer repo (nix-lefthook-ascii-only PR) | C4 |
| T10 | | roll out to all 50+ nix-lefthook-* repos | C2,C4 |

## §B Bugs

(none yet)
