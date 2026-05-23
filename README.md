# nix-lefthook-ci-action

[![CI](https://github.com/pr0d1r2/nix-lefthook-ci-action/actions/workflows/ci.yml/badge.svg)](https://github.com/pr0d1r2/nix-lefthook-ci-action/actions/workflows/ci.yml)

Composite GitHub Action for Nix + lefthook CI.
One-line drop-in for repos using `nix-dev-shell-agentic`.
Pin by commit SHA for deterministic, reproducible builds.

## Usage

### Minimal (zero-config)

```yaml
jobs:
  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: pr0d1r2/nix-lefthook-ci-action@<SHA>

  build-macos:
    if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
    runs-on: macos-latest
    steps:
      - uses: pr0d1r2/nix-lefthook-ci-action@<SHA>
```

### With customization

```yaml
- uses: pr0d1r2/nix-lefthook-ci-action@<SHA>
  with:
    flake-check-timeout: "60"
    pre-build-commands: |
      cp .vulnix-whitelist-system.toml.example .vulnix-whitelist-system.toml
    extra-env: "LEFTHOOK_BATS_CHANGED_JOBS=1 LEFTHOOK_BATS_CHANGED_TIMEOUT=300"
    keep-home: "true"
    skip-pre-commit: "true"
```

## Inputs

| Input | Default | Description |
|---|---|---|
| `accept-flake-config` | `true` | Pass `--accept-flake-config` to nix commands |
| `pre-build-commands` | `""` | Shell commands to run before `nix build` |
| `extra-env` | `""` | Environment variables prepended to lefthook commands |
| `flake-check-timeout` | `""` | Override `LEFTHOOK_NIX_FLAKE_CHECK_TIMEOUT` (seconds) |
| `keep-home` | `false` | Keep `HOME` in `nix develop` (needed for GNU parallel) |
| `skip-pre-commit` | `false` | Skip pre-commit stage, run only pre-push |
| `devshell` | `ci` | Nix devShell to use (e.g. `ci`, `checks`) |
| `skip-build` | `false` | Skip `nix build` step (for repos with no default package) |
| `cachix-cache` | `pr0d1r2` | Cachix cache name (empty string disables) |

## What it does

1. Checks out code
2. Installs Nix with flakes enabled
3. Sets up cachix binary cache (pull-only, no auth needed for public caches)
4. Runs pre-build commands (if configured)
5. Runs `nix build`
6. Installs lefthook remotes
7. Runs `lefthook run pre-commit --all-files`
8. Runs `lefthook run pre-push --all-files`

## Pinning

Always pin to a commit SHA, not a branch:

```yaml
# Deterministic
- uses: pr0d1r2/nix-lefthook-ci-action@a1b2c3d4e5f6

# Non-deterministic — avoid
- uses: pr0d1r2/nix-lefthook-ci-action@main
```

All internal dependencies are also SHA-pinned:
`actions/checkout`, `cachix/install-nix-action`, `cachix/cachix-action`.
