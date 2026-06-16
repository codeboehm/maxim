#!/usr/bin/env bash
#
# install.sh — install the maxim skills into Mistral Vibe's global skills dir.
#
# Usage:
#   ./install.sh          copy skills into ~/.vibe/skills/ (default)
#   ./install.sh --link   symlink instead, so edits in this repo take effect live
#   ./install.sh --dry-run
#
set -euo pipefail

mode="copy"
dry=0
for arg in "$@"; do
  case "$arg" in
    --link)    mode="link" ;;
    --dry-run) dry=1 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/skills"
dest="${VIBE_SKILLS_DIR:-$HOME/.vibe/skills}"

[ -d "$src" ] || { echo "no skills/ dir next to install.sh ($src)" >&2; exit 1; }

echo "maxim install"
echo "  from: $src"
echo "  into: $dest   (mode: $mode)"
echo

run() { if [ "$dry" -eq 1 ]; then echo "  + $*"; else eval "$*"; fi; }

run "mkdir -p \"$dest\""

for skill in "$src"/*/; do
  name="$(basename "$skill")"
  target="$dest/$name"
  if [ -e "$target" ] || [ -L "$target" ]; then
    echo "  ~ replacing existing $name"
    run "rm -rf \"$target\""
  else
    echo "  + installing $name"
  fi
  if [ "$mode" = "link" ]; then
    run "ln -s \"${skill%/}\" \"$target\""
  else
    run "cp -r \"${skill%/}\" \"$target\""
  fi
done

# Ensure the deterministic pre-flight stays executable.
if [ "$dry" -eq 0 ] && [ -f "$dest/verify/preflight.sh" ]; then
  chmod +x "$dest/verify/preflight.sh"
fi

echo
echo "Done. Start a NEW Mistral Vibe conversation so it picks up the skills."
echo "Then add an AGENTS.md to your project (see AGENTS.example.md)."
