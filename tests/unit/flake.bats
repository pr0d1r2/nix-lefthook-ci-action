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

@test "uses the standard checksFor and actionlint implementation" {
    run grep -E 'checksFor|mkActionlintCheck' "$FLAKE"
    [ "$status" -ne 0 ]
}

@test "declares the actions fragment for workflow checks" {
    run grep -A8 'fragments = \[' "$FLAKE"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"actions"'* ]]
    [ -d "$REPO_ROOT/.github/workflows" ]
}
