# cc-declutter

> Audit and safely prune a bloated [Claude Code](https://claude.com/claude-code) setup.

A Claude Code skill that helps you reclaim context window, disk space, and
sanity after your `~/.claude/` directory has accumulated dozens of plugins,
hundreds of skills, stale session history, and a pile of hooks that you
can't remember installing.

**It does three things, in order of caution:**

1. **`audit`** — Report only. Tells you what's bloated and why.
2. **`plan <stack>`** — Generate a dry-run `prune.sh` script based on your stack. Never executes automatically.
3. **`restore`** — Roll back from an automatic backup.

---

## Why this exists

### The symptom

You installed Claude Code, then a plugin or two. Maybe
[Everything Claude Code](https://github.com/everything-claude-code/everything-claude-code),
maybe [claude-devfleet](https://github.com/anthropics/claude-code),
maybe a few marketplace skills you thought might come in handy.

Months later, you notice Claude Code feels slower. Responses got shorter.
Sometimes it ignores obvious context. Sometimes it picks the wrong skill.
You upgrade the model, turn Fast mode on and off, fiddle with `/compact` —
nothing quite fixes it.

The real problem isn't the model. It's that **you've been running out of
context before you type a single character.**

### The numbers (from a real developer's machine, audited 2026-04-14)

| Source of bloat | Session-start cost |
|---|---|
| 240 skills (names + descriptions) | ~14,200 tokens |
| `rules/common/` + `rules/zh/` | ~2,100 tokens |
| `SessionStart` hook injecting prior session summary | ~3,100 tokens |
| **Total consumed before the first message** | **~19,400 tokens** |

That's **~10% of a 200k-context window** spent on stuff you likely never
use — before Claude even sees your question. The skills list alone includes
`customs-trade-compliance`, `nutrient-document-processing`, `visa-doc-translate`,
and 200 others that shipped with plugins and silently bloat every session.

On the same machine, `~/.claude/projects/` grew to **1.2 GB** of session
history, most of it from projects last touched 6+ months ago.

### Why does this happen

- **Default installs are maximalist.** Tools like ECC ship with **150+ skills** out of the box. It's generous, but every skill's one-line description is injected into system prompt at session start. There's no "lazy discovery" — Claude has to know what exists before it can decide to call one.
- **Duplicate installation.** Some plugins install into the plugin cache **and** copy files into `~/.claude/skills/`. Result: the same skill appears as `commit` and `everything-claude-code:commit`, doubling the context cost.
- **Hooks compound silently.** A `SessionStart` hook that reinjects "recent work summary" sounds harmless. Run it 20 times as you pop sessions in and out, and you've burned 60k+ tokens on stale context that's mostly garbage.
- **Rules accumulate.** `rules/common/` + `rules/zh/` (Chinese duplicate) + `rules/python/` + `rules/typescript/` + `rules/swift/` ... languages you don't touch still occupy `~/.claude/` and, for the top-level common dirs, system prompt space.
- **No feedback loop.** Claude Code doesn't tell you "by the way, 40% of your system prompt is things you never called in the last 90 days." So the bloat is invisible until someone points a tool at it.

### Why existing audit tools don't solve it

Several existing skills **describe** the problem:

- `skill-stocktake` — audits skills and commands
- `workspace-surface-audit` — audits MCP servers, plugins, hooks
- `context-budget` — estimates session context consumption
- `skill-health` — skill portfolio dashboard

None of them **safely remove** anything. You read the audit, then you're
on your own with `rm -rf` and a vague memory of what each skill does.

`cc-declutter` fills the gap between "tell me what's broken" and "clean it
up without me breaking my setup." It produces a fully-commented shell
script you review line-by-line, with automatic backups and a dry-run
default. Nothing is ever deleted without your explicit `DRY_RUN=0`.

### Who this is for

- You installed ECC or a similar bundle and now regret it.
- Your `~/.claude/` is multi-GB and you can't remember why.
- Claude Code feels degraded but you've already eliminated the obvious causes (Fast mode, model choice, network).
- You want to clean up once, commit the change to a script, and re-run the same cleanup on your other machines.

### What good looks like after

Same machine, after running `cc-declutter plan` and executing the generated script:

| Metric | Before | After |
|---|---|---|
| Skills count | 240 | 19 |
| Session-start token cost (skills + rules) | ~17,300 | ~1,100 |
| `~/.claude/projects/` size | 1.2 GB | ~140 MB |
| SessionStart hook overhead | ~3,100 tokens | 0 |

Responses feel snappier. Claude picks the right skill more often because
there are fewer decoys. Session history restore works faster. No magic —
just less garbage in the system prompt.

---

## Design principles

- **Never auto-delete.** Everything is generated as a shell script with dry-run mode enabled by default.
- **Always back up first.** Backups go to `~/.claude/backups/<date>-cc-declutter/` with a `RESTORE.md` inside.
- **Stay in `~/.claude/`.** The skill never touches anything outside the user config directory.
- **JSON edits go through Python.** No fragile `sed` one-liners for `settings.json` / `installed_plugins.json`.
- **Report-first.** `audit` never writes. `plan` writes only to the backup directory.

---

## Installation

Requires: [Claude Code](https://claude.com/claude-code) installed.

### Option A — via `install.sh` (recommended)

```bash
git clone https://github.com/ClayCosmos/cc-declutter.git
cd cc-declutter
bash install.sh                # symlink — recommended for developers
# or
bash install.sh --copy         # static copy — recommended for users
```

### Option B — manual

```bash
mkdir -p ~/.claude/skills/cc-declutter
cp SKILL.md ~/.claude/skills/cc-declutter/
```

### Verification

Open a new Claude Code session and ask:

```
Show me the cc-declutter audit mode
```

If the skill is discoverable, Claude will explain the three modes.

---

## Usage

### 1. Audit — diagnose only

In any Claude Code session:

```
Run cc-declutter audit on my Claude Code setup.
```

Claude will:

1. Inventory `~/.claude/skills/` and detect duplicates with plugin caches.
2. Parse `~/.claude/settings.json` to list every hook (especially `SessionStart`).
3. Measure session history size per project.
4. Estimate the token cost of skills and rules injected at session start.
5. Print a ranked report — biggest pain points first.

**No files are modified.** The audit is safe to run anywhere, anytime.

### 2. Plan — generate dry-run script

Declare your stack as a comma-separated list. Supported tokens:

```
python, go, rust, ts, java, ios, android, ops, llm, ml, frontend, backend
```

```
Run cc-declutter plan with stack python,go,rust,ts,ios,ops
```

Claude will:

1. Create a backup at `~/.claude/backups/<date>-cc-declutter/` containing `skills/`, `rules/`, `settings.json`, `installed_plugins.json`, and project `MEMORY.md`.
2. Write `~/.claude/backups/<date>-cc-declutter/prune.sh` — a fully commented shell script with `DRY_RUN=1` by default.
3. Write `RESTORE.md` — exact commands to roll back.
4. Print the paths and stop. **Nothing is executed.**

To review:

```bash
cat ~/.claude/backups/<date>-cc-declutter/prune.sh
```

To dry-run:

```bash
bash ~/.claude/backups/<date>-cc-declutter/prune.sh
```

To actually execute:

```bash
DRY_RUN=0 bash ~/.claude/backups/<date>-cc-declutter/prune.sh
```

### 3. Restore — roll back

```
Run cc-declutter restore from the latest backup
```

Claude will list available backups under `~/.claude/backups/` and ask which
one to restore from. No destructive operations run during restore.

---

## Stack → keep-list mapping

Default whitelist when `plan` is invoked. Customize in `SKILL.md`:

| Stack token | Skills kept |
|---|---|
| **(always)** | `tdd-workflow`, `coding-standards`, `api-design`, `security-review`, `deep-research` |
| `python` | `python-patterns`, `python-testing` |
| `go` | `golang-patterns`, `golang-testing` |
| `rust` | `rust-patterns`, `rust-testing` |
| `ts` / `frontend` | `frontend-patterns`, `e2e-testing` |
| `java` | `java-coding-standards`, `springboot-patterns`, `springboot-security`, `jpa-patterns` |
| `ios` | `swiftui-patterns`, `swift-concurrency-6-2`, `swift-actor-persistence`, `swift-protocol-di-testing`, `liquid-glass-design` |
| `android` | `android-clean-architecture`, `kotlin-patterns`, `kotlin-coroutines-flows`, `kotlin-testing`, `kotlin-ktor-patterns`, `compose-multiplatform-patterns` |
| `ops` | `docker-patterns`, `deployment-patterns`, `database-migrations`, `postgres-patterns` |
| `llm` | `claude-api`, `mcp-server-patterns`, `eval-harness` |
| `ml` | `pytorch-patterns` |

Skills not in the union of matched categories are recommended for deletion,
except any skill whose `SKILL.md` **lacks** an `origin:` frontmatter field
and **differs** from all plugin-cache copies — those are flagged as
"potentially user-authored, review manually."

---

## What cc-declutter does **NOT** do

- **Does not uninstall plugins.** It recommends, but leaves the actual `/plugin remove` step to you. The `installed_plugins.json` edit is opt-in inside the generated script.
- **Does not delete `~/.claude/plugins/cache/`.** That's plugin source material. Removing it is the plugin manager's job.
- **Does not touch project memory (`MEMORY.md`).** Memory is always backed up, never deleted.
- **Does not modify any file outside `~/.claude/`.** Not your repos, not `/tmp`, nothing else.
- **Does not run across machines automatically.** Each machine is audited and cleaned independently.

---

## Known gotchas

- `continuous-learning` / `continuous-learning-v2` are referenced by ECC's `observe.sh` hook. If ECC's hooks are still active in `settings.json`, do not delete those skills.
- Some rules directories (`~/.claude/rules/<language>/`) load conditionally per project. Keeping them has no session-start cost — they're loaded only when you open a project in that language.
- `~/.claude/rules/common/` and `~/.claude/rules/zh/` are injected at **every** session. If you don't read Chinese, delete `zh/`.
- On Linux, `du -sh` may report slightly different numbers than macOS BSD `du`. Both are fine for relative comparisons.

---

## Safety rails in the generated script

Every `prune.sh` produced by `plan`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DRY_RUN=${DRY_RUN:-1}          # ← default is dry-run

run() {
  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] $*"
  else
    eval "$*"
  fi
}

# Every destructive line is wrapped in run()
run 'rm -rf ~/.claude/skills/example-skill'    # comment: why we remove this
```

You must explicitly opt in with `DRY_RUN=0` to actually execute. Every line
has an inline comment explaining the rationale.

---

## Development

The skill itself is a single Markdown file: `SKILL.md`. The frontmatter
declares `name` and `description` for Claude Code's skill resolver; the
body is the prompt that guides Claude when the skill is invoked.

To iterate:

```bash
# Edit SKILL.md in this repo
vim SKILL.md

# If installed via symlink, changes take effect in the next Claude session.
# If installed via copy, re-run install.sh or copy manually.
```

To test against a messy setup, the `examples/` directory contains sanitized
audit outputs from real machines.

---

## Roadmap

v0.1 (current) — MVP

- [x] `audit` mode with estimated token cost
- [x] `plan <stack>` with default whitelist
- [x] `restore` from backup
- [x] Safety rails (dry-run, backups, no external writes)

v0.2 — data-driven recommendations

- [ ] Parse `~/.claude/history.jsonl` and `bash-commands.log` to detect **actually-used** skills over the last N days
- [ ] Recommend deletion based on usage, not only stack
- [ ] Show "before/after" token cost diff (e.g. "session start context: 27.4k → 9.1k")

v0.3 — interactive

- [ ] `plan --interactive` — confirm/reject each skill one-by-one
- [ ] Integration with `skill-stocktake` and `workspace-surface-audit` for a unified report

v0.4 — cross-platform

- [ ] Windows support (path handling, no `du`)
- [ ] Dockerized test harness with a synthetic "bloated" `~/.claude/` fixture

---

## Contributing

Issues and PRs welcome. For significant additions (new modes, new stack
tokens, integration with other skills), please open an issue first so we
can discuss the shape before you spend time on a PR.

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

MIT. See [LICENSE](LICENSE).
