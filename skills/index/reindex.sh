#!/usr/bin/env bash
#
# reindex.sh — regenerate .agents/index.md from the artifacts' own headers.
# Part of the `index` skill. Deterministic; no LLM judgment.
#
# Rescans .agents/{prompts,specs,plans,verifications}/*.md and
# .agents/project.md, and rewrites .agents/index.md FROM SCRATCH every run —
# never an incremental append or merge. Because nothing is ever appended,
# there is no "stale row pointing at a deleted file" state to detect or
# repair: deleting an artifact and rerunning removes its row automatically.
#
# Usage: bash reindex.sh [project-root]

set -uo pipefail

# Determinism guard: some shells (Claude Code / agent harnesses, user rc
# files) export wrapper *functions* over core tools. Under `set -u` such a
# wrapper can abort mid-pipe, silently corrupting extraction. Drop any
# inherited function shadows so every tool below is the real binary.
unset -f grep sed awk find cat printf wc basename dirname sort head date paste 2>/dev/null || true

root="${1:-.}"
agents="$root/.agents"
mkdir -p "$agents"
out="$agents/index.md"
now="$(date +'%Y-%m-%d %H:%M')"

# ---- extraction helpers -----------------------------------------------

title_of() {  # title_of <file> — first "# " heading, text after ": " if present
  local line
  line="$(grep -m1 '^# ' "$1" 2>/dev/null)"
  line="${line#\# }"
  case "$line" in
    *": "*) printf '%s' "${line#*: }" ;;
    *) printf '%s' "$line" ;;
  esac
}

field_of() {  # field_of <file> <FieldName> — value of "- **FieldName:** ...",
              # collapsing wrapped continuation lines (indented, no blank line
              # or new "- **" bullet in between) into one space-joined value.
  awk -v field="- **$2:**" '
    index($0, field) == 1 {
      val = substr($0, length(field) + 1)
      sub(/^[ \t]+/, "", val)
      on = 1
      next
    }
    on && /^[ \t]+[^ \t]/ {
      line = $0
      sub(/^[ \t]+/, "", line)
      val = val " " line
      next
    }
    on { exit }
    END { print val }
  ' "$1" 2>/dev/null
}

strip_ticks() {  # strip_ticks <value> — remove one wrapping pair of `backticks`
                  # (and surrounding whitespace) around an otherwise-plain path,
                  # e.g. `.agents/prompts/foo.md` -> .agents/prompts/foo.md
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  s="${s#\`}"
  s="${s%\`}"
  printf '%s' "$s"
}

prompt_date() {  # prompt_date <file> — derive date from the leading unix timestamp in the filename
  local ts
  ts="$(basename "$1" | grep -oE '^[0-9]+')"
  if [ -z "$ts" ]; then
    printf '%s' "—"
    return
  fi
  date -d "@$ts" +%F 2>/dev/null || date -r "$ts" +%F 2>/dev/null || printf '%s' "—"
}

# ---- build the artifact rows ------------------------------------------

rows=""

for f in "$agents"/prompts/*.md; do
  [ -e "$f" ] || continue
  base="$(basename "$f" .md)"
  slug="${base#*-}"
  rows+="| prompt | $slug | $(prompt_date "$f") | — | $(title_of "$f") | prompts/$(basename "$f") |  |"$'\n'
done

for f in "$agents"/specs/*.md; do
  [ -e "$f" ] || continue
  slug="$(basename "$f" .md)"
  src="$(strip_ticks "$(field_of "$f" "Source prompt")")"
  link=""
  [ -n "$src" ] && link="← prompt: $(basename "$src" .md)"
  rows+="| spec | $slug | $(field_of "$f" Date) | $(field_of "$f" Status) | $(title_of "$f") | specs/$(basename "$f") | $link |"$'\n'
done

for f in "$agents"/plans/*.md; do
  [ -e "$f" ] || continue
  slug="$(basename "$f" .md)"
  sp="$(strip_ticks "$(field_of "$f" Spec)")"
  link=""
  [ -n "$sp" ] && link="← spec: $(basename "$sp" .md)"
  rows+="| plan | $slug | $(field_of "$f" Date) | $(field_of "$f" Status) | $(title_of "$f") | plans/$(basename "$f") | $link |"$'\n'
done

for f in "$agents"/verifications/*.md; do
  [ -e "$f" ] || continue
  slug="$(basename "$f" .md)"
  tg="$(strip_ticks "$(field_of "$f" Target)")"
  link=""
  [ -n "$tg" ] && link="← target: $(basename "$tg" .md)"
  rows+="| verification | $slug | $(field_of "$f" Date) | $(field_of "$f" Verdict) | $(title_of "$f") | verifications/$(basename "$f") | $link |"$'\n'
done

# ---- write the index ---------------------------------------------------

{
  echo "# Artifact index"
  echo
  echo "- **Generated:** $now by \`skills/index/reindex.sh\`"
  echo "- **Do not hand-edit** — rerun the script; it is fully regenerated from the artifacts' own headers each time."
  echo
  echo "## Prompts, specs, plans, verifications"
  echo "| Type | Slug | Date | Status | Title | Path | Links |"
  echo "|------|------|------|--------|-------|------|-------|"
  printf '%s' "$rows"
  echo
  echo "## project.md sections"
  echo "| Section | Line |"
  echo "|---------|------|"
  if [ -f "$agents/project.md" ]; then
    grep -n '^## ' "$agents/project.md" | while IFS=: read -r ln heading; do
      echo "| ${heading#\#\# } | $ln |"
    done
  fi
} > "$out"
