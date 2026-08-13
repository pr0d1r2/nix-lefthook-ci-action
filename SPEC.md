# SPEC — nix-lefthook-ci-action

## §G Goal

Composite GitHub Action for Nix + lefthook CI. One-line drop-in for repos using `nix-dev-shell-agentic`. Checks out code, installs Nix with flakes, sets up cachix (pull + optional push), builds the flake, then runs all lefthook pre-commit and pre-push hooks on all files. Pin by commit SHA for deterministic CI. Opensource-safe: zero credentials in tracked files, zero local paths, zero private refs. Cachix push accelerates builds across all consumer repos — contributors and CI get pre-built devShells and packages.

## §C Constraints

- C1: GitHub composite action — `action.yml`, no Docker, no JS runtime
- C2: Fully SHA-pinned — consumers pin `@<commit-sha>`, action pins all its dependencies (`actions/checkout`, `cachix/install-nix-action`, `cachix/cachix-action`) by SHA too
- C3: MIT license
- C4: Zero-config default — works without any `with:` inputs for standard nix-lefthook repos
- C5: Assumes consumer has devShell (default `.#ci`, configurable via `devshell` input) provided by `nix-dev-shell-agentic.lib.mkShells`
- C6: Isolated environment — `--ignore-environment` prevents host tool leakage into nix develop
- C7: No `nix-dev-shell-agentic` dependency — this repo defines its own standalone `flake.nix` with devShell directly from nixpkgs
- C8: Detached from parent project — no credential leaks, no hardcoded local paths, no private repo refs
- C9: Dogfood — self-CI uses this action (`uses: ./`) to validate itself, proving the action works
- C10: Cachix push never leaks private assets — push is gated on `github.event.repository.private == false` AND presence of auth token; private repos only pull from cache
- C11: Cachix auth token is a runtime secret (`secrets.CACHIX_AUTH_TOKEN`) — never stored in tracked files, passed as action input from consumer workflow

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
  - `cachix-auth-token` (string, default `""`) — cachix auth token for pushing builds; when non-empty AND repo is public, built store paths are pushed to cachix after successful build
- I.ci: `.github/workflows/ci.yml` — self-CI: dogfoods this action with `skip-build: true`
- I.flake: `flake.nix` — standalone devShell `ci` with all tools needed by lefthook remote hooks
- I.lefthook: `lefthook.yml` — remote hooks appropriate for repo file types (`.yml`, `.md`, `.nix`)

## §V Invariants

- V1: Action installs Nix with `experimental-features = nix-command flakes` via `cachix/install-nix-action` (SHA-pinned)
- V1b: When `cachix-cache` is non-empty, action sets up cachix binary cache via `cachix/cachix-action` (SHA-pinned) — pull-only when no auth token provided (public caches need no auth for reads)
- V1c: When `cachix-auth-token` is non-empty AND `github.event.repository.private == false`, cachix-action receives auth token and pushes all built store paths to cache automatically (cachix-action handles push transparently after nix build/develop)
- V1d: When `cachix-auth-token` is non-empty but repo is private, auth token is NOT passed to cachix-action — prevents leaking private build artifacts to public cache; a warning step logs that push was skipped due to private repo
- V2: Action checks out code via `actions/checkout` (SHA-pinned)
- V3: `nix build` runs before any lefthook checks — ensures flake evaluates cleanly (skippable via `skip-build`)
- V4: `lefthook install` fetches remotes before running hooks
- V5: Pre-commit runs `lefthook run pre-commit --all-files` — hooks use `{staged_files}` template, `--all-files` substitutes all tracked files
- V6: Pre-push runs `lefthook run pre-push --all-files` — hooks use `{push_files}` template, `--all-files` substitutes all tracked files
- V6b: Step ordering: checkout → nix install → cachix (with conditional push) → pre-build commands → build → lefthook install → pre-commit → pre-push
- V7: `--ignore-environment` isolates from host — only `TERM` (and optionally `HOME`) kept
- V8: `TERM=dumb` prevents terminal control sequences in CI logs
- V9: Pre-build commands execute before `nix build` — enables setup like copying whitelist files
- V10: `skip-pre-commit=true` skips pre-commit stage entirely — for repos where pre-push subsumes pre-commit
- V11: `keep-home=true` also runs `mkdir -p "$HOME/.parallel" && touch "$HOME/.parallel/will-cite"` — suppresses GNU parallel citation prompt
- V12: Empty/unset optional inputs produce no extra flags — clean command lines by default
- V13: Self-CI dogfoods this action via `uses: ./` with `skip-build: true` (no default package to build)
- V14: Linting (markdownlint, yamllint, nixfmt, statix, deadnix, typos, editorconfig-checker, etc.) handled by lefthook remote hooks — not standalone CI actions
- V15: `flake.nix` defines devShell directly from nixpkgs — no `nix-dev-shell-agentic` import (C7)
- V16: No credentials, secrets, tokens, API keys, or private paths in any tracked file
- V17: `devshell` input controls which nix devShell is used — defaults to `ci`, passed as `.#<devshell>` in all `nix develop` commands
- V18: `flake.nix` provides both `default` (dev) and `ci` devShells — both include lefthook + all tools required by configured remote hooks
- V18a: `flake.nix` includes `nixConfig` with cachix substituters + trusted public keys — enables `accept-flake-config` and faster CI builds
- V18b: `default` devShell runs `lefthook install` via shellHook — local commits/pushes trigger same checks as CI
- V19: `lefthook.yml` uses remote hooks from `nix-lefthook-*` repos — same pattern as consumer repos
- V20: `nix flake check` runs as lefthook hook — validates flake evaluates cleanly on every commit
- V21: `.gitignore` excludes `.lefthook/` (remote hook downloads) and other generated artifacts

## §T Tasks

| id | status | task | cites |
|----|--------|------|-------|
| T1 | x | composite action with checkout + cachix + nix install + build + lefthook install + pre-commit + pre-push | V1,V1b,V2,V3,V4,V5,V6,V6b,I.action |
| T2 | x | SHA-pin all action dependencies (checkout, install-nix-action, cachix-action, markdownlint-cli2-action) | C2 |
| T3 | x | input parameters for all variation axes including `devshell`, `skip-build`, `cachix-cache` | I.inputs,V9,V10,V11,V12,V17 |
| T4 | x | isolated nix develop with --ignore-environment | V7,V8,C6 |
| T6 | x | standalone flake.nix with `default` + `ci` devShells (lefthook + all hook tools, no nix-dev-shell-agentic) | V15,V18,V18b,C7,I.flake |
| T7 | x | README with usage examples + pinning guidance | C4,C2 |
| T8 | x | branch protection requiring PRs | C8 |
| T9 | | test action on consumer repo (nix-lefthook-ascii-only PR) | C4 |
| T10 | | roll out to all 50+ nix-lefthook-* repos | C2,C4 |
| T13 | x | add `cachix-auth-token` input to `action.yml` | I.inputs,C11 |
| T14 | x | gate cachix push on public repo + token presence — pass `authToken` to cachix-action only when both conditions met | V1c,V1d,C10 |
| T15 | x | add warning step when push skipped due to private repo | V1d |
| T16 | x | update README with cachix push usage example (secret setup) | T13 |
| T17 | x | update self-CI to pass `CACHIX_AUTH_TOKEN` secret for dogfooding push | V13,C9 |
| T18 | x | update SPEC §V invariants for cachix push behavior | V1c,V1d |
| T19 | | roll out `cachix-auth-token` input to consumer repos (set repo-level secret + pass in workflow) | T10,C10 |
| T20 | | test private repo guard — fork to private repo, set token, confirm warning appears and push skipped | V1d,C10 |
| T11 | x | lefthook.yml with remote hooks for repo file types (.yml, .md, .nix) | V14,V19,V20,I.lefthook |
| T12 | x | self-CI dogfood: replace standalone actions with `uses: ./` + `skip-build: true` | V13,C9,I.ci |

## §B Bugs

| id | date | cause | fix |
|----|------|-------|-----|
| B1 | 2026-07-21 | duplicate `default` attribute in `packages` (symlinkJoin + mkShell both referencing undefined `ciPackages`) broke flake evaluation | remove both broken `default` entries from `packages`; devShells already handled by `set-and-setting.lib.mkDevShells` |
| B2 | 2026-07-21 | `confirm` app coherence check fails — `lefthook-markdownlint`, `lefthook-markdownlint-agentic`, `lefthook-yamllint` referenced in generated `lefthook.yml` but not on PATH because confirm app's `runtimeInputs` only had basic tools | add `mat.packages` (from `materializationFor`) to confirm app's `runtimeInputs` so all fragment tools are on PATH |
| B3 | 2026-07-21 | ascii-only check fails on em-dash in `action.yml` cachix push warning message | replace em-dash with ASCII double-dash (`--`) |
| B4 | 2026-07-21 | deadnix flags unused `nix-lefthook` flake input (declared and destructured but never referenced in outputs) | remove `nix-lefthook` input; tools come transitively via `set-and-setting` |
| B5 | 2026-07-21 | `execute-permissions` check fails because `run-lefthook.sh` has +x bit; `file-size-check` fails due to missing `config/lefthook/file_size_limits.yml`; `nix-no-embedded-shell` flags embedded shell in `flake.nix` confirm app; `shfmt` rejects 4-space indent in `run-lefthook.sh`; `nixfmt` rejects formatting of `flake.nix` | remove +x from `run-lefthook.sh` and invoke via `bash` in `action.yml`; add `config/lefthook/file_size_limits.yml`; add `.nix-embedded-shell-allowlist` for `flake.nix`; fix indentation to 2-space; run `nixfmt` on `flake.nix` |
| B6 | 2026-07-29 | `nix flake update` bumped `set-and-setting` to a version that removed the `lib` output (`attribute 'lib' missing`); consumer flake.nix was calling `set-and-setting.lib.*` directly | adopt `mk-consumer-flake.nix` pattern from `set-and-setting`, passing `set-and-setting.inputs.set-and-setting` (inner version that still has `lib`) |
| B7 | 2026-07-29 | `file-size-check` fails because `flake.lock` (179101 bytes) exceeds the `.lock` extension limit (100000) after pin update; `statix` flags assignment-instead-of-inherit on `set-and-setting` in `flake.nix` | raise `.lock` limit from 100000 to 200000 in `config/lefthook/file_size_limits.yml`; use `inherit (set-and-setting.inputs) set-and-setting` in `flake.nix` |
| B8 | 2026-08-13 | guardrails `executability` check cannot run `lefthook dump` because the repository configuration was named `lefthook-repo.yml`, which Lefthook does not discover by default | rename the configuration to `lefthook.yml` and stop ignoring that tracked configuration |
| B9 | 2026-08-13 | `nix flake check` failed while evaluating the pinned `actions` fragment because it passed a scalar regex to Nixpkgs `sourceByRegex`, which now requires a list | replace the fragment with an equivalent local `actionlint` check using the list-form regex |
| B10 | 2026-08-13 | guardrails `fidelity` check found the tracked `lefthook.yml` stale because it still contained the pre-materialization hand-written hooks instead of the configuration generated from the declared fragments | materialize and commit the fragment-generated `lefthook.yml` |
