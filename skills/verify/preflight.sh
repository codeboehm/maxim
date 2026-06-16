#!/usr/bin/env bash
#
# preflight.sh — deterministic pre-flight checks for a planning artifact
# (a spec, plan, or analysis). Part of the `verify` skill.
#
# Catches the cheap, mechanical failures so the model never has to reason about
# them — and so it cannot rubber-stamp past them:
#   A. Banned calibration words   (DEFINITIVE / PROVEN / SUPERSEDES / GUARANTEED)
#   B. Contradictory conclusions  (asserts both "no changes" and "changes required")
#   C. Unresolvable file:line citations (file missing, or line beyond EOF)
#   D. Quoted code token not found near its citation        (WARN — advisory)
#   E. Behavioral/security claim with no adjacent evidence  (FAIL)
#
# Run this on the ARTIFACT UNDER REVIEW (the spec/plan), not on a verification
# report — a report legitimately quotes banned words in its calibration section.
#
# Usage: bash preflight.sh <artifact.md> [search-root ...]
# Exit:  0 = clean · 1 = one or more checks failed (treat as auto-FAIL) · 2 = usage

set -uo pipefail

artifact="${1:-}"
if [ -z "$artifact" ] || [ ! -f "$artifact" ]; then
  echo "usage: bash preflight.sh <artifact.md> [search-root ...]" >&2
  exit 2
fi
shift || true

# Search root(s) for citation resolution: explicit args, else the artifact's git
# tree, else its directory. The tree is walked directly (find), so submodule
# working files are included — unlike `git ls-files`, which stops at gitlinks.
roots=("$@")
if [ "${#roots[@]}" -eq 0 ]; then
  root="$(git -C "$(dirname "$artifact")" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -z "$root" ] && root="$(cd "$(dirname "$artifact")" && pwd)"
  roots=("$root")
fi

fail=0
echo "== Pre-flight: $artifact =="
echo

# ---- A. Banned calibration words -------------------------------------------
echo "-- A. Banned calibration words --"
if grep -niE '\b(definitive|proven|supersedes|guaranteed)\b' "$artifact"; then
  echo "  -> FAIL: remove emphatic claim-words; show the evidence instead."
  fail=1
else
  echo "  ok: none found"
fi
echo

# ---- B. Contradictory conclusions ------------------------------------------
# A line stating "no [...] changes required" matches both patterns; treat any
# line that is itself a no-change statement as NEG only, so a single, consistent
# "no changes required" verdict doesn't read as a contradiction.
echo "-- B. Contradictory conclusion (no-change vs change-required) --"
neg="$(grep -niE 'no (changes?|action|code changes?)[a-z ]{0,20}(warranted|required|needed|necessary)' "$artifact" || true)"
pos_all="$(grep -niE '\b(changes (required|warranted|needed)|action required)\b' "$artifact" || true)"
neg_nums=" $(printf '%s\n' "$neg" | grep -oE '^[0-9]+' | sort -un | tr '\n' ' ')"
pos=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  ln="${line%%:*}"
  case "$neg_nums" in *" $ln "*) continue ;; esac
  pos+="$line"$'\n'
done <<< "$pos_all"
pos="$(printf '%s' "$pos" | sed '/^[[:space:]]*$/d')"
if [ -n "$neg" ] && [ -n "$pos" ]; then
  echo "  -> FAIL: document asserts BOTH conclusions:"
  echo "  no-change:";        printf '%s\n' "$neg" | sed 's/^/    /'
  echo "  change-required:";  printf '%s\n' "$pos" | sed 's/^/    /'
  fail=1
else
  echo "  ok: single consistent conclusion (or none detected)"
fi
echo

# ---- C. file:line citations resolve ----------------------------------------
echo "-- C. Unresolvable file:line citations --"
INDEX="$(
  for r in "${roots[@]}"; do
    find "$r" -type f \
      -not -path '*/.git/*' -not -path '*/node_modules/*' \
      -not -path '*/vendor/*' -not -path '*/session/*' -not -path '*/logs/*' \
      2>/dev/null
  done
)"

citations="$(grep -oE '[A-Za-z0-9_./-]+\.(php|js|ts|sql|json|md|scss|css|html|sh|py|java):[0-9][0-9,\-]*' "$artifact" | sort -u || true)"

cite_fail=0
if [ -z "$citations" ]; then
  echo "  (no file:line citations found)"
else
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    file="${tok%:*}"
    spec="${tok##*:}"

    # Highest line referenced: ranges a-b -> b, lists a,b,c -> max.
    maxline=0
    IFS=',' read -ra parts <<< "$spec"
    for p in "${parts[@]}"; do
      hi="${p##*-}"
      [[ "$hi" =~ ^[0-9]+$ ]] || continue
      (( hi > maxline )) && maxline="$hi"
    done

    # Resolve: suffix-path match first, then bare basename.
    esc="$(printf '%s' "$file" | sed 's/[.[\*^$/]/\\&/g')"
    hits="$(printf '%s\n' "$INDEX" | grep -E "(^|/)$esc$" || true)"
    if [ -z "$hits" ]; then
      escb="$(printf '%s' "$(basename "$file")" | sed 's/[.[\*^$/]/\\&/g')"
      hits="$(printf '%s\n' "$INDEX" | grep -E "(^|/)$escb$" || true)"
    fi
    if [ -z "$hits" ]; then
      echo "  MISSING FILE: $tok  (nothing matches '$file')"
      cite_fail=1; continue
    fi

    # OK if any candidate file is long enough (allow trailing-newline slack).
    ok=0
    while IFS= read -r cand; do
      [ -z "$cand" ] && continue
      lc="$(wc -l < "$cand" 2>/dev/null | tr -d ' ')"; [ -z "$lc" ] && lc=0
      (( lc + 1 >= maxline )) && { ok=1; break; }
    done <<< "$hits"
    if [ "$ok" -eq 0 ]; then
      best="$(printf '%s\n' "$hits" | head -1)"
      lc="$(wc -l < "$best" 2>/dev/null | tr -d ' ')"
      echo "  LINE OUT OF RANGE: $tok  (file has ~$lc lines)"
      cite_fail=1
    fi
  done <<< "$citations"
  [ "$cite_fail" -eq 0 ] && echo "  ok: all citations resolve"
fi
[ "$cite_fail" -eq 1 ] && fail=1
echo

# ---- D. Quoted code token actually appears near its citation (WARN) --------
# Heuristic, advisory only. When a markdown line carries BOTH a file:line
# citation AND a code-like `backticked` token, the token should appear within a
# few lines of the citation in the real file. Proposals legitimately cite
# not-yet-existing code, so this WARNS (does not force FAIL) — but it surfaces
# "I cited X:42 for `foo`, but `foo` isn't at X:42" mismatches for the reviewer.
echo "-- D. Quoted token appears near its citation (advisory) --"
resolve_file() {
  local f="$1" esc hits
  esc="$(printf '%s' "$f" | sed 's/[.[\*^$/]/\\&/g')"
  hits="$(printf '%s\n' "$INDEX" | grep -E "(^|/)$esc$" | head -1 || true)"
  if [ -z "$hits" ]; then
    esc="$(printf '%s' "$(basename "$f")" | sed 's/[.[\*^$/]/\\&/g')"
    hits="$(printf '%s\n' "$INDEX" | grep -E "(^|/)$esc$" | head -1 || true)"
  fi
  printf '%s' "$hits"
}
d_warn=0
while IFS= read -r mdline; do
  cites="$(printf '%s' "$mdline" | grep -oE '[A-Za-z0-9_./-]+\.(php|js|ts|sql|json|md|scss|css|html|sh|py|java):[0-9][0-9,\-]*' || true)"
  [ -z "$cites" ] && continue
  # code-like backticked tokens: must contain :: -> () @ / or be CamelCase
  ctoks="$(printf '%s' "$mdline" | grep -oE '`[^`]+`' | tr -d '`' \
          | grep -oE '@?[A-Za-z_][A-Za-z0-9_]*(::|->)?[A-Za-z0-9_]*(\(\))?(/\*)?' \
          | awk 'length($0)>=3' | sort -u || true)"
  ctoks="$(printf '%s\n' "$ctoks" | grep -E '::|->|\(\)|^@|/|[a-z][A-Z]' || true)"
  [ -z "$ctoks" ] && continue
  matched=0
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    file="${tok%:*}"; spec="${tok##*:}"
    lo="${spec%%[,-]*}"; hi="${spec##*[,-]}"
    [[ "$lo" =~ ^[0-9]+$ ]] || continue
    [[ "$hi" =~ ^[0-9]+$ ]] || hi="$lo"
    path="$(resolve_file "$file")"; [ -z "$path" ] && continue
    window="$(sed -n "$(( lo>5 ? lo-5 : 1 )),$(( hi+5 ))p" "$path" 2>/dev/null)"
    while IFS= read -r ct; do
      [ -z "$ct" ] && continue
      base="${ct%%(*}"; base="${base%%::*}"; base="${base%%->*}"; base="${base%/*}"
      [ -z "$base" ] && continue
      printf '%s' "$window" | grep -qF "$base" && { matched=1; break; }
    done <<< "$ctoks"
    [ "$matched" -eq 1 ] && break
  done <<< "$cites"
  if [ "$matched" -eq 0 ]; then
    echo "  WARN: [$(printf '%s' "$ctoks" | tr '\n' ' ')] not found near [$(printf '%s' "$cites" | tr '\n' ' ')]"
    echo "        $(printf '%s' "$mdline" | sed 's/^[[:space:]]*//' | cut -c1-90)"
    d_warn=1
  fi
done < "$artifact"
[ "$d_warn" -eq 0 ] && echo "  ok: quoted tokens resolve near their citations"
echo

# ---- E. Strong behavioral claims must carry adjacent evidence (FAIL) --------
# The failure mode no model caught: a confident behavioral/security assertion
# ("X can access Y", "breaks server-to-server", "privilege escalation") with no
# grep/caller/file:line evidence beside it. Require evidence on the claim line or
# within +/-3 lines; otherwise it's unsubstantiated. Code fences are skipped.
echo "-- E. Behavioral/security claims carry adjacent evidence --"
claim_re='can access|cannot access|grants? (unrestricted )?access|access (all|any)|would break|breaks? (the )?server|server-to-server|cross-service|privilege escalation|scope bypass|replay attack|\bCSRF\b|must not require|required for (the )?architecture|can.?t happen|cannot happen|\bbypass(es|ed)?\b'
ev_re='[A-Za-z0-9_./-]+\.(php|js|ts|sql|json|sh|py|java):[0-9]|grep |grep"|`grep|rg |->request\(|str_starts_with|str_ends_with'
e_fail=0; infence=0; lineno=0
while IFS= read -r line; do
  lineno=$((lineno+1))
  case "$line" in '```'*) infence=$((1-infence)); continue ;; esac
  [ "$infence" -eq 1 ] && continue
  case "$line" in '#'*|'##'*|'###'*|'####'*|'#####'*) continue ;; esac  # skip headings
  printf '%s' "$line" | grep -qiE "$claim_re" || continue
  printf '%s' "$line" | grep -qiE "$ev_re" && continue
  ctx="$(sed -n "$(( lineno>3 ? lineno-3 : 1 )),$(( lineno+3 ))p" "$artifact")"
  printf '%s' "$ctx" | grep -qiE "$ev_re" && continue
  echo "  UNSUBSTANTIATED (L$lineno): $(printf '%s' "$line" | sed 's/^[[:space:]]*//' | cut -c1-100)"
  e_fail=1
done < "$artifact"
if [ "$e_fail" -eq 0 ]; then
  echo "  ok: behavioral claims carry adjacent evidence"
else
  echo "  -> FAIL: each claim above needs an adjacent grep/caller/file:line, or must be cut."
  fail=1
fi
echo

# ---- Verdict ---------------------------------------------------------------
if [ "$fail" -eq 0 ]; then
  echo "PRE-FLIGHT: PASS (mechanical checks clean${d_warn:+; see D warnings})"
  exit 0
fi
echo "PRE-FLIGHT: FAIL (fix the items above; verdict cannot be PASS)"
exit 1
