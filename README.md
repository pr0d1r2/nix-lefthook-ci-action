# nix-lefthook-ci-action

[![CI](https://github.com/pr0d1r2/nix-lefthook-ci-action/actions/workflows/ci.yml/badge.svg)](https://github.com/pr0d1r2/nix-lefthook-ci-action/actions/workflows/ci.yml)

Composite GitHub Action for Nix + lefthook CI.
Pin by commit SHA for deterministic, reproducible builds.

## Usage

### Minimal (zero-config)

```yaml
jobs:
  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: pr0d1r2/nix-lefthook-ci-action@<SHA>

  build-macos:
    if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v6
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

## Pinning

Always pin to a commit SHA, not a branch:

```yaml
# Deterministic
- uses: pr0d1r2/nix-lefthook-ci-action@a1b2c3d4e5f6

# Non-deterministic — avoid
- uses: pr0d1r2/nix-lefthook-ci-action@main
```
