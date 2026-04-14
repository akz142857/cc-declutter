# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- Parse `~/.claude/history.jsonl` and `bash-commands.log` to detect actually-used skills over the last N days
- `plan --interactive` mode for per-skill confirm/reject
- Before/after token cost diff in audit report
- Windows support

## [0.1.0] — 2026-04-14

Initial MVP.

### Added

- `audit` mode — diagnose bloat in `~/.claude/` without modifying anything
- `plan <stack>` mode — generate a dry-run `prune.sh` based on declared stack
- `restore` mode — roll back from automatic backup
- Default stack → skill whitelist for `python`, `go`, `rust`, `ts`, `java`, `ios`, `android`, `ops`, `llm`, `ml`, `frontend`, `backend`
- Safety rails: dry-run by default, automatic backup, scoped to `~/.claude/` only
- `install.sh` with symlink (default) and `--copy` modes
