#!/usr/bin/env bash
#
# query.sh — deterministic keyword pre-filter over the artifact index.
# Part of the `index` skill. Mechanizes *matching*, not *relevance*: a
# keyword hit is a mechanical fact ("this string appears here"); deciding
# whether the matched artifact is actually relevant to the current task is
# still the calling skill's judgment call — the same call it would make
# reading a directory listing. Never read a result here as proof of
# relatedness.
#
# Always refreshes the index first (unconditionally), so what this prints
# is current regardless of whether an earlier skill's own "refresh the
# index" step actually ran.
#
# Usage: bash query.sh <keyword> [<keyword> ...]

set -uo pipefail

unset -f grep sed awk find cat printf wc basename dirname sort head date paste 2>/dev/null || true

here="$(cd "$(dirname "$0")" && pwd)"
root="."
agents="$root/.agents"

if [ $# -eq 0 ]; then
  echo "usage: bash query.sh <keyword> [<keyword> ...]" >&2
  exit 2
fi

bash "$here/reindex.sh" "$root" >/dev/null

pattern="$(printf '%s\n' "$@" | paste -sd'|' -)"

echo "== Tier 1: .agents/index.md rows matching [$*] =="
tier1="$(grep -iE "$pattern" "$agents/index.md" 2>/dev/null | grep '^|' || true)"
if [ -n "$tier1" ]; then
  printf '%s\n' "$tier1"
  exit 0
fi
echo "(no matches in .agents/index.md)"
echo
echo "== Tier 2: full-text fallback across .agents/ =="
found=0
for d in prompts specs plans verifications; do
  for f in "$agents/$d"/*.md; do
    [ -e "$f" ] || continue
    hit="$(grep -niE -C2 "$pattern" "$f" 2>/dev/null || true)"
    if [ -n "$hit" ]; then
      echo "--- $d/$(basename "$f") ---"
      printf '%s\n' "$hit"
      found=1
    fi
  done
done
[ "$found" -eq 0 ] && echo "(no matches anywhere in .agents/)"
