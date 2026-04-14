---
name: cc-declutter
description: Audit and safely prune a bloated Claude Code setup — skills, rules, hooks, plugins, session history. Reports context-window cost, recommends deletions by user stack, and generates a dry-run shell script (never auto-deletes). Use when Claude Code feels slow, skill lists are 200+ entries, session startup context is huge, or you suspect the config has accumulated cruft over time.
origin: self
version: 0.1.1
---

# cc-declutter — Claude Code Slim-Down Assistant

Helps users reclaim context and clean up `~/.claude/` after accumulating
plugins, skills, rules, hooks, and session history that no longer serve them.

**Golden rule: never delete anything directly. Always:**
1. Back up to `~/.claude/backups/<YYYY-MM-DD-cc-declutter>/`
2. Write a `prune.sh` script with every `rm` / file edit as a separate line, each with a human-readable comment
3. Show the script to the user
4. Let the user `cat prune.sh` and `bash prune.sh` manually when they're satisfied

## Invocation Modes

User can request one of three modes. If unclear, ask.

### Mode 1: `audit` — Diagnose only

Produce a plain-text report of what's bloated. Do NOT write or delete anything.

Checks to perform (all via `Bash`):

1. **Skills inventory**
   - `ls ~/.claude/skills/ | wc -l` — total count
   - For each: cross-check with `ls ~/.claude/plugins/cache/*/*/skills/` (identify ECC/plugin duplicates using `diff -q`)
   - Sample 5 SKILL.md files and check for `origin:` frontmatter field to detect source
   - Flag suspicious cases: orphaned copies where the upstream plugin is uninstalled

2. **Plugins**
   - `cat ~/.claude/plugins/installed_plugins.json` — list active plugins
   - `du -sh ~/.claude/plugins/cache/*/*/` — size per plugin
   - Flag: same plugin at multiple scopes, versions stacked in cache, plugins listed but skills not on disk

3. **Rules**
   - `ls ~/.claude/rules/` — all language directories
   - `common/` + `zh/` (or other lang variants) are injected into EVERY session — flag as high-cost
   - Language-specific dirs (`python/`, `swift/`, etc.) load conditionally — low-cost, safe to keep

4. **Hooks in `~/.claude/settings.json`**
   - Parse JSON, list all `SessionStart` / `PreToolUse` / `PostToolUse` / `Stop` entries
   - Flag SessionStart especially — those run every session and often inject big context
   - Note any hook scripts that read `~/.claude/projects/*/sessions/` (session summary pollution)

5. **Session history per project**
   - `du -sh ~/.claude/projects/*/` sorted by size desc
   - Top 5 projects with size > 100MB → candidates for pruning old sessions

6. **Skills list injection cost estimate**
   - Sum character count of `description` frontmatter across all enabled skills × ~0.3 tokens/char
   - Report estimated tokens injected into every session

**Output format:** a markdown table grouped by category, with a
"highest pain" line at the top (e.g. "Your biggest issue is 240 skills
injecting ~14k tokens at every session start").

---

### Mode 2: `plan <stack>` — Generate prune script

Take a comma-separated stack hint from the user:
`python,go,rust,ts,java,ios,android,ops,llm,frontend,backend,ml`

1. **Build a whitelist** by mapping stack → skill keep-list. Use these
   canonical groupings (extend as needed):
   - **python** → `python-patterns`, `python-testing`
   - **go** → `golang-patterns`, `golang-testing`
   - **rust** → `rust-patterns`, `rust-testing`
   - **ts / frontend** → `frontend-patterns`, `e2e-testing`
   - **java** → `java-coding-standards`, `springboot-patterns`, `springboot-security`, `jpa-patterns`
   - **ios** → `swiftui-patterns`, `swift-concurrency-6-2`, `swift-actor-persistence`, `swift-protocol-di-testing`, `liquid-glass-design`
   - **android** → `android-clean-architecture`, `kotlin-patterns`, `kotlin-coroutines-flows`, `kotlin-testing`, `kotlin-ktor-patterns`, `compose-multiplatform-patterns`
   - **ops** → `docker-patterns`, `deployment-patterns`, `database-migrations`, `postgres-patterns`
   - **llm** → `claude-api`, `mcp-server-patterns`, `eval-harness`
   - **ml** → `pytorch-patterns`
   - **core (always)** → `tdd-workflow`, `coding-standards`, `api-design`, `security-review`, `deep-research`

2. **Create backup dir** `~/.claude/backups/<date>-cc-declutter/`
   - Always copy (cheap, small): `settings.json`, `installed_plugins.json`, `rules/`, project MEMORY.md
   - **Targeted skill backup**: for each skill the plan will delete, copy its
     full directory to `<backup>/skills/<skill-name>/`. Do NOT bulk-copy the
     entire `~/.claude/skills/` tree — on a bloated install it's hundreds of MB
     and wasteful. Only back up what you're about to destroy.
   - Also write `<backup>/skills-manifests/` containing every skill's SKILL.md
     (including skills that will be kept) as a forensic index — cheap,
     useful for post-hoc "wait, what did I have?" questions.
   - Add `RESTORE.md` with exact restore commands, distinguishing:
     - ECC/plugin skills → can be restored by reinstalling the plugin
     - User-authored skills → restore from `<backup>/skills/<name>/`

3. **Write `~/.claude/backups/<date>-cc-declutter/prune.sh`** with:
   - Shebang `#!/usr/bin/env bash` + `set -euo pipefail`
   - Top comment: "Review every line. Run with `bash prune.sh` when satisfied."
   - A `DRY_RUN=${DRY_RUN:-1}` gate — first line does `DRY_RUN=0 bash prune.sh` if user wants real execution
   - One `rm -rf` / command per line, preceded by a `#` comment explaining why
   - Group sections with clear headers:
     ```
     # === Skills not in whitelist ===
     # === Redundant rules (e.g. rules/zh if English common is kept) ===
     # === Old session history (keep 5 most recent per project) ===
     # === SessionStart hook removal (suggest, don't force) ===
     ```
   - For SessionStart / plugin removal: generate a Python one-liner that edits the JSON (not `sed`), since JSON is fragile

4. **Do NOT execute the script.** Print the path and tell user:
   `cat <path>` to review, then `bash <path>` when ready, or
   `DRY_RUN=0 bash <path>` if the script supports it.

---

### Mode 3: `restore [backup-name]` — Roll back

1. List available backups: `ls ~/.claude/backups/ | grep cc-declutter`
2. If backup specified: copy from it back into `~/.claude/`
3. If not specified: show list and ask which one

Use `cp -r` preserving timestamps (`-p`). Never run destructive ops during restore.

---

## Safety Rules (non-negotiable)

1. **Never `rm` anything outside `~/.claude/`.** The skill operates in user config only.
2. **Never edit `installed_plugins.json` directly without backup.** Prefer recommending `/plugin` UI flow in the report.
3. **Never delete `~/.claude/plugins/cache/`.** That's plugin source — removal forces redownload and may lose unpushed local edits.
4. **Detect user-authored skills.** If a `SKILL.md` lacks `origin: ECC` frontmatter AND differs from any plugin cache copy, flag as "potentially user-authored — review manually before delete".
5. **Never remove hooks silently.** Always list them in the report; require user confirmation in the generated script.
6. **Cross-platform.** Avoid `sed -i ''` vs `sed -i` divergence (Mac vs Linux). Use Python for JSON edits.

---

## Output Examples

### Audit report (abbreviated)

```
## Top pain points
1. 240 skills inject ~14,200 tokens at session start (83% from ECC duplicates)
2. 3 projects have >200MB session history (oldest session 8 months old)
3. SessionStart hook reads last 50 sessions — adds ~3k tokens per session

## Skills (240 total)
- ECC-sourced duplicates: 150
- User-authored (no plugin upstream): 4 (listed below, review manually)
- Remaining: 86 (stack-relevant, keep)

## Rules
- common/ — 10 files, ~6KB (always loaded)
- zh/     — 10 files, ~6KB (always loaded, duplicate of common/)
- 11 language dirs — load on demand, safe to keep
...
```

### Generated prune.sh (abbreviated)

```bash
#!/usr/bin/env bash
# cc-declutter prune script — generated 2026-04-14
# Review every line. To actually execute: DRY_RUN=0 bash prune.sh
set -euo pipefail
DRY_RUN=${DRY_RUN:-1}
run() { if [ "$DRY_RUN" = "1" ]; then echo "[dry-run] $*"; else eval "$*"; fi; }

# === Backup location: ~/.claude/backups/2026-04-14-cc-declutter/ ===

# === Remove 180 skills not matching stack: python,go,ios,android ===
run 'rm -rf ~/.claude/skills/article-writing'       # content/marketing, off-stack
run 'rm -rf ~/.claude/skills/laravel-patterns'      # PHP, off-stack
# ... (177 more)

# === Remove rules/zh (duplicate of rules/common in English) ===
run 'rm -rf ~/.claude/rules/zh'

# === Remove ECC plugin entry from installed_plugins.json ===
run "python3 -c \"import json,pathlib; p=pathlib.Path.home()/'.claude/plugins/installed_plugins.json'; d=json.loads(p.read_text()); d['plugins'].pop('everything-claude-code@everything-claude-code', None); p.write_text(json.dumps(d, indent=2))\""

# === Remove SessionStart hook (pollutes context with session summary) ===
run "python3 -c \"import json,pathlib; p=pathlib.Path.home()/'.claude/settings.json'; d=json.loads(p.read_text()); d.get('hooks', {}).pop('SessionStart', None); p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + '\\n')\""

# === Prune project session history (keep 5 most recent per project) ===
# Use Python (see "Session pruning" below) — not shell.
...
```

---

## Session pruning — use Python, not shell

**Do not generate shell loops like `ls -t $dir/*.jsonl | tail -n +6 | xargs rm`.**
They silently no-op on wrong paths and leave orphaned sibling directories.
Emit the snippet below instead, wrapped in the script's `run` helper:

```bash
run "python3 - <<'PY'
from pathlib import Path
import shutil

base = Path.home() / '.claude/projects'
for proj in sorted(base.iterdir()):
    if not proj.is_dir():
        continue
    jsonls = sorted(
        [f for f in proj.iterdir() if f.is_file() and f.suffix == '.jsonl'],
        key=lambda f: f.stat().st_mtime,
        reverse=True,
    )
    for f in jsonls[5:]:                  # keep newest 5
        uuid_dir = proj / f.stem          # sibling dir holding subagent data
        if uuid_dir.is_dir():
            shutil.rmtree(uuid_dir)
        f.unlink()
PY
"
```

**Claude Code session layout** (as of 2026-04):

```
~/.claude/projects/<slug>/
├── <session-uuid>.jsonl          ← transcript (what we sort by mtime)
├── <session-uuid>/               ← sibling dir: subagents/, tool-results/
│   ├── subagents/
│   └── tool-results/
├── memory/                       ← NEVER TOUCH: user's project memory
└── ...
```

Non-negotiable rules for this operation:

- Enumerate `.jsonl` files in the project root directly — not in subdirs
- Match each deleted `.jsonl` with its sibling UUID directory and remove both
- Never touch `memory/` or any non-UUID subdirectory
- Configurable keep-count (default 5) — expose via flag in future iterations

---

## Known Gotchas

- `continuous-learning` / `continuous-learning-v2` skills are referenced by
  ECC hooks (`observe.sh`). If ECC hooks are still active, don't delete them.
- Some skills have `allowed-tools` restrictions in frontmatter — removing
  those skills won't break anything, but users may notice missing `/slash` commands.
- `installed_plugins.json` can have a plugin listed under multiple scopes
  (user vs project). Only remove the entry matching the user's intent.
- `~/.claude/projects/<proj>/memory/MEMORY.md` is project memory (small,
  ~150 chars per line). Never delete unless user explicitly says to.
- On Linux, `du -sh` behaves slightly differently than macOS BSD version.
  Prefer `du -sh --apparent-size` if available, else document the variance.
- **Dry-run passing ≠ correctness.** Shell loops that reference non-existent
  paths (`ls $missing/*.jsonl 2>/dev/null`) silently no-op in both dry-run
  and real mode. Always validate target existence in the generator, not at
  script run time. For anything involving directory layout assumptions,
  prefer Python (see Session pruning section above).
- **Never emit uncertainty into the generated script.** If the generator is
  unsure whether to keep a skill (e.g. niche but stack-adjacent), it must
  decide one way or the other BEFORE emitting the line. Comments like
  `# actually keep? remove; niche` push the decision to the user at the worst
  possible moment (script review), and if the user glosses over the comment,
  it causes silent wrong deletes. Rule: every `rm` line gets a definite
  reason. Every "keep" decision gets no line at all.

---

## Recovery

If something breaks after running `prune.sh`:

```
ls ~/.claude/backups/  # find the right backup dir
# Everything is in there: skills/, rules/, settings.json, installed_plugins.json
cp -rp ~/.claude/backups/<date>-cc-declutter/skills ~/.claude/
cp -p  ~/.claude/backups/<date>-cc-declutter/settings.json ~/.claude/
# etc.
```

Or read `RESTORE.md` inside the backup dir — it lists exact commands
tailored to what was removed.
