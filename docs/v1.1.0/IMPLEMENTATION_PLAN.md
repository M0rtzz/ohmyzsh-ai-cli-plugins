# v1.1.0 Implementation Plan - Oh My Zsh Completion Plugin Upgrade

## Objective
Upgrade `claude`, `codex`, and `gemini` completion plugins to match current CLI behavior while keeping the implementation simple, portable, and maintainable.

## Baseline (2026-02-28)
- Local CLIs were upgraded (`claude`, `codex`, `gemini`) before planning.
- `check_sync.sh` currently reports "no issues", but this is not trustworthy on macOS:
  - It depends on GNU `timeout`, which is not installed by default on macOS.
  - When `timeout` is missing, recursive checks are silently skipped, causing false green results.
- Verified top-level command drift:
  - `claude`: missing `agents`, `auth`; stale `migrate-installer` remains in plugin command list.
  - `codex`: missing `app`, `debug`, `fork`, `review`.
  - `gemini`: top-level commands aligned, but subcommand drift exists.
- Verified global option drift (minimum known gap):
  - `claude`: at least 16 missing flags.
  - `codex`: at least 14 missing flags.
  - `gemini`: main options aligned; new subcommand items need update.

## Scope
- In scope:
  - `claude/claude.plugin.zsh`
  - `codex/codex.plugin.zsh`
  - `gemini/gemini.plugin.zsh` (validation + targeted updates only if required)
  - `check_sync.sh`
  - `README.md` (command coverage and usage examples)
  - `VERSION` (release bump)
- Out of scope:
  - No completion code generator framework.
  - No full architecture rewrite.
  - No behavior changes unrelated to completion correctness.

## Design Principles
- KISS: keep handwritten completion functions and explicit command arrays.
- YAGNI: only add commands/options observed from current CLI help output.
- Single responsibility: each subcommand has its own focused completion function.
- Portability first: scripts must run on both macOS and Linux.

## Stage Breakdown

### Stage 1 - Validation Tool Hardening (Foundation)
Status: Completed

Tasks:
1. Replace hard dependency on `timeout` with a portable timeout strategy:
   - Prefer `timeout` if available.
   - Fallback to `gtimeout` if available.
   - Final fallback: run without timeout but print explicit warning.
2. Make `check_sync.sh` fail loudly:
   - Exit non-zero when issues are found.
   - Exit non-zero when prerequisite execution tooling is unavailable in strict mode.
3. Improve signal quality:
   - Print per-command check lines even when a command has no diffs.
   - Print a warning summary when checks are skipped.

Deliverables:
- Reliable `check_sync.sh` output on macOS and Linux.
- Deterministic exit code for CI usage.

Acceptance:
- Running `bash check_sync.sh` on macOS performs real checks (not silent skip).
- Script returns non-zero when a known mismatch is injected.

Dependencies:
- None

---

### Stage 2A - Claude Completion Upgrade
Status: Completed

Tasks:
1. Update top-level command list:
   - Add `agents`, `auth`.
   - Remove or gate stale `migrate-installer` entry.
2. Add/update completion handlers:
   - `_claude_code_agents`
   - `_claude_code_auth` (+ nested `login/logout/status` commands)
3. Sync global options with current CLI:
   - Add missing flags such as `--agent`, `--debug-file`, `--disable-slash-commands`,
     `--effort`, `--file`, `--from-pr`, `--max-budget-usd`, `--no-chrome`,
     `--no-session-persistence`, `--tmux`, `--worktree`, `-w`.
   - Keep backward-compatible aliases where still accepted.

Deliverables:
- Claude top-level and new subcommands complete via Tab completion.

Acceptance:
- `check_sync.sh` reports no missing Claude commands/options.
- Manual checks pass for `claude auth <Tab>`, `claude agents <Tab>`.

Dependencies:
- Stage 1

---

### Stage 2B - Codex Completion Upgrade
Status: Completed

Tasks:
1. Update top-level command list:
   - Add `app`, `debug`, `fork`, `review`.
2. Add/update completion handlers:
   - `_codex_app`
   - `_codex_debug`
   - `_codex_fork`
   - `_codex_review`
3. Sync global options with current CLI:
   - Add missing flags such as `--profile`, `--sandbox`, `--ask-for-approval`,
     `--search`, `--add-dir`, `--local-provider`, `--no-alt-screen`,
     `--full-auto`, `--dangerously-bypass-approvals-and-sandbox`, `-V`.

Deliverables:
- Codex new commands and shared options available in completion flow.

Acceptance:
- `check_sync.sh` reports no missing Codex commands/options.
- Manual checks pass for `codex review <Tab>`, `codex fork <Tab>`, `codex debug <Tab>`.

Dependencies:
- Stage 1

---

### Stage 2C - Gemini Completion Upgrade
Status: Completed

Tasks:
1. Sync `mcp` subcommands:
   - Add `enable`, `disable`.
2. Sync `extensions` subcommands:
   - Add `config`.
3. Align updated option aliases/shape:
   - `gemini mcp add`: support `--type` alias (in addition to `--transport`).
   - Re-check argument cardinality for commands that now accept multiple names.

Deliverables:
- Gemini subcommand tree matches upgraded CLI behavior.

Acceptance:
- `check_sync.sh` reports no missing Gemini commands/options.
- Manual checks pass for `gemini mcp enable <Tab>`, `gemini mcp disable <Tab>`,
  `gemini extensions config <Tab>`.

Dependencies:
- Stage 1

---

### Stage 3 - Documentation and Release
Status: Completed

Tasks:
1. Update `README.md` command coverage to reflect real CLI support.
2. Update troubleshooting section to mention sync-check portability behavior.
3. Bump `VERSION` to `1.1.0`.
4. Run final verification:
   - `bash check_sync.sh`
   - install/uninstall smoke checks in a clean shell session.

Deliverables:
- Updated docs + releasable plugin set.

Acceptance:
- README command lists match plugin reality.
- Final sync check passes with valid execution paths.

Dependencies:
- Stage 2A, Stage 2B, and Stage 2C

## Parallelization Plan
- Stage 2A (Claude) and Stage 2B (Codex) can run in parallel after Stage 1.
- Stage 2C (Gemini) can run in parallel with Stage 2A/2B after Stage 1.
- Stage 3 depends on Stage 2A, Stage 2B, and Stage 2C.

Estimated parallelism:
- Serial path length: 3 stages (1 -> 2 -> 3)
- Parallel branch in stage 2: 2 streams

## Risks and Mitigation
- Risk: CLI help output format changes again.
  - Mitigation: keep parser tolerant and CI-gated with non-zero failure.
- Risk: Overly broad option completion introduces noise.
  - Mitigation: only complete documented options and explicit enum values.
- Risk: Dynamic completion calls slow down shell interaction.
  - Mitigation: keep dynamic calls limited to existing MCP/extension list lookups.

## Definition of Done
1. `check_sync.sh` is portable and trustworthy on macOS/Linux.
2. `claude` and `codex` command/option trees match current CLI help output.
3. `gemini` command/option tree matches current CLI help output.
4. README and VERSION are updated.
5. Install + completion smoke tests pass.
