#!/usr/bin/env bash
# Full interactive completion automation for claude/codex/gemini.
# It discovers commands/options from live CLI help output, then verifies each
# one through real interactive zsh + Tab completion via expect.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECT_BIN="${EXPECT_BIN:-expect}"
EXPECT_TIMEOUT="${EXPECT_TIMEOUT:-2}"
EXPECT_VERBOSE="${EXPECT_VERBOSE:-0}"
MAX_DEPTH="${MAX_DEPTH:-3}"
CASE_LIMIT="${CASE_LIMIT:-0}"        # 0 means no limit
STRICT_HELP="${STRICT_HELP:-1}"      # fail if any help output cannot be parsed
KEEP_TMP_HOME="${KEEP_TMP_HOME:-0}"  # keep isolated HOME for debugging
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-5}"

TMP_HOME=""
CASE_FILE_RAW=""
CASE_FILE=""
SKIPPED_FILE=""
TIMEOUT_CMD=""

log() {
    printf '[interactive-test] %s\n' "$*"
}

die() {
    printf '[interactive-test] ERROR: %s\n' "$*" >&2
    exit 1
}

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
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

detect_timeout_cmd() {
    if command -v timeout >/dev/null 2>&1; then
        TIMEOUT_CMD="timeout"
    elif command -v gtimeout >/dev/null 2>&1; then
        TIMEOUT_CMD="gtimeout"
    else
        TIMEOUT_CMD=""
    fi
}

prepare_temp_home() {
    TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/ohmyzsh-completion-e2e.XXXXXX")"
    CASE_FILE_RAW="$TMP_HOME/cases.raw.tsv"
    CASE_FILE="$TMP_HOME/cases.tsv"
    SKIPPED_FILE="$TMP_HOME/skipped.txt"
    : > "$CASE_FILE_RAW"
    : > "$CASE_FILE"
    : > "$SKIPPED_FILE"

    mkdir -p "$TMP_HOME/.oh-my-zsh/custom/plugins"
    cat > "$TMP_HOME/.zshrc" <<'EOF'
plugins=(git)
EOF
    log "Prepared isolated HOME: $TMP_HOME"
}

install_plugins() {
    log "Installing plugins into isolated HOME"
    if ! printf 'y\n' | HOME="$TMP_HOME" bash "$ROOT_DIR/install.sh" >"$TMP_HOME/install.log" 2>&1; then
        tail -n 120 "$TMP_HOME/install.log" >&2 || true
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
setopt NO_BEEP
unsetopt LIST_BEEP
zstyle ':completion:*' menu no
PROMPT='PROMPT> '
EOF
}

escape_regex() {
    printf '%s' "$1" | sed -e 's/[][(){}.^$*+?|\\/]/\\&/g'
}

sanitize_label() {
    printf '%s' "$1" | sed -E 's/[^A-Za-z0-9]+/_/g; s/^_+//; s/_+$//'
}

PROBE_OUTPUT=""
PROBE_RC=0
PROBE_TIMEOUT=0
HELP_STATUS="ok"

run_probe() {
    local cmd="$1"
    local output rc
    PROBE_TIMEOUT=0

    set +e
    if [[ -n "$TIMEOUT_CMD" ]]; then
        output=$("$TIMEOUT_CMD" "$TIMEOUT_SECONDS" bash -c "$cmd" 2>&1)
        rc=$?
    else
        output=$(bash -c "$cmd" 2>&1)
        rc=$?
    fi
    set -e

    PROBE_OUTPUT="$output"
    PROBE_RC=$rc

    if [[ $rc -eq 124 ]] || [[ $rc -eq 137 ]]; then
        PROBE_TIMEOUT=1
    fi
}

get_help_output() {
    local cmd="$1"
    local output=""
    local timed_out=0
    HELP_STATUS="ok"

    run_probe "$cmd --help"
    output="$PROBE_OUTPUT"
    [[ $PROBE_TIMEOUT -eq 1 ]] && timed_out=1

    if [[ -z "$output" ]] || [[ "$output" == *"unknown option"* ]]; then
        run_probe "$cmd -h"
        output="$PROBE_OUTPUT"
        [[ $PROBE_TIMEOUT -eq 1 ]] && timed_out=1
    fi

    if [[ -z "$output" ]] || [[ "$output" == *"unknown option"* ]]; then
        run_probe "$cmd"
        output="$PROBE_OUTPUT"
        [[ $PROBE_TIMEOUT -eq 1 ]] && timed_out=1
    fi

    if [[ -z "$output" ]]; then
        if [[ $timed_out -eq 1 ]]; then
            HELP_STATUS="timeout"
        else
            HELP_STATUS="empty"
        fi
    elif [[ "$output" == *"command not found"* ]] || [[ "$output" == *"No such file"* ]]; then
        HELP_STATUS="invalid"
    elif [[ $timed_out -eq 1 ]]; then
        HELP_STATUS="partial-timeout"
    fi

    printf '%s' "$output"
}

extract_commands_from_help() {
    local help_output="$1"
    local full_cmd="$2"
    local commands_section
    local depth col

    commands_section=$(echo "$help_output" | sed -n '/^Commands:/,/^Options:/p; /^Subcommands:/,/^Options:/p; /^Available Commands:/,/^Options:/p; /^命令：/,/^选项：/p; /^子命令：/,/^选项：/p')
    depth=$(echo "$full_cmd" | awk '{print NF}')

    if [[ -n "$full_cmd" ]] && echo "$commands_section" | grep -qE "^  $full_cmd "; then
        col=$((depth + 1))
        echo "$commands_section" | \
            grep -E "^  $full_cmd " | \
            awk -v col="$col" '{print $col}' | \
            sed 's/|.*//g; s/\[.*//g; s/<.*//g' | \
            grep -v '^$' | \
            grep -v '^help$' | \
            sort -u || true
    else
        echo "$commands_section" | \
            grep -E '^  [a-z][a-z0-9|_-]*' | \
            sed 's/|.*//g; s/\[.*//g; s/<.*//g' | \
            awk '{print $1}' | \
            grep -v '^$' | \
            grep -v '^help$' | \
            sort -u || true
    fi
}

extract_options_from_help() {
    local help_output="$1"
    {
        echo "$help_output" | awk '
            /^(Options:|Flags:|Global Options:|选项：|标志：)$/ { in_opts=1; next }
            in_opts && /^[A-Z][A-Za-z0-9 _-]*:$/ { in_opts=0 }
            in_opts && /^[[:space:]]+-/ { print }
        ' | awk '{print $1, $2}' | grep -oE -- '--[A-Za-z][A-Za-z0-9_-]*' || true

        echo "$help_output" | awk '
            /^(Options:|Flags:|Global Options:|选项：|标志：)$/ { in_opts=1; next }
            in_opts && /^[A-Z][A-Za-z0-9 _-]*:$/ { in_opts=0 }
            in_opts && /^[[:space:]]+-/ { print }
        ' | awk '{print $1, $2}' | grep -oE -- '-[A-Za-z]([^A-Za-z]|$)' | sed 's/[^-A-Za-z]//g' || true
    } | sort -u
}

add_case() {
    local cli="$1"
    local context="$2"
    local kind="$3"
    local token="$4"
    local prefix input pattern label

    if [[ "$kind" == "command" ]]; then
        if [[ ${#token} -le 1 ]]; then
            prefix="$token"
        else
            prefix="${token%?}"
        fi
    elif [[ "$kind" == "option" ]]; then
        if [[ "$token" == --* ]]; then
            if [[ ${#token} -gt 3 ]]; then
                prefix="${token%?}"
            else
                prefix="--"
            fi
        elif [[ "$token" == -* ]]; then
            # For short options we use "-" to force list output.
            prefix="-"
        else
            return
        fi
    else
        return
    fi

    input="$context $prefix"
    input="$(echo "$input" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
    pattern="$(escape_regex "$token")"
    label="$(sanitize_label "${cli}__${context}__${kind}__${token}")"

    printf '%s\t%s\t%s\t%s\t%s\n' "$cli" "$label" "$input" "$pattern" "$token" >> "$CASE_FILE_RAW"
}

build_cases_recursive() {
    local cli="$1"
    local base_cmd="$2"
    local cmd_path="$3"
    local depth="$4"
    local full_cmd context help_output cmds opts

    if [[ "$depth" -gt "$MAX_DEPTH" ]]; then
        return
    fi

    if [[ -z "$cmd_path" ]]; then
        full_cmd="$base_cmd"
    else
        full_cmd="$base_cmd $cmd_path"
    fi
    context="$full_cmd"

    help_output="$(get_help_output "$full_cmd")"
    if [[ -z "$help_output" ]] || [[ "$HELP_STATUS" != "ok" && "$HELP_STATUS" != "partial-timeout" ]]; then
        printf '%s|%s\n' "$full_cmd" "$HELP_STATUS" >> "$SKIPPED_FILE"
        return
    fi

    cmds="$(extract_commands_from_help "$help_output" "$full_cmd")"
    opts="$(extract_options_from_help "$help_output")"

    if [[ -n "$cmds" ]]; then
        while IFS= read -r token; do
            [[ -z "$token" ]] && continue
            add_case "$cli" "$context" "command" "$token"
        done <<< "$cmds"
    fi

    if [[ -n "$opts" ]]; then
        while IFS= read -r token; do
            [[ -z "$token" ]] && continue
            add_case "$cli" "$context" "option" "$token"
        done <<< "$opts"
    fi

    if [[ "$depth" -lt "$MAX_DEPTH" ]] && [[ -n "$cmds" ]]; then
        while IFS= read -r subcmd; do
            [[ -z "$subcmd" ]] && continue
            # avoid trivial loops
            if [[ " $cmd_path " == *" $subcmd "* ]]; then
                continue
            fi
            if [[ -z "$cmd_path" ]]; then
                build_cases_recursive "$cli" "$base_cmd" "$subcmd" $((depth + 1))
            else
                build_cases_recursive "$cli" "$base_cmd" "$cmd_path $subcmd" $((depth + 1))
            fi
        done <<< "$cmds"
    fi
}

generate_case_file() {
    log "Generating full completion cases from live CLI help output (MAX_DEPTH=$MAX_DEPTH)"
    build_cases_recursive "claude" "claude" "" 0
    build_cases_recursive "codex" "codex" "" 0
    build_cases_recursive "gemini" "gemini" "" 0

    sort -u "$CASE_FILE_RAW" > "$CASE_FILE"

    if [[ "$CASE_LIMIT" != "0" ]]; then
        head -n "$CASE_LIMIT" "$CASE_FILE" > "$CASE_FILE.limit"
        mv "$CASE_FILE.limit" "$CASE_FILE"
        log "CASE_LIMIT applied: $CASE_LIMIT"
    fi

    local total skipped
    total=$(wc -l < "$CASE_FILE" | tr -d ' ')
    skipped=$(wc -l < "$SKIPPED_FILE" | tr -d ' ')

    log "Generated $total interactive cases"
    awk -F'\t' '{count[$1]++} END {for (k in count) printf("[interactive-test] cases[%s]=%d\n", k, count[k]);}' "$CASE_FILE" | sort

    if [[ "$skipped" -gt 0 ]]; then
        log "Skipped command help reads: $skipped"
        sed -n '1,10p' "$SKIPPED_FILE" | sed 's/^/[interactive-test] skipped: /'
        if [[ "$STRICT_HELP" == "1" ]]; then
            die "STRICT_HELP=1 and some help outputs were skipped"
        fi
    fi

    [[ "$total" -gt 0 ]] || die "No test cases generated"
}

run_expect_suite() {
    log "Running full interactive suite via expect (timeout=${EXPECT_TIMEOUT}s per case)"

    set +e
    HOME="$TMP_HOME" CASE_FILE="$CASE_FILE" EXPECT_TIMEOUT="$EXPECT_TIMEOUT" EXPECT_VERBOSE="$EXPECT_VERBOSE" "$EXPECT_BIN" <<'EXP' > "$TMP_HOME/expect.log" 2>&1
set timeout $env(EXPECT_TIMEOUT)
set verbose $env(EXPECT_VERBOSE)
set fail_count 0

proc fail {label input pattern token} {
    global fail_count
    incr fail_count
    puts stderr ""
    puts stderr "FAIL\t$label\tinput=$input\tpattern=$pattern\ttoken=$token"
}

proc tc {input pattern label token} {
    global verbose
    # Ctrl+U clears current input line.
    send -- "\u0015"
    send -- "$input\t"
    expect {
        -re $pattern {
            if {$verbose == "1"} {
                puts "PASS\t$label\t$token"
            }
        }
        timeout { fail $label $input $pattern $token }
    }
}

spawn env TERM=dumb HOME=$env(HOME) zsh -i
expect "PROMPT> "

set fp [open $env(CASE_FILE) r]
set total 0
while {[gets $fp line] >= 0} {
    if {$line eq ""} { continue }
    set fields [split $line "\t"]
    if {[llength $fields] < 5} { continue }
    set label [lindex $fields 1]
    set input [lindex $fields 2]
    set pattern [lindex $fields 3]
    set token [lindex $fields 4]
    incr total
    tc $input $pattern $label $token
}
close $fp

puts "SUMMARY\ttotal=$total\tfailed=$fail_count"
send -- "\u0015"
send -- "exit\r"
expect eof

if {$fail_count > 0} {
    exit 1
}
exit 0
EXP
    local ec=$?
    set -e

    local summary total failed
    summary="$(grep -aoE 'SUMMARY[[:space:]]+total=[0-9]+[[:space:]]+failed=[0-9]+' "$TMP_HOME/expect.log" | tail -n 1 || true)"
    total="$(echo "$summary" | sed -n 's/.*total=\([0-9][0-9]*\).*/\1/p')"
    failed="$(echo "$summary" | sed -n 's/.*failed=\([0-9][0-9]*\).*/\1/p')"

    if [[ -n "$summary" ]]; then
        log "Interactive suite summary: total=${total:-unknown} failed=${failed:-unknown}"
    else
        log "Interactive suite summary not found (check $TMP_HOME/expect.log)"
    fi

    if [[ $ec -ne 0 ]]; then
        log "Interactive suite reported failures. Showing first failing lines:"
        grep -aoE 'FAIL[^\r\n]*' "$TMP_HOME/expect.log" | head -n 20 || true
        return 1
    fi

    return 0
}

run_uninstall_smoke() {
    log "Running uninstall smoke test"
    if ! printf 'y\n' | HOME="$TMP_HOME" bash "$ROOT_DIR/uninstall.sh" >"$TMP_HOME/uninstall.log" 2>&1; then
        tail -n 120 "$TMP_HOME/uninstall.log" >&2 || true
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
    detect_timeout_cmd

    log "Configuration: MAX_DEPTH=$MAX_DEPTH EXPECT_TIMEOUT=$EXPECT_TIMEOUT EXPECT_VERBOSE=$EXPECT_VERBOSE CASE_LIMIT=$CASE_LIMIT STRICT_HELP=$STRICT_HELP TIMEOUT_CMD=${TIMEOUT_CMD:-none}"
    prepare_temp_home
    install_plugins
    write_test_zshrc
    generate_case_file

    local expect_failed=0
    local uninstall_failed=0

    if ! run_expect_suite; then
        expect_failed=1
    fi

    if ! run_uninstall_smoke; then
        uninstall_failed=1
    fi

    if [[ "$expect_failed" -eq 1 ]] || [[ "$uninstall_failed" -eq 1 ]]; then
        die "Completed with failures (expect_failed=$expect_failed uninstall_failed=$uninstall_failed)"
    fi

    log "PASS: full interactive completion automation finished"
}

main "$@"
