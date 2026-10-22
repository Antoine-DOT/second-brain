#!/usr/bin/env bash
# Stop: block once if repos got commits during the session but the vault did not.
V="${SECOND_BRAIN_VAULT:-$HOME/second-brain}"
[ -d "$V/.git" ] || exit 0
in=$(cat)
[ "$(jq -r '.stop_hook_active // false' <<<"$in")" = true ] && exit 0
sid=$(jq -r '.session_id // empty' <<<"$in"); [ -n "$sid" ] || exit 0
cwd=$(jq -r '.cwd // empty' <<<"$in")
d="$HOME/.claude/second-brain-state"; m="$d/$sid"; mkdir -p "$d"
now=$(date +%s)
[ -f "$m" ] || { echo "$now" > "$m"; exit 0; }
since=$(cat "$m")
newer() { git -C "$1" log --all --format=%ct --max-count=200 2>/dev/null | awk -v t="$since" '$1>t{n++} END{print n+0}'; }
repos=""; vreal=$(cd "$V" && pwd -P)
for r in "$HOME"/projects/*/ "$HOME"/Developer/*/ "$cwd"; do
  [ -n "$r" ] && top=$(git -C "$r" rev-parse --show-toplevel 2>/dev/null) || continue
  [ "$(cd "$top" && pwd -P)" = "$vreal" ] && continue
  case " $repos " in *" $top "*) continue;; esac
  [ "$(newer "$top")" -gt 0 ] && repos="$repos $top"
done
[ -n "$repos" ] || exit 0
echo "$now" > "$m"   # block at most once per batch of commits
[ "$(newer "$V")" -gt 0 ] && exit 0
names=$(for r in $repos; do basename "$r"; done | paste -sd, - | sed 's/,/, /g')
jq -n --arg r "Commits were made during this session ($names) but the vault ($V) was not updated. If the work has lasting value (deployment, infrastructure change, validation, decision), write raw/sessions/YYYY-MM-DD-<project>-<slug>.md, update wiki/projects/<project>.md, the entities touched, wiki/index.md and wiki/log.md following $V/CLAUDE.md, then git commit + push. Otherwise (small local work), say so in one line and stop." '{decision:"block",reason:$r}'
