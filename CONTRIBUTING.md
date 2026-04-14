# Contributing to cc-declutter

Thanks for considering a contribution. This is a small, focused project —
the goal is a reliable tool for cleaning up `~/.claude/`, not a general-purpose
Claude Code manager. Contributions are welcome within that scope.

## Ways to help

- **Bug reports.** If you ran `audit` or `plan` and got a wrong/misleading result, open an issue with your OS, Claude Code version, and a sanitized snippet of the report.
- **Stack presets.** If you work in a stack that isn't covered (e.g. Elixir, Zig, Flutter), propose a keep-list via issue or PR.
- **Hooks/plugin detection.** New ECC releases or new popular plugins may create bloat patterns the current audit logic misses. Concrete examples help.
- **Documentation.** Real-world audit output in `examples/` (sanitized) is valuable — see existing examples for the redaction style.

## What is out of scope

- **Automating plugin install/remove** — that's the job of `/plugin` in Claude Code itself.
- **General Claude Code configuration management** — use [`configure-ecc`](https://github.com/everything-claude-code/everything-claude-code) or official docs.
- **Synchronizing config across machines** — a separate problem; dotfiles tools (chezmoi, yadm) handle it better.

## Development workflow

1. Fork and clone.
2. Install as symlink so your edits take effect immediately:

   ```bash
   bash install.sh
   ```

3. Start a fresh Claude Code session and test your changes by invoking the skill.
4. For logic changes in `SKILL.md`, test all three modes:
   - `audit` on a bloated setup (mock some files in `~/.claude/skills/` if needed)
   - `plan python,go` and inspect the generated `prune.sh` — it should be readable and every line commented
   - `restore` from the backup dir
5. Update `CHANGELOG.md` under `[Unreleased]`.
6. Submit a PR with a short description of the problem and the fix.

## Safety requirements

Any PR that changes the `plan` logic MUST preserve these invariants:

1. **Default `DRY_RUN=1`** in the generated script.
2. **Backup created before any recommendation** of destructive action.
3. **Every `rm` / `mv` / JSON edit in the generated script has an inline comment** explaining why.
4. **No writes outside `~/.claude/`** — verify with a grep for the script paths.
5. **JSON edits use Python**, not `sed` / `jq` / shell string manipulation.

A PR that weakens any of these will be rejected or asked to add safety back.

## Testing

There is no automated test suite yet (the skill is prompt-driven). Manual
testing checklist for any change to `SKILL.md`:

- [ ] `audit` completes without errors on a fresh `~/.claude/`
- [ ] `audit` completes without errors on a heavily-bloated setup
- [ ] `plan <stack>` generates a syntactically valid `prune.sh` (bash -n prune.sh passes)
- [ ] `prune.sh` with `DRY_RUN=1` prints actions but performs none
- [ ] `prune.sh` with `DRY_RUN=0` actually performs the documented changes
- [ ] `restore` from the generated backup returns `~/.claude/` to pre-prune state

If/when a test harness is added (see Roadmap in README), this list becomes automated.

## Coding style

- Markdown in `SKILL.md`: one idea per paragraph, code fences for every command
- Shell in `install.sh`: `set -euo pipefail`, functions over inline logic, `shellcheck` clean
- Be conservative with emojis (none in generated `prune.sh`)

## License

By contributing, you agree your contributions will be licensed under
the project's [MIT License](LICENSE).
