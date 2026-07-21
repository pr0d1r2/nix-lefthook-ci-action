#!/usr/bin/env bash
set -euo pipefail

# Runs lefthook inside a pure nix develop shell.
# All configuration via environment variables (set by action.yml env: block).
#
# Required:
#   STAGE           — lefthook stage: install, pre-commit, or pre-push
#   DEVSHELL        — nix devShell name (e.g. ci)
#
# Optional:
#   ACCEPT_FLAKE_CONFIG  — "true" to pass --accept-flake-config
#   KEEP_HOME            — "true" to pass --keep HOME (needed for GNU parallel)
#   EXTRA_ENV            — extra env vars prepended to command (e.g. "FOO=1 BAR=2")
#   FLAKE_CHECK_TIMEOUT  — override LEFTHOOK_NIX_FLAKE_CHECK_TIMEOUT (seconds)
#   FLAKE_EVAL_TIMEOUT   — override LEFTHOOK_NIX_FLAKE_EVAL_TIMEOUT (seconds)

export TERM=dumb
nix_args=(nix develop)
[[ "${ACCEPT_FLAKE_CONFIG:-}" == "true" ]] && nix_args+=(--accept-flake-config)
nix_args+=(".#${DEVSHELL}" --ignore-environment --keep TERM)
[[ "${KEEP_HOME:-}" == "true" ]] && nix_args+=(--keep HOME)

cmd=""
if [[ "${KEEP_HOME:-}" == "true" ]]; then
  # shellcheck disable=SC2016 # $HOME must expand in the inner bash -c shell, not here
  cmd+='mkdir -p "$HOME/.parallel" && touch "$HOME/.parallel/will-cite"; '
fi
[[ -n "${EXTRA_ENV:-}" ]] && cmd+="${EXTRA_ENV} "
[[ -n "${FLAKE_CHECK_TIMEOUT:-}" ]] && cmd+="LEFTHOOK_NIX_FLAKE_CHECK_TIMEOUT=${FLAKE_CHECK_TIMEOUT} "
[[ -n "${FLAKE_EVAL_TIMEOUT:-}" ]] && cmd+="LEFTHOOK_NIX_FLAKE_EVAL_TIMEOUT=${FLAKE_EVAL_TIMEOUT} "

if [[ "$STAGE" == "install" ]]; then
  cmd+="lefthook install"
else
  cmd+="lefthook run ${STAGE} --all-files"
fi

nix_args+=(--command bash -c "$cmd")
"${nix_args[@]}"
