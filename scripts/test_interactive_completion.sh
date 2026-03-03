#!/usr/bin/env bash
# End-to-end interactive completion test for claude/codex/gemini plugins.
# This script launches an actual interactive zsh session via expect, sends Tab,
# and validates completion behavior.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECT_BIN="${EXPECT_BIN:-expect}"
EXPECT_TIMEOUT="${EXPECT_TIMEOUT:-12}"
KEEP_TMP_HOME="${KEEP_TMP_HOME:-0}"

TMP_HOME=""

log() {
    printf '[interactive-test] %s\n' "$*"
}

die() {
    printf '[interactive-test] ERROR: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    if [[ -n "$TMP_HOME" && -d "$TMP_HOME" ]]; then
        if [[ "$KEEP_TMP_HOME" == "1" ]]; then
            log "KEEP_TMP_HOME=1, preserving temp HOME: $TMP_HOME"
        else
            rm -rf "$TMP_HOME"
        fi
    fi
}

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

prepare_temp_home() {
    TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/ohmyzsh-completion-e2e.XXXXXX")"
    mkdir -p "$TMP_HOME/.oh-my-zsh/custom/plugins"
    cat > "$TMP_HOME/.zshrc" <<'EOF'
plugins=(git)
EOF
    log "Prepared isolated HOME: $TMP_HOME"
}

install_plugins() {
    log "Installing plugins into isolated HOME"
    if ! printf 'y\n' | HOME="$TMP_HOME" bash "$ROOT_DIR/install.sh" >"$TMP_HOME/install.log" 2>&1; then
        tail -n 80 "$TMP_HOME/install.log" >&2 || true
        die "install.sh failed"
    fi

    local plugin
    for plugin in claude codex gemini; do
        [[ -f "$TMP_HOME/.oh-my-zsh/custom/plugins/$plugin/$plugin.plugin.zsh" ]] || die "Missing installed plugin file: $plugin"
    done
}

write_test_zshrc() {
    cat > "$TMP_HOME/.zshrc" <<'EOF'
plugins=(git claude codex gemini)
autoload -Uz compinit
compinit
source "$HOME/.oh-my-zsh/custom/plugins/claude/claude.plugin.zsh"
source "$HOME/.oh-my-zsh/custom/plugins/codex/codex.plugin.zsh"
source "$HOME/.oh-my-zsh/custom/plugins/gemini/gemini.plugin.zsh"
setopt AUTO_LIST
unsetopt LIST_BEEP
zstyle ':completion:*' menu no
PROMPT='PROMPT> '
EOF
}

run_expect_suite() {
    log "Running interactive completion assertions (EXPECT_TIMEOUT=${EXPECT_TIMEOUT}s)"

    if ! HOME="$TMP_HOME" EXPECT_TIMEOUT="$EXPECT_TIMEOUT" "$EXPECT_BIN" <<'EXP' >"$TMP_HOME/expect.log" 2>&1; then
set timeout $env(EXPECT_TIMEOUT)

proc fail {label input pattern} {
    puts stderr "FAIL $label input=$input pattern=$pattern"
    exit 1
}

proc tc {input pattern label} {
    # Ctrl+U: clear current input line to keep cases independent.
    send -- "\u0015"
    send -- "$input\t"
    expect {
        -re $pattern { puts "PASS $label" }
        timeout { fail $label $input $pattern }
    }
}

spawn zsh -i
expect "PROMPT> "

# Claude
tc "claude au" {auth} {claude-auth}
tc "claude ag" {agents} {claude-agents}
tc "claude --wor" {--wor.*ktree} {claude-worktree-option}
tc "claude plugin li" {plugin list} {claude-plugin-list}

# Codex
tc "codex rev" {review} {codex-review}
tc "codex for" {fork} {codex-fork}
tc "codex --ask-for-a" {ask-for-a.*pproval} {codex-ask-for-approval-option}
tc "codex debug app-server se" {send-message-v2} {codex-debug-send-message-v2}

# Gemini
tc "gemini sk" {skills} {gemini-skills}
tc "gemini ho" {hooks} {gemini-hooks}
tc "gemini mcp en" {mcp enable} {gemini-mcp-enable}
tc "gemini extensions conf" {extensions config} {gemini-extensions-config}
tc "gemini --raw-o" {--raw-o.*utput} {gemini-raw-output-option}

send -- "\u0015"
send -- "exit\r"
expect eof
EXP
        tail -n 120 "$TMP_HOME/expect.log" >&2 || true
        die "Interactive completion suite failed"
    fi

    cat "$TMP_HOME/expect.log"
}

run_uninstall_smoke() {
    log "Running uninstall smoke test"
    if ! printf 'y\n' | HOME="$TMP_HOME" bash "$ROOT_DIR/uninstall.sh" >"$TMP_HOME/uninstall.log" 2>&1; then
        tail -n 80 "$TMP_HOME/uninstall.log" >&2 || true
        die "uninstall.sh failed"
    fi

    local plugin
    for plugin in claude codex gemini; do
        if [[ -d "$TMP_HOME/.oh-my-zsh/custom/plugins/$plugin" ]]; then
            die "Plugin directory still exists after uninstall: $plugin"
        fi
    done
}

main() {
    trap cleanup EXIT

    require_cmd "$EXPECT_BIN"
    require_cmd zsh
    require_cmd claude
    require_cmd codex
    require_cmd gemini

    prepare_temp_home
    install_plugins
    write_test_zshrc
    run_expect_suite
    run_uninstall_smoke

    log "PASS: interactive completion automation finished"
}

main "$@"
