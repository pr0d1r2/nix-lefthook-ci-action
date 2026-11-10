#!/usr/bin/env bats

setup() {
    if [ -n "$BATS_TEST_DIRNAME" ]; then
        REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    else
        REPO_ROOT="$(pwd)"
    fi
    export REPO_ROOT
    FLAKE="$REPO_ROOT/flake.nix"
}

@test "uses the standard consumer flake implementation" {
    run grep -F 'set-and-setting.lib.mkConsumerFlake' "$FLAKE"
    [ "$status" -eq 0 ]
}

@test "declares the actions fragment for workflow checks" {
    run grep -A8 'fragments = \[' "$FLAKE"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"actions"'* ]]
    [ -d "$REPO_ROOT/.github/workflows" ]
}

@test "flake.lock does not pin the nixpkgs rev with brotli CVE-2026-111497" {
    run grep -F 'c508844df6c28fa6dabc1b6af70f3ccbd65c5201' "$REPO_ROOT/flake.lock"
    [ "$status" -eq 1 ]
}
