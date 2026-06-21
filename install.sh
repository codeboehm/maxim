#!/usr/bin/env bash
#
# install.sh — install the maxim discipline skills into your coding agents'
# GLOBAL user directories, and (on request) into a repo's .github/skills/ for
# GitHub Copilot and other agentskills-aware tools.
#
# Targets:
#   Mistral Vibe   → ~/.vibe/skills/      + a managed block in ~/.vibe/AGENTS.md
#   Claude Code    → ~/.claude/skills/    + a managed block in ~/.claude/CLAUDE.md
#   GitHub Copilot → ~/.copilot/AGENTS.md (global custom instructions; see note)
#   Any repo       → <repo>/.github/skills/   (--github-skills)
#
# It is NON-DESTRUCTIVE. It only ever manages its own skills (tracked in a
# .maxim-manifest) and a clearly-marked managed block in your always-on files.
# A same-named skill it did not install is reported and left untouched (use
# --force to replace it). --uninstall removes only what maxim added.
#
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/skills"
block_src="$here/agents/discipline-block.md"
manifest_name=".maxim-manifest"
BEGIN_MARK="<!-- >>> maxim (managed) — do not edit between these markers >>> -->"
END_MARK="<!-- <<< maxim (managed) <<< -->"

usage() {
  cat <<'EOF'
maxim install — discipline skills for Mistral Vibe, Claude Code & GitHub Copilot

Usage:
  ./install.sh                      install into every detected agent (copy mode)
  ./install.sh --agent claude       only this agent (vibe|claude|copilot|all)
  ./install.sh --agent vibe,claude  comma/space list of agents
  ./install.sh --link               symlink skills instead of copying (live edits)
  ./install.sh --copy               force copy mode (default)
  ./install.sh --skills-only        install skills; skip the always-on block
  ./install.sh --dry-run            print what would happen; write nothing
  ./install.sh --github-skills DIR  bundle skills into DIR/.github/skills/
  ./install.sh --force              replace even a same-named FOREIGN skill
  ./install.sh --uninstall          remove only what maxim installed
  ./install.sh -h | --help          this help

Non-destructive: maxim never overwrites a skill it didn't install, and merges
its always-on rules as a marked block — your other content is preserved.
EOF
}

# ---------------------------------------------------------------- args
mode="copy"; dry=0; force=0; uninstall=0; skills_only=0; agents_arg=""; gh_repo=""
while [ $# -gt 0 ]; do
  case "$1" in
    --link)             mode="link" ;;
    --copy)             mode="copy" ;;
    --dry-run)          dry=1 ;;
    --force)            force=1 ;;
    --uninstall)        uninstall=1 ;;
    --skills-only)      skills_only=1 ;;
    --agent)            agents_arg="${2:-}"; shift ;;
    --agent=*)          agents_arg="${1#*=}" ;;
    --github-skills)    gh_repo="${2:-}"; shift ;;
    --github-skills=*)  gh_repo="${1#*=}" ;;
    -h|--help)          usage; exit 0 ;;
    *) echo "unknown arg: $1  (try --help)" >&2; exit 2 ;;
  esac
  shift
done

[ -d "$src" ] || { echo "no skills/ dir next to install.sh ($src)" >&2; exit 1; }

run() { if [ "$dry" -eq 1 ]; then echo "    + $*"; else eval "$*"; fi; }

# ---------------------------------------------------------------- ownership
# A target skill is maxim-owned iff it is a symlink resolving into THIS repo,
# or it is listed in the dest's .maxim-manifest. Only owned skills are ever
# replaced or removed without --force.
is_owned() {  # is_owned <dest> <name>
  local dest="$1" name="$2" target="$1/$2" rl
  if [ -L "$target" ]; then
    rl="$(readlink -f "$target" 2>/dev/null || true)"
    case "$rl" in "$src"/*) return 0 ;; esac
  fi
  [ -f "$dest/$manifest_name" ] && grep -qxF "$name" "$dest/$manifest_name"
}

write_manifest() {  # write_manifest <dest> <name...>
  local dest="$1"; shift
  local file="$dest/$manifest_name"
  if [ "$dry" -eq 1 ]; then echo "    + would write manifest: $file ($# skills)"; return; fi
  { echo "# maxim-manifest — skills maxim installed here; managed by install.sh."
    echo "# Safe to remove with: install.sh --uninstall"
    echo "# generated: $(date +%F)  mode: $mode  source: $src"
    for n in "$@"; do [ -n "$n" ] && echo "$n"; done
  } > "$file"
}

# ---------------------------------------------------------------- skills
install_skills() {  # install_skills <dest> <label>
  local dest="$1" label="$2" name target
  echo "  $label skills → $dest  (mode: $mode)"
  run "mkdir -p \"$dest\""
  local installed=()
  for skill in "$src"/*/; do
    name="$(basename "$skill")"; target="$dest/$name"
    if [ -e "$target" ] || [ -L "$target" ]; then
      if is_owned "$dest" "$name"; then
        echo "    ~ replacing maxim skill: $name"
        run "rm -rf \"$target\""
      elif [ "$force" -eq 1 ]; then
        echo "    ! --force: replacing FOREIGN skill: $name"
        run "rm -rf \"$target\""
      else
        echo "    ⨯ SKIP (exists, not maxim's): $name  — use --force to replace"
        continue
      fi
    else
      echo "    + installing: $name"
    fi
    if [ "$mode" = "link" ]; then run "ln -s \"${skill%/}\" \"$target\""
    else run "cp -r \"${skill%/}\" \"$target\""; fi
    installed+=("$name")
  done
  write_manifest "$dest" "${installed[@]:-}"
  if [ "$dry" -eq 0 ] && [ -f "$dest/verify/preflight.sh" ]; then
    chmod +x "$dest/verify/preflight.sh" 2>/dev/null || true
  fi
}

uninstall_skills() {  # uninstall_skills <dest> <label>
  local dest="$1" label="$2" name target
  [ -d "$dest" ] || return 0
  echo "  $label skills ← $dest"
  for skill in "$src"/*/; do
    name="$(basename "$skill")"; target="$dest/$name"
    if [ -e "$target" ] || [ -L "$target" ]; then
      if is_owned "$dest" "$name"; then
        echo "    - removing maxim skill: $name"
        run "rm -rf \"$target\""
      else
        echo "    · keeping (not maxim's): $name"
      fi
    fi
  done
  if [ -f "$dest/$manifest_name" ]; then echo "    - removing manifest"; run "rm -f \"$dest/$manifest_name\""; fi
}

# ---------------------------------------------------------------- always-on block
write_block() {  # write_block <file>
  local file="$1" tmp
  if [ "$dry" -eq 1 ]; then
    if [ -f "$file" ] && grep -qF "$BEGIN_MARK" "$file"; then echo "    ~ would refresh maxim block in $file"
    else echo "    + would add maxim block to $file"; fi
    return
  fi
  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp)"
  if [ -f "$file" ]; then
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
      $0==b {skip=1} skip && $0==e {skip=0; next} !skip {print}
    ' "$file" > "$tmp"
  fi
  [ -s "$tmp" ] && [ -n "$(tail -c1 "$tmp")" ] && printf '\n' >> "$tmp"
  { printf '%s\n' "$BEGIN_MARK"; cat "$block_src"; printf '%s\n' "$END_MARK"; } >> "$tmp"
  mv "$tmp" "$file"
  echo "    ✓ wrote maxim block → $file"
}

remove_block() {  # remove_block <file>
  local file="$1" tmp
  [ -f "$file" ] || return 0
  grep -qF "$BEGIN_MARK" "$file" || return 0
  if [ "$dry" -eq 1 ]; then echo "    - would remove maxim block from $file"; return; fi
  tmp="$(mktemp)"
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0==b {skip=1} skip && $0==e {skip=0; next} !skip {print}
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "    - removed maxim block from $file"
}

# ---------------------------------------------------------------- per-agent
do_agent() {  # do_agent <label> <skills_dest|""> <always_file> <is_copilot 0|1>
  local label="$1" skills_dest="$2" always_file="$3" is_copilot="$4"
  echo "→ $label"
  if [ "$uninstall" -eq 1 ]; then
    [ -n "$skills_dest" ] && uninstall_skills "$skills_dest" "$label"
    remove_block "$always_file"
    return
  fi
  [ -n "$skills_dest" ] && install_skills "$skills_dest" "$label"
  if [ "$skills_only" -eq 0 ]; then write_block "$always_file"; fi
  if [ "$is_copilot" -eq 1 ] && [ "$skills_only" -eq 0 ]; then
    echo "    ℹ Copilot reads custom instructions from the git root, the cwd, and any"
    echo "      dirs in COPILOT_CUSTOM_INSTRUCTIONS_DIRS. To apply maxim globally, add"
    echo "      this to your shell profile (it is NOT edited for you):"
    echo "        export COPILOT_CUSTOM_INSTRUCTIONS_DIRS=\"\$HOME/.copilot\${COPILOT_CUSTOM_INSTRUCTIONS_DIRS:+,\$COPILOT_CUSTOM_INSTRUCTIONS_DIRS}\""
  fi
}

process_agent() {
  case "$1" in
    vibe)    do_agent "Mistral Vibe"      "${VIBE_SKILLS_DIR:-$HOME/.vibe/skills}"     "$HOME/.vibe/AGENTS.md"   0 ;;
    claude)  do_agent "Claude Code"       "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}" "$HOME/.claude/CLAUDE.md" 0 ;;
    copilot) do_agent "GitHub Copilot CLI" ""                                          "$HOME/.copilot/AGENTS.md" 1 ;;
    *) echo "unknown agent: $1  (use vibe|claude|copilot|all)" >&2; exit 2 ;;
  esac
}

detected_agents() {
  [ -d "$HOME/.vibe" ]   && echo vibe
  [ -d "$HOME/.claude" ] && echo claude
  { command -v copilot >/dev/null 2>&1 || [ -d "$HOME/.copilot" ]; } && echo copilot
}

# ---------------------------------------------------------------- repo bundle
github_skills() {  # github_skills <repo>
  local repo="$1" dest="$1/.github/skills"
  echo "→ Repo bundle (.github/skills) — Copilot & any agentskills-aware tool"
  [ -d "$repo" ] || { echo "  repo path not found: $repo" >&2; exit 1; }
  if [ "$uninstall" -eq 1 ]; then
    uninstall_skills "$dest" "repo"
    remove_block "$repo/.github/copilot-instructions.md"
    return
  fi
  install_skills "$dest" "repo"
  if [ "$skills_only" -eq 0 ]; then write_block "$repo/.github/copilot-instructions.md"; fi
}

# ---------------------------------------------------------------- main
echo "maxim install  (source: $src)"
[ "$dry" -eq 1 ] && echo "  DRY RUN — nothing will be written"
echo

ran_something=0
if [ -n "$gh_repo" ]; then github_skills "$gh_repo"; ran_something=1; fi

# Run agent installs when agents were named explicitly, or by default (no repo-only run).
if [ -n "$agents_arg" ] || [ -z "$gh_repo" ]; then
  declare -a agents=()
  if [ -n "$agents_arg" ]; then
    IFS=', ' read -r -a agents <<< "$agents_arg"
  fi
  # expand "all" or default to detected
  if [ "${#agents[@]}" -eq 0 ] || printf '%s\n' "${agents[@]}" | grep -qx all; then
    mapfile -t agents < <(detected_agents)
  fi
  if [ "${#agents[@]}" -eq 0 ]; then
    echo "→ No agents detected (~/.vibe, ~/.claude, copilot). Name one with --agent,"
    echo "  or bundle into a repo with --github-skills DIR."
  else
    for a in "${agents[@]}"; do [ -n "$a" ] && process_agent "$a"; done
    ran_something=1
  fi
fi

echo
if [ "$dry" -eq 1 ]; then
  echo "Done (dry run). Re-run without --dry-run to apply."
elif [ "$ran_something" -eq 1 ] && [ "$uninstall" -eq 0 ]; then
  echo "Done. Start a NEW agent session so it picks up the skills."
  echo "Add an AGENTS.md to your project for stack/constraints (see AGENTS.example.md)."
elif [ "$uninstall" -eq 1 ]; then
  echo "Uninstall complete. Only maxim-managed skills and blocks were removed."
fi
