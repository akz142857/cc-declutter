#!/usr/bin/env bash
#
# cc-declutter installer
# https://github.com/ClayCosmos/cc-declutter
#
# Usage:
#   bash install.sh              # symlink SKILL.md into ~/.claude/skills/cc-declutter/
#   bash install.sh --copy       # copy SKILL.md (static, survives repo moves)
#   bash install.sh --uninstall  # remove the skill directory
#
# Symlink mode is recommended for contributors — edits to SKILL.md in this
# repo take effect in the next Claude Code session immediately.
# Copy mode is recommended for end users — the installed skill is independent
# of where this repo lives.

set -euo pipefail

REPO_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SKILL_NAME="cc-declutter"
SKILL_SRC="${REPO_DIR}/SKILL.md"
CLAUDE_HOME="${CLAUDE_HOME:-${HOME}/.claude}"
SKILL_DIR="${CLAUDE_HOME}/skills/${SKILL_NAME}"
SKILL_DST="${SKILL_DIR}/SKILL.md"

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RED='\033[0;31m'
COLOR_RESET='\033[0m'

info()  { printf "%b\n" "${COLOR_GREEN}[cc-declutter]${COLOR_RESET} $*"; }
warn()  { printf "%b\n" "${COLOR_YELLOW}[cc-declutter]${COLOR_RESET} $*" >&2; }
fail()  { printf "%b\n" "${COLOR_RED}[cc-declutter]${COLOR_RESET} $*" >&2; exit 1; }

check_prereqs() {
  [ -f "${SKILL_SRC}" ] || fail "SKILL.md not found at ${SKILL_SRC}. Run this script from the repo root."
  [ -d "${CLAUDE_HOME}" ] || fail "Claude Code config directory not found at ${CLAUDE_HOME}. Is Claude Code installed?"
}

backup_existing() {
  if [ -e "${SKILL_DIR}" ] || [ -L "${SKILL_DIR}" ]; then
    local backup_dir="${CLAUDE_HOME}/backups/$(date +%Y-%m-%d)-cc-declutter-install"
    mkdir -p "${backup_dir}"
    warn "Existing ${SKILL_DIR} detected. Backing up to ${backup_dir}/"
    mv "${SKILL_DIR}" "${backup_dir}/"
  fi
}

install_symlink() {
  mkdir -p "${SKILL_DIR}"
  ln -sf "${SKILL_SRC}" "${SKILL_DST}"
  info "Installed as symlink: ${SKILL_DST} → ${SKILL_SRC}"
  info "Edits to ${SKILL_SRC} take effect in the next Claude Code session."
}

install_copy() {
  mkdir -p "${SKILL_DIR}"
  cp -p "${SKILL_SRC}" "${SKILL_DST}"
  info "Installed as copy: ${SKILL_DST}"
  info "Re-run install.sh after editing ${SKILL_SRC} to refresh the installed copy."
}

uninstall() {
  if [ -e "${SKILL_DIR}" ] || [ -L "${SKILL_DIR}" ]; then
    rm -rf "${SKILL_DIR}"
    info "Removed ${SKILL_DIR}"
  else
    warn "Nothing to uninstall at ${SKILL_DIR}"
  fi
}

print_next_steps() {
  cat <<'EOF'

Next steps:

  1. Start a new Claude Code session (close and re-open the CLI, or /clear).
  2. Ask Claude any of:
       "Run cc-declutter audit"
       "Run cc-declutter plan with stack python,go,rust,ts,ios,ops"
       "Run cc-declutter restore"

  The audit is read-only — safe to run anytime.
  The plan writes a dry-run shell script to ~/.claude/backups/<date>-cc-declutter/.
  Nothing is deleted until you explicitly run that script with DRY_RUN=0.

EOF
}

main() {
  local mode="symlink"
  if [ "${1:-}" = "--copy" ]; then
    mode="copy"
  elif [ "${1:-}" = "--uninstall" ]; then
    uninstall
    exit 0
  elif [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
  elif [ -n "${1:-}" ]; then
    fail "Unknown argument: $1. Use --copy, --uninstall, or --help."
  fi

  check_prereqs
  backup_existing

  if [ "${mode}" = "copy" ]; then
    install_copy
  else
    install_symlink
  fi

  print_next_steps
}

main "$@"
