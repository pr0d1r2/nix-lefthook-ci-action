#!/usr/bin/env bats
# shellcheck disable=SC2016,SC2030,SC2031

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    if [ -n "$BATS_TEST_DIRNAME" ]; then
        REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    else
        REPO_ROOT="$(pwd)"
    fi
    export REPO_ROOT
    SCRIPT="$REPO_ROOT/run-lefthook.sh"

    MOCK_DIR="$(mktemp -d)"
    MOCK_LOG="$MOCK_DIR/nix-args.log"
    export MOCK_LOG
    cat > "$MOCK_DIR/nix" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${MOCK_LOG}"
# Extract the bash -c command: find -c flag, next arg is the command
found_c=false
for arg in "$@"; do
    if $found_c; then
        echo "$arg" > "${MOCK_LOG}.cmd"
        break
    fi
    if [[ "$arg" == "-c" ]]; then
        found_c=true
    fi
done
MOCK
    chmod +x "$MOCK_DIR/nix"
    export PATH="$MOCK_DIR:$PATH"
}

teardown() {
    rm -rf "$MOCK_DIR"
}

@test "run-lefthook.sh exists" {
    [ -f "$SCRIPT" ]
}

@test "run-lefthook.sh has bash shebang" {
    head -1 "$SCRIPT" | grep -q '#!/usr/bin/env bash'
}

@test "STAGE=install runs lefthook install" {
    export STAGE=install DEVSHELL=ci
    run "$SCRIPT"
    assert_success
    cmd="$(cat "$MOCK_LOG.cmd")"
    assert_equal "$cmd" "lefthook install"
}

@test "STAGE=pre-commit runs lefthook run pre-commit --all-files" {
    export STAGE=pre-commit DEVSHELL=ci
    run "$SCRIPT"
    assert_success
    cmd="$(cat "$MOCK_LOG.cmd")"
    assert_equal "$cmd" "lefthook run pre-commit --all-files"
}

@test "STAGE=pre-push runs lefthook run pre-push --all-files" {
    export STAGE=pre-push DEVSHELL=ci
    run "$SCRIPT"
    assert_success
    cmd="$(cat "$MOCK_LOG.cmd")"
    assert_equal "$cmd" "lefthook run pre-push --all-files"
}

@test "DEVSHELL is passed to nix develop" {
    export STAGE=install DEVSHELL=myshell
    run "$SCRIPT"
    assert_success
    run grep -x '.#myshell' "$MOCK_LOG"
    assert_success
}

@test "ACCEPT_FLAKE_CONFIG=true passes --accept-flake-config" {
    export STAGE=install DEVSHELL=ci ACCEPT_FLAKE_CONFIG=true
    run "$SCRIPT"
    assert_success
    run grep -x -- '--accept-flake-config' "$MOCK_LOG"
    assert_success
}

@test "ACCEPT_FLAKE_CONFIG unset omits --accept-flake-config" {
    export STAGE=install DEVSHELL=ci
    unset ACCEPT_FLAKE_CONFIG
    run "$SCRIPT"
    assert_success
    run grep -x -- '--accept-flake-config' "$MOCK_LOG"
    assert_failure
}

@test "KEEP_HOME=true passes --keep HOME" {
    export STAGE=pre-commit DEVSHELL=ci KEEP_HOME=true
    run "$SCRIPT"
    assert_success
    run grep -x 'HOME' "$MOCK_LOG"
    assert_success
}

@test "KEEP_HOME=true prepends parallel will-cite to command" {
    export STAGE=pre-commit DEVSHELL=ci KEEP_HOME=true
    run "$SCRIPT"
    assert_success
    cmd="$(cat "$MOCK_LOG.cmd")"
    [[ "$cmd" == *'mkdir -p "$HOME/.parallel"'* ]]
    [[ "$cmd" == *'will-cite'* ]]
}

@test "EXTRA_ENV is prepended to command" {
    export STAGE=pre-commit DEVSHELL=ci EXTRA_ENV="FOO=1 BAR=2"
    run "$SCRIPT"
    assert_success
    cmd="$(cat "$MOCK_LOG.cmd")"
    [[ "$cmd" == *"FOO=1 BAR=2"* ]]
}

@test "FLAKE_CHECK_TIMEOUT sets LEFTHOOK_NIX_FLAKE_CHECK_TIMEOUT" {
    export STAGE=pre-commit DEVSHELL=ci FLAKE_CHECK_TIMEOUT=300
    run "$SCRIPT"
    assert_success
    cmd="$(cat "$MOCK_LOG.cmd")"
    [[ "$cmd" == *"LEFTHOOK_NIX_FLAKE_CHECK_TIMEOUT=300"* ]]
}

@test "FLAKE_EVAL_TIMEOUT sets LEFTHOOK_NIX_FLAKE_EVAL_TIMEOUT" {
    export STAGE=pre-commit DEVSHELL=ci FLAKE_EVAL_TIMEOUT=120
    run "$SCRIPT"
    assert_success
    cmd="$(cat "$MOCK_LOG.cmd")"
    [[ "$cmd" == *"LEFTHOOK_NIX_FLAKE_EVAL_TIMEOUT=120"* ]]
}

@test "all timeout vars combined in command" {
    export STAGE=pre-push DEVSHELL=ci FLAKE_CHECK_TIMEOUT=300 FLAKE_EVAL_TIMEOUT=120
    run "$SCRIPT"
    assert_success
    cmd="$(cat "$MOCK_LOG.cmd")"
    [[ "$cmd" == *"LEFTHOOK_NIX_FLAKE_CHECK_TIMEOUT=300"* ]]
    [[ "$cmd" == *"LEFTHOOK_NIX_FLAKE_EVAL_TIMEOUT=120"* ]]
    [[ "$cmd" == *"lefthook run pre-push --all-files" ]]
}

@test "uses --ignore-environment and --keep TERM" {
    export STAGE=install DEVSHELL=ci
    run "$SCRIPT"
    assert_success
    run grep -x -- '--ignore-environment' "$MOCK_LOG"
    assert_success
    run grep -x -- '--keep' "$MOCK_LOG"
    assert_success
    run grep -x 'TERM' "$MOCK_LOG"
    assert_success
}
