#!/usr/bin/env bash
# setup-hooks.sh — install tracked git hooks into the active git hooks directory
#
# Run once after cloning:
#   bash scripts/setup-hooks.sh
#
# Idempotent: safe to run multiple times.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_SOURCE="$REPO_ROOT/git-hooks"

# Respect core.hooksPath when configured; fall back to .git/hooks
_configured_path="$(git -C "$REPO_ROOT" config core.hooksPath 2>/dev/null || true)"
if [[ -n "$_configured_path" ]]; then
  # core.hooksPath may be relative — resolve it from the repo root
  case "$_configured_path" in
    /*) HOOKS_DEST="$_configured_path" ;;
    *)  HOOKS_DEST="$REPO_ROOT/$_configured_path" ;;
  esac
else
  HOOKS_DEST="$REPO_ROOT/.git/hooks"
fi

if [[ ! -d "$HOOKS_SOURCE" ]]; then
  printf '[setup-hooks] ERROR: %s not found. Run from repo root.\n' "$HOOKS_SOURCE" >&2
  exit 1
fi

if [[ ! -d "$HOOKS_DEST" ]]; then
  printf '[setup-hooks] ERROR: %s not found. Is this a git repository?\n' "$HOOKS_DEST" >&2
  exit 1
fi

installed=0
for hook in "$HOOKS_SOURCE"/*; do
  [[ -f "$hook" ]] || continue
  hook_name="$(basename "$hook")"
  dest="$HOOKS_DEST/$hook_name"

  if [[ -L "$dest" ]]; then
    # Already a symlink — update it in case source moved
    rm "$dest"
  elif [[ -f "$dest" ]]; then
    printf '[setup-hooks] Backing up existing %s -> %s.bak\n' "$hook_name" "$hook_name"
    mv "$dest" "${dest}.bak"
  fi

  ln -s "$hook" "$dest"
  chmod +x "$dest"
  printf '[setup-hooks] Installed %s\n' "$hook_name"
  (( installed++ )) || true
done

if [[ "$installed" -eq 0 ]]; then
  printf '[setup-hooks] No hooks found in %s\n' "$HOOKS_SOURCE"
else
  printf '[setup-hooks] Done. %d hook(s) installed.\n' "$installed"
fi
