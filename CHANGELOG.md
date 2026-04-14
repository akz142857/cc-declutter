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

## [0.1.1] — 2026-04-14

Bug-fix release after first real-world run on a 165-skill / 711 MB install
surfaced three concrete defects in the 0.1.0 generator.

### Fixed

- **Session pruning silently no-op'd.** The generated shell loop looked for
  `~/.claude/projects/<proj>/sessions/*.jsonl`, but Claude Code actually
  stores transcripts as `<proj>/<uuid>.jsonl` with a sibling `<uuid>/`
  directory. The missing path caused `ls` to return empty and `xargs -r`
  to no-op without error. On the test install, 223 MB of old sessions were
  supposed to be removed but weren't. Now generated scripts use a Python
  snippet that handles the real directory layout and deletes both the
  `.jsonl` transcript and its sibling UUID directory atomically.
- **Orphaned UUID sibling directories.** Even with the path fix, the old
  template only removed `.jsonl` files, leaving behind the sibling
  directories containing subagent and tool-result data (often the bulk of
  session disk usage). New template deletes both.
- **Incomplete skill backup.** The 0.1.0 generator backed up only SKILL.md
  manifests, not full skill contents. For ECC/plugin skills this is fine —
  they can be restored from the plugin cache — but for user-authored skills
  it was a silent data-loss path. New spec: back up the full directory of
  every skill the plan will delete; still write a manifest index for all
  skills as forensic reference.

### Added

- New "Session pruning — use Python, not shell" section in SKILL.md with a
  canonical snippet the generator must use.
- Two new Known Gotchas entries: dry-run-passing ≠ correctness, and never
  emit uncertain `# actually keep?` comments into generated scripts.

## [0.1.0] — 2026-04-14

Initial MVP.

### Added

- `audit` mode — diagnose bloat in `~/.claude/` without modifying anything
- `plan <stack>` mode — generate a dry-run `prune.sh` based on declared stack
- `restore` mode — roll back from automatic backup
- Default stack → skill whitelist for `python`, `go`, `rust`, `ts`, `java`, `ios`, `android`, `ops`, `llm`, `ml`, `frontend`, `backend`
- Safety rails: dry-run by default, automatic backup, scoped to `~/.claude/` only
- `install.sh` with symlink (default) and `--copy` modes
