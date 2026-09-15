#!/usr/bin/env bash
# Reset ephemeral sandbox dirs to a fresh state.
# Removes everything inside workspace/ and .opencode-state/ except .gitkeep.
# Usage: ./clean.sh [--force|-f|--yes|-y]
set -euo pipefail

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force|-f|--yes|-y) FORCE=1 ;;
    --help|-h)
      echo "Usage: ./clean.sh [--force]"
      echo "  Without --force, asks for confirmation before deleting."
      exit 0
      ;;
    *) echo "Unknown argument: $arg (try --help)" >&2; exit 1 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGETS=("workspace" ".opencode-state")

# Warn if the sandbox container is still running against these bind mounts.
if command -v docker >/dev/null 2>&1 && [ -n "$(docker compose --project-directory "$ROOT" ps -q 2>/dev/null || true)" ]; then
  echo "WARNING: agent-sandbox container is running. Stop it first to avoid surprises:"
  echo "  docker compose --project-directory \"$ROOT\" down"
  if [ "$FORCE" -eq 0 ]; then
    read -r -p "Continue anyway? [y/N] " answer
    case "$answer" in
      [yY][eE][sS]|[yY]) ;;
      *) echo "Aborted."; exit 1 ;;
    esac
  fi
fi

if [ "$FORCE" -eq 0 ]; then
  echo "This will delete ALL contents of:"
  for d in "${TARGETS[@]}"; do echo "  $ROOT/$d (except .gitkeep)"; done
  read -r -p "Continue? [y/N] " answer
  case "$answer" in
    [yY][eE][sS]|[yY]) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

for d in "${TARGETS[@]}"; do
  dir="$ROOT/$d"
  mkdir -p "$dir"
  # Delete everything one level deep except .gitkeep (handles dotfiles too).
  find "$dir" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' -exec rm -rf {} +
  # Keep the dir tracked in git.
  touch "$dir/.gitkeep"
  echo "Cleaned $dir"
done

echo "Done. Fresh workspace + state ready."
