#!/usr/bin/env bash
# UserPromptSubmit: tell Claude the context size once it passes a threshold (rule "Switching sessions" in POLICY.md).
SOFT=${CLAUDE_CTX_SOFT:-300000}; HARD=${CLAUDE_CTX_HARD:-450000}
in=$(cat)
t=$(jq -r '.transcript_path // empty' <<<"$in"); [ -f "$t" ] || exit 0
ctx=$(tail -n 400 "$t" | python3 -c '
import json,sys
n=0
for l in sys.stdin:
    try: m=json.loads(l).get("message") or {}
    except Exception: continue
    u=m.get("usage") if isinstance(m,dict) else None
    if u: n=u.get("input_tokens",0)+u.get("cache_read_input_tokens",0)+u.get("cache_creation_input_tokens",0)
print(n)')
[ "${ctx:-0}" -ge "$SOFT" ] || exit 0
k=$((ctx/1000))
if [ "$ctx" -ge "$HARD" ]; then
  msg="Session context: ~${k}k tokens (high threshold ${HARD%000}k). Rule \"Switching sessions\": at the end of the current step (work committed or recorded, nothing pending), record a trace in the vault with a Resume line, then hand over to a new session."
else
  msg="Session context: ~${k}k tokens (threshold ${SOFT%000}k passed). Rule \"Switching sessions\": at the next end of phase, record a trace in the vault with a Resume line, then hand over to a new session. Never in the middle of a task."
fi
jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$m}}'
