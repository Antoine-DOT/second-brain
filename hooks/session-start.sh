#!/usr/bin/env bash
# SessionStart: pull the vault and give Claude its context (deadlines, recent log, inbox, last Resume line).
# Optional: SECOND_BRAIN_HEALTH_HOST=<ssh host> reads a sync health file (status=OK|ALERT, "- problem" lines)
# written by the server that bridges the phone (see README).
V="${SECOND_BRAIN_VAULT:-$HOME/second-brain}"
[ -d "$V/.git" ] || exit 0
# Session marker for the Stop check (kept on resume/compact).
in=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$in" 2>/dev/null)
src=$(jq -r '.source // empty' <<<"$in" 2>/dev/null)
if [ -n "$sid" ]; then
  mkdir -p "$HOME/.claude/second-brain-state"
  m="$HOME/.claude/second-brain-state/$sid"; [ -f "$m" ] || date +%s > "$m"
fi
pull=$(GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=8" git -C "$V" pull --rebase --autostash --quiet 2>&1) && status="up to date" || status="pull failed (${pull%%$'\n'*}): work locally, reconcile later"
log=$(grep "^## \[" "$V/wiki/log.md" 2>/dev/null | tail -5)
# Inbox: lines written after the marker in Inbox.md (mostly from the phone).
n_inbox=$(sed -n '/<!-- inbox:start -->/,$p' "$V/Inbox.md" 2>/dev/null | tail -n +2 | grep -c '[^[:space:]]')
inbox=""; [ "${n_inbox:-0}" -gt 0 ] && inbox="
📥 Inbox: $n_inbox item(s) to triage in $V/Inbox.md. If the session is interactive and the request is not urgent, triage them first following the \"Inbox\" section of $V/CLAUDE.md, then reply \"📥 inbox triaged: …\"."
health="" msg=""
if [ -n "$SECOND_BRAIN_HEALTH_HOST" ]; then
  h=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$SECOND_BRAIN_HEALTH_HOST" cat "${SECOND_BRAIN_HEALTH_FILE:-livesync/health.txt}" 2>/dev/null) || h="- sync server unreachable: state unknown"
  probs=$(grep '^- ' <<<"$h")
  checked=$(sed -n 's/^checked=//p' <<<"$h")
  [ -n "$checked" ] && [ $(( $(date +%s) - checked )) -gt 1200 ] && probs="$probs
- health check stopped $(( ($(date +%s) - checked) / 60 )) min ago"
  probs=$(sed '/^$/d' <<<"$probs")
  health="
Vault sync: OK."
  [ -n "$probs" ] && health="
⚠️ VAULT SYNC ALERT, report it at the top of your reply:
$probs" && msg="⚠️ Vault sync: $(tr '\n' ' ' <<<"$probs")"
fi
due=$(sed -n '/^## 📅 Upcoming deadlines/,/^## /p' "$V/Home.md" 2>/dev/null | grep "^- " | head -6)
# After a /clear: hand back the latest Resume line so the new conversation does not start blank.
resume=""
if [ "$src" = clear ]; then
  f=$(ls -t "$V"/raw/sessions/*.md 2>/dev/null | head -20 | while read -r x; do grep -qE "^(- )?(\*\*)?Resume" "$x" && { echo "$x"; break; }; done)
  [ -n "$f" ] && resume="
🔁 Resuming after a session switch ($f):
$(grep -m1 -E "^(- )?(\*\*)?Resume" "$f")
Re-read this report and the project page, restore the working environment, sum up where things stand in 3 lines, then wait for the user."
fi
ctx="Vault ($V, $status): durable memory for projects, infrastructure, ideas and the journal. Before working on a project or a machine, read wiki/index.md, then wiki/projects/<project>.md or wiki/entities/<host>.md. After a deployment, an infrastructure change or a validation, write raw/sessions/… and update the wiki following $V/CLAUDE.md, then commit + push. Capture as you go: any durable information (fact, decision, deadline, thought) goes to the right page in the same turn, with \"📝 noted in <page>\", then python3 $V/scripts/dashboard.py. Dashboard: $V/Home.md. Upcoming deadlines:
$due
Latest log entries:
$log$health$inbox$resume"
if [ -n "$msg" ]; then jq -n --arg c "$ctx" --arg m "$msg" '{systemMessage:$m,hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
else jq -n --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'; fi
