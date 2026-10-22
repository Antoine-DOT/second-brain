# second-brain

The structure of the second brain I use every day with Claude Code and Codex:
an Obsidian vault that AI agents read at the start of a session and update
at the end. This repository contains the schema, the scripts and the hooks,
with an example project. None of my own content is here.

It follows Andrej Karpathy's [LLM Wiki](https://gist.github.com/karpathy) idea:
the agent does not search your notes from scratch every time (that would be
RAG). It maintains a wiki: when something new comes in, it updates the pages
it affects, the links between them, an index and a log. I pick the sources and
make the decisions. The agent does the bookkeeping.

## What it does for me

- **Memory across sessions.** Each project has a page with its state,
  decisions and next step. After real work (a release, an infra change),
  the agent writes a short session report and updates that page. The next
  session, with the same agent or another one, picks up from there.
- **A dashboard.** `Home.md` lists deadlines, active projects and open
  questions. It is generated from a few frontmatter fields
  (`scripts/dashboard.py`).
- **An inbox on my phone.** I write one line in `Inbox.md` from my iPhone.
  At the next session, the agent files each line where it belongs.
- **Reading notes.** When I say "note this" about a book, an article or a
  video, the agent stores the exact words, a page for the work, and links to
  topic pages. When I prepare a post, it brings back what I captured on that
  topic, with exact sources. A paraphrase is never presented as a quote.
- **Guardrails.** An idea is never turned into a task without my decision.
  No secrets in the vault, only where they are stored. When the vault
  disagrees with git or the live system, the technical source wins.

## Layout

```text
CLAUDE.md          the schema: how the agent reads, writes and maintains the vault
AGENTS.md          link to CLAUDE.md, for Codex
POLICY.md          short rules to paste into ~/.claude/CLAUDE.md (global instructions)
Home.md            dashboard (the block between the markers is generated)
Inbox.md           quick capture, mostly from the phone
Library.md         reading list, generated
raw/               sources, journal, ideas, session reports: never edited afterwards
wiki/              everything the agent writes: projects, entities, concepts, analyses
scripts/           dashboard.py
hooks/             Claude Code hooks
.obsidian/         minimal settings and a CSS snippet that hides the agents' files
```

## Hooks (Claude Code)

| Hook | Event | What it does |
| --- | --- | --- |
| `session-start.sh` | SessionStart | Pulls the vault and gives the agent the upcoming deadlines, the latest log entries and the number of items waiting in the inbox. After a `/clear`, it also hands back the last "Resume" line, so the new session does not start blank. |
| `stop-check.sh` | Stop | If code was committed during the session but the vault was not touched, asks the agent once whether the work deserves a trace. |
| `context-size-check.sh` | UserPromptSubmit | Warns when the context gets large, so the session is handed over at the end of a phase, never in the middle of a task. |
| `delegation-reminder.sh` | Stop | For repositories listed in `SECOND_BRAIN_DELEGATE_PATHS`, reminds the agent that feature code goes to Codex while Claude reviews. Optional. |

They need `jq`, `git` and `python3`. See `hooks/settings.example.json`.

## Getting started

```bash
git clone https://github.com/Antoine-DOT/second-brain.git ~/second-brain
cd ~/second-brain && rm -rf .git && git init   # it's your vault now
python3 scripts/dashboard.py
```

1. Open the folder in Obsidian and enable the `hide-system` CSS snippet
   if it is not already enabled.
2. Copy `hooks/*.sh` to `~/.claude/hooks/` and merge
   `hooks/settings.example.json` into `~/.claude/settings.json`. Set
   `SECOND_BRAIN_VAULT` to the vault path.
3. Paste `POLICY.md` into `~/.claude/CLAUDE.md` and replace `__VAULT__` with
   the vault path.
4. Push the vault to a private git remote you control. Do not put it in an
   iCloud folder: iCloud creates conflict copies, even inside `.git`.
5. Delete `wiki/projects/example.md` and its session report once you have
   seen the format.

## Phone sync (optional)

My setup: Obsidian on the iPhone with the Self-hosted LiveSync plugin, a
CouchDB on a small server reachable only over my VPN, a bridge that writes
the vault to a git clone on that server, and a timer that commits and pushes
every few minutes. The Mac pulls on the same schedule. The server also writes
a small health file, which the start hook reads (`SECOND_BRAIN_HEALTH_HOST`)
so a broken sync is reported at the start of the next session.

That part depends on your own infrastructure, so it is described here
rather than shipped as scripts.

## License

MIT
