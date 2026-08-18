#!/usr/bin/env bats

setup() {
    if [ -n "$BATS_TEST_DIRNAME" ]; then
        REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    else
        REPO_ROOT="$(pwd)"
    fi
    export REPO_ROOT
    ACTION="$REPO_ROOT/action.yml"
}

@test "nix installer without extra platforms uses the GitHub token" {
    run grep -A4 "if: inputs.extra-platforms == ''" "$ACTION"
    [ "$status" -eq 0 ]
    [[ "$output" == *'access-tokens = github.com=${{ github.token }}'* ]]
}

@test "nix installer with extra platforms keeps both settings" {
    run grep -A5 "if: inputs.extra-platforms != ''" "$ACTION"
    [ "$status" -eq 0 ]
    [[ "$output" == *'access-tokens = github.com=${{ github.token }}'* ]]
    [[ "$output" == *'extra-platforms = ${{ inputs.extra-platforms }}'* ]]
}
