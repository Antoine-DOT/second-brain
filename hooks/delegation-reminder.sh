#!/usr/bin/env bash
# Stop: for repos in "efficient" mode, remind once per session when code was committed or
# edited without any `codex exec` (feature code should go to the delegated agent).
# Set SECOND_BRAIN_DELEGATE_PATHS to a list of path fragments, e.g. "my-app:other-repo".
in=$(cat)
[ "$(jq -r '.stop_hook_active // false' <<<"$in")" = true ] && exit 0
cwd=$(jq -r '.cwd // empty' <<<"$in"); hit=""
IFS=: read -ra frags <<<"${SECOND_BRAIN_DELEGATE_PATHS:-}"
for f in "${frags[@]}"; do [ -n "$f" ] && case "$cwd" in *"$f"*) hit=1;; esac; done
[ -n "$hit" ] || exit 0
sid=$(jq -r '.session_id // empty' <<<"$in"); t=$(jq -r '.transcript_path // empty' <<<"$in")
[ -n "$sid" ] && [ -f "$t" ] || exit 0
m="$HOME/.claude/second-brain-state/codex-reminded-$sid"; [ -f "$m" ] && exit 0
V="${SECOND_BRAIN_VAULT:-$HOME/second-brain}"
read -r code codex < <(python3 -c '
import json,re,sys
vault=sys.argv[2]
code=codex=0
for l in open(sys.argv[1]):
    try: c=json.loads(l).get("message",{}).get("content")
    except Exception: continue
    if not isinstance(c,list): continue
    for b in c:
        if not isinstance(b,dict) or b.get("type")!="tool_use": continue
        i=b.get("input") or {}
        if b.get("name") in ("Edit","Write","MultiEdit") and vault not in str(i.get("file_path","")): code+=1
        cmd=str(i.get("command",""))
        if "codex exec" in cmd: codex+=1
        elif re.search(r"git\b[^|;&]*\bcommit\b",cmd) and vault not in cmd: code+=1
print(code,codex)' "$t" "$V")
[ "${codex:-0}" -eq 0 ] && [ "${code:-0}" -gt 0 ] || exit 0
mkdir -p "${m%/*}"; touch "$m"
jq -n '{decision:"block",reason:"Reminder (once per session): this repository delegates feature work (POLICY.md). Code was committed or edited without any `codex exec`. If this was a feature or a large design pass, the rest goes to Codex (Claude writes the brief and reviews). If it was a small fix or an operation, say so in one line and stop."}'
