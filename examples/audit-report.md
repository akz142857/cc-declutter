# Example audit report

Sanitized from a real developer's machine. Paths and project names
have been replaced with placeholders. The numbers are real.

---

## Top pain points

1. **240 skills** inject an estimated **~14,200 tokens** into system prompt at every session start. 150 of them are ECC-sourced duplicates (same content available as both `skill-name` and `everything-claude-code:skill-name`).
2. **SessionStart hook** reads and reinjects summaries from the last 5 sessions — adds an estimated **~3,100 tokens** per session regardless of relevance.
3. **3 projects** have session history >200 MB, including some sessions older than 6 months.
4. **`rules/zh/`** duplicates `rules/common/` content in Chinese. Both are injected at every session. If only one language is needed, the other contributes ~6 KB of dead context.

---

## Skills inventory

- **Total:** 240
- **ECC-sourced (identical content in plugin cache):** 150
- **User-authored (no upstream, unique content):** 4
  - `my-project-specific-lint`
  - `personal-commit-template`
  - `custom-deploy-checklist`
  - `demo-slide-generator`
- **Potentially orphaned** (copied from a plugin that's been uninstalled): 7

Estimated session-start token cost: **14,200 tokens** (sum of `description` fields × ~0.3 tokens/char).

## Stack-based recommendation

Declared stack: `python, go, ts, ops`

| Action | Count | Examples |
|---|---|---|
| Keep (stack match) | 14 | `python-patterns`, `golang-testing`, `frontend-patterns`, `postgres-patterns` |
| Keep (always) | 5 | `tdd-workflow`, `coding-standards`, `api-design`, `security-review`, `deep-research` |
| Remove (off-stack) | 213 | `swift-*`, `kotlin-*`, `springboot-*`, `laravel-*`, `django-*`, … |
| Review manually (user-authored) | 4 | (see above) |
| Review manually (orphaned) | 7 | (see above) |

---

## Plugins

```
ralph-loop@claude-plugins-official        @ project scope   (123 MB cached)
gopls-lsp@claude-plugins-official         @ user scope      (18 MB cached)
rust-analyzer-lsp@claude-plugins-official @ user scope      (42 MB cached)
fakechat@claude-plugins-official          @ user + project  (2 MB cached)
codex@openai-codex                        @ project scope   (34 MB cached)
everything-claude-code@ECC                @ user scope      (215 MB cached)   ← source of most bloat
```

Total plugin cache: **434 MB**. No duplicated-scope installs detected.

---

## Hooks

| Hook | Location | Est. token cost per invocation | Note |
|---|---|---|---|
| `SessionStart` | session-start-bootstrap.js (ECC) | ~3,100 | Reads recent session summaries. **Primary session-start pollution source.** |
| `PreToolUse:Bash` | block-no-verify | <50 | Safety check, keep |
| `PreToolUse:Bash` | auto-tmux-dev.js | <50 | Developer convenience, keep |
| `PreToolUse:*` | continuous-learning-v2/observe.sh (ECC) | <100 | Async, low impact |
| `PostToolUse:Bash` | command-log + cost-tracker | <100 | Logging, keep |

**Recommendation:** Remove `SessionStart` hook if you don't rely on session resumption. Other hooks are cheap and can stay.

---

## Rules

| Directory | Files | Size | Injection |
|---|---|---|---|
| `rules/common/` | 10 | ~6 KB | every session |
| `rules/zh/` | 10 | ~6 KB | every session (duplicate of common, translated) |
| `rules/python/` | 5 | ~4 KB | only when working in Python project |
| `rules/swift/` | — | — | only when working in Swift project |
| `rules/typescript/` | — | — | only when working in TS project |
| … 11 more language dirs | — | — | conditional — no session-start cost |

**Recommendation:** Remove `rules/zh/` if you don't need bilingual rules. Language dirs load conditionally — keep them for all languages you use across projects.

---

## Session history

Top projects by size, sorted descending:

```
288 MB   ~/Code/example-org/my-big-project/
214 MB   ~/Code/example-org/another-project/
187 MB   ~/Code/side-projects/experimental/
 94 MB   ~/Code/example-org/smaller-service/
 47 MB   ~/Code/example-org/library-xyz/
```

Oldest session file: 2025-09-03 (~8 months old).

**Recommendation:** For each project, keep the 5 most recent session JSONL
files. Older sessions are extremely rarely referenced — `/resume-session`
only uses the most recent by default.

---

## Estimated improvement after `prune.sh`

| Metric | Before | After | Delta |
|---|---|---|---|
| Skills count | 240 | 19 | −221 |
| Session-start token cost (skills + rules) | ~17,300 | ~1,100 | **−93%** |
| Total `~/.claude/projects/` size | 1.2 GB | ~140 MB | **−88%** |
| SessionStart hook overhead | ~3,100 tokens | 0 | — |

---

## Safety notes (generated `prune.sh` will enforce these)

- All deletions are wrapped in a `run()` function that respects `DRY_RUN=1` default.
- All modified JSON files (`settings.json`, `installed_plugins.json`) are backed up before edit.
- User-authored skills (the 4 flagged above) are **not** included in the script by default — you must add them manually after review.
- Every line in `prune.sh` has an inline comment explaining what and why.
